import 'package:flutter/material.dart';
import 'main.dart';

class ConfiguracoesPage extends StatelessWidget {
  const ConfiguracoesPage({super.key});

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

            const Card(
              child: ListTile(
                leading: Icon(
                  Icons.local_shipping,
                  color: Colors.orange,
                ),
                title: Text('Valor por entrega'),
                subtitle: Text('R\$ 3,00 por pacote'),
              ),
            ),

            const SizedBox(height: 10),

            const Card(
              child: ListTile(
                leading: Icon(
                  Icons.info,
                  color: Colors.blue,
                ),
                title: Text('Versão'),
                subtitle: Text('Entrega App v1.0'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}