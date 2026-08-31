import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'foto_zoom_page.dart';
import 'model/pacote.dart';

class DetalhesEntregaPage extends StatelessWidget {
  final Pacote pacote;

  const DetalhesEntregaPage({
    super.key,
    required this.pacote,
  });

  String _dataFormatada() {
    return DateFormat('dd/MM/yyyy HH:mm').format(pacote.dataLeitura);
  }

  bool get _temGps {
    return pacote.lat != null && pacote.lng != null;
  }

  String get _transportadora {
    return pacote.transportadora ?? "Sem transportadora";
  }

  Color get _statusColor {
    return pacote.entregue ? Colors.green : Colors.orange;
  }

  IconData get _transportadoraIcon {
    if (_transportadora.toLowerCase().contains('anjun')) {
      return Icons.local_shipping;
    }

    return Icons.delivery_dining;
  }

  bool _temFotoUrl(String? url) {
    return url != null && url.trim().isNotEmpty && url.trim() != 'null';
  }

  bool _temFotoLocal(String? path) {
    if (kIsWeb) return false;

    return path != null &&
        path.trim().isNotEmpty &&
        path.trim() != 'null' &&
        File(path).existsSync();
  }

  bool get _temSegundaFoto {
    return _temFotoUrl(pacote.fotoUrl2) || _temFotoLocal(pacote.fotoPath2);
  }

  Future<void> _abrirGoogleMaps(BuildContext context) async {
    if (!_temGps) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("GPS não disponível para esta entrega"),
        ),
      );
      return;
    }

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${pacote.lat},${pacote.lng}',
    );

    final abriu = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!abriu && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Não foi possível abrir o Google Maps"),
        ),
      );
    }
  }

  Widget _infoCard({
    required IconData icon,
    required String titulo,
    required String valor,
    Color? iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? Colors.blue,
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(valor),
      ),
    );
  }

  Widget _fotoEntrega(
    BuildContext context, {
    required String? url,
    required String? path,
  }) {
    // Decodifica a imagem já no tamanho de exibição (260dp de altura) em vez
    // do tamanho original da foto. Sem isso, uma foto de 12MP tirada pela
    // câmera é decodificada inteira na memória só pra mostrar essa miniatura
    // — em celulares com pouca RAM isso causa travamentos e até crash.
    final cacheHeight = (260 * MediaQuery.devicePixelRatioOf(context)).round();

    if (_temFotoUrl(url)) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FotoZoomPage(imagemUrl: url),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            url!,
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
            cacheHeight: cacheHeight,
            errorBuilder: (context, error, stackTrace) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Erro ao carregar foto do Google Drive",
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (_temFotoLocal(path)) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FotoZoomPage(imagemPath: path),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            File(path!),
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
            cacheHeight: cacheHeight,
          ),
        ),
      );
    }

    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text("Nenhuma foto disponível para esta entrega"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Comprovante da Baixa"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF1E293B),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.blue,
                      child: Icon(
                        _transportadoraIcon,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      pacote.codigo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _transportadora,
                      style: const TextStyle(
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _statusColor),
              ),
              child: Row(
                children: [
                  Icon(
                    pacote.entregue ? Icons.check_circle : Icons.access_time,
                    color: _statusColor,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    pacote.entregue ? "ENTREGA FINALIZADA" : "PENDENTE",
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _infoCard(
              icon: Icons.person,
              titulo: "Recebido por",
              valor: pacote.nomeRecebedor == null ||
                      pacote.nomeRecebedor!.trim().isEmpty
                  ? "Não informado"
                  : pacote.nomeRecebedor!,
            ),
            _infoCard(
              icon: Icons.calendar_month,
              titulo: "Data e hora",
              valor: _dataFormatada(),
            ),
            _infoCard(
              icon: Icons.location_on,
              titulo: "Localização",
              valor: _temGps
                  ? "Lat: ${pacote.lat}\nLng: ${pacote.lng}"
                  : "GPS não disponível",
              iconColor: _temGps ? Colors.green : Colors.orange,
            ),
            if (_temGps)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _abrirGoogleMaps(context),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map,
                        size: 40,
                        color: Colors.green,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Abrir localização no Google Maps",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Text(
              "Foto da entrega",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            _fotoEntrega(context, url: pacote.fotoUrl, path: pacote.fotoPath),
            if (_temSegundaFoto) ...[
              const SizedBox(height: 16),
              const Text(
                "2ª foto da entrega",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              _fotoEntrega(
                context,
                url: pacote.fotoUrl2,
                path: pacote.fotoPath2,
              ),
            ],
          ],
        ),
      ),
    );
  }
}