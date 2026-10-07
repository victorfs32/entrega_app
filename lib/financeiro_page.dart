import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'lancamento_page.dart';
import 'services/lancamentos_service.dart';
import 'ui/painel_financeiro.dart';
import 'utils/quinzena.dart' as quinzena;

class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  final valorController = TextEditingController();
  final observacaoController = TextEditingController();

  // Streams criados uma vez só — um novo a cada build() re-assinaria o
  // Firestore e piscava a tela.
  final Stream<List<Lancamento>> _lancamentos = LancamentosService.ouvir();
  late final Stream<QuerySnapshot> _pagamentos = FirebaseFirestore.instance
      .collection('pagamentos')
      .where('motoristaId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
      .snapshots();
  bool salvando = false;

  @override
  void dispose() {
    valorController.dispose();
    observacaoController.dispose();
    super.dispose();
  }

  Future<void> _abrirLancamento({DateTime? dia, Lancamento? lancamento}) async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LancamentoPage(diaInicial: dia, lancamento: lancamento),
      ),
    );

    if (salvou == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lançamento salvo.')));
    }
  }

  Future<void> _registrarRecebimento() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    final valorTexto = valorController.text.trim().replaceAll(',', '.');
    final valor = double.tryParse(valorTexto);

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido.')));
      return;
    }

    setState(() => salvando = true);

    try {
      await FirebaseFirestore.instance.collection('pagamentos').add({
        'motoristaId': usuario.uid,
        'valor': valor,
        'observacao': observacaoController.text.trim(),
        'data': Timestamp.now(),
        'criadoEm': Timestamp.now(),
      });

      valorController.clear();
      observacaoController.clear();

      if (!mounted) return;

      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recebimento registrado.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao registrar: $e')));
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Future<void> _apagarRecebimento(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar recebimento?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await FirebaseFirestore.instance.collection('pagamentos').doc(id).delete();
  }

  Widget _linhaResumo({
    required IconData icon,
    required String titulo,
    required String valor,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(titulo)),
          Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _formatarDinheiro(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;
    final colors = Theme.of(context).colorScheme;

    if (usuario == null) {
      return const Scaffold(body: Center(child: Text('Faça login novamente.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Financeiro')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirLancamento,
        icon: const Icon(Icons.add),
        label: const Text('Lançar o dia'),
      ),
      body: StreamBuilder<List<Lancamento>>(
        stream: _lancamentos,
        builder: (context, lancamentosSnap) {
          final lancamentos = lancamentosSnap.data ?? const <Lancamento>[];

          // O ganho vem só dos lançamentos diários feitos à mão (cada um
          // com o valor por pacote de cada empresa gravado na hora) — as
          // baixas bipadas não entram aqui, pra não contar em dobro.
          final resumoTotal = LancamentosService.somar(lancamentos);
          final totalEntregas = resumoTotal.totalPacotes;
          final ganhoTotal = resumoTotal.ganho;

          return StreamBuilder<QuerySnapshot>(
            // Sem orderBy aqui de propósito: combinar isso com o where
            // de motoristaId exigiria um índice composto no Firestore.
            // A lista é pequena (recebimentos manuais), então ordena
            // no cliente mesmo.
            stream: _pagamentos,
            builder: (context, pagamentosSnap) {
              if (pagamentosSnap.connectionState == ConnectionState.waiting &&
                  !pagamentosSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = (pagamentosSnap.data?.docs ?? []).toList()
                ..sort((a, b) {
                  final dataA =
                      (a.data() as Map<String, dynamic>)['data'] as Timestamp?;
                  final dataB =
                      (b.data() as Map<String, dynamic>)['data'] as Timestamp?;
                  return (dataB?.seconds ?? 0).compareTo(dataA?.seconds ?? 0);
                });
              final totalRecebido = docs.fold<double>(0, (soma, doc) {
                final dados = doc.data() as Map<String, dynamic>;
                final valor = dados['valor'];
                return soma + (valor is num ? valor.toDouble() : 0);
              });
              final saldo = ganhoTotal - totalRecebido;

              final agora = DateTime.now();
              final inicioQuinzena = quinzena.inicioDaQuinzena(agora);
              final fimQuinzena = quinzena.fimDaQuinzena(agora);
              final previsaoPagamento = quinzena.previsaoPagamento(fimQuinzena);
              final fimQuinzenaExclusivo = fimQuinzena.add(
                const Duration(days: 1),
              );

              final resumoQuinzena = LancamentosService.somar(
                lancamentos,
                inicio: inicioQuinzena,
                fim: fimQuinzena,
              );
              final entregasQuinzena = resumoQuinzena.totalPacotes;
              final ganhoQuinzena = resumoQuinzena.ganho;

              final recebidoQuinzena = docs.fold<double>(0, (soma, doc) {
                final dados = doc.data() as Map<String, dynamic>;
                final dataPagamento = (dados['data'] as Timestamp?)?.toDate();

                if (dataPagamento == null ||
                    dataPagamento.isBefore(inicioQuinzena) ||
                    !dataPagamento.isBefore(fimQuinzenaExclusivo)) {
                  return soma;
                }

                final valor = dados['valor'];
                return soma + (valor is num ? valor.toDouble() : 0);
              });

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  PainelHero(
                    rotulo: 'Saldo a receber',
                    valor: saldo,
                    apoio: '$totalEntregas pacotes lançados no total',
                    pilulas: [
                      (
                        Icons.inventory_2_outlined,
                        'Anjun ${resumoTotal.anjun}',
                      ),
                      (Icons.inventory_outlined, 'iMile ${resumoTotal.imile}'),
                    ],
                  ),

                  const SizedBox(height: 14),

                  FaixaMetricas(
                    itens: [
                      ('Total ganho', _formatarDinheiro(ganhoTotal)),
                      ('Já recebido', _formatarDinheiro(totalRecebido)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Quinzena atual (${DateFormat('dd/MM').format(inicioQuinzena)} a ${DateFormat('dd/MM').format(fimQuinzena)})',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _CalendarioQuinzena(
                            inicioQuinzena: inicioQuinzena,
                            fimQuinzena: fimQuinzena,
                          ),
                          const SizedBox(height: 14),
                          _linhaResumo(
                            icon: Icons.inventory_2_outlined,
                            titulo:
                                'Ganho na quinzena ($entregasQuinzena pacotes)',
                            valor: _formatarDinheiro(ganhoQuinzena),
                            color: colors.primary,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 36, bottom: 4),
                            child: Text(
                              'Anjun ${resumoQuinzena.anjun} • iMile ${resumoQuinzena.imile}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          _linhaResumo(
                            icon: Icons.check_circle_outline,
                            titulo: 'Recebido na quinzena',
                            valor: _formatarDinheiro(recebidoQuinzena),
                            color: Colors.green,
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(Icons.event_available, color: Colors.orange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Previsão de pagamento',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(previsaoPagamento),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Até 5 dias úteis depois do fim da quinzena.',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const TituloSecao('Lançamentos do dia'),

                  if (lancamentos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Nenhum lançamento ainda. Toque em "Lançar o dia" '
                        'pra registrar quantos pacotes entregou.',
                      ),
                    ),

                  ...lancamentos.take(15).map((l) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.today_outlined),
                        title: Text(
                          '${DateFormat('dd/MM/yyyy').format(l.dia)} — '
                          '${_formatarDinheiro(l.ganho)}',
                        ),
                        subtitle: Text('Anjun ${l.anjun} • iMile ${l.imile}'),
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: () => _abrirLancamento(lancamento: l),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registrar recebimento',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: valorController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Valor recebido',
                              prefixText: 'R\$ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: observacaoController,
                            decoration: const InputDecoration(
                              labelText: 'Observação (opcional)',
                              hintText: 'Ex: Pix de segunda-feira',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: salvando
                                  ? null
                                  : _registrarRecebimento,
                              icon: const Icon(Icons.add),
                              label: Text(
                                salvando ? 'Salvando...' : 'Registrar',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const TituloSecao('Recebimentos'),

                  if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Nenhum recebimento registrado ainda.'),
                    ),

                  ...docs.map((doc) {
                    final dados = doc.data() as Map<String, dynamic>;
                    final valor = (dados['valor'] as num?)?.toDouble() ?? 0;
                    final data = (dados['data'] as Timestamp?)?.toDate();
                    final observacao = (dados['observacao'] ?? '').toString();

                    final subtitulo = [
                      if (data != null)
                        DateFormat('dd/MM/yyyy HH:mm').format(data),
                      if (observacao.isNotEmpty) observacao,
                    ].join(' • ');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(
                          Icons.attach_money,
                          color: Colors.green,
                        ),
                        title: Text(_formatarDinheiro(valor)),
                        subtitle: subtitulo.isEmpty ? null : Text(subtitulo),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _apagarRecebimento(doc.id),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Grade do mês da quinzena informada, com os dias do período destacados —
/// só pra visualizar o intervalo, sem navegação entre meses nem seleção
/// (a quinzena atual é sempre calculada a partir da data de hoje).
class _CalendarioQuinzena extends StatelessWidget {
  final DateTime inicioQuinzena;
  final DateTime fimQuinzena;

  const _CalendarioQuinzena({
    required this.inicioQuinzena,
    required this.fimQuinzena,
  });

  static const _diasSemana = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semanticColors = context.semanticColors;
    final hoje = DateTime.now();

    final ano = inicioQuinzena.year;
    final mes = inicioQuinzena.month;

    final primeiroDiaMes = DateTime(ano, mes, 1);
    final diasNoMes = DateTime(ano, mes + 1, 0).day;

    // Dart: weekday vai de 1 (segunda) a 7 (domingo). A grade começa no
    // domingo, então o número de espaços vazios antes do dia 1 é
    // `weekday % 7` (domingo vira 0 espaços, segunda 1, ... sábado 6).
    final espacosVazios = primeiroDiaMes.weekday % 7;

    final celulas = <Widget>[
      for (var i = 0; i < espacosVazios; i++) const SizedBox.shrink(),
      for (var dia = 1; dia <= diasNoMes; dia++)
        _celulaDia(
          data: DateTime(ano, mes, dia),
          colors: colors,
          destaque: semanticColors.success,
          hoje: hoje,
        ),
    ];

    return Column(
      children: [
        Row(
          children: _diasSemana
              .map(
                (letra) => Expanded(
                  child: Center(
                    child: Text(
                      letra,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: celulas,
        ),
      ],
    );
  }

  Widget _celulaDia({
    required DateTime data,
    required ColorScheme colors,
    required Color destaque,
    required DateTime hoje,
  }) {
    final dentroDaQuinzena =
        !data.isBefore(inicioQuinzena) && !data.isAfter(fimQuinzena);
    final ehInicio = quinzena.mesmoDia(data, inicioQuinzena);
    final ehFim = quinzena.mesmoDia(data, fimQuinzena);
    final ehHoje = quinzena.mesmoDia(data, hoje);

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: dentroDaQuinzena ? destaque.withValues(alpha: 0.85) : null,
        borderRadius: BorderRadius.circular(8),
        border: ehHoje && !dentroDaQuinzena
            ? Border.all(color: colors.primary, width: 1.5)
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${data.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: dentroDaQuinzena || ehHoje
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: dentroDaQuinzena
                    ? Colors.white
                    : (ehHoje ? colors.primary : colors.onSurface),
              ),
            ),
            if (ehInicio || ehFim)
              Text(
                ehInicio ? 'Início' : 'Fim',
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
