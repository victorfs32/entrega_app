import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'entregas_page.dart';
import 'relatorios_page.dart';
import 'configuracoes_page.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final String servidorFotos =
    "https://servidor-fotos-entregas.vercel.app";

  bool sincronizando = false;
  int totalEncontradas = 0;
  int totalEnviadas = 0;
  int totalIgnoradas = 0;
  int totalErros = 0;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _sincronizarFotosAutomatico();
      }
    });
  }

  void _abrirEntregas(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EntregasPage(),
      ),
    );
  }

  Future<Map<String, dynamic>> _enviarFotoParaServidor({
    required String codigo,
    required String fotoPath,
  }) async {
    final arquivo = File(fotoPath);

    if (!await arquivo.exists()) {
      throw Exception('Arquivo não encontrado no celular');
    }

    final url = Uri.parse('$servidorFotos/upload');

    final request = http.MultipartRequest('POST', url);
    request.fields['codigo'] = codigo;

    request.files.add(
      await http.MultipartFile.fromPath(
        'foto',
        arquivo.path,
      ),
    );

    final response = await request.send().timeout(
          const Duration(seconds: 12),
        );

    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Servidor respondeu erro: $responseBody');
    }

    final decoded = jsonDecode(responseBody);

    if (decoded['fotoUrl'] == null || decoded['fotoPath'] == null) {
      throw Exception('Servidor não retornou fotoUrl/fotoPath');
    }

    return decoded;
  }

  Future<void> _sincronizarFotosAutomatico() async {
    await _executarSincronizacao(mostrarMensagemFinal: false);
  }

  Future<void> _sincronizarFotosManual() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sincronizar fotos?'),
          content: const Text(
            'O app vai procurar entregas no Firebase que tenham fotoPath, '
            'Enviar fotos pendentes para o servidor online',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sincronizar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    await _executarSincronizacao(mostrarMensagemFinal: true);
  }

  Future<void> _executarSincronizacao({
    required bool mostrarMensagemFinal,
  }) async {
    if (sincronizando) return;

    setState(() {
      sincronizando = true;
      totalEncontradas = 0;
      totalEnviadas = 0;
      totalIgnoradas = 0;
      totalErros = 0;
    });

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('entregas').get();

      if (!mounted) return;

      setState(() {
        totalEncontradas = snapshot.docs.length;
      });

      for (final doc in snapshot.docs) {
        final dados = doc.data();

        final codigo = (dados['codigo'] ?? '').toString().trim();
        final fotoPath = (dados['fotoPath'] ?? '').toString().trim();
        final fotoUrl = (dados['fotoUrl'] ?? '').toString().trim();

        if (codigo.isEmpty || fotoPath.isEmpty) {
          if (!mounted) return;
          setState(() => totalIgnoradas++);
          continue;
        }

        if (fotoUrl.isNotEmpty && fotoUrl != 'null') {
          if (!mounted) return;
          setState(() => totalIgnoradas++);
          continue;
        }

        try {
          final resultadoUpload = await _enviarFotoParaServidor(
            codigo: codigo,
            fotoPath: fotoPath,
          );

          await FirebaseFirestore.instance
              .collection('entregas')
              .doc(doc.id)
              .update({
            'fotoUrl': resultadoUpload['fotoUrl'],
            'fotoServerPath': resultadoUpload['fotoPath'],
            'fotoSincronizada': true,
            'dataSincronizacaoFoto': Timestamp.now(),
            'erroSincronizacaoFoto': FieldValue.delete(),
          });

          if (!mounted) return;
          setState(() => totalEnviadas++);
        } catch (e) {
          await FirebaseFirestore.instance
              .collection('entregas')
              .doc(doc.id)
              .update({
            'fotoSincronizada': false,
            'erroSincronizacaoFoto': e.toString(),
          }).catchError((_) {});

          if (!mounted) return;
          setState(() => totalErros++);
        }
      }

      if (!mounted) return;

      if (mostrarMensagemFinal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Finalizado. Enviadas: $totalEnviadas | Ignoradas: $totalIgnoradas | Erros: $totalErros',
            ),
            backgroundColor: totalErros == 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      if (mostrarMensagemFinal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar entregas no Firebase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (!mounted) return;

      setState(() {
        sincronizando = false;
      });
    }
  }

  Widget _itemMenu({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback? onTap,
    Color iconColor = Colors.blue,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32, color: iconColor),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitulo),
        trailing: sincronizando && titulo == 'Sincronizar fotos'
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progresso = totalEncontradas == 0
        ? 'Preparando sincronização...'
        : 'Encontradas: $totalEncontradas | Enviadas: $totalEnviadas | Ignoradas: $totalIgnoradas | Erros: $totalErros';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _itemMenu(
              icon: Icons.list_alt,
              titulo: 'Entregas',
              subtitulo: 'Ver pacotes entregues e pendentes',
              onTap: () => _abrirEntregas(context),
            ),
            _itemMenu(
              icon: Icons.bar_chart,
              titulo: 'Relatórios',
              subtitulo: 'Ganhos por dia e por semana',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RelatoriosPage()),
                );
              },
            ),
            _itemMenu(
              icon: Icons.cloud_upload,
              titulo: 'Sincronizar fotos',
              subtitulo: sincronizando
                  ? progresso
                  : 'Enviar fotos pendentes para o servidor do PC',
              iconColor: Colors.green,
              onTap: sincronizando ? null : _sincronizarFotosManual,
            ),
            _itemMenu(
              icon: Icons.settings,
              titulo: 'Configurações',
              subtitulo: 'Ajustes do aplicativo',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ConfiguracoesPage()),
                );
              },
            ),
            _itemMenu(
              icon: Icons.info,
              titulo: 'Sobre o app',
              subtitulo: 'Informações do Entrega App',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}