import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Checagem compartilhada entre o scanner individual e o de lote: impede
/// que o motorista bipe de novo um pacote que ele mesmo já entregou.
class EntregaStatusService {
  EntregaStatusService._();

  // Falha aberta (retorna false) se der erro de rede — não trava o
  // motorista por uma instabilidade momentânea de conexão.
  static Future<bool> jaEntregue(String codigo) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return false;

    try {
      final consulta = await FirebaseFirestore.instance
          .collection('entregas')
          .where('codigo', isEqualTo: codigo)
          .where('motoristaId', isEqualTo: usuario.uid)
          .limit(1)
          .get();

      if (consulta.docs.isEmpty) return false;

      return consulta.docs.first.data()['entregue'] == true;
    } catch (_) {
      return false;
    }
  }
}
