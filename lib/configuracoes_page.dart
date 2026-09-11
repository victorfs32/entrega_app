import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'main.dart';

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _motoristaFuture;

  @override
  void initState() {
    super.initState();
    _motoristaFuture = _carregarMotorista();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _carregarMotorista() {
    return FirebaseFirestore.instance
        .collection('motoristas')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get();
  }

  Future<void> _editarValorPacote(double valorAtual) async {
    final controller = TextEditingController(
      text: valorAtual.toStringAsFixed(2).replaceAll('.', ','),
    );

    final novoValor = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        String? erro;

        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Valor por pacote'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor recebido por pacote entregue',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (erro != null) ...[
                    const SizedBox(height: 10),
                    Text(erro!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final texto = controller.text.trim().replaceAll(',', '.');
                    final valor = double.tryParse(texto);

                    if (valor == null || valor <= 0) {
                      setStateDialog(() => erro = 'Informe um valor válido.');
                      return;
                    }

                    Navigator.pop(dialogContext, valor);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (novoValor == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'valorPacote': novoValor});

      if (!mounted) return;

      setState(() {
        _motoristaFuture = _carregarMotorista();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor por pacote atualizado.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _motoristaFuture,
              builder: (context, snapshot) {
                double valorPacote = 3.0;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final dados = snapshot.data!.data();
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
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar valor',
                      onPressed: () => _editarValorPacote(valorPacote),
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
