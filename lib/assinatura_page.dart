import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AssinaturaPage extends StatefulWidget {
  final String motoristaId;
  final String? email;
  final DateTime? venceuEm;

  const AssinaturaPage({
    super.key,
    required this.motoristaId,
    required this.email,
    required this.venceuEm,
  });

  @override
  State<AssinaturaPage> createState() => _AssinaturaPageState();
}

class _AssinaturaPageState extends State<AssinaturaPage> {
  static const String _servidorUrl =
      'https://servidor-fotos-entregas.vercel.app';

  final Dio _dio = Dio();

  bool carregando = true;
  String? erro;
  String? copiaECola;
  Uint8List? qrCodeBytes;
  num valor = 10;

  @override
  void initState() {
    super.initState();
    _gerarCobranca();
  }

  Future<void> _gerarCobranca() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final resposta = await _dio.post(
        '$_servidorUrl/pagamento/gerar',
        data: {
          'motoristaId': widget.motoristaId,
          'email': widget.email,
        },
      );

      final dados = resposta.data as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        copiaECola = dados['copiaECola'] as String?;
        qrCodeBytes = dados['qrCodeBase64'] != null
            ? base64Decode(dados['qrCodeBase64'] as String)
            : null;
        valor = (dados['valor'] as num?) ?? valor;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        erro = 'Não foi possível gerar a cobrança. Tente novamente.';
        carregando = false;
      });
    }
  }

  void _copiarCodigo() {
    if (copiaECola == null) return;

    Clipboard.setData(ClipboardData(text: copiaECola!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código Pix copiado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final venceuEm = widget.venceuEm;

    return Scaffold(
      appBar: AppBar(title: const Text('Assinatura')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.lock_clock,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              venceuEm == null
                  ? 'Assinatura pendente'
                  : 'Assinatura vencida',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'O uso do Baixa Fácil custa R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')} '
              'por semana. Pague pelo Pix abaixo para liberar o acesso — a '
              'tela libera sozinha assim que o pagamento for confirmado.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (carregando)
              const Center(child: CircularProgressIndicator())
            else if (erro != null) ...[
              Text(
                erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _gerarCobranca,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar de novo'),
              ),
            ] else ...[
              if (qrCodeBytes != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Image.memory(qrCodeBytes!, width: 220, height: 220),
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _copiarCodigo,
                icon: const Icon(Icons.copy),
                label: const Text('Copiar código Pix'),
              ),
              const SizedBox(height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Aguardando confirmação do pagamento...',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
