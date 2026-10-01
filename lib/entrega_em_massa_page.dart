import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart';
import 'model/pacote.dart';
import 'services/entrega_status_service.dart';
import 'services/localizacao_service.dart';
import 'utils/codigo_rastreio.dart';

class _ItemLote {
  final String codigo;
  final String transportadora;
  final File foto;

  _ItemLote({
    required this.codigo,
    required this.transportadora,
    required this.foto,
  });
}

/// Bipa vários pacotes em sequência para o mesmo recebedor/local — só o
/// nome do recebedor e o GPS são compartilhados pelo lote. Antes de salvar,
/// mostra uma tela de conferência com a lista completa e o total de
/// pacotes.
///
/// A "foto do pacote" é o próprio frame que o leitor de código capturou no
/// momento do bipe (returnImage: true no MobileScannerController), não uma
/// foto tirada numa câmera separada depois. Chegou a existir uma 2ª câmera
/// dedicada pra foto (como na entrega individual), mas abrir/fechar duas
/// câmeras diferentes em sequência repetidas vezes causava uma disputa de
/// hardware real nesse fluxo ("No supported surface combination",
/// "controllerAlreadyInitialized") que nem aumentar bastante as pausas de
/// segurança resolvia de vez — usar só a câmera do leitor elimina a troca
/// de câmera inteira.
class EntregaEmMassaPage extends StatefulWidget {
  const EntregaEmMassaPage({super.key});

  @override
  State<EntregaEmMassaPage> createState() => _EntregaEmMassaPageState();
}

class _EntregaEmMassaPageState extends State<EntregaEmMassaPage> {
  final nomeController = TextEditingController();
  final List<_ItemLote> itens = [];
  final Set<String> codigosNoLote = {};

  // Só fica nulo entre a tela de conferência e o leitor (ver
  // _abrirConfirmacao/_voltarParaScannerDaConfirmacao) — durante o
  // escaneamento em si, o controller nunca é descartado, porque a "foto"
  // de cada pacote vem do próprio frame do leitor, sem precisar de uma
  // câmera separada.
  MobileScannerController? controller;
  int _scannerGeracao = 0;
  Directory? _fotosDirCache;

  bool escaneando = false;
  bool confirmando = false;
  bool processandoFoto = false;
  bool salvando = false;

  // O leitor pode falhar ao (re)abrir por vários motivos transitórios
  // (ex: voltando da tela de conferência). Em vez de exigir que o
  // motorista toque em "Tentar novamente" toda vez, tenta de novo sozinho
  // algumas vezes antes de mostrar o botão manual.
  int _tentativasScanner = 0;
  bool _retryScannerAgendado = false;

  double? lat;
  double? lng;

  @override
  void initState() {
    super.initState();
    _pegarGPS();
  }

  @override
  void dispose() {
    nomeController.dispose();
    controller?.dispose();
    super.dispose();
  }

