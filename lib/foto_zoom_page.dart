import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class FotoZoomPage extends StatelessWidget {
  final String? imagemPath;
  final String? imagemUrl;

  const FotoZoomPage({
    super.key,
    this.imagemPath,
    this.imagemUrl,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;

    if (imagemUrl != null && imagemUrl!.isNotEmpty) {
      imageProvider = NetworkImage(imagemUrl!);
    } else if (!kIsWeb &&
        imagemPath != null &&
        imagemPath!.isNotEmpty) {
      imageProvider = FileImage(File(imagemPath!));
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Foto"),
        ),
        body: const Center(
          child: Text("Foto indisponível"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: PhotoView(
          imageProvider: imageProvider,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
        ),
      ),
    );
  }
}