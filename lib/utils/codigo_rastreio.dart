/// Reconhecimento e limpeza dos formatos de código de rastreio suportados
/// (iMile e Anjun, formatos antigo e novo). Compartilhado entre o
/// escaneamento de um pacote só e o escaneamento em lote.
class CodigoRastreio {
  CodigoRastreio._();

  // iMile antiga: 13 números
  static final RegExp _imileAntigo = RegExp(r'^\d{13}$');

  // iMile nova: KW + 13 números + BR
  static final RegExp _imileNovo = RegExp(r'^KW\d{13}BR$');

  // Anjun antiga: AJ + 15 números
  static final RegExp _anjunAntigo = RegExp(r'^AJ\d{15}$');

  // Anjun nova: TT + 15 números
  static final RegExp _anjunNovo = RegExp(r'^TT\d{15}$');

  static String limpar(String codigo) {
    return codigo.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static bool valido(String codigo) {
    final c = limpar(codigo);

    return _imileAntigo.hasMatch(c) ||
        _imileNovo.hasMatch(c) ||
        _anjunAntigo.hasMatch(c) ||
        _anjunNovo.hasMatch(c);
  }

  static String transportadora(String codigo) {
    final c = limpar(codigo);

    if (_anjunAntigo.hasMatch(c) || _anjunNovo.hasMatch(c)) {
      return 'Anjun';
    }

    if (_imileAntigo.hasMatch(c) || _imileNovo.hasMatch(c)) {
      return 'iMile';
    }

    return 'Desconhecida';
  }
}
