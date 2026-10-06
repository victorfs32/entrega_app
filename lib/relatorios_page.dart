import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'services/lancamentos_service.dart';
import 'utils/quinzena.dart' as quinzena;

class _DiaEntregas {
  final DateTime dia;
  final int quantidade;

  _DiaEntregas({required this.dia, required this.quantidade});
}

/// Relatórios de produção e ganho, calculados a partir dos lançamentos
/// diários (os mesmos que alimentam o Financeiro) — assim os números das
/// duas telas nunca divergem.
class RelatoriosPage extends StatelessWidget {
  const RelatoriosPage({super.key});

  String _formatarDinheiro(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _letraDia(int weekday) {
    const letras = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    return letras[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lancamento>>(
      stream: LancamentosService.ouvir(),
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

        final diasDecorridosNoMes = agora.day;
        final mediaDiariaMes = diasDecorridosNoMes == 0
            ? 0.0
            : resumoMes.totalPacotes / diasDecorridosNoMes;

        final ultimos7Dias = List.generate(7, (i) {
          final dia = hoje.subtract(Duration(days: 6 - i));
          final resumo = LancamentosService.somar(
            lancamentos,
            inicio: dia,
            fim: dia,
          );

          return _DiaEntregas(dia: dia, quantidade: resumo.totalPacotes);
        });

        final colors = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Relatórios'), centerTitle: true),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pacotes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TileRelatorio(
                        valor: '${resumoOntem.totalPacotes}',
                        titulo: 'Ontem',
                        backgroundColor: context.accentColors.container(3),
                        foregroundColor: context.accentColors.onContainer(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TileRelatorio(
                        valor: '${resumoHoje.totalPacotes}',
                        titulo: 'Hoje',
                        backgroundColor: context.accentColors.container(2),
                        foregroundColor: context.accentColors.onContainer(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TileRelatorio(
                        valor: '${resumoMes.totalPacotes}',
                        titulo: 'Mês',
                        backgroundColor: context.accentColors.container(1),
                        foregroundColor: context.accentColors.onContainer(1),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  'Ganhos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TileRelatorio(
                        valor: 'R\$ ${_formatarDinheiro(resumoHoje.ganho)}',
                        titulo: 'Hoje',
                        backgroundColor: context.accentColors.container(3),
                        foregroundColor: context.accentColors.onContainer(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TileRelatorio(
                        valor: 'R\$ ${_formatarDinheiro(resumoQuinzena.ganho)}',
                        titulo: 'Quinzena',
                        backgroundColor: context.accentColors.container(2),
                        foregroundColor: context.accentColors.onContainer(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TileRelatorio(
                        valor: 'R\$ ${_formatarDinheiro(resumoMes.ganho)}',
                        titulo: 'Mês',
                        backgroundColor: context.accentColors.container(1),
                        foregroundColor: context.accentColors.onContainer(1),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Card(
                  child: ListTile(
                    leading: Icon(Icons.speed, color: colors.primary),
                    title: const Text('Média diária do mês'),
                    subtitle: Text(
                      '${resumoMes.totalPacotes} pacotes em '
                      '$diasDecorridosNoMes dia(s)',
                    ),
                    trailing: Text(
                      '${mediaDiariaMes.toStringAsFixed(1).replaceAll('.', ',')}/dia',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Últimos 7 dias',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: _GraficoSemana(
                      dias: ultimos7Dias,
                      letraDia: _letraDia,
                      colors: colors,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TileRelatorio extends StatelessWidget {
  final String valor;
  final String titulo;
  final Color backgroundColor;
  final Color foregroundColor;

  const _TileRelatorio({
    required this.valor,
    required this.titulo,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              style: TextStyle(color: foregroundColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraficoSemana extends StatelessWidget {
  final List<_DiaEntregas> dias;
  final String Function(int weekday) letraDia;
  final ColorScheme colors;

  const _GraficoSemana({
    required this.dias,
    required this.letraDia,
    required this.colors,
  });

  bool _ehHoje(DateTime dia) {
    final hoje = DateTime.now();
    return dia.day == hoje.day &&
        dia.month == hoje.month &&
        dia.year == hoje.year;
  }

  @override
  Widget build(BuildContext context) {
    const alturaMax = 90.0;
    final maior = dias.fold<int>(
      0,
      (a, d) => d.quantidade > a ? d.quantidade : a,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: dias.map((d) {
        final hoje = _ehHoje(d.dia);
        final altura = maior == 0 ? 4.0 : (d.quantidade / maior) * alturaMax;

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${d.quantidade}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: altura < 4 ? 4 : altura,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: hoje ? colors.primary : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                letraDia(d.dia.weekday),
                style: TextStyle(
                  fontSize: 11,
                  color: hoje ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: hoje ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
