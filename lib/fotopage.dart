import 'dart:io';
import 'package:flutter/material.dart';

import 'camera_entrega_page.dart';

class FotoPage extends StatefulWidget {
  const FotoPage({super.key});

  @override
  State<FotoPage> createState() => _FotoPageState();
}

class _FotoPageState extends State<FotoPage> {
  File? imagem;

  Future<void> tirarFoto() async {
    final foto = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (_) => const CameraEntregaPage()),
    );

    if (foto == null) return;

    setState(() {
      imagem = foto;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foto da Entrega')),
      body: Center(
        child: imagem == null
            ? ElevatedButton(
                onPressed: tirarFoto,
                child: const Text("Tirar foto da entrega"),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.file(imagem!, height: 400),
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
