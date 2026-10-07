import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'services/lancamentos_service.dart';
import 'ui/painel_financeiro.dart';

/// Lançamento: quantos pacotes foram entregues em cada empresa e o valor
/// pago por pacote de cada uma. Cada vez que abre sem [lancamento] cria um
/// lançamento novo — um dia pode ter vários (rota da manhã, da tarde...) e o
/// ganho do dia é a soma. Com [lancamento], edita aquele.
class LancamentoPage extends StatefulWidget {
  final DateTime? diaInicial;
  final Lancamento? lancamento;

  const LancamentoPage({super.key, this.diaInicial, this.lancamento});

  @override
  State<LancamentoPage> createState() => _LancamentoPageState();
}

class _LancamentoPageState extends State<LancamentoPage> {
  final anjunController = TextEditingController();
  final imileController = TextEditingController();
  final valorAnjunController = TextEditingController();
  final valorImileController = TextEditingController();

  late DateTime dia;
  List<Lancamento> existentes = [];
  StreamSubscription<List<Lancamento>>? _assinatura;

  // Valores que estavam gravados no perfil ao abrir a tela — usados só pra
  // saber se precisa atualizar o perfil ao salvar.
  double _valorAnjunPerfil = 0;
  double _valorImilePerfil = 0;

  bool carregandoValores = true;
  bool salvando = false;

  Lancamento? get _editando => widget.lancamento;

  @override
  void initState() {
    super.initState();

    final base = _editando?.dia ?? widget.diaInicial ?? DateTime.now();
    dia = DateTime(base.year, base.month, base.day);

    _carregarValoresDoPerfil();

    // Só pra avisar quanto o dia já tem lançado; não mexe nos campos.
    _assinatura = LancamentosService.ouvir().listen((lista) {
      if (!mounted) return;
      setState(() => existentes = lista);
    });
  }

  @override
  void dispose() {
    _assinatura?.cancel();
    anjunController.dispose();
    imileController.dispose();
    valorAnjunController.dispose();
    valorImileController.dispose();
    super.dispose();
  }

  static const _diasSemana = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  static String _dinheiro(double valor) =>
      valor.toStringAsFixed(2).replaceAll('.', ',');

  Future<void> _carregarValoresDoPerfil() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(usuario.uid)
          .get();

      final dados = doc.data();
      final base = (dados?['valorPacote'] as num?)?.toDouble() ?? 3.0;

