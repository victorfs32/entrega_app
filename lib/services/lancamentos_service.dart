import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Lançamento diário feito à mão pelo motorista: quantos pacotes entregou
/// em cada empresa naquele dia. É a fonte dos números de ganho do app —
/// as baixas bipadas (fotos/comprovante) são um registro à parte e não
/// entram nessa conta, pra não contar o mesmo pacote duas vezes.
///
/// Os valores por pacote ficam gravados no próprio lançamento (e não só no
/// perfil), então mudar o valor depois não reescreve o ganho de dias já
/// lançados.
class Lancamento {
  /// Id do documento — um dia pode ter vários lançamentos (ex.: rota da
  /// manhã e da tarde), então o dia sozinho não identifica o lançamento.
  final String id;
  final DateTime dia;
  final int anjun;
  final int imile;
  final double valorAnjun;
  final double valorImile;

  const Lancamento({
    this.id = '',
    required this.dia,
    required this.anjun,
    required this.imile,
    required this.valorAnjun,
    required this.valorImile,
  });

  int get totalPacotes => anjun + imile;

  double get ganho => anjun * valorAnjun + imile * valorImile;

  factory Lancamento.fromMap(Map<String, dynamic> dados, {String id = ''}) {
    final diaTexto = (dados['dia'] ?? '').toString();
    final dia =
        DateTime.tryParse(diaTexto) ??
        (dados['data'] as Timestamp?)?.toDate() ??
        DateTime.now();

    double numero(dynamic valor, double padrao) {
      return valor is num ? valor.toDouble() : padrao;
    }

    return Lancamento(
      id: id,
      dia: DateTime(dia.year, dia.month, dia.day),
      anjun: (dados['anjun'] as num?)?.toInt() ?? 0,
      imile: (dados['imile'] as num?)?.toInt() ?? 0,
      valorAnjun: numero(dados['valorAnjun'], 0),
      valorImile: numero(dados['valorImile'], 0),
    );
  }
}

class LancamentosService {
  LancamentosService._();

  static final DateFormat _formatoDia = DateFormat('yyyy-MM-dd');

  static String chaveDoDia(DateTime dia) => _formatoDia.format(dia);

  /// Todos os lançamentos do motorista logado, do mais recente pro mais
  /// antigo. Poucos por dia, então a lista cresce devagar — dá pra ouvir
  /// tudo de uma vez sem paginar. Só filtra por motoristaId
  /// (igualdade simples, sem índice composto) e ordena aqui no cliente.
  static Stream<List<Lancamento>> ouvir() {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return Stream.value(const []);

    return FirebaseFirestore.instance
        .collection('lancamentos')
        .where('motoristaId', isEqualTo: usuario.uid)
        .snapshots()
        .map((snap) {
          final lista = snap.docs
              .map((doc) => Lancamento.fromMap(doc.data(), id: doc.id))
              .toList();
          lista.sort((a, b) => b.dia.compareTo(a.dia));
          return lista;
        });
  }

  /// Meta de ganho por quinzena, guardada no perfil do motorista (assim o
  /// dashboard enxerga a mesma meta). `null` quando não foi definida.
  static Stream<double?> ouvirMeta() {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return Stream.value(null);

    return FirebaseFirestore.instance
        .collection('motoristas')
        .doc(usuario.uid)
        .snapshots()
        .map((doc) {
          final meta = (doc.data()?['metaQuinzena'] as num?)?.toDouble();
          return meta != null && meta > 0 ? meta : null;
        });
  }

  /// Define a meta da quinzena; `null` (ou 0) remove.
  static Future<void> definirMeta(double? meta) {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return Future.value();

    return FirebaseFirestore.instance
        .collection('motoristas')
        .doc(usuario.uid)
        .update({
          'metaQuinzena': meta != null && meta > 0
              ? meta
              : FieldValue.delete(),
        });
  }

  /// Cria um lançamento novo ([id] nulo) ou corrige um existente. Um mesmo
  /// dia pode ter quantos lançamentos o motorista quiser; o ganho do dia é a
  /// soma deles.
  static Future<void> salvar({
    String? id,
    required DateTime dia,
    required int anjun,
    required int imile,
    required double valorAnjun,
    required double valorImile,
  }) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) throw Exception('Faça login novamente.');

    final diaLimpo = DateTime(dia.year, dia.month, dia.day);

    final colecao = FirebaseFirestore.instance.collection('lancamentos');
    final dados = {
      'motoristaId': usuario.uid,
      'dia': chaveDoDia(diaLimpo),
      'data': Timestamp.fromDate(diaLimpo),
      'anjun': anjun,
      'imile': imile,
      'valorAnjun': valorAnjun,
      'valorImile': valorImile,
      'atualizadoEm': Timestamp.now(),
    };

    if (id == null || id.isEmpty) {
      await colecao.add(dados);
    } else {
      await colecao.doc(id).set(dados);
    }
  }

  static Future<void> apagar(String id) async {
    if (FirebaseAuth.instance.currentUser == null || id.isEmpty) return;

    await FirebaseFirestore.instance.collection('lancamentos').doc(id).delete();
  }

  /// Soma dos lançamentos cujo dia cai em [inicio]..[fim] (inclusive).
  static ResumoLancamentos somar(
    List<Lancamento> lancamentos, {
    DateTime? inicio,
    DateTime? fim,
  }) {
    var anjun = 0;
    var imile = 0;
    var ganho = 0.0;

    for (final l in lancamentos) {
      if (inicio != null && l.dia.isBefore(inicio)) continue;
      if (fim != null && l.dia.isAfter(fim)) continue;

      anjun += l.anjun;
      imile += l.imile;
      ganho += l.ganho;
    }

    return ResumoLancamentos(anjun: anjun, imile: imile, ganho: ganho);
  }
}

class ResumoLancamentos {
  final int anjun;
  final int imile;
  final double ganho;

  const ResumoLancamentos({
    required this.anjun,
    required this.imile,
    required this.ganho,
  });

  int get totalPacotes => anjun + imile;
}
