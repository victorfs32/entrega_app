import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'services/rota_lida_service.dart';
import 'utils/codigo_rastreio.dart';

/// Acha a parada da rota (lida do outro app) de um pacote: bipando o código,
/// quando o outro app mostra o código junto da parada, ou digitando parte do
/// endereço (rua, número) — que é o que está na etiqueta do pacote.
class AchaParadaPage extends StatefulWidget {
  const AchaParadaPage({super.key});

  @override
  State<AchaParadaPage> createState() => _AchaParadaPageState();
}

class _AchaParadaPageState extends State<AchaParadaPage> {
  final _rota = RotaLidaService.instance;

  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController busca = TextEditingController();

  String? codigo;
  bool naoValido = false;
  Parada? achadaPeloCodigo;
  List<Parada> achadasPeloEndereco = const [];
  DateTime _ultimaLeitura = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    controller.dispose();
    busca.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final bruto = capture.barcodes.firstOrNull?.rawValue;
    if (bruto == null || bruto.isEmpty) return;

    // Evita reler o mesmo código várias vezes por segundo.
    final agora = DateTime.now();
    if (agora.difference(_ultimaLeitura) < const Duration(milliseconds: 900)) {
      return;
    }
    _ultimaLeitura = agora;

    final limpo = CodigoRastreio.limpar(bruto);

    if (!CodigoRastreio.valido(limpo)) {
      setState(() {
        codigo = bruto;
        naoValido = true;
        achadaPeloCodigo = null;
      });
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      codigo = limpo;
      naoValido = false;
      achadaPeloCodigo = _rota.buscarPorCodigo(limpo);
    });
  }

  void _buscarEndereco(String texto) {
    setState(() => achadasPeloEndereco = _rota.buscarPorEndereco(texto));
  }

  Widget _cartaoParada(Parada parada, {bool destaque = false}) {
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
                    parada.pacotes == null
                        ? 'Parada ${parada.id}'
                        : 'Parada ${parada.id} • ${parada.pacotes} pacote${parada.pacotes == 1 ? '' : 's'}',
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

  Widget _resultadoDoCodigo() {
    final colors = Theme.of(context).colorScheme;

    if (codigo == null) {
      return Text(
        'Bipe o pacote ou digite o endereço da etiqueta.',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.onSurfaceVariant),
      );
    }

    if (naoValido) {
      return Text(
        'Esse código não é de pacote Anjun/iMile ($codigo).',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.onSurfaceVariant),
      );
    }

    final parada = achadaPeloCodigo;

    if (parada != null) return _cartaoParada(parada, destaque: true);

    return Column(
      children: [
        Text(
          codigo!,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Esse código não aparece na tela da rota. Digite parte do '
          'endereço da etiqueta (rua e número) pra achar a parada.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
      ],
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
            height: 200,
            width: double.infinity,
            child: MobileScanner(controller: controller, onDetect: _onDetect),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _resultadoDoCodigo(),
                const SizedBox(height: 14),
                TextField(
                  controller: busca,
                  onChanged: _buscarEndereco,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Endereço (ex.: alameda verde 100)',
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
