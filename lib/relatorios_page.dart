import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'main.dart';

class _DiaEntregas {
  final DateTime dia;
  final int quantidade;

  _DiaEntregas({required this.dia, required this.quantidade});
}

class RelatoriosPage extends StatelessWidget {
  const RelatoriosPage({super.key});

  bool _mesmoDia(DateTime a, DateTime b) {
    return a.day == b.day && a.month == b.month && a.year == b.year;
  }

  String _formatarDinheiro(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _letraDia(int weekday) {
    const letras = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    return letras[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return const Scaffold(
        body: Center(child: Text('Usuário não logado')),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('motoristas')
          .doc(usuario.uid)
          .get(),
      builder: (context, snapshot) {
        double valorPacote = 3.00;

        if (snapshot.hasData && snapshot.data!.exists) {
          final dados = snapshot.data!.data() as Map<String, dynamic>?;

          final valor = dados?['valorPacote'];

          if (valor is int) {
            valorPacote = valor.toDouble();
          } else if (valor is double) {
            valorPacote = valor;
          } else if (valor is String) {
            valorPacote = double.tryParse(valor.replaceAll(',', '.')) ?? 3.00;
          }
        }

        final agora = DateTime.now();

        final inicioHoje = DateTime(agora.year, agora.month, agora.day);
        final inicioAmanha = inicioHoje.add(const Duration(days: 1));

        final ontem = inicioHoje.subtract(const Duration(days: 1));

        final inicioMes = DateTime(agora.year, agora.month, 1);
        final inicioProximoMes = DateTime(agora.year, agora.month + 1, 1);

        final inicioSemana = inicioHoje.subtract(
          Duration(days: inicioHoje.weekday - 1),
        );

        final fimSemana = inicioSemana.add(const Duration(days: 7));

        final entreguesHoje = listaPacotes.where((p) {
          return p.entregue &&
              !p.dataLeitura.isBefore(inicioHoje) &&
              p.dataLeitura.isBefore(inicioAmanha);
        }).length;

        final entreguesOntem = listaPacotes.where((p) {
          return p.entregue && _mesmoDia(p.dataLeitura, ontem);
        }).length;

        final entreguesMes = listaPacotes.where((p) {
          return p.entregue &&
              !p.dataLeitura.isBefore(inicioMes) &&
              p.dataLeitura.isBefore(inicioProximoMes);
        }).length;

        final entreguesSemana = listaPacotes.where((p) {
          return p.entregue &&
              !p.dataLeitura.isBefore(inicioSemana) &&
              p.dataLeitura.isBefore(fimSemana);
        }).length;

        final ganhoHoje = entreguesHoje * valorPacote;
        final ganhoSemana = entreguesSemana * valorPacote;
        final ganhoMes = entreguesMes * valorPacote;

        final diasDecorridosNoMes = agora.day;
        final mediaDiariaMes = diasDecorridosNoMes == 0
            ? 0.0
            : entreguesMes / diasDecorridosNoMes;

        final ultimos7Dias = List.generate(7, (i) {
          final dia = inicioHoje.subtract(Duration(days: 6 - i));
          final quantidade = listaPacotes.where((p) {
            return p.entregue && _mesmoDia(p.dataLeitura, dia);
          }).length;

          return _DiaEntregas(dia: dia, quantidade: quantidade);
        });

        final colors = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Relatórios'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Entregas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TileRelatorio(
                        valor: '$entreguesOntem',
                        titulo: 'Ontem',
                        backgroundColor: colors.secondaryContainer,
                        foregroundColor: colors.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TileRelatorio(
                        valor: '$entreguesHoje',
                        titulo: 'Hoje',
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TileRelatorio(
                        valor: '$entreguesMes',
                        titulo: 'Mês',
                        backgroundColor: colors.tertiaryContainer,
                        foregroundColor: colors.onTertiaryContainer,
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
                        valor: 'R\$ ${_formatarDinheiro(ganhoHoje)}',
                        titulo: 'Hoje',
                        backgroundColor: colors.secondaryContainer,
                        foregroundColor: colors.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TileRelatorio(
                        valor: 'R\$ ${_formatarDinheiro(ganhoSemana)}',
                        titulo: 'Semana',
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TileRelatorio(
                        valor: 'R\$ ${_formatarDinheiro(ganhoMes)}',
                        titulo: 'Mês',
                        backgroundColor: colors.tertiaryContainer,
                        foregroundColor: colors.onTertiaryContainer,
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
                      '$entreguesMes entregas em $diasDecorridosNoMes dia(s)',
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
    return dia.day == hoje.day && dia.month == hoje.month && dia.year == hoje.year;
  }

  @override
  Widget build(BuildContext context) {
    const alturaMax = 90.0;
    final maior = dias.fold<int>(0, (a, d) => d.quantidade > a ? d.quantidade : a);

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