  MobileScannerController _novoScannerController() {
    _scannerGeracao++;
    return MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      // Precisa estar ligado pra BarcodeCapture.image vir preenchido —
      // é esse frame que vira a "foto do pacote" salva no lote.
      returnImage: true,
    );
  }

  Future<void> _pegarGPS() async {
    // GPS é opcional no lote: se não vier, segue sem travar o fluxo.
    final position = await LocalizacaoService.obterLocalizacao();

    if (!mounted || position == null) return;

    setState(() {
      lat = position.latitude;
      lng = position.longitude;
    });
  }

  Future<Directory> _fotosDir() async {
    final cache = _fotosDirCache;
    if (cache != null) return cache;

    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/fotos_entregas');

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _fotosDirCache = dir;
    return dir;
  }

  void _iniciarEscaneamento() {
    if (nomeController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    _tentativasScanner = 0;
    setState(() {
      escaneando = true;
      controller = _novoScannerController();
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (processandoFoto) return;
    if (controller == null) return;
    if (capture.barcodes.isEmpty) return;

    String? codigoLido;

    for (final barcode in capture.barcodes) {
      final valor = barcode.rawValue;
      if (valor == null || valor.trim().isEmpty) continue;

      final limpo = CodigoRastreio.limpar(valor);
      if (CodigoRastreio.valido(limpo)) {
        codigoLido = limpo;
        break;
      }
    }

    if (codigoLido == null) return;

    if (codigosNoLote.contains(codigoLido)) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pacote $codigoLido já foi bipado neste lote.')),
      );
      return;
    }

    // Captura o frame já aqui, antes de qualquer outro await — é a cena
    // exata que o leitor estava vendo no instante do bipe.
    final bytesImagem = capture.image;

    if (bytesImagem == null) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não deu pra capturar a foto, bipe de novo.'),
        ),
      );
      return;
    }

    processandoFoto = true;

    try {
      if (await EntregaStatusService.jaEntregue(codigoLido)) {
        await HapticFeedback.heavyImpact();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pacote $codigoLido já foi entregue anteriormente.'),
          ),
        );
        return;
      }

      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);

      final transportadora = CodigoRastreio.transportadora(codigoLido);
      final codigo = codigoLido;

      final dir = await _fotosDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final arquivoFoto = File('${dir.path}/${codigo}_$timestamp.jpg');
      await arquivoFoto.writeAsBytes(bytesImagem);

      if (!mounted) return;

      setState(() {
        itens.add(
          _ItemLote(
            codigo: codigo,
            transportadora: transportadora,
            foto: arquivoFoto,
          ),
        );
        codigosNoLote.add(codigo);
      });
    } finally {
      // Sem câmera pra trocar e reabrir, não precisa de pausa nenhuma
      // aqui — o leitor nunca saiu do ar durante o bipe.
      processandoFoto = false;
    }
  }

  void _reiniciarScanner() {
    _tentativasScanner = 0;
    _retryScannerAgendado = false;
    setState(() => controller = _novoScannerController());
  }

  void _agendarRetryScannerAutomatico() {
    const maxTentativasAutomaticas = 3;

    if (_retryScannerAgendado ||
        _tentativasScanner >= maxTentativasAutomaticas) {
      return;
    }

    _retryScannerAgendado = true;
    _tentativasScanner++;

    Future.delayed(Duration(milliseconds: 500 * _tentativasScanner), () {
      _retryScannerAgendado = false;
      if (!mounted) return;
      setState(() => controller = _novoScannerController());
    });
  }

  void _removerItem(int index) {
    setState(() {
      codigosNoLote.remove(itens[index].codigo);
      itens.removeAt(index);
    });
  }

  Future<void> _abrirConfirmacao() async {
    if (itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bipe pelo menos um pacote antes de finalizar.'),
        ),
      );
      return;
    }

    final controladorAtual = controller;
    setState(() {
      controller = null;
      confirmando = true;
    });
    await controladorAtual?.dispose();
  }

  void _voltarParaScannerDaConfirmacao() {
    setState(() {
      confirmando = false;
      controller = _novoScannerController();
    });
  }

  Future<Pacote> _salvarItemDoLote({
    required _ItemLote item,
    required User usuario,
    required Map<String, dynamic>? motorista,
    required String nomeRecebedor,
  }) async {
    final dadosEntrega = {
      'codigo': item.codigo,
      'transportadora': item.transportadora,
      'recebedor': nomeRecebedor,
      'entregue': true,

      'fotoPath': item.foto.path,
      'fotoUrl': null,
      'fotoServerPath': null,
      'fotoSincronizada': false,

      'lat': lat,
      'lng': lng,

      'dataEntrega': Timestamp.now(),

      'motoristaId': usuario.uid,
      'motoristaEmail': usuario.email ?? '',
      'motoristaNome': motorista?['nome'] ?? '',
      'motoristaTelefone': motorista?['telefone'] ?? '',
      'motoristaTransportadora':
          motorista?['transportadora'] ?? item.transportadora,
    };

    // Filtra também por motoristaId: sem isso, a busca tenta enxergar
    // entregas de qualquer dono, e a regra do Firestore recusa a consulta
    // inteira pra quem não é admin (ela não consegue provar que só
    // voltariam documentos que esse motorista pode ler).
    final consulta = await FirebaseFirestore.instance
        .collection('entregas')
        .where('codigo', isEqualTo: item.codigo)
        .where('motoristaId', isEqualTo: usuario.uid)
        .limit(1)
        .get();

    if (consulta.docs.isNotEmpty) {
      await consulta.docs.first.reference.update(dadosEntrega);
    } else {
      await FirebaseFirestore.instance.collection('entregas').add({
        ...dadosEntrega,
        'dataLeitura': Timestamp.now(),
      });
    }

    return Pacote(
      codigo: item.codigo,
      transportadora: item.transportadora,
      dataLeitura: DateTime.now(),
      nomeRecebedor: nomeRecebedor,
      fotoPath: item.foto.path,
      lat: lat,
      lng: lng,
      entregue: true,
    );
  }

  Future<void> _salvarLote() async {
    setState(() => salvando = true);

    try {
      final usuario = FirebaseAuth.instance.currentUser;

      if (usuario == null) {
        throw Exception('Usuário não autenticado. Faça login novamente.');
      }

      final nomeRecebedor = nomeController.text.trim();

      final motoristaDoc = await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(usuario.uid)
          .get();

      final motorista = motoristaDoc.data();

      // Um pacote por vez, esperando cada consulta+escrita terminar antes de
      // ir pro próximo, deixava "Salvando lote..." parado por muito tempo em
      // lotes grandes (cada item é uma query + um write, sequenciais). Como
      // cada item tem um código único dentro do lote (garantido por
      // codigosNoLote ao bipar), não há dependência entre eles — rodar em
      // paralelo é seguro e corta o tempo total de N vezes o round-trip de
      // rede pra só um.
      final pacotesAtualizados = await Future.wait(
        itens.map(
          (item) => _salvarItemDoLote(
            item: item,
            usuario: usuario,
            motorista: motorista,
            nomeRecebedor: nomeRecebedor,
          ),
        ),
      );

      for (final pacoteAtualizado in pacotesAtualizados) {
        final index = listaPacotes.indexWhere(
          (p) => p.codigo == pacoteAtualizado.codigo,
        );

        if (index >= 0) {
          listaPacotes[index] = pacoteAtualizado;
        } else {
          listaPacotes.add(pacoteAtualizado);
        }
      }

      if (!mounted) return;
      Navigator.pop(context, itens.length);
    } catch (e) {
      if (!mounted) return;

      setState(() => salvando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar lote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _telaNome() {
    final gpsOk = lat != null && lng != null;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Entrega em massa')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.dynamic_feed,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Bipe vários pacotes seguidos pro mesmo recebedor e local',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'O nome do recebedor e a localização valem pra todo o lote. '
              'Cada pacote continua tirando a foto de sempre.',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nomeController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Nome de quem recebeu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    gpsOk ? Icons.check_circle : Icons.location_searching,
                    color: gpsOk ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      gpsOk
                          ? 'GPS OK'
                          : 'GPS não disponível (não impede de começar)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (!gpsOk)
                    TextButton(
                      onPressed: _pegarGPS,
                      child: const Text('Tentar de novo'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: nomeController.text.trim().isEmpty
                    ? null
                    : _iniciarEscaneamento,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Começar a bipar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _telaScanner() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null)
            MobileScanner(
              // Key nova a cada recriação força o mobile_scanner a
              // desmontar e montar a view nativa do zero, em vez de
              // tentar reaproveitar uma sessão de câmera antiga.
              key: ValueKey(_scannerGeracao),
              controller: controller!,
              onDetect: _onDetect,
              fit: BoxFit.cover,
              errorBuilder: (context, error) {
                // A causa mais comum aqui é a câmera de foto ainda não ter
                // liberado o hardware a tempo — um problema transitório,
                // não algo que o motorista precise resolver tocando em um
                // botão toda vez. Agenda a nova tentativa fora do build().
                final aindaTentandoSozinho =
                    _tentativasScanner < 3 || _retryScannerAgendado;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _agendarRetryScannerAutomatico(),
                );

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (aindaTentandoSozinho) ...[
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          const Text(
                            'Reconectando a câmera...',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ] else ...[
                          const Icon(
                            Icons.no_photography,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Não foi possível abrir a câmera: '
                            '${error.errorCode.name}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _reiniciarScanner,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      _BotaoCircularLote(
                        icon: Icons.close,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${itens.length} pacote(s) — ${nomeController.text.trim()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (itens.isNotEmpty) _tiraListaEscaneados(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _abrirConfirmacao,
                      icon: const Icon(Icons.playlist_add_check),
                      label: Text('Revisar e finalizar (${itens.length})'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiraListaEscaneados() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: itens.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = itens[index];
          final cacheSize = (56 * MediaQuery.devicePixelRatioOf(context))
              .round();

          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  item.foto,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  cacheWidth: cacheSize,
                  cacheHeight: cacheSize,
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => _removerItem(index),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _telaConfirmacao() {
    final colors = Theme.of(context).colorScheme;
    final nomeRecebedor = nomeController.text.trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || salvando) return;
        _voltarParaScannerDaConfirmacao();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Conferir lote'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: salvando ? null : _voltarParaScannerDaConfirmacao,
          ),
        ),
        body: salvando
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Salvando lote...'),
                  ],
                ),
              )
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          color: colors.onPrimaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${itens.length} pacote${itens.length == 1 ? '' : 's'} '
                                'pronto${itens.length == 1 ? '' : 's'} pra finalizar',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                              Text(
                                'Recebedor: ${nomeRecebedor.isEmpty ? '—' : nomeRecebedor}',
                                style: TextStyle(
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: itens.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum pacote no lote',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            itemCount: itens.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = itens[index];
                              final cacheSize =
                                  (52 * MediaQuery.devicePixelRatioOf(context))
                                      .round();

                              return Material(
                                color: colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                          item.foto,
                                          width: 52,
                                          height: 52,
                                          fit: BoxFit.cover,
                                          cacheWidth: cacheSize,
                                          cacheHeight: cacheSize,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.codigo,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.transportadora,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _removerItem(index),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: itens.isEmpty ? null : _salvarLote,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text('Confirmar entrega (${itens.length})'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (confirmando) return _telaConfirmacao();
    return escaneando ? _telaScanner() : _telaNome();
  }
}

class _BotaoCircularLote extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _BotaoCircularLote({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
