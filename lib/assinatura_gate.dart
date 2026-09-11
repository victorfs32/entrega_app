import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'assinatura_page.dart';
import 'main.dart';

/// Fica entre o login confirmado e a Home: se a cobrança de assinatura
/// estiver ativada (configuracoes/app.assinaturaAtiva) e o motorista não é
/// admin nem está em dia, mostra a tela de pagamento em vez do app.
///
/// Desativado por padrão (assinaturaAtiva ausente = false) — o admin liga
/// pelo dashboard quando quiser cobrar de verdade, sem precisar de outro
/// APK.
class AssinaturaGate extends StatelessWidget {
  const AssinaturaGate({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return const HomePage();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('configuracoes')
          .doc('app')
          .snapshots(),
      builder: (context, configSnapshot) {
        final configDados =
            configSnapshot.data?.data() as Map<String, dynamic>?;
        final assinaturaAtiva = configDados?['assinaturaAtiva'] == true;

        if (!assinaturaAtiva) {
          return const HomePage();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('motoristas')
              .doc(usuario.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final dados = snapshot.data?.data() as Map<String, dynamic>?;
            final ehAdmin = dados?['admin'] == true;

            if (ehAdmin) {
              return const HomePage();
            }

            final pagoAte = (dados?['pagoAte'] as Timestamp?)?.toDate();
            final emDia = pagoAte != null && pagoAte.isAfter(DateTime.now());

            if (emDia) {
              return const HomePage();
            }

            return AssinaturaPage(
              motoristaId: usuario.uid,
              email: usuario.email,
              venceuEm: pagoAte,
            );
          },
        );
      },
    );
  }
}
