/// Reconhecimento e limpeza dos formatos de código de rastreio suportados
/// (Anjun e iMile). Compartilhado entre o escaneamento de um pacote só e o
/// escaneamento em lote.
///
/// A iMile tem dois formatos aceitos: só "13 números" (sem prefixo), um
/// padrão genérico que pode eventualmente bater com uma leitura
/// errada/parcial de um código de barras da Anjun (ex: um segundo código
/// na mesma etiqueta); e o formato novo "2 letras + 13 números + 2 letras"
/// (ex: KW0890815907698BR). Por isso a transportadora detectada
/// automaticamente por esse código continua editável nas telas de
/// registro — o motorista corrige na hora se perceber que classificou
/// errado, sem precisar travar o fluxo de escaneamento com uma
/// confirmação toda vez.
class CodigoRastreio {
  CodigoRastreio._();

  // Anjun antiga: AJ + 15 números
  static final RegExp _anjunAntigo = RegExp(r'^AJ\d{15}$');

  // Anjun nova: TT + 15 números
  static final RegExp _anjunNovo = RegExp(r'^TT\d{15}$');

  // iMile: exatamente 13 números, sem letras
  static final RegExp _imile = RegExp(r'^\d{13}$');

  // iMile novo formato: 2 letras + 13 números + 2 letras (ex: KW0890815907698BR)
  static final RegExp _imileNovo = RegExp(r'^[A-Z]{2}\d{13}[A-Z]{2}$');

  static const List<String> transportadorasDisponiveis = ['Anjun', 'iMile'];

  static String limpar(String codigo) {
    return codigo.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static bool valido(String codigo) {
    final c = limpar(codigo);

    return _anjunAntigo.hasMatch(c) ||
        _anjunNovo.hasMatch(c) ||
        _imile.hasMatch(c) ||
        _imileNovo.hasMatch(c);
  }

  static String transportadora(String codigo) {
    final c = limpar(codigo);

    if (_anjunAntigo.hasMatch(c) || _anjunNovo.hasMatch(c)) {
      return 'Anjun';
    }

    if (_imile.hasMatch(c) || _imileNovo.hasMatch(c)) {
      return 'iMile';
    }

    return 'Desconhecida';
  }
}
