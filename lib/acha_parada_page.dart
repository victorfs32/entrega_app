import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'services/rota_lida_service.dart';
import 'utils/codigo_rastreio.dart';

/// Bipa um pacote e mostra em qual parada da rota (lida do outro app) ele
/// está. Fica escaneando em sequência: é só apontar pro próximo pacote.
class AchaParadaPage extends StatefulWidget {
  const AchaParadaPage({super.key});

  @override
  State<AchaParadaPage> createState() => _AchaParadaPageState();
}

class _AchaParadaPageState extends State<AchaParadaPage> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  String? codigo;
  List<String>? linhas;
  bool naoValido = false;
  DateTime _ultimaLeitura = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    controller.dispose();
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
        linhas = null;
        naoValido = true;
      });
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      codigo = limpo;
      linhas = RotaLidaService.instance.buscar(limpo);
      naoValido = false;
    });
  }

  Widget _resultado(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;

    if (codigo == null) {
      return Text(
        'Aponte a câmera para o código de barras do pacote.',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.onSurfaceVariant),
      );
    }

    if (naoValido) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.help_outline, size: 32),
          const SizedBox(height: 6),
          Text('Esse código não é de pacote Anjun/iMile.', style: tema.titleMedium),
          Text(codigo!, style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      );
    }

    final encontrado = linhas;

    if (encontrado == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 34, color: colors.error),
          const SizedBox(height: 6),
          Text(
            'Não está na rota lida',
            style: tema.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(codigo!, style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(
            'Leia a rota de novo, abrindo a parada desse pacote.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.place, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Parada encontrada',
                style: tema.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              CodigoRastreio.transportadora(codigo!),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Linhas de texto em volta do código na tela do outro app: o número
        // da parada e o endereço aparecem aqui.
        for (final linha in encontrado)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Text(
              linha,
              style: linha.contains(codigo!)
                  ? const TextStyle(fontWeight: FontWeight.w800)
                  : null,
            ),
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
          Expanded(
            flex: 5,
            child: MobileScanner(controller: controller, onDetect: _onDetect),
          ),
          Expanded(
            flex: 4,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Center(child: _resultado(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
