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

/// Um texto da tela do outro app com a posição dele (pixels da tela).
class ItemTela {
  final String texto;
  final int topo;
  final int esquerda;
  final int base;
  final int direita;

  const ItemTela(this.texto, this.topo, this.esquerda, this.base, this.direita);

  int get centroY => (topo + base) ~/ 2;
}

/// Uma parada da rota lida da tela do outro app: o ID (número da parada), o
/// endereço e, na lista da rota, quantos pacotes tem nela — o resto da tela é
/// descartado.
class Parada {
  final String id;
  final String endereco;

  /// Bairro, cidade e CEP, quando aparecem logo abaixo do endereço.
  final String? local;

  /// Quantidade de pacotes da parada (aparece na lista da rota).
  final int? pacotes;

  const Parada({
    required this.id,
    required this.endereco,
    this.local,
    this.pacotes,
  });

  int get ordem => int.tryParse(id) ?? 1 << 30;

  /// Junta o que esta leitura trouxe com o que já se sabia da parada.
  Parada mesclarCom(Parada anterior) => Parada(
    id: id,
    endereco: endereco,
    local: local ?? anterior.local,
    pacotes: pacotes ?? anterior.pacotes,
  );

  Map<String, dynamic> paraMapa() => {
    'id': id,
    'endereco': endereco,
    if (local != null) 'local': local,
    if (pacotes != null) 'pacotes': pacotes,
  };

  factory Parada.deMapa(Map<String, dynamic> m) => Parada(
    id: (m['id'] ?? '').toString(),
    endereco: (m['endereco'] ?? '').toString(),
    local: m['local']?.toString(),
    pacotes: (m['pacotes'] as num?)?.toInt(),
  );
}

/// Rota "lida" da tela de outro app (ex.: Circuit). Funciona sem API: o
/// serviço de acessibilidade do Android entrega os textos da tela do app
/// escolhido, e aqui se extrai deles o ID, o endereço e a quantidade de
/// pacotes de cada parada.
class RotaLidaService {
  RotaLidaService._();

  static final RotaLidaService instance = RotaLidaService._();

  static const MethodChannel _canal = MethodChannel('baixafacil/leitor_tela');

  static const String _chaveParadas = 'rota_lida_paradas';
  static const String _chaveCodigos = 'rota_lida_codigos';
  static const String _chaveAlvo = 'rota_lida_alvo';
  static const String _chaveAlvoNome = 'rota_lida_alvo_nome';

  // Qualquer coisa que pareça um código de pacote: o filtro de verdade é
  // CodigoRastreio.valido depois.
  static final RegExp _candidato = RegExp(
    r'[A-Za-z]{0,2}\d{13,15}[A-Za-z]{0,2}',
  );

  // "ID" numa linha e o número na seguinte, ou tudo junto ("ID 2", "2
  // Originally 2nd"). Cobre o Circuit em inglês e em português.
  static final RegExp _idJunto = RegExp(r'^ID\s*[:\-]?\s*(\d+)\b');
  static final RegExp _idComOriginal = RegExp(
    r'^(\d+)\s+(Originally|Originalmente)\b',
    caseSensitive: false,
  );
  static final RegExp _soNumero = RegExp(r'^(\d+)\b');

  // "Rua Alameda Verde, 100": texto, vírgula, número do imóvel.
  static final RegExp _enderecoComNumero = RegExp(r'^.{3,}?,\s*\d+\b');
  static final RegExp _cep = RegExp(r'\d{5}-?\d{3}');
  static final RegExp _progresso = RegExp(r'^\d+\s*/\s*\d+$');

  static final RegExp _horario = RegExp(r'^\d{1,2}:\d{2}$');
  static final RegExp _numeroCurto = RegExp(r'^\d{1,3}$');
  static final RegExp _idBadge = RegExp(r'^ID\s*[:\-]?\s*(\d+)$');

  /// ID da parada → parada.
  final Map<String, Parada> _paradas = {};

  /// Código de pacote → ID da parada onde ele apareceu junto (só acontece se
  /// o outro app mostrar o código, por exemplo nas notas da parada).
  final Map<String, String> _codigos = {};

  /// Últimas telas lidas, só pra diagnóstico ("ver texto lido").
  final List<List<String>> _ultimasTelas = [];

  String? pacoteAlvo;
  String? nomeAlvo;
  bool _carregado = false;

  int get totalParadas => _paradas.length;

  int get totalCodigos => _codigos.length;

  List<Parada> get paradas {
    final lista = _paradas.values.toList();
    lista.sort((a, b) => a.ordem.compareTo(b.ordem));
    return lista;
  }

  List<List<String>> get ultimasTelas => List.unmodifiable(_ultimasTelas);

