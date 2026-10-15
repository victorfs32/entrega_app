import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'services/etiqueta_ocr_service.dart';
import 'services/rota_lida_service.dart';
import 'utils/codigo_rastreio.dart';
import 'utils/combinar_endereco.dart';

/// Acha a parada da rota (lida do outro app) de um pacote. Bipou o código:
/// se o outro app mostra o código junto da parada, é direto; senão o app lê
/// o endereço impresso na etiqueta (OCR, no próprio celular) e procura a
/// parada com esse endereço. Dá pra digitar o endereço também.
class AchaParadaPage extends StatefulWidget {
  const AchaParadaPage({super.key});

  @override
  State<AchaParadaPage> createState() => _AchaParadaPageState();
}

class _AchaParadaPageState extends State<AchaParadaPage> {
  final _rota = RotaLidaService.instance;

  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    // O frame do bipe é a imagem lida pelo OCR: quanto mais nítida, melhor
    // o texto da etiqueta é reconhecido.
    returnImage: true,
    cameraResolution: const Size(1920, 1080),
  );
  final TextEditingController busca = TextEditingController();

  String? codigo;
  bool naoValido = false;
  bool lendoEtiqueta = false;
  String? textoDaEtiqueta;
  String? erroOcr;
  Parada? achadaPeloCodigo;
  List<ParadaCandidata> achadasPelaEtiqueta = const [];
  List<Parada> achadasPeloEndereco = const [];

  DateTime _ultimaLeitura = DateTime.fromMillisecondsSinceEpoch(0);
  int _geracao = 0;

  @override
  void dispose() {
    controller.dispose();
    busca.dispose();
    super.dispose();
  }

  void _limparResultado() {
    achadaPeloCodigo = null;
    achadasPelaEtiqueta = const [];
    textoDaEtiqueta = null;
    erroOcr = null;
    lendoEtiqueta = false;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final bruto = capture.barcodes.firstOrNull?.rawValue;
    if (bruto == null || bruto.isEmpty) return;

    // Evita reler o mesmo código várias vezes por segundo.
    final agora = DateTime.now();
    if (agora.difference(_ultimaLeitura) < const Duration(milliseconds: 900)) {
      return;
    }
    _ultimaLeitura = agora;

    final geracao = ++_geracao;
    final limpo = CodigoRastreio.limpar(bruto);

    if (!CodigoRastreio.valido(limpo)) {
      setState(() {
        _limparResultado();
        codigo = bruto;
        naoValido = true;
      });
      return;
    }

    HapticFeedback.mediumImpact();

    final direta = _rota.buscarPorCodigo(limpo);
    final imagem = capture.image;

    setState(() {
      _limparResultado();
      codigo = limpo;
      naoValido = false;
      achadaPeloCodigo = direta;
      lendoEtiqueta = direta == null && imagem != null;
      if (direta == null && imagem == null) {
        erroOcr = 'Não consegui capturar a etiqueta. Bipe de novo.';
      }
    });

    if (direta != null || imagem == null) return;

    try {
      final texto = await EtiquetaOcrService.ler(imagem);
      if (!mounted || geracao != _geracao) return;

      setState(() {
        lendoEtiqueta = false;
        textoDaEtiqueta = texto;
        achadasPelaEtiqueta = CombinarEndereco.procurar(texto, _rota.paradas);
      });
    } catch (_) {
      if (!mounted || geracao != _geracao) return;

      setState(() {
        lendoEtiqueta = false;
        erroOcr = 'Não consegui ler o texto da etiqueta.';
      });
    }
  }

  void _buscarEndereco(String texto) {
    setState(() => achadasPeloEndereco = _rota.buscarPorEndereco(texto));
  }

  Widget _cartaoParada(
    Parada parada, {
    bool destaque = false,
    String? selo,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      color: destaque ? colors.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.primary,
              child: Text(
                parada.id,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: parada.id.length > 2 ? 14 : 18,
                  color: colors.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      'Parada ${parada.id}',
                      if (parada.pacotes != null)
                        '${parada.pacotes} pacote${parada.pacotes == 1 ? '' : 's'}',
                      ?selo,
                    ].join(' • '),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    parada.endereco,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (parada.local != null)
                    Text(
                      parada.local!,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultadoDoBipe() {
    final colors = Theme.of(context).colorScheme;
    final apagado = TextStyle(color: colors.onSurfaceVariant, fontSize: 13);

    if (codigo == null) {
      return Text(
        'Bipe o pacote com o código e o endereço da etiqueta '
        'aparecendo juntos na câmera.',
        textAlign: TextAlign.center,
        style: apagado,
      );
    }

    if (naoValido) {
      return Text(
        'Esse código não é de pacote Anjun/iMile ($codigo).',
        textAlign: TextAlign.center,
        style: apagado,
      );
    }

    final titulo = Text(
      codigo!,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    );

    if (achadaPeloCodigo != null) {
      return Column(
        children: [
          titulo,
          const SizedBox(height: 8),
          _cartaoParada(achadaPeloCodigo!, destaque: true),
        ],
      );
    }

    if (lendoEtiqueta) {
      return Column(
        children: [
          titulo,
          const SizedBox(height: 10),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 8),
          Text('Lendo o endereço da etiqueta...', style: apagado),
        ],
      );
    }

    if (erroOcr != null) {
      return Column(
        children: [
          titulo,
          const SizedBox(height: 6),
          Text(erroOcr!, textAlign: TextAlign.center, style: apagado),
        ],
      );
    }

    if (achadasPelaEtiqueta.isEmpty) {
      return Column(
        children: [
          titulo,
          const SizedBox(height: 6),
          Text(
            'Não achei uma parada com o endereço dessa etiqueta. '
            'Tente enquadrar melhor o endereço ou digite abaixo.',
            textAlign: TextAlign.center,
            style: apagado,
          ),
          if ((textoDaEtiqueta ?? '').trim().isNotEmpty)
            TextButton(
              onPressed: _mostrarTextoLido,
              child: const Text('Ver o que foi lido da etiqueta'),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titulo,
        const SizedBox(height: 8),
        for (var i = 0; i < achadasPelaEtiqueta.length; i++)
          _cartaoParada(
            achadasPelaEtiqueta[i].parada,
            destaque: i == 0,
            selo: achadasPelaEtiqueta[i].exata ? null : 'confira',
          ),
        if (achadasPelaEtiqueta.length > 1)
          Text(
            'Mais de uma parada combina — confira o número na etiqueta.',
            textAlign: TextAlign.center,
            style: apagado,
          ),
        TextButton(
          onPressed: _mostrarTextoLido,
          child: const Text('Ver o que foi lido da etiqueta'),
        ),
      ],
    );
  }

  void _mostrarTextoLido() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Texto lido da etiqueta',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(textoDaEtiqueta ?? ''),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achar a parada'),
        actions: [
          IconButton(
            tooltip: 'Lanterna',
            icon: const Icon(Icons.flash_on),
            onPressed: controller.toggleTorch,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 240,
            width: double.infinity,
            child: MobileScanner(controller: controller, onDetect: _onDetect),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _resultadoDoBipe(),
                const SizedBox(height: 14),
                TextField(
                  controller: busca,
                  onChanged: _buscarEndereco,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Ou digite o endereço (ex.: alameda verde 100)',
                    border: const OutlineInputBorder(),
                    suffixIcon: busca.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              busca.clear();
                              _buscarEndereco('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                if (busca.text.trim().isNotEmpty && achadasPeloEndereco.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Nenhuma parada com esse endereço na rota lida.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final parada in achadasPeloEndereco.take(8))
                  _cartaoParada(parada),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
