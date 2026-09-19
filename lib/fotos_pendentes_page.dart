import 'package:flutter/material.dart';

import 'main.dart';
import 'detalhes_entrega_page.dart';
import 'model/pacote.dart';

class FotosPendentesPage extends StatelessWidget {
  const FotosPendentesPage({super.key});

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year} às '
        '${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final pendentes = listaPacotes
        .where((p) => p.entregue && p.fotoUrl == null)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fotos pendentes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: pendentes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_done_outlined,
                    size: 80,
                    color: colors.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma foto pendente',
                    style: TextStyle(
                      fontSize: 20,
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Essas entregas ainda não terminaram de enviar a foto '
                    'para o servidor. Abra o Menu e toque em "Sincronizar '
                    'fotos" para tentar de novo, ou use o wi-fi/dados móveis '
                    'com sinal melhor.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: pendentes.length,
                    itemBuilder: (context, index) {
                      final Pacote pacote = pendentes[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Material(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                          elevation: 2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetalhesEntregaPage(pacote: pacote),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: colors.secondaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.cloud_upload_outlined,
                                      color: colors.onSecondaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pacote.codigo,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.local_shipping,
                                              size: 16,
                                              color: colors.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              pacote.transportadora ??
                                                  'Sem transportadora',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule,
                                              size: 16,
                                              color: colors.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatarData(
                                                pacote.dataLeitura,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.chevron_right,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
