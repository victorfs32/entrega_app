import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import 'main.dart';
import 'model/pacote.dart';

class RegistrarEntregaPage extends StatefulWidget {
  final String codigo;
  final String transportadora;

  const RegistrarEntregaPage({
    super.key,
    required this.codigo,
    required this.transportadora,
  });

  @override
  State<RegistrarEntregaPage> createState() => _RegistrarEntregaPageState();
}

class _RegistrarEntregaPageState extends State<RegistrarEntregaPage> {
  final TextEditingController nomeController = TextEditingController();
  final ImagePicker picker = ImagePicker();

  File? foto;
  double? lat;
  double? lng;

  bool salvando = false;
  bool pegandoGps = true;

  @override
  void initState() {
    super.initState();
    _pegarGPS();
  }

  @override
  void dispose() {
    nomeController.dispose();
    super.dispose();
  }

  Future<void> _pegarGPS() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => pegandoGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => pegandoGps = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 3),
      );

      if (!mounted) return;

      setState(() {
        lat = position.latitude;
        lng = position.longitude;
        pegandoGps = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => pegandoGps = false);
    }
  }

  Future<void> _tirarFoto() async {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fotosDir = Directory('${appDir.path}/fotos_entregas');

    if (!await fotosDir.exists()) {
      await fotosDir.create(recursive: true);
    }

    final nomeArquivo =
        '${widget.codigo}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final novaFoto = await File(picked.path).copy(
      '${fotosDir.path}/$nomeArquivo',
    );

    setState(() {
      foto = novaFoto;
    });
  }

  Future<void> _salvarEntrega() async {
    if (salvando) return;

    final nomeRecebedor = nomeController.text.trim();

    if (nomeRecebedor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o nome de quem recebeu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tire a foto da entrega antes de salvar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      final usuario = FirebaseAuth.instance.currentUser;

      if (usuario == null) {
        if (!mounted) return;

        setState(() {
          salvando = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário não autenticado. Faça login novamente.'),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      final motoristaDoc = await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(usuario.uid)
          .get();

      final motorista = motoristaDoc.data();

      final consulta = await FirebaseFirestore.instance
          .collection('entregas')
          .where('codigo', isEqualTo: widget.codigo)
          .limit(1)
          .get();

      final dadosEntrega = {
        'codigo': widget.codigo,
        'transportadora': widget.transportadora,
        'recebedor': nomeRecebedor,
        'entregue': true,

        'fotoPath': foto!.path,
        'fotoUrl': null,
        'fotoServerPath': null,
        'fotoSincronizada': false,

        'lat': lat,
        'lng': lng,

        'dataEntrega': Timestamp.now(),

        'motoristaId': usuario.uid,
        'motoristaEmail': usuario.email ?? '',
        'motoristaNome': motorista?['nome'] ?? '',
        'motoristaTelefone': motorista?['telefone'] ?? '',
        'motoristaTransportadora':
            motorista?['transportadora'] ?? widget.transportadora,
      };

      if (consulta.docs.isNotEmpty) {
        await consulta.docs.first.reference.update(dadosEntrega);
      } else {
        await FirebaseFirestore.instance.collection('entregas').add({
          ...dadosEntrega,
          'dataLeitura': Timestamp.now(),
        });
      }

      final index = listaPacotes.indexWhere(
        (p) => p.codigo == widget.codigo,
      );

      final pacoteAtualizado = Pacote(
        codigo: widget.codigo,
        transportadora: widget.transportadora,
        dataLeitura: DateTime.now(),
        nomeRecebedor: nomeRecebedor,
        fotoPath: foto!.path,
        lat: lat,
        lng: lng,
        entregue: true,
      );

      if (index >= 0) {
        listaPacotes[index] = pacoteAtualizado;
      } else {
        listaPacotes.add(pacoteAtualizado);
      }

      if (!mounted) return;

      Navigator.pop(context, widget.codigo);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        salvando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar entrega: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpsOk = lat != null && lng != null;

    final podeSalvar =
        !salvando && nomeController.text.trim().isNotEmpty && foto != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Entrega"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2),
                title: Text(widget.codigo),
                subtitle: Text(widget.transportadora),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: nomeController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Quem recebeu",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: salvando ? null : _tirarFoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  foto == null ? "Tirar foto da entrega" : "Trocar foto",
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (foto != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  foto!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 12),

            Row(
              children: [
                Icon(
                  gpsOk ? Icons.check_circle : Icons.location_searching,
                  color: gpsOk ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gpsOk
                        ? "GPS OK: $lat, $lng"
                        : pegandoGps
                            ? "Pegando GPS..."
                            : "GPS não disponível, mas pode salvar.",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Foto salva no celular. Sincronize depois em casa.",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: podeSalvar ? _salvarEntrega : null,
                icon: salvando
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check),
                label: salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        nomeController.text.trim().isEmpty
                            ? "Informe o recebedor"
                            : foto == null
                                ? "Tire a foto da entrega"
                                : "Confirmar Entrega",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}