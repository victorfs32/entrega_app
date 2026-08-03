import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'RegistrarEntregaPage.dart';
import 'utils/codigo_rastreio.dart';

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
    returnImage: false,
  );

  bool jaLeu = false;
  bool flashLigado = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (jaLeu) return;
    if (capture.barcodes.isEmpty) return;

    String? codigoLido;

    // Procura um código válido entre todos os códigos detectados.
    for (final barcode in capture.barcodes) {
      final valor = barcode.rawValue;

      if (valor == null || valor.trim().isEmpty) {
        continue;
      }

      final codigoLimpo = CodigoRastreio.limpar(valor);

      if (CodigoRastreio.valido(codigoLimpo)) {
        codigoLido = codigoLimpo;
        break;
      }
    }

    if (codigoLido == null) return;

    jaLeu = true;

    // Congela a câmera imediatamente.
    await controller.stop();

    // Vibração curta.
    await HapticFeedback.mediumImpact();

    // Som padrão de confirmação do sistema.
    await SystemSound.play(SystemSoundType.click);

    if (!mounted) return;

    final transportadora = CodigoRastreio.transportadora(codigoLido);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrarEntregaPage(
          codigo: codigoLido!,
          transportadora: transportadora,
        ),
      ),
    );
  }

  Future<void> _alternarFlash() async {
    await controller.toggleTorch();

    if (!mounted) return;

    setState(() {
      flashLigado = !flashLigado;
    });
  }

  void _fecharScanner() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),

          // Fundo escuro com área de leitura transparente.
          const ScannerOverlay(),

          SafeArea(
            child: Stack(
              children: [
                // Botão fechar.
                Positioned(
                  top: 12,
                  left: 16,
                  child: _BotaoCircular(
                    icon: Icons.close,
                    onPressed: _fecharScanner,
                  ),
                ),

                // Texto superior.
                const Positioned(
                  top: 22,
                  left: 80,
                  right: 80,
                  child: Text(
                    'Escanear pacote',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),

                // Instrução abaixo da área de leitura.
                Positioned(
                  left: 24,
                  right: 24,
                  top: MediaQuery.of(context).size.height * 0.62,
                  child: const Text(
                    'Aponte o código de barras para o centro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),

                // Botão flash.
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _alternarFlash,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: flashLigado
                              ? Colors.white
                              : Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          flashLigado
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: flashLigado
                              ? Colors.black
                              : Colors.white,
                          size: 30,
                        ),
                      ),
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
}

class _BotaoCircular extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _BotaoCircular({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: Colors.white,
            size: 27,
          ),
        ),
      ),
    );
  }
}

class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ScannerOverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final larguraArea = size.width * 0.86;
    const alturaArea = 190.0;

    final esquerda = (size.width - larguraArea) / 2;
    final topo = (size.height - alturaArea) / 2 - 20;

    final areaLeitura = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        esquerda,
        topo,
        larguraArea,
        alturaArea,
      ),
      const Radius.circular(18),
    );

    final fundo = Path()
      ..addRect(
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height,
        ),
      )
      ..addRRect(areaLeitura)
      ..fillType = PathFillType.evenOdd;

    final pinturaFundo = Paint()
      ..color = Colors.black.withValues(alpha: 0.58);

    canvas.drawPath(fundo, pinturaFundo);

    final pinturaBorda = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(areaLeitura, pinturaBorda);

    const tamanhoCanto = 30.0;
    const espessuraCanto = 5.0;

    final pinturaCantos = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = espessuraCanto
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Canto superior esquerdo
    canvas.drawLine(
      Offset(esquerda, topo + tamanhoCanto),
      Offset(esquerda, topo),
      pinturaCantos,
    );
    canvas.drawLine(
      Offset(esquerda, topo),
      Offset(esquerda + tamanhoCanto, topo),
      pinturaCantos,
    );

    // Canto superior direito
    canvas.drawLine(
      Offset(esquerda + larguraArea - tamanhoCanto, topo),
      Offset(esquerda + larguraArea, topo),
      pinturaCantos,
    );
    canvas.drawLine(
      Offset(esquerda + larguraArea, topo),
      Offset(esquerda + larguraArea, topo + tamanhoCanto),
      pinturaCantos,
    );

    // Canto inferior esquerdo
    canvas.drawLine(
      Offset(esquerda, topo + alturaArea - tamanhoCanto),
      Offset(esquerda, topo + alturaArea),
      pinturaCantos,
    );
    canvas.drawLine(
      Offset(esquerda, topo + alturaArea),
      Offset(esquerda + tamanhoCanto, topo + alturaArea),
      pinturaCantos,
    );

    // Canto inferior direito
    canvas.drawLine(
      Offset(
        esquerda + larguraArea - tamanhoCanto,
        topo + alturaArea,
      ),
      Offset(
        esquerda + larguraArea,
        topo + alturaArea,
      ),
      pinturaCantos,
    );
    canvas.drawLine(
      Offset(
        esquerda + larguraArea,
        topo + alturaArea,
      ),
      Offset(
        esquerda + larguraArea,
        topo + alturaArea - tamanhoCanto,
      ),
      pinturaCantos,
    );

    // Linha central para ajudar a posicionar o código.
    final pinturaLinha = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.85)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(esquerda + 18, topo + alturaArea / 2),
      Offset(esquerda + larguraArea - 18, topo + alturaArea / 2),
      pinturaLinha,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}