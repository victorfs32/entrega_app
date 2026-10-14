import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/codigo_rastreio.dart';

/// App instalado que dá pra escolher como alvo da leitura de tela.
class AppInstalado {
  final String nome;
  final String pacote;

  const AppInstalado({required this.nome, required this.pacote});
}

/// Rota "lida" da tela de outro app (ex.: Circuit): pra cada código de
/// pacote visto na tela, guarda as linhas de texto em volta dele — é onde
/// aparecem o número da parada e o endereço. Funciona sem API: o serviço de
/// acessibilidade do Android entrega os textos da tela do app escolhido e
/// aqui só se procura neles os códigos que o Baixa Fácil reconhece.
class RotaLidaService {
  RotaLidaService._();

  static final RotaLidaService instance = RotaLidaService._();

  static const MethodChannel _canal = MethodChannel('baixafacil/leitor_tela');

  static const String _chaveIndice = 'rota_lida_indice';
  static const String _chaveAlvo = 'rota_lida_alvo';
  static const String _chaveAlvoNome = 'rota_lida_alvo_nome';

  // Qualquer coisa que pareça um código de pacote: o filtro de verdade é
  // CodigoRastreio.valido depois.
  static final RegExp _candidato = RegExp(
    r'[A-Za-z]{0,2}\d{13,15}[A-Za-z]{0,2}',
  );

  /// Código limpo → linhas de texto em volta dele na tela.
  final Map<String, List<String>> _indice = {};

  /// Últimas telas lidas, só pra diagnóstico ("ver texto lido").
  final List<List<String>> _ultimasTelas = [];

  String? pacoteAlvo;
  String? nomeAlvo;
  bool _carregado = false;

  int get totalCodigos => _indice.length;

  List<List<String>> get ultimasTelas => List.unmodifiable(_ultimasTelas);

  Future<void> carregar() async {
    if (_carregado) return;
    _carregado = true;

    final prefs = await SharedPreferences.getInstance();

    pacoteAlvo = prefs.getString(_chaveAlvo);
    nomeAlvo = prefs.getString(_chaveAlvoNome);

    final salvo = prefs.getString(_chaveIndice);
    if (salvo != null) {
      try {
        final mapa = jsonDecode(salvo) as Map<String, dynamic>;
        for (final entrada in mapa.entries) {
          _indice[entrada.key] = (entrada.value as List).cast<String>();
        }
      } catch (_) {
        // índice corrompido: recomeça vazio
      }
    }

    if (pacoteAlvo != null) {
      await _canal.invokeMethod('definirAlvo', {'pacote': pacoteAlvo});
    }
  }

  Future<bool> servicoAtivo() async {
    try {
      return await _canal.invokeMethod<bool>('servicoAtivo') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> abrirAcessibilidade() =>
      _canal.invokeMethod('abrirAcessibilidade');

  Future<void> abrirDetalhesDoApp() =>
      _canal.invokeMethod('abrirDetalhesDoApp');

  Future<List<AppInstalado>> listarApps() async {
    final lista = await _canal.invokeListMethod<Map>('listarApps') ?? const [];

    return lista
        .map(
          (m) => AppInstalado(
            nome: (m['nome'] ?? '').toString(),
            pacote: (m['pacote'] ?? '').toString(),
          ),
        )
        .toList();
  }

  Future<void> definirAlvo(AppInstalado app) async {
    pacoteAlvo = app.pacote;
    nomeAlvo = app.nome;

    await _canal.invokeMethod('definirAlvo', {'pacote': app.pacote});

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveAlvo, app.pacote);
    await prefs.setString(_chaveAlvoNome, app.nome);
  }

  Future<void> capturar(bool ligado) =>
      _canal.invokeMethod('capturar', {'ligado': ligado});

  Future<bool> abrirAlvo() async {
    final pacote = pacoteAlvo;
    if (pacote == null) return false;

    return await _canal.invokeMethod<bool>('abrirApp', {'pacote': pacote}) ??
        false;
  }

  /// Busca no serviço as telas lidas desde a última chamada e atualiza o
  /// índice. Devolve quantos códigos novos apareceram.
  Future<int> coletar() async {
    final brutas = await _canal.invokeListMethod<List>('retirarTelas');
    if (brutas == null || brutas.isEmpty) return 0;

    var novos = 0;

    for (final bruta in brutas) {
      final tela = bruta.map((l) => l.toString()).toList();

      _ultimasTelas.add(tela);
      if (_ultimasTelas.length > 12) _ultimasTelas.removeAt(0);

      for (var i = 0; i < tela.length; i++) {
        for (final achado in _candidato.allMatches(tela[i])) {
          final codigo = CodigoRastreio.limpar(achado.group(0)!);
          if (!CodigoRastreio.valido(codigo)) continue;

          // Algumas linhas antes (número da parada / nome) e depois
          // (endereço, observações).
          final de = i - 4 < 0 ? 0 : i - 4;
          final ate = i + 7 > tela.length ? tela.length : i + 7;

          if (!_indice.containsKey(codigo)) novos++;
          _indice[codigo] = tela.sublist(de, ate);
        }
      }
    }

    await _salvar();
    return novos;
  }

  /// Linhas de texto em volta do código na rota lida, ou null se ele não
  /// apareceu em nenhuma tela.
  List<String>? buscar(String codigo) => _indice[CodigoRastreio.limpar(codigo)];

  Future<void> limpar() async {
    _indice.clear();
    _ultimasTelas.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveIndice);
  }

  Future<void> _salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveIndice, jsonEncode(_indice));
  }
}
