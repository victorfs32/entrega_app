import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart';

class LoginPage extends StatefulWidget {
  final String? mensagemInicial;

  const LoginPage({super.key, this.mensagemInicial});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  bool carregando = false;
  String erro = '';

  @override
  void initState() {
    super.initState();
    erro = widget.mensagemInicial ?? '';
  }

  Future<void> entrar() async {
    setState(() {
      carregando = true;
      erro = '';
    });

    try {
      final credencial = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: senhaController.text.trim(),
      );

      final motoristaDoc = await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(credencial.user!.uid)
          .get();

      if (motoristaDoc.data()?['ativo'] == false) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        setState(() {
          erro = 'Sua conta está bloqueada. Fale com o administrador.';
        });

        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      setState(() {
        erro = 'E-mail ou senha incorretos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/branding/baixa_facil_mark.png',
                    width: 96,
                    height: 96,
                    semanticLabel: 'Logo Baixa Fácil',
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Baixa Fácil',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Acesse sua conta de motorista'),
                  const SizedBox(height: 26),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: senhaController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (erro.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      erro,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],

                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: carregando ? null : entrar,
                      child: Text(
                        carregando ? 'Entrando...' : 'Entrar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
