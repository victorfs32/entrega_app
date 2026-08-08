import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ResultadoSincronizacao {
  final int totalEncontradas;
  final int totalEnviadas;
  final int totalIgnoradas;
  final int totalErros;

  const ResultadoSincronizacao({
    required this.totalEncontradas,
    required this.totalEnviadas,
    required this.totalIgnoradas,
    required this.totalErros,
  });
}

/// Envia para o servidor as fotos de entregas que ainda só existem no
/// celular. É um singleton para que a sincronização automática (disparada
/// ao abrir o app) e a sincronização manual (botão no Menu) nunca rodem
/// em paralelo nem enviem a mesma foto duas vezes.
class SincronizacaoFotosService {
  SincronizacaoFotosService._();

  static final SincronizacaoFotosService instance =
      SincronizacaoFotosService._();

  static const String _servidorFotos =
      "https://servidor-fotos-entregas.vercel.app";

  bool _emExecucao = false;
  bool get emExecucao => _emExecucao;

  String _texto(dynamic valor) {
    final texto = (valor ?? '').toString().trim();
    return texto == 'null' ? '' : texto;
  }

  bool _temFotoRemota(Map<String, dynamic> dados) {
    return _texto(dados['fotoUrl']).isNotEmpty ||
        _texto(dados['fotoViewUrl']).isNotEmpty ||
        _texto(dados['fotoDownloadUrl']).isNotEmpty;
  }

  Future<void> _marcarErro(
    DocumentReference<Map<String, dynamic>> entrega,
    String mensagem,
  ) async {
    await entrega
        .update({
          'fotoSincronizada': false,
          'erroSincronizacaoFoto': mensagem,
          'dataErroSincronizacaoFoto': Timestamp.now(),
        })
        .catchError((_) {});
  }

  /// Comprime uma cópia da foto só para o envio ao servidor. O arquivo
  /// original (em qualidade máxima) nunca é tocado — ele continua sendo o
  /// que fica salvo no celular e referenciado em [fotoPath]. Isso existe
  /// porque a Vercel recusa requisições acima de ~4,5MB
  /// (FUNCTION_PAYLOAD_TOO_LARGE), e uma foto em ResolutionPreset.max
  /// facilmente passa disso.
  Future<File> _comprimirParaEnvio(File original) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final resultado = await FlutterImageCompress.compressAndGetFile(
        original.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1600,
        minHeight: 1600,
        format: CompressFormat.jpeg,
      );

      if (resultado == null) return original;

      return File(resultado.path);
    } catch (_) {
      return original;
    }
  }

  Future<Map<String, dynamic>> _enviarFotoParaServidor({
    required String codigo,
    required String fotoPath,
    required String motoristaId,
  }) async {
    final arquivo = File(fotoPath);

    if (!await arquivo.exists()) {
      throw Exception('Arquivo da foto não encontrado neste celular');
    }

    final arquivoParaEnvio = await _comprimirParaEnvio(arquivo);

    try {
      final url = Uri.parse('$_servidorFotos/upload');

      final request = http.MultipartRequest('POST', url);
      request.fields['codigo'] = codigo;
      request.fields['motoristaId'] = motoristaId;

      request.files.add(
        await http.MultipartFile.fromPath('foto', arquivoParaEnvio.path),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 60),
      );

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Servidor respondeu erro: $responseBody');
      }

      final decoded = jsonDecode(responseBody);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Servidor retornou uma resposta inválida');
      }

      if (_texto(decoded['fotoUrl']).isEmpty) {
        throw Exception('Servidor não retornou fotoUrl');
      }

      return decoded;
    } finally {
      if (arquivoParaEnvio.path != arquivo.path) {
        try {
          await arquivoParaEnvio.delete();
        } catch (_) {}
      }
    }
  }

  /// Sincroniza as fotos pendentes do motorista logado.
  /// Retorna `null` se não houver usuário logado, se uma sincronização já
  /// estiver em andamento, ou se ocorrer um erro ao buscar as entregas.
  Future<ResultadoSincronizacao?> sincronizar({
    void Function(int encontradas, int ignoradas)? onInicio,
    void Function(int enviadas, int erros)? onProgresso,
  }) async {
    if (_emExecucao) return null;

    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return null;

    _emExecucao = true;

    var totalEnviadas = 0;
    var totalErros = 0;

    try {
      final uid = usuario.uid;

      final snapshot = await FirebaseFirestore.instance
          .collection('entregas')
          .where('motoristaId', isEqualTo: uid)
          .get();

      final entregas = snapshot.docs.where((doc) {
        return doc.data()['entregue'] == true;
      }).toList();

      final pendentes = entregas.where((doc) {
        return !_temFotoRemota(doc.data());
      }).toList();

      final totalEncontradas = pendentes.length;
      final totalIgnoradas = entregas.length - pendentes.length;
      onInicio?.call(totalEncontradas, totalIgnoradas);

      for (final doc in pendentes) {
        final dados = doc.data();

        final codigo = _texto(dados['codigo']);
        final fotoPath = _texto(dados['fotoPath']);

        if (codigo.isEmpty) {
          await _marcarErro(doc.reference, 'Entrega sem código para sincronizar');
          totalErros++;
          onProgresso?.call(totalEnviadas, totalErros);
          continue;
        }

        if (fotoPath.isEmpty) {
          await _marcarErro(doc.reference, 'Entrega sem caminho local da foto');
          totalErros++;
          onProgresso?.call(totalEnviadas, totalErros);
          continue;
        }

        try {
          final resultadoUpload = await _enviarFotoParaServidor(
            codigo: codigo,
            fotoPath: fotoPath,
            motoristaId: uid,
          );

          final dadosAtualizados = <String, dynamic>{
            'fotoUrl': _texto(resultadoUpload['fotoUrl']),
            'fotoSincronizada': true,
            'dataSincronizacaoFoto': Timestamp.now(),
            'erroSincronizacaoFoto': FieldValue.delete(),
            'dataErroSincronizacaoFoto': FieldValue.delete(),
          };

          final fileId = _texto(resultadoUpload['fileId']);
          final fotoViewUrl = _texto(resultadoUpload['fotoViewUrl']);
          final fotoDownloadUrl = _texto(resultadoUpload['fotoDownloadUrl']);

          if (fileId.isNotEmpty) {
            dadosAtualizados['fotoServerPath'] = fileId;
          }

          if (fotoViewUrl.isNotEmpty) {
            dadosAtualizados['fotoViewUrl'] = fotoViewUrl;
          }

          if (fotoDownloadUrl.isNotEmpty) {
            dadosAtualizados['fotoDownloadUrl'] = fotoDownloadUrl;
          }

          await doc.reference.update(dadosAtualizados);

          totalEnviadas++;
          onProgresso?.call(totalEnviadas, totalErros);
        } catch (e) {
          await _marcarErro(doc.reference, e.toString());
          totalErros++;
          onProgresso?.call(totalEnviadas, totalErros);
        }
      }

      return ResultadoSincronizacao(
        totalEncontradas: totalEncontradas,
        totalEnviadas: totalEnviadas,
        totalIgnoradas: totalIgnoradas,
        totalErros: totalErros,
      );
    } catch (_) {
      return null;
    } finally {
      _emExecucao = false;
    }
  }
}
