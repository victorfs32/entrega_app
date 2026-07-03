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

  String limparCodigo(String codigo) {
    return codigo
        .trim()
        .replaceAll(' ', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .toUpperCase();
  }

  bool codigoValido(String codigo) {
    final c = limparCodigo(codigo);

    final codigoImile = RegExp(r'^\d{13}$');
    final codigoAnjun = RegExp(r'^AJ\d{15}$');

    return codigoImile.hasMatch(c) || codigoAnjun.hasMatch(c);
  }

  String identificarTransportadora(String codigo) {
    final c = limparCodigo(codigo);

    if (RegExp(r'^AJ\d{15}$').hasMatch(c)) {
      return 'Anjun';
    }

    if (RegExp(r'^\d{13}$').hasMatch(c)) {
      return 'iMile';
    }

    return 'Desconhecida';
  }

  void _onDetect(BarcodeCapture capture) {
    if (jaLeu) return;
    if (capture.barcodes.isEmpty) return;

    final codigoLido = capture.barcodes.first.rawValue;

    if (codigoLido == null || codigoLido.trim().isEmpty) return;

    final codigo = limparCodigo(codigoLido);

    if (!codigoValido(codigo)) {
      return;
    }

    jaLeu = true;

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