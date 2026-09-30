import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'main.dart';

// Pagamento é quinzenal: dia 1 ao 15, e dia 16 até o fim do mês. O
// dinheiro da quinzena não cai na hora — o motorista informou que leva
// até 5 dias corridos depois do fim de cada quinzena (então até dia 20
// pra 1ª quinzena, e até dia 5 do mês seguinte pra 2ª).
DateTime _inicioDaQuinzena(DateTime data) {
  final dia = data.day <= 15 ? 1 : 16;
  return DateTime(data.year, data.month, dia);
}

DateTime _fimDaQuinzena(DateTime data) {
  if (data.day <= 15) {
    return DateTime(data.year, data.month, 15);
  }

  // Dia 0 do mês seguinte = último dia do mês atual, lida sozinho com
  // meses de 28, 29, 30 ou 31 dias.
  final ultimoDia = DateTime(data.year, data.month + 1, 0);
  return DateTime(ultimoDia.year, ultimoDia.month, ultimoDia.day);
}

DateTime _previsaoPagamento(DateTime fimQuinzena) {
  return fimQuinzena.add(const Duration(days: 5));
}

bool _mesmoDia(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  final valorController = TextEditingController();
  final observacaoController = TextEditingController();
  bool salvando = false;

  // Buscado uma vez só via count() (não baixa os documentos, só o número)
  // em vez de um StreamBuilder ouvindo em tempo real TODAS as entregas já
  // feitas só pra contar quantas são — isso mantinha uma conexão aberta
  // baixando o histórico inteiro de novo a cada rebuild da tela.
  int? _totalEntregasPagas;

  @override
  void initState() {
    super.initState();
    _carregarTotalEntregas();
  }

  Future<void> _carregarTotalEntregas() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    try {
      final agregada = await FirebaseFirestore.instance
          .collection('entregas')
          .where('motoristaId', isEqualTo: usuario.uid)
          .where('entregue', isEqualTo: true)
          .count()
          .get();

      if (!mounted) return;
      setState(() => _totalEntregasPagas = agregada.count ?? 0);
    } catch (_) {
      // Sem conseguir a contagem, o resumo só fica zerado até a próxima
      // vez que a tela abrir — não é crítico.
    }
  }

  @override
  void dispose() {
    valorController.dispose();
    observacaoController.dispose();
    super.dispose();
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('motoristas')
            .doc(usuario.uid)
            .snapshots(),
        builder: (context, motoristaSnap) {
          final dadosMotorista =
              motoristaSnap.data?.data() as Map<String, dynamic>?;
          final valorPacoteRaw = dadosMotorista?['valorPacote'];
          final valorPacote = valorPacoteRaw is num
              ? valorPacoteRaw.toDouble()
              : 3.0;

          final totalEntregas = _totalEntregasPagas ?? 0;
          final ganhoTotal = totalEntregas * valorPacote;

          return StreamBuilder<QuerySnapshot>(
            // Sem orderBy aqui de propósito: combinar isso com o where
            // de motoristaId exigiria um índice composto no Firestore.
            // A lista é pequena (recebimentos manuais), então ordena
            // no cliente mesmo.
            stream: FirebaseFirestore.instance
                .collection('pagamentos')
                .where('motoristaId', isEqualTo: usuario.uid)
                .snapshots(),
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
              final inicioQuinzena = _inicioDaQuinzena(agora);
              final fimQuinzena = _fimDaQuinzena(agora);
              final previsaoPagamento = _previsaoPagamento(fimQuinzena);
              final fimQuinzenaExclusivo = fimQuinzena.add(
                const Duration(days: 1),
              );

              final entregasQuinzena = listaPacotes.where((p) {
                return p.entregue &&
                    !p.dataLeitura.isBefore(inicioQuinzena) &&
                    p.dataLeitura.isBefore(fimQuinzenaExclusivo);
              }).length;

              final ganhoQuinzena = entregasQuinzena * valorPacote;

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
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumo financeiro',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 24),
                          _linhaResumo(
                            icon: Icons.inventory_2_outlined,
                            titulo: 'Total ganho ($totalEntregas entregas)',
                            valor: _formatarDinheiro(ganhoTotal),
                            color: colors.primary,
                          ),
                          _linhaResumo(
                            icon: Icons.check_circle_outline,
                            titulo: 'Total já recebido',
                            valor: _formatarDinheiro(totalRecebido),
                            color: Colors.green,
                          ),
                          const Divider(height: 24),
                          _linhaResumo(
                            icon: Icons.account_balance_wallet_outlined,
                            titulo: 'Saldo a receber',
                            valor: _formatarDinheiro(saldo),
                            color: saldo > 0 ? Colors.orange : colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

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
                                'Ganho na quinzena ($entregasQuinzena entregas)',
                            valor: _formatarDinheiro(ganhoQuinzena),
                            color: colors.primary,
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
                              'Até 5 dias corridos depois do fim da quinzena.',
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

                  Text(
                    'Recebimentos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

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
    final ehInicio = _mesmoDia(data, inicioQuinzena);
    final ehFim = _mesmoDia(data, fimQuinzena);
    final ehHoje = _mesmoDia(data, hoje);

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
