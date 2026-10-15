import '../services/rota_lida_service.dart';

/// Parada que pode ser a do pacote, com uma nota de quão bem o endereço da
/// etiqueta combina com o da parada.
class ParadaCandidata {
  final Parada parada;
  final double pontos;

  /// Nome da rua e número do imóvel bateram com a etiqueta.
  final bool exata;

  const ParadaCandidata(this.parada, this.pontos, {required this.exata});
}

/// Descobre a(s) parada(s) da rota a partir do texto lido (OCR) da etiqueta
/// do pacote: compara o nome da rua e o número do imóvel de cada parada com
/// as palavras e números que aparecem na etiqueta. Tolera um erro de leitura
/// por palavra, que é comum em OCR.
class CombinarEndereco {
  CombinarEndereco._();

  // Palavras que não ajudam a distinguir uma rua da outra.
  static const Set<String> _comuns = {
    'rua', 'r', 'avenida', 'av', 'travessa', 'tv', 'estrada', 'rodovia',
    'praca', 'pca', 'de', 'da', 'do', 'dos', 'das', 'e', 'n', 'no', 'numero',
  };

  static List<ParadaCandidata> procurar(
    String textoEtiqueta,
    List<Parada> paradas, {
    int maximo = 3,
  }) {
    final texto = RotaLidaService.normalizar(textoEtiqueta);

    final palavras = texto
        .split(RegExp(r'[^a-z0-9]+'))
        .where((p) => p.isNotEmpty)
        .toList();

    final numeros = palavras.where((p) => RegExp(r'^\d+$').hasMatch(p)).toSet();
    final soDigitos = texto.replaceAll(RegExp(r'\D'), '');

    final candidatas = <ParadaCandidata>[];

    for (final parada in paradas) {
      final endereco = RotaLidaService.normalizar(parada.endereco);
      final partes = endereco.split(',');

      final rua = partes.first;
      final numero = partes.length > 1
          ? RegExp(r'\d+').firstMatch(partes.sublist(1).join(' '))?.group(0)
          : null;

      final termos = rua
          .split(RegExp(r'[^a-z0-9]+'))
          .where((t) => t.length >= 3 && !_comuns.contains(t))
          .toList();

      if (termos.isEmpty) continue;

      final achados = termos.where((t) => _aparece(t, palavras)).length;
      final fracao = achados / termos.length;

      final numeroBate = numero != null && numeros.contains(numero);

      // CEP da parada aparecendo na etiqueta reforça (muitas paradas
      // dividem o CEP, então vale pouco).
      final cep = RegExp(
        r'\d{5}-?\d{3}',
      ).firstMatch(parada.local ?? '')?.group(0)?.replaceAll('-', '');
      final cepBate = cep != null && soDigitos.contains(cep);

      // Rua bem reconhecida e, quando a parada tem número, o número também.
      final ruaOk = fracao >= 0.6;
      if (!ruaOk || (numero != null && !numeroBate)) continue;

      final pontos = fracao * 2 + (numeroBate ? 2 : 0) + (cepBate ? 0.5 : 0);

      candidatas.add(
        ParadaCandidata(
          parada,
          pontos,
          exata: fracao >= 0.99 && (numero == null || numeroBate),
        ),
      );
    }

    candidatas.sort((a, b) => b.pontos.compareTo(a.pontos));

    return candidatas.take(maximo).toList();
  }

  // O termo aparece entre as palavras da etiqueta, aceitando 1 letra errada
  // (2 em palavras longas) por causa de erros de leitura.
  static bool _aparece(String termo, List<String> palavras) {
    final tolerancia = termo.length >= 9 ? 2 : (termo.length >= 5 ? 1 : 0);

    for (final palavra in palavras) {
      if (palavra == termo) return true;
      if (tolerancia > 0 &&
          (palavra.length - termo.length).abs() <= tolerancia &&
          _distancia(palavra, termo) <= tolerancia) {
        return true;
      }
    }

    return false;
  }

  // Distância de Levenshtein (número mínimo de trocas/inserções/remoções).
  static int _distancia(String a, String b) {
    var anterior = List<int>.generate(b.length + 1, (i) => i);

    for (var i = 1; i <= a.length; i++) {
      final atual = List<int>.filled(b.length + 1, 0)..[0] = i;

      for (var j = 1; j <= b.length; j++) {
        final custo = a[i - 1] == b[j - 1] ? 0 : 1;
        final troca = anterior[j - 1] + custo;
        final insere = atual[j - 1] + 1;
        final remove = anterior[j] + 1;

        atual[j] = troca < insere
            ? (troca < remove ? troca : remove)
            : (insere < remove ? insere : remove);
      }

      anterior = atual;
    }

    return anterior[b.length];
  }
}
