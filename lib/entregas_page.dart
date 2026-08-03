import 'package:flutter/material.dart';

import 'main.dart';
import 'detalhes_entrega_page.dart';
import 'model/pacote.dart';

class EntregasPage extends StatefulWidget {
  const EntregasPage({super.key});

  @override
  State<EntregasPage> createState() => _EntregasPageState();
}

class _EntregasPageState extends State<EntregasPage> {
  DateTime dataSelecionada = DateTime.now();
  final buscaController = TextEditingController();
  String termoBusca = '';

  @override
  void dispose() {
    buscaController.dispose();
    super.dispose();
  }

  bool mesmoDia(DateTime data1, DateTime data2) {
    return data1.day == data2.day &&
        data1.month == data2.month &&
        data1.year == data2.year;
  }

  bool _combinaComBusca(Pacote pacote, String termo) {
    return pacote.codigo.toLowerCase().contains(termo) ||
        (pacote.transportadora ?? '').toLowerCase().contains(termo) ||
        (pacote.nomeRecebedor ?? '').toLowerCase().contains(termo);
  }

  Future<void> escolherData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: dataSelecionada,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );

    if (data != null) {
      setState(() {
        dataSelecionada = data;
      });
    }
  }

  String formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final pacotesDoDia = listaPacotes
        .where((pacote) {
          final data = pacote.dataLeitura;

          return pacote.entregue && mesmoDia(data, dataSelecionada);
        })
        .toList()
        .reversed
        .toList();

    final termo = termoBusca.trim().toLowerCase();

    final pacotes = termo.isEmpty
        ? pacotesDoDia
        : pacotesDoDia.where((p) => _combinaComBusca(p, termo)).toList();

    final buscaSemResultado =
        termo.isNotEmpty && pacotesDoDia.isNotEmpty && pacotes.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Baixas Realizadas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: escolherData,
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: TextField(
              controller: buscaController,
              onChanged: (valor) => setState(() => termoBusca = valor),
              decoration: InputDecoration(
                hintText: 'Buscar por código, recebedor ou transportadora',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: termoBusca.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          buscaController.clear();
                          setState(() => termoBusca = '');
                        },
                      ),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.all(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Baixas do dia',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatarData(dataSelecionada),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${pacotesDoDia.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: pacotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: colors.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          buscaSemResultado
                              ? 'Nenhum resultado para "${termoBusca.trim()}"'
                              : 'Nenhuma baixa em\n${formatarData(dataSelecionada)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: pacotes.length,
                    itemBuilder: (context, index) {
                      final pacote = pacotes[index];

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
                                  builder: (_) => DetalhesEntregaPage(
                                    pacote: pacote,
                                  ),
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
                                      color: colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: colors.onPrimaryContainer,
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
                                                  "Sem transportadora",
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person,
                                              size: 16,
                                              color: colors.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                pacote.nomeRecebedor ??
                                                    "Não informado",
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'ENTREGUE',
                                            style: TextStyle(
                                              color: colors.onPrimaryContainer,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
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
