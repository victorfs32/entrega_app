import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  Future<Map<String, dynamic>?> _buscarMotorista() async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('motoristas')
        .doc(usuario.uid)
        .get();

    return doc.data();
  }

  Future<void> _sair(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _buscarMotorista(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final motorista = snapshot.data;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 42,
                          child: Icon(Icons.person, size: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          motorista?['nome'] ?? 'Motorista',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          motorista?['admin'] == true
                              ? 'Administrador'
                              : 'Motorista',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('E-mail'),
                        subtitle: Text(
                          motorista?['email'] ?? usuario?.email ?? 'Não informado',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.phone),
                        title: const Text('Telefone'),
                        subtitle: Text(
                          motorista?['telefone'] ?? 'Não informado',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.local_shipping),
                        title: const Text('Transportadora'),
                        subtitle: Text(
                          motorista?['transportadora'] ?? 'Não informado',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.verified_user),
                        title: const Text('Status'),
                        subtitle: Text(
                          motorista?['ativo'] == false ? 'Inativo' : 'Ativo',
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _sair(context),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Sair da conta',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}