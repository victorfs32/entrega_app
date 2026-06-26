import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'RegistrarEntregaPage.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool jaLeu = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String identificarTransportadora(String codigo) {
    if (codigo.toUpperCase().startsWith('AJ')) {
      return 'Anjun';
    }

    return 'iMile';
  }

  void _onDetect(BarcodeCapture capture) {
    if (jaLeu) return;
    if (capture.barcodes.isEmpty) return;

    final codigoLido = capture.barcodes.first.rawValue;

    if (codigoLido == null || codigoLido.trim().isEmpty) return;

    jaLeu = true;

    final codigo = codigoLido.trim();
    final transportadora = identificarTransportadora(codigo);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrarEntregaPage(
          codigo: codigo,
          transportadora: transportadora,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Dar Baixa'),
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: _onDetect,
      ),
    );
  }
}