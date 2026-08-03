import 'dart:convert';
import 'dart:io';

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

  static const String versaoUrl =
      'https://servidor-fotos-entregas.vercel.app/versao';

  final Dio _dio = Dio();

  Future<AtualizacaoInfo?> verificarAtualizacao() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final versaoAtual = packageInfo.version;

      final response = await _dio.get(versaoUrl);

      if (response.statusCode != 200) {
        return null;
      }

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data as Map<String, dynamic>;

      final novaVersao = (data['versao'] ?? '').toString().trim();
      final notas = (data['notas'] ?? 'Nova versão disponível.').toString();
      final apkUrl = (data['apkUrl'] ?? '').toString();

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