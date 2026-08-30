import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AtualizacaoInfo {
  final bool temAtualizacao;
  final String versaoAtual;
  final String novaVersao;
  final String notas;
  final String apkUrl;
  final String nomeArquivo;

  AtualizacaoInfo({
    required this.temAtualizacao,
    required this.versaoAtual,
    required this.novaVersao,
    required this.notas,
    required this.apkUrl,
    required this.nomeArquivo,
  });
}

class AtualizacaoService {
  static const String apkName = 'entrega_app.apk';

  final Dio _dio = Dio();

  // Lê a versão mais recente direto do Firestore (mesmo doc do modo de
  // manutenção), em vez de um endpoint próprio — o admin publica um APK
  // novo em qualquer link público (GitHub Releases, Google Drive, etc.)
  // e cola o link no dashboard, sem precisar de servidor nem OAuth.
  Future<AtualizacaoInfo?> verificarAtualizacao() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final versaoAtual = packageInfo.version;

      final doc = await FirebaseFirestore.instance
          .collection('configuracoes')
          .doc('app')
          .get();

      final data = doc.data();
      if (data == null) return null;

      final novaVersao = (data['ultimaVersao'] ?? '').toString().trim();
      final notas =
          (data['notasAtualizacao'] ?? 'Nova versão disponível.').toString();
      final apkUrl = (data['apkUrl'] ?? '').toString().trim();

      if (novaVersao.isEmpty || apkUrl.isEmpty) {
        return null;
      }

      final temAtualizacao = _compararVersoes(novaVersao, versaoAtual) > 0;

      return AtualizacaoInfo(
        temAtualizacao: temAtualizacao,
        versaoAtual: versaoAtual,
        novaVersao: novaVersao,
        notas: notas,
        apkUrl: apkUrl,
        nomeArquivo: apkName,
      );
    } catch (_) {
      return null;
    }
  }

  Future<File> baixarApk({
    required String url,
    required String nomeArquivo,
    required void Function(int recebido, int total) onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$nomeArquivo';

    await _dio.download(
      url,
      filePath,
      onReceiveProgress: onProgress,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    return File(filePath);
  }

  int _compararVersoes(String nova, String atual) {
    final novaPartes = nova.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final atualPartes =
        atual.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final tamanho = novaPartes.length > atualPartes.length
        ? novaPartes.length
        : atualPartes.length;

    for (int i = 0; i < tamanho; i++) {
      final n = i < novaPartes.length ? novaPartes[i] : 0;
      final a = i < atualPartes.length ? atualPartes[i] : 0;

      if (n > a) return 1;
      if (n < a) return -1;
    }

    return 0;
  }
}