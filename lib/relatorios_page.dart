import 'package:flutter/material.dart';

import 'services/lancamentos_service.dart';
import 'ui/painel_financeiro.dart';
import 'utils/quinzena.dart' as quinzena;

/// Relatórios de produção e ganho, calculados a partir dos lançamentos
/// diários (os mesmos que alimentam o Financeiro) — assim os números das
/// duas telas nunca divergem.
class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  // Um stream só pra tela inteira — criar um novo a cada build()
  // re-assinaria o Firestore e piscava os números.
  final Stream<List<Lancamento>> _lancamentos = LancamentosService.ouvir();

  static String _dinheiro(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: StreamBuilder<List<Lancamento>>(
        stream: _lancamentos,
        builder: (context, snapshot) {
          final lancamentos = snapshot.data ?? const <Lancamento>[];

          final agora = DateTime.now();
          final hoje = DateTime(agora.year, agora.month, agora.day);
          final ontem = hoje.subtract(const Duration(days: 1));

          final resumoHoje = LancamentosService.somar(
            lancamentos,
            inicio: hoje,
            fim: hoje,
          );
          final resumoOntem = LancamentosService.somar(
            lancamentos,
            inicio: ontem,
            fim: ontem,
          );
          final resumoQuinzena = LancamentosService.somar(
            lancamentos,
            inicio: quinzena.inicioDaQuinzena(hoje),
            fim: quinzena.fimDaQuinzena(hoje),
          );
          final resumoMes = LancamentosService.somar(
            lancamentos,
            inicio: DateTime(hoje.year, hoje.month, 1),
            fim: DateTime(hoje.year, hoje.month + 1, 0),
          );

          final mediaDiariaMes = agora.day == 0
              ? 0.0
              : resumoMes.totalPacotes / agora.day;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              PainelHero(
                rotulo: 'Ganho do mês',
                valor: resumoMes.ganho,
                apoio:
                    '${resumoMes.totalPacotes} pacotes • média de '
                    '${mediaDiariaMes.toStringAsFixed(1).replaceAll('.', ',')}'
                    ' por dia',
                pilulas: [
                  (Icons.inventory_2_outlined, 'Anjun ${resumoMes.anjun}'),
                  (Icons.inventory_outlined, 'iMile ${resumoMes.imile}'),
                ],
              ),

              const TituloSecao('Pacotes'),
              FaixaMetricas(
                itens: [
                  ('Ontem', '${resumoOntem.totalPacotes}'),
                  ('Hoje', '${resumoHoje.totalPacotes}'),
                  ('Quinzena', '${resumoQuinzena.totalPacotes}'),
                ],
              ),

              const TituloSecao('Ganhos'),
              FaixaMetricas(
                itens: [
                  ('Hoje', _dinheiro(resumoHoje.ganho)),
                  ('Quinzena', _dinheiro(resumoQuinzena.ganho)),
                  ('Mês', _dinheiro(resumoMes.ganho)),
                ],
              ),

              const SizedBox(height: 14),

              GraficoGanhos(lancamentos: lancamentos),
            ],
          );
        },
      ),
    );
  }
}
