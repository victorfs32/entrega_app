import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'main.dart';

class RelatoriosPage extends StatelessWidget {
  const RelatoriosPage({super.key});

  bool _mesmoDia(DateTime a, DateTime b) {
    return a.day == b.day && a.month == b.month && a.year == b.year;
  }

  String _formatarDinheiro(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Text(
            'Usuário não logado',
            style: TextStyle(color: Colors.white),
          ),
        ),
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
            valorPacote = double.tryParse(
                  valor.replaceAll(',', '.'),
                ) ??
                3.00;
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

        final ganhosSemana = entreguesSemana * valorPacote;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            title: const Text('Relatórios'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.green,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(
                                '$entreguesOntem',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Ontem',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: Colors.orange,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(
                                '$entreguesHoje',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Hoje',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: Colors.blue,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(
                                '$entreguesMes',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Mês',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Card(
                  color: const Color(0xFF1E293B),
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_month,
                      color: Colors.blue,
                    ),
                    title: const Text(
                      'Entregas da Semana',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Segunda até domingo',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: Text(
                      '$entreguesSemana',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                Card(
                  color: const Color(0xFF1E293B),
                  child: ListTile(
                    leading: const Icon(
                      Icons.attach_money,
                      color: Colors.green,
                    ),
                    title: const Text(
                      'Ganho da Semana',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'R\$ ${_formatarDinheiro(valorPacote)} por pacote',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: Text(
                      'R\$ ${_formatarDinheiro(ganhosSemana)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
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