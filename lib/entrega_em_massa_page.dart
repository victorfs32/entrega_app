import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import 'camera_entrega_page.dart';
import 'main.dart';
import 'model/pacote.dart';
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

/// Bipa vários pacotes em sequência para o mesmo recebedor/local, tirando
/// uma foto individual de cada um (a foto continua sendo a prova de entrega
/// por pacote — só o nome do recebedor e o GPS são compartilhados pelo lote).
class EntregaEmMassaPage extends StatefulWidget {
  const EntregaEmMassaPage({super.key});

  @override
  State<EntregaEmMassaPage> createState() => _EntregaEmMassaPageState();
}

class _EntregaEmMassaPageState extends State<EntregaEmMassaPage> {
  final nomeController = TextEditingController();
  final List<_ItemLote> itens = [];
  final Set<String> codigosNoLote = {};

  // Nulo enquanto a câmera de foto está aberta ou sendo trocada: o
  // mobile_scanner e o camera disputam o mesmo hardware, então o leitor
  // fica sem controller (tela mostra um loading) até a foto voltar.
  MobileScannerController? controller;
  int _scannerGeracao = 0;
  Directory? _fotosDirCache;

  bool escaneando = false;
  bool processandoFoto = false;
  bool salvando = false;

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
      returnImage: false,
    );
  }

  Future<void> _pegarGPS() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      );

      if (!mounted) return;

      setState(() {
        lat = position.latitude;
        lng = position.longitude;
      });
    } catch (_) {
      // GPS é opcional no lote: se não vier, segue sem travar o fluxo.
    }
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

    processandoFoto = true;

    // Fecha o leitor de vez (não só stop()) antes de abrir a câmera de
    // foto. Um stop() sozinho pode deixar a sessão de câmera "presa" no
    // driver do aparelho, e a segunda câmera (a de foto) abre com tela
    // preta porque não consegue pegar o hardware.
    final controladorAntigo = controller;
    setState(() => controller = null);
    await controladorAntigo?.dispose();

    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.click);

    if (!mounted) return;

    final transportadora = CodigoRastreio.transportadora(codigoLido);
    final codigo = codigoLido;

    final foto = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (_) => const CameraEntregaPage()),
    );

    if (foto != null && mounted) {
      final dir = await _fotosDir();
      final nomeArquivo = '${codigo}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fotoSalva = await foto.copy('${dir.path}/$nomeArquivo');

      if (mounted) {
        setState(() {
          itens.add(
            _ItemLote(
              codigo: codigo,
              transportadora: transportadora,
              foto: fotoSalva,
            ),
          );
          codigosNoLote.add(codigo);
        });
      }
    }

    // A câmera de foto agora espera o próprio dispose() antes de fechar a
    // tela (camera_entrega_page.dart), mas a confirmação que o Android/iOS
    // dá pro plugin nem sempre significa que o hardware já está 100% livre
    // no driver. Essa pausa extra é a margem de segurança pra evitar a
    // corrida — sem ela, o leitor às vezes abre com tela preta.
    await Future.delayed(const Duration(milliseconds: 600));

    processandoFoto = false;
    if (!mounted) return;

    setState(() => controller = _novoScannerController());
  }

  void _reiniciarScanner() {
    setState(() => controller = _novoScannerController());
  }

  void _removerItem(int index) {
    setState(() {
      codigosNoLote.remove(itens[index].codigo);
      itens.removeAt(index);
    });
  }

  Future<void> _confirmarFinalizacao() async {
    if (itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bipe pelo menos um pacote antes de finalizar.'),
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar entrega em lote?'),
          content: Text(
            '${itens.length} pacote(s) serão marcados como entregues '
            'para "${nomeController.text.trim()}".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar bipando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    final controladorAtual = controller;
    setState(() => controller = null);
    await controladorAtual?.dispose();

    await _salvarLote();
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

      for (final item in itens) {
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

        final consulta = await FirebaseFirestore.instance
            .collection('entregas')
            .where('codigo', isEqualTo: item.codigo)
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

        final index = listaPacotes.indexWhere((p) => p.codigo == item.codigo);

        final pacoteAtualizado = Pacote(
          codigo: item.codigo,
          transportadora: item.transportadora,
          dataLeitura: DateTime.now(),
          nomeRecebedor: nomeRecebedor,
          fotoPath: item.foto.path,
          lat: lat,
          lng: lng,
          entregue: true,
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

    return Scaffold(
      appBar: AppBar(title: const Text('Entrega em massa')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quem vai receber os pacotes?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Esse nome e a localização atual valem para todos os pacotes '
              'bipados neste lote. A foto continua sendo tirada uma por pacote.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nomeController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Nome de quem recebeu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  gpsOk ? Icons.check_circle : Icons.location_searching,
                  color: gpsOk ? Colors.green : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gpsOk ? 'GPS OK' : 'Pegando GPS... (não impede de começar)',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const Spacer(),
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
      body: salvando
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Salvando lote...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : Stack(
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
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                          ),
                        ),
                      );
                    },
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
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
                            onPressed: _confirmarFinalizacao,
                            icon: const Icon(Icons.check),
                            label: Text('Finalizar lote (${itens.length})'),
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
          final cacheSize = (56 * MediaQuery.devicePixelRatioOf(context)).round();

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
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
