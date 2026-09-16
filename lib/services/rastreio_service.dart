import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

const String _chaveCodigoAtivo = 'rastreio_codigo_ativo';
const int _intervaloAtualizacaoMs = 10000;

/// Rastreio em tempo real pro cliente acompanhar a entrega por um link
/// público, sem login. Duas partes independentes:
///
/// - O **serviço em primeiro plano** (GPS + notificação permanente) liga
///   e desliga uma vez por turno, via [iniciarServico]/[pararServico].
/// - O que é **gravado no Firestore e exposto publicamente** é por
///   entrega: mesmo com o serviço ligado o turno inteiro, só grava
///   localização enquanto existe um "código ativo" (entre escanear e
///   confirmar a entrega — ver [iniciarRastreioEntrega]/
///   [encerrarRastreioEntrega]).
class RastreioService {
  RastreioService._();

  static void _configurar() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'rastreio_baixa_facil',
        channelName: 'Rastreio de entregas',
        channelDescription:
            'Mantém o GPS ativo durante o turno para o cliente acompanhar '
            'a entrega em tempo real.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(_intervaloAtualizacaoMs),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> servicoAtivo() => FlutterForegroundTask.isRunningService;

  /// Pede as permissões necessárias (notificação + localização). Não pede
  /// localização em segundo plano de propósito — o foreground service já
  /// cobre isso enquanto está ativo (ver comentário no AndroidManifest).
  static Future<bool> _solicitarPermissoes() async {
    final permissaoNotificacao = await FlutterForegroundTask.checkNotificationPermission();
    if (permissaoNotificacao != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    var permissaoLocalizacao = await Geolocator.checkPermission();

    if (permissaoLocalizacao == LocationPermission.denied) {
      permissaoLocalizacao = await Geolocator.requestPermission();
    }

    return permissaoLocalizacao == LocationPermission.always ||
        permissaoLocalizacao == LocationPermission.whileInUse;
  }

  /// Liga o serviço de rastreio do turno. Retorna `false` se a permissão
  /// de localização foi negada.
  static Future<bool> iniciarServico() async {
    final permitido = await _solicitarPermissoes();
    if (!permitido) return false;

    _configurar();

    if (await FlutterForegroundTask.isRunningService) return true;

    final resultado = await FlutterForegroundTask.startService(
      serviceId: 301,
      notificationTitle: 'Baixa Fácil — Rastreamento ativo',
      notificationText: 'Suas entregas em rota são compartilhadas com o cliente.',
      callback: iniciarRastreioCallback,
    );

    return resultado is ServiceRequestSuccess;
  }

  static Future<void> pararServico() async {
    await definirCodigoAtivo(null);
    await FlutterForegroundTask.stopService();
  }

  static Future<void> definirCodigoAtivo(String? codigo) async {
    final prefs = await SharedPreferences.getInstance();

    if (codigo == null) {
      await prefs.remove(_chaveCodigoAtivo);
    } else {
      await prefs.setString(_chaveCodigoAtivo, codigo);
    }
  }

  /// Marca esse código como "em rota": o próximo ciclo do serviço em
  /// segundo plano já passa a gravar a localização nele. Não falha a
  /// entrega se o serviço do turno não estiver ligado — o rastreio
  /// público é um extra, não um requisito pra registrar a entrega.
  static Future<void> iniciarRastreioEntrega(
    String codigo,
    String transportadora,
  ) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    await definirCodigoAtivo(codigo);

    try {
      final motoristaDoc = await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(usuario.uid)
          .get();

      final nome = (motoristaDoc.data()?['nome'] ?? '').toString();
      final agora = DateTime.now();

      await FirebaseFirestore.instance
          .collection('rastreio_publico')
          .doc(codigo)
          .set({
        'motoristaId': usuario.uid,
        'motoristaNome': nome,
        'transportadora': transportadora,
        'emAndamento': true,
        'criadoEm': Timestamp.fromDate(agora),
        'expiraEm': Timestamp.fromDate(agora.add(const Duration(days: 7))),
      }, SetOptions(merge: true));
    } catch (_) {
      // Sem rastreio público não impede a entrega — segue o fluxo normal.
    }
  }

  /// Encerra o rastreio público desse código (entrega confirmada ou
  /// abandonada). Só limpa o "código ativo" se ainda for esse mesmo
  /// código, pra não apagar o de uma entrega diferente já iniciada.
  static Future<void> encerrarRastreioEntrega(String codigo) async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getString(_chaveCodigoAtivo) == codigo) {
      await prefs.remove(_chaveCodigoAtivo);
    }

    try {
      await FirebaseFirestore.instance
          .collection('rastreio_publico')
          .doc(codigo)
          .set({'emAndamento': false}, SetOptions(merge: true));
    } catch (_) {}
  }
}

// O callback precisa ser uma função de nível superior (top-level) — o
// plugin chama isso numa isolate separada pra rodar o handler.
@pragma('vm:entry-point')
void iniciarRastreioCallback() {
  FlutterForegroundTask.setTaskHandler(_RastreioTaskHandler());
}

class _RastreioTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();

    // A isolate do serviço em segundo plano não compartilha estado com a
    // isolate principal do app — precisa inicializar o Firebase de novo
    // aqui antes de qualquer chamada ao Firestore.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _atualizarLocalizacao();
  }

  Future<void> _atualizarLocalizacao() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final codigo = prefs.getString(_chaveCodigoAtivo);

      // Sem entrega em rota agora: mantém o GPS "quente" mas não grava
      // nada — é isso que mantém a exposição pública restrita a entregas
      // ativas, mesmo com o serviço ligado o turno inteiro.
      if (codigo == null) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      await FirebaseFirestore.instance
          .collection('rastreio_publico')
          .doc(codigo)
          .set({
        'lat': position.latitude,
        'lng': position.longitude,
        'atualizadoEm': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Falha pontual de GPS/rede não derruba o serviço — tenta de novo
      // no próximo ciclo.
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