      _valorAnjunPerfil = (dados?['valorAnjun'] as num?)?.toDouble() ?? base;
      _valorImilePerfil = (dados?['valorImile'] as num?)?.toDouble() ?? base;
    } catch (_) {
      _valorAnjunPerfil = 3.0;
      _valorImilePerfil = 3.0;
    }

    if (!mounted) return;

    setState(() {
      carregandoValores = false;
      _preencherCampos();
    });
  }

  /// Lançamento sendo editado usa os valores dele (histórico fiel); um novo
  /// começa vazio, com os valores atuais do perfil.
  void _preencherCampos() {
    final existente = _editando;

    anjunController.text = existente != null ? '${existente.anjun}' : '';
    imileController.text = existente != null ? '${existente.imile}' : '';

    final valorAnjun = existente != null && existente.valorAnjun > 0
        ? existente.valorAnjun
        : _valorAnjunPerfil;
    final valorImile = existente != null && existente.valorImile > 0
        ? existente.valorImile
        : _valorImilePerfil;

    valorAnjunController.text = _dinheiro(valorAnjun);
    valorImileController.text = _dinheiro(valorImile);
  }

  /// Outros lançamentos já feitos na data escolhida (sem contar o que está
  /// sendo editado).
  List<Lancamento> _outrosDoDia() {
    return existentes
        .where((l) => l.dia == dia && l.id != _editando?.id)
        .toList();
  }

  int _inteiro(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  double? _decimal(TextEditingController c) {
    return double.tryParse(c.text.trim().replaceAll(',', '.'));
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: dia,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );

    if (escolhida == null) return;

    setState(() {
      dia = DateTime(escolhida.year, escolhida.month, escolhida.day);
    });
  }

  Future<void> _salvar() async {
    if (salvando) return;

    final anjun = _inteiro(anjunController);
    final imile = _inteiro(imileController);
    final valorAnjun = _decimal(valorAnjunController);
    final valorImile = _decimal(valorImileController);

    if (anjun == 0 && imile == 0) {
      _aviso('Informe a quantidade de pacotes de pelo menos uma empresa.');
      return;
    }

    if (valorAnjun == null ||
        valorAnjun <= 0 ||
        valorImile == null ||
        valorImile <= 0) {
      _aviso('Informe o valor por pacote das duas empresas.');
      return;
    }

    setState(() => salvando = true);

    try {
      await LancamentosService.salvar(
        id: _editando?.id,
        dia: dia,
        anjun: anjun,
        imile: imile,
        valorAnjun: valorAnjun,
        valorImile: valorImile,
      );

      // Guarda os valores no perfil pra já virem preenchidos nos próximos
      // lançamentos. Se isso falhar, o lançamento em si já foi salvo.
      if (valorAnjun != _valorAnjunPerfil || valorImile != _valorImilePerfil) {
        final usuario = FirebaseAuth.instance.currentUser;
        if (usuario != null) {
          try {
            await FirebaseFirestore.instance
                .collection('motoristas')
                .doc(usuario.uid)
                .update({'valorAnjun': valorAnjun, 'valorImile': valorImile});
            _valorAnjunPerfil = valorAnjun;
            _valorImilePerfil = valorImile;
          } catch (_) {}
        }
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => salvando = false);
      _aviso('Erro ao salvar: $e');
    }
  }

  Future<void> _apagar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar lançamento?'),
        content: Text(
          'Esse lançamento de ${DateFormat('dd/MM/yyyy').format(dia)} será '
          'removido do seu financeiro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await LancamentosService.apagar(_editando?.id ?? '');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _aviso('Erro ao apagar: $e');
    }
  }

  void _aviso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  Widget _campoEmpresa({
    required String nome,
    required IconData icone,
    required Color cor,
    required TextEditingController quantidade,
    required TextEditingController valor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, color: cor),
                const SizedBox(width: 10),
                Text(
                  nome,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantidade,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Pacotes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: valor,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Valor por pacote',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final anjun = _inteiro(anjunController);
    final imile = _inteiro(imileController);
    final valorAnjun = _decimal(valorAnjunController) ?? 0;
    final valorImile = _decimal(valorImileController) ?? 0;
    final ganho = anjun * valorAnjun + imile * valorImile;

    final editando = _editando;
    final outros = _outrosDoDia();
    final ganhoOutros = outros.fold<double>(0, (soma, l) => soma + l.ganho);
    final hoje = DateTime.now();
    final ehHoje =
        dia.year == hoje.year && dia.month == hoje.month && dia.day == hoje.day;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando != null ? 'Editar lançamento' : 'Novo lançamento'),
        actions: [
          if (editando != null)
            IconButton(
              tooltip: 'Apagar lançamento',
              icon: const Icon(Icons.delete_outline),
              onPressed: salvando ? null : _apagar,
            ),
        ],
      ),
      body: carregandoValores
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.calendar_today_outlined,
                        color: colors.primary,
                      ),
                      title: Text(
                        ehHoje
                            ? 'Hoje, ${DateFormat('dd/MM/yyyy').format(dia)}'
                            : '${_diasSemana[dia.weekday - 1]}, '
                                  '${DateFormat('dd/MM/yyyy').format(dia)}',
                      ),
                      subtitle: Text(
                        outros.isNotEmpty
                            ? 'Esse dia já tem ${outros.length} '
                                  'lançamento${outros.length == 1 ? '' : 's'} '
                                  '(R\$ ${_dinheiro(ganhoOutros)}) — este será somado'
                            : 'Toque pra escolher outra data',
                      ),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: salvando ? null : _escolherData,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _campoEmpresa(
                    nome: 'Anjun',
                    icone: Icons.local_shipping_outlined,
                    cor: Colors.orange,
                    quantidade: anjunController,
                    valor: valorAnjunController,
                  ),
                  _campoEmpresa(
                    nome: 'iMile',
                    icone: Icons.inventory_2_outlined,
                    cor: Colors.blue,
                    quantidade: imileController,
                    valor: valorImileController,
                  ),
                  const SizedBox(height: 10),
                  PainelHero(
                    rotulo: 'Ganho deste lançamento',
                    valor: ganho,
                    apoio: outros.isEmpty
                        ? '${anjun + imile} pacotes'
                        : '${anjun + imile} pacotes • dia fica com '
                              'R\$ ${_dinheiro(ganhoOutros + ganho)}',
                    pilulas: [
                      (Icons.local_shipping_outlined, 'Anjun $anjun'),
                      (Icons.inventory_outlined, 'iMile $imile'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: salvando ? null : _salvar,
                      icon: salvando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        editando != null
                            ? 'Atualizar lançamento'
                            : 'Salvar lançamento',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