  Future<void> carregar() async {
    if (_carregado) return;
    _carregado = true;

    final prefs = await SharedPreferences.getInstance();

    pacoteAlvo = prefs.getString(_chaveAlvo);
    nomeAlvo = prefs.getString(_chaveAlvoNome);

    try {
      final salvas = prefs.getString(_chaveParadas);
      if (salvas != null) {
        for (final item in jsonDecode(salvas) as List) {
          final parada = Parada.deMapa(item as Map<String, dynamic>);
          _paradas[parada.id] = parada;
        }
      }

      final codigos = prefs.getString(_chaveCodigos);
      if (codigos != null) {
        (jsonDecode(codigos) as Map<String, dynamic>).forEach(
          (codigo, id) => _codigos[codigo] = id.toString(),
        );
      }
    } catch (_) {
      // dados corrompidos: recomeça vazio
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

  /// Extrai ID e endereço de uma tela de parada aberta (detalhe); null se a
  /// tela não é de uma parada (mapa, lista etc.).
  static Parada? lerParada(List<String> tela) {
    final linhas = tela.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // 1) ID da parada
    String? id;
    for (var i = 0; i < linhas.length && id == null; i++) {
      final linha = linhas[i];

      final junto = _idJunto.firstMatch(linha);
      if (junto != null) {
        id = junto.group(1);
        break;
      }

      final comOriginal = _idComOriginal.firstMatch(linha);
      if (comOriginal != null) {
        id = comOriginal.group(1);
        break;
      }

      if (linha.toUpperCase() == 'ID' && i + 1 < linhas.length) {
        id = _soNumero.firstMatch(linhas[i + 1])?.group(1);
      }
    }

    if (id == null) return null;

    // 2) Endereço: o título da parada. É a linha "texto, número" que vem
    // logo antes do status/progresso ("Entregue", "2/45"); se não achar
    // esse ponto de referência, a primeira linha com cara de endereço.
    String? endereco;

    bool pareceEndereco(String l) =>
        _enderecoComNumero.hasMatch(l) && !_cep.hasMatch(l);

    final iProgresso = linhas.indexWhere((l) => _progresso.hasMatch(l));

    if (iProgresso > 0) {
      for (var i = iProgresso - 1; i >= 0; i--) {
        if (pareceEndereco(linhas[i])) {
          endereco = linhas[i];
          break;
        }
      }
    }

    endereco ??= linhas.where(pareceEndereco).firstOrNull;

    // Bairro / cidade / CEP: a linha com CEP.
    final local = linhas
        .where((l) => _cep.hasMatch(l) && l != endereco)
        .firstOrNull;

    if (endereco == null) return null;

    return Parada(id: id, endereco: endereco, local: local);
  }

  /// Lê a LISTA da rota (uma linha por parada: número e horário à esquerda,
  /// endereço, bairro, chips com a quantidade de pacotes e o ID à direita).
  /// Usa a posição dos textos pra separar as linhas, porque a ordem em que o
  /// Android entrega os textos mistura colunas.
  static List<Parada> lerLista(List<ItemTela> itens) {
    // Número da linha: texto numérico com um horário logo abaixo, na mesma
    // coluna. É isso que separa a lista dos pinos numerados do mapa.
    final sequencias = itens.where((n) {
      if (!_numeroCurto.hasMatch(n.texto)) return false;

      return itens.any(
        (t) =>
            _horario.hasMatch(t.texto) &&
            (t.esquerda - n.esquerda).abs() < 40 &&
            t.topo > n.topo &&
            t.topo - n.topo < 140,
      );
    }).toList()..sort((a, b) => a.topo.compareTo(b.topo));

    final paradas = <Parada>[];

    for (var k = 0; k < sequencias.length; k++) {
      final seq = sequencias[k];
      final inicio = seq.topo - 14;
      final fim = k + 1 < sequencias.length
          ? sequencias[k + 1].topo - 14
          : 1 << 30;

      final linha = itens
          .where((i) => i.topo >= inicio && i.topo < fim && i != seq)
          .toList();

      // ID: "ID 1" num texto só, ou "ID" e o número em textos vizinhos.
      String? id;
      ItemTela? marcaId;

      for (final i in linha) {
        final junto = _idBadge.firstMatch(i.texto);
        if (junto != null) {
          id = junto.group(1);
          marcaId = i;
          break;
        }
      }

      if (id == null) {
        marcaId = linha.where((i) => i.texto.toUpperCase() == 'ID').firstOrNull;

        if (marcaId != null) {
          final marca = marcaId;
          final vizinho = linha
              .where(
                (i) =>
                    _numeroCurto.hasMatch(i.texto) &&
                    i.esquerda >= marca.esquerda &&
                    (i.centroY - marca.centroY).abs() < 30,
              )
              .firstOrNull;
          id = vizinho?.texto;
        }
      }

      if (id == null || marcaId == null) continue;

      final limiteDireito = marcaId.esquerda - 8;

      // Textos de conteúdo: à direita da coluna do número, antes do ID.
      final conteudo =
          linha
              .where(
                (i) =>
                    i.esquerda > seq.esquerda + 40 &&
                    i.esquerda < limiteDireito &&
                    !_horario.hasMatch(i.texto) &&
                    !_numeroCurto.hasMatch(i.texto) &&
                    i != marcaId,
              )
              .toList()
            ..sort(
              (a, b) => a.topo != b.topo
                  ? a.topo.compareTo(b.topo)
                  : a.esquerda.compareTo(b.esquerda),
            );

      if (conteudo.isEmpty) continue;

      final endereco = conteudo.first.texto;
      final local =
          conteudo.length > 1 && conteudo[1].topo > conteudo.first.topo
          ? conteudo[1].texto
          : null;

      // Quantidade de pacotes: número solto no meio da linha (chip).
      final chip = linha
          .where(
            (i) =>
                _numeroCurto.hasMatch(i.texto) &&
                i.esquerda > seq.esquerda + 40 &&
                i.esquerda < limiteDireito,
          )
          .firstOrNull;

      paradas.add(
        Parada(
          id: id,
          endereco: endereco,
          local: local,
          pacotes: chip == null ? null : int.tryParse(chip.texto),
        ),
      );
    }

    return paradas;
  }

  /// Busca no serviço as telas lidas desde a última chamada e atualiza as
  /// paradas. Devolve quantas paradas novas apareceram.
  Future<int> coletar() async {
    final brutas = await _canal.invokeListMethod<List>('retirarTelas');
    if (brutas == null || brutas.isEmpty) return 0;

    var novas = 0;

    void guardarParada(Parada parada) {
      final anterior = _paradas[parada.id];
      if (anterior == null) novas++;
      _paradas[parada.id] = anterior == null
          ? parada
          : parada.mesclarCom(anterior);
    }

    for (final bruta in brutas) {
      final itens = bruta.map((l) {
        final c = l as List;
        return ItemTela(
          c[0].toString(),
          (c[1] as num).toInt(),
          (c[2] as num).toInt(),
          (c[3] as num).toInt(),
          (c[4] as num).toInt(),
        );
      }).toList();

      final tela = itens.map((i) => i.texto).toList();

      // Pra diagnóstico: o texto com a posição (y, x) de cada item.
      _ultimasTelas.add(
        itens.map((i) => '${i.texto}   [y=${i.topo} x=${i.esquerda}]').toList(),
      );
      if (_ultimasTelas.length > 12) _ultimasTelas.removeAt(0);

      // Lista da rota: várias paradas de uma vez.
      for (final parada in lerLista(itens)) {
        guardarParada(parada);
      }

      // Tela de uma parada aberta.
      final parada = lerParada(tela);
      if (parada != null) {
        guardarParada(parada);

        // Se a tela da parada também mostra códigos de pacote (notas, por
        // exemplo), liga cada código a essa parada.
        for (final linha in tela) {
          for (final achado in _candidato.allMatches(linha)) {
            final codigo = CodigoRastreio.limpar(achado.group(0)!);
            if (CodigoRastreio.valido(codigo)) _codigos[codigo] = parada.id;
          }
        }
      }
    }

    await _salvar();
    return novas;
  }

  /// Parada em que o código foi visto junto, ou null.
  Parada? buscarPorCodigo(String codigo) {
    final id = _codigos[CodigoRastreio.limpar(codigo)];
    return id == null ? null : _paradas[id];
  }

  /// Paradas cujo endereço contém todas as palavras digitadas (sem
  /// diferenciar maiúsculas nem acentos).
  List<Parada> buscarPorEndereco(String texto) {
    final palavras = _normalizar(texto).split(' ').where((p) => p.isNotEmpty);
    if (palavras.isEmpty) return const [];

    return paradas.where((p) {
      final alvo = _normalizar('${p.endereco} ${p.local ?? ''}');
      return palavras.every(alvo.contains);
    }).toList();
  }

  static String _normalizar(String texto) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const para = 'aaaaaeeeeiiiiooooouuuucn';

    final minusculo = texto.toLowerCase();
    final saida = StringBuffer();

    for (final c in minusculo.split('')) {
      final i = de.indexOf(c);
      saida.write(i >= 0 ? para[i] : c);
    }

    return saida.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> limpar() async {
    _paradas.clear();
    _codigos.clear();
    _ultimasTelas.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveParadas);
    await prefs.remove(_chaveCodigos);
  }

  Future<void> _salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chaveParadas,
      jsonEncode(_paradas.values.map((p) => p.paraMapa()).toList()),
    );
    await prefs.setString(_chaveCodigos, jsonEncode(_codigos));
  }
}
