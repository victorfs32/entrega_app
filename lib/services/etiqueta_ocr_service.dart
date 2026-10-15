import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Lê o texto impresso numa foto da etiqueta do pacote (OCR no próprio
/// aparelho, sem internet). Usado pra achar o endereço de entrega.
class EtiquetaOcrService {
  EtiquetaOcrService._();

  /// Texto reconhecido na imagem (JPEG/PNG em bytes); vazio se não leu nada.
  static Future<String> ler(Uint8List imagem) async {
    final arquivo = File(
      '${Directory.systemTemp.path}/etiqueta_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );

    final reconhecedor = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      await arquivo.writeAsBytes(imagem, flush: true);

      final resultado = await reconhecedor.processImage(
        InputImage.fromFilePath(arquivo.path),
      );

      return resultado.text;
    } finally {
      await reconhecedor.close();
      try {
        await arquivo.delete();
      } catch (_) {}
    }
  }
}
