import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'main.dart';

class ConfiguracoesPage extends StatelessWidget {
  const ConfiguracoesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: MyApp.darkMode,
              builder: (context, isDark, child) {
                return Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.dark_mode),
                    title: const Text('Tema Escuro'),
                    subtitle: const Text(
                      'Ativar tema escuro em todo aplicativo',
                    ),
                    value: isDark,
                    onChanged: (value) {
                      MyApp.salvarTema(value);
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('motoristas')
                  .doc(usuario?.uid)
                  .get(),
              builder: (context, snapshot) {
                double valorPacote = 3.0;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final dados =
                      snapshot.data!.data() as Map<String, dynamic>?;

                  final valor = dados?['valorPacote'];

                  if (valor is int) {
                    valorPacote = valor.toDouble();
                  } else if (valor is double) {
                    valorPacote = valor;
                  }
                }

                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_shipping,
                      color: Colors.orange,
                    ),
                    title: const Text('Valor por entrega'),
                    subtitle: Text(
                      'R\$ ${valorPacote.toStringAsFixed(2).replaceAll('.', ',')} por pacote',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final versao = snapshot.data?.version ?? '...';

                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.info,
                      color: Colors.blue,
                    ),
                    title: const Text('Versão'),
                    subtitle: Text('Baixa Fácil v$versao'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}