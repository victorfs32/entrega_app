import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraEntregaPage extends StatefulWidget {
  const CameraEntregaPage({super.key});

  @override
  State<CameraEntregaPage> createState() => _CameraEntregaPageState();
}

class _CameraEntregaPageState extends State<CameraEntregaPage>
    with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras = [];

  bool carregando = true;
  bool tirandoFoto = false;
  bool flashLigado = false;
  String? erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciarCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _iniciarCamera();
    }
  }

  Future<void> _iniciarCamera() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          erro = 'Nenhuma camera encontrada neste aparelho.';
          carregando = false;
        });
        return;
      }

      final cameraTraseira = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final novoController = CameraController(
        cameraTraseira,
        // Qualidade máxima suportada pelo aparelho para a foto de
        // comprovante. A miniatura continua sendo decodificada em baixa
        // resolução via cacheWidth/cacheHeight nas telas que exibem a
        // foto — isso não reduz a qualidade do arquivo salvo, só evita
        // decodificar a imagem inteira na memória pra mostrar uma
        // miniatura pequena.
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await novoController.initialize();
      await novoController.setFlashMode(FlashMode.off);

      if (!mounted) {
        await novoController.dispose();
        return;
      }

      setState(() {
        controller = novoController;
        flashLigado = false;
        carregando = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        erro = _mensagemErroCamera(e);
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        erro = 'Nao foi possivel abrir a camera: $e';
        carregando = false;
      });
    }
  }

  String _mensagemErroCamera(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Permita o acesso a camera para tirar a foto da entrega.';
      default:
        return 'Nao foi possivel abrir a camera: ${e.description ?? e.code}';
    }
  }

  Future<void> _alternarFlash() async {
    final cameraController = controller;

    if (cameraController == null || tirandoFoto) return;

    final novoEstado = !flashLigado;

    try {
      await cameraController.setFlashMode(
        novoEstado ? FlashMode.torch : FlashMode.off,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash nao disponivel neste aparelho.')),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      flashLigado = novoEstado;
    });
  }

  Future<void> _tirarFoto() async {
    final cameraController = controller;

    if (cameraController == null ||
        !cameraController.value.isInitialized ||
        tirandoFoto) {
      return;
    }

    setState(() {
      tirandoFoto = true;
    });

    try {
      final foto = await cameraController.takePicture();

      if (!mounted) return;

      // Tira o CameraPreview da árvore ANTES de dar dispose no controller.
      // Se o preview ainda estiver montado quando o controller for
      // descartado, o plugin tenta redesenhar em cima de um controller já
      // morto e derruba a tela com CameraException(buildPreview...).
      setState(() => controller = null);
      await WidgetsBinding.instance.endOfFrame;

      // Só agora, com o preview já fora da tela, é seguro esperar o
      // hardware ser liberado de verdade antes de voltar. Sem esse await
      // aqui, quem chamou esta tela pode tentar abrir a câmera de novo
      // (leitor de código, próxima foto) antes do sistema soltar essa
      // sessão — o que aparece como tela preta.
      await cameraController.dispose();

      if (!mounted) return;

      Navigator.pop(context, File(foto.path));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        tirandoFoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao tirar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _conteudo() {
    final cameraController = controller;

    if (carregando) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _iniciarCamera,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (cameraController == null || !cameraController.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Center(child: CameraPreview(cameraController));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _conteudo(),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 16,
                  child: _BotaoCamera(
                    icon: Icons.close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Positioned(
                  top: 24,
                  left: 80,
                  right: 80,
                  child: Text(
                    'Foto da entrega',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 16,
                  child: _BotaoCamera(
                    icon: flashLigado
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onPressed: _alternarFlash,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: Center(
                    child: GestureDetector(
                      onTap: tirandoFoto ? null : _tirarFoto,
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 5),
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: tirandoFoto ? 34 : 58,
                            height: tirandoFoto ? 34 : 58,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: tirandoFoto
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                          ),
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

class _BotaoCamera extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _BotaoCamera({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
