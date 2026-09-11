import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final nomeController = TextEditingController();
  final telefoneController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  bool carregando = false;
  String erro = '';

  @override
  void dispose() {
    nomeController.dispose();
    telefoneController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _mostrarBoasVindas() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.celebration_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Bem-vindo ao Baixa Fácil!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Sua conta foi criada. Aqui vai um resumo rápido do que você '
                'pode fazer:',
              ),
              SizedBox(height: 14),
              _ItemBoasVindas(
                icon: Icons.qr_code_scanner,
                texto: 'Bipar pacotes e registrar a entrega com foto na hora.',
              ),
              _ItemBoasVindas(
                icon: Icons.dynamic_feed,
                texto: 'Bipar vários pacotes seguidos no modo "Entrega em massa".',
              ),
              _ItemBoasVindas(
                icon: Icons.bar_chart,
                texto: 'Acompanhar relatórios e o financeiro (ganho x recebido).',
              ),
              _ItemBoasVindas(
                icon: Icons.cloud_upload_outlined,
                texto: 'As fotos sincronizam sozinhas com a internet ligada.',
              ),
              SizedBox(height: 14),
              _ItemBoasVindas(
                icon: Icons.computer,
                texto:
                    'Também existe um painel para computador, com relatórios '
                    'e mais detalhes — peça o link ao administrador se '
                    'quiser acessar pelo navegador.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Começar a usar'),
          ),
        ],
      ),
    );
  }

  String? _validarCampos() {
    if (nomeController.text.trim().isEmpty) {
      return 'Informe seu nome.';
    }

    if (telefoneController.text.trim().isEmpty) {
      return 'Informe seu telefone.';
    }

    if (!emailController.text.trim().contains('@')) {
      return 'Informe um e-mail válido.';
    }

    if (senhaController.text.trim().length != 6) {
      return 'A senha precisa ter exatamente 6 dígitos.';
    }

    if (senhaController.text.trim() != confirmarSenhaController.text.trim()) {
      return 'As senhas não coincidem.';
    }

    return null;
  }

  Future<void> _cadastrar() async {
    final erroValidacao = _validarCampos();

    if (erroValidacao != null) {
      setState(() => erro = erroValidacao);
      return;
    }

    setState(() {
      carregando = true;
      erro = '';
    });

    try {
      final credencial = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: senhaController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(credencial.user!.uid)
          .set({
        'nome': nomeController.text.trim(),
        'telefone': telefoneController.text.trim(),
        'email': emailController.text.trim(),
        'admin': false,
        'ativo': true,
        'valorPacote': 3,
        'criadoEm': Timestamp.now(),
      });

      if (!mounted) return;

      await _mostrarBoasVindas();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        erro = switch (e.code) {
          'email-already-in-use' => 'Esse e-mail já está cadastrado.',
          'invalid-email' => 'E-mail inválido.',
          'weak-password' => 'Senha muito fraca.',
          _ => 'Não foi possível cadastrar. Tente novamente.',
        };
      });
    } catch (_) {
      setState(() => erro = 'Não foi possível cadastrar. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cadastre-se como motorista',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('Leva menos de um minuto.'),
            const SizedBox(height: 24),

            TextField(
              controller: nomeController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: telefoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefone',
                hintText: '(85) 99999-9999',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: senhaController,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Senha (6 dígitos)',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: confirmarSenhaController,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Confirmar senha',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),

            if (erro.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(erro, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 22),

            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: carregando ? null : _cadastrar,
                child: Text(carregando ? 'Criando conta...' : 'Criar conta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemBoasVindas extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _ItemBoasVindas({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
