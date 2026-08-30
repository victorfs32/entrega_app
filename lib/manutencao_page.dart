import 'package:flutter/material.dart';

class ManutencaoPage extends StatelessWidget {
  final String? mensagem;

  const ManutencaoPage({super.key, this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build_circle_outlined, size: 90, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  'Estamos em manutenção',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  (mensagem == null || mensagem!.trim().isEmpty)
                      ? 'O aplicativo está temporariamente indisponível. Tente novamente em alguns minutos.'
                      : mensagem!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
