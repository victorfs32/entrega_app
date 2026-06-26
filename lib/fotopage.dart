import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FotoPage extends StatefulWidget {
  const FotoPage({super.key});

  @override
  State<FotoPage> createState() => _FotoPageState();
}

class _FotoPageState extends State<FotoPage> {
  File? imagem;

  final ImagePicker picker = ImagePicker();

  Future<void> tirarFoto() async {
    final foto = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (foto == null) return;

    setState(() {
      imagem = File(foto.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto da Entrega'),
      ),
      body: Center(
        child: imagem == null
            ? ElevatedButton(
                onPressed: tirarFoto,
                child: const Text("Tirar foto da entrega"),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.file(
                    imagem!,
                    height: 400,
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      // 🔥 retorna a imagem para a tela anterior
                      Navigator.pop(context, imagem);
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              ),
      ),
    );
  }
}