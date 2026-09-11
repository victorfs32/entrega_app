import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'assinatura_page.dart';

/// Checa se o motorista pode usar as funcionalidades que exigem assinatura
/// em dia (bipar/registrar entrega) — admin e app com cobrança desligada
/// sempre liberam. Se estiver bloqueado, mostra um aviso com atalho pra
/// tela de pagamento e retorna `false`; quem chamar não deve prosseguir
/// com a ação nesse caso.
Future<bool> verificarAcessoLiberado(BuildContext context) async {
  final usuario = FirebaseAuth.instance.currentUser;
  if (usuario == null) return true;

  try {
    final configDoc = await FirebaseFirestore.instance
        .collection('configuracoes')
        .doc('app')
        .get();

    final assinaturaAtiva = configDoc.data()?['assinaturaAtiva'] == true;
    if (!assinaturaAtiva) return true;

    final motoristaDoc = await FirebaseFirestore.instance
        .collection('motoristas')
        .doc(usuario.uid)
        .get();

    final dados = motoristaDoc.data();
    if (dados?['admin'] == true) return true;

    final pagoAte = (dados?['pagoAte'] as Timestamp?)?.toDate();
    final emDia = pagoAte != null && pagoAte.isAfter(DateTime.now());
    if (emDia) return true;
  } catch (_) {
    // Sem conseguir confirmar por um problema de rede, não bloqueia —
    // igual ao resto do app, prefere deixar passar a travar o motorista
    // por uma falha momentânea de conexão.
    return true;
  }

  if (!context.mounted) return false;

  final irPagar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Assinatura necessária'),
      content: const Text(
        'Pra bipar e registrar entregas, sua assinatura semanal precisa '
        'estar em dia. Você ainda pode ver a tela inicial normalmente.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Depois'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Pagar agora'),
        ),
      ],
    ),
  );

  if (irPagar == true && context.mounted) {
    final usuarioAtual = FirebaseAuth.instance.currentUser;

    if (usuarioAtual != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssinaturaPage(
            motoristaId: usuarioAtual.uid,
            email: usuarioAtual.email,
            venceuEm: null,
          ),
        ),
      );
    }
  }

  return false;
}
