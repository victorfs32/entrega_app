import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  final valorController = TextEditingController();
  final observacaoController = TextEditingController();
  bool salvando = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor válido.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recebimento registrado.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar: $e')),
      );
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
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
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
          final dadosMotorista = motoristaSnap.data?.data() as Map<String, dynamic>?;
          final valorPacoteRaw = dadosMotorista?['valorPacote'];
          final valorPacote = valorPacoteRaw is num ? valorPacoteRaw.toDouble() : 3.0;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('entregas')
                .where('motoristaId', isEqualTo: usuario.uid)
                .where('entregue', isEqualTo: true)
                .snapshots(),
            builder: (context, entregasSnap) {
              final totalEntregas = entregasSnap.data?.docs.length ?? 0;
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
                      final dataA = (a.data() as Map<String, dynamic>)['data'] as Timestamp?;
                      final dataB = (b.data() as Map<String, dynamic>)['data'] as Timestamp?;
                      return (dataB?.seconds ?? 0).compareTo(dataA?.seconds ?? 0);
                    });
                  final totalRecebido = docs.fold<double>(0, (soma, doc) {
                    final dados = doc.data() as Map<String, dynamic>;
                    final valor = dados['valor'];
                    return soma + (valor is num ? valor.toDouble() : 0);
                  });
                  final saldo = ganhoTotal - totalRecebido;

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
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                              Text(
                                'Registrar recebimento',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                  onPressed: salvando ? null : _registrarRecebimento,
                                  icon: const Icon(Icons.add),
                                  label: Text(salvando ? 'Salvando...' : 'Registrar'),
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
                          if (data != null) DateFormat('dd/MM/yyyy HH:mm').format(data),
                          if (observacao.isNotEmpty) observacao,
                        ].join(' • ');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.attach_money, color: Colors.green),
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
          );
        },
      ),
    );
  }
}
