/// Reconhecimento e limpeza dos formatos de código de rastreio suportados
/// (Anjun, formatos antigo e novo). Compartilhado entre o escaneamento de
/// um pacote só e o escaneamento em lote.
///
/// iMile foi removida de propósito: o formato antigo dela era só "13
/// números" (sem nenhum prefixo), um padrão genérico demais que às vezes
/// casava com leituras erradas/parciais de código de barras da Anjun,
/// classificando como iMile um pacote que na verdade era da Anjun.
class CodigoRastreio {
  CodigoRastreio._();

  // Anjun antiga: AJ + 15 números
  static final RegExp _anjunAntigo = RegExp(r'^AJ\d{15}$');

  // Anjun nova: TT + 15 números
  static final RegExp _anjunNovo = RegExp(r'^TT\d{15}$');

  static String limpar(String codigo) {
    return codigo.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static bool valido(String codigo) {
    final c = limpar(codigo);

    return _anjunAntigo.hasMatch(c) || _anjunNovo.hasMatch(c);
  }

  static String transportadora(String codigo) {
    final c = limpar(codigo);

    if (_anjunAntigo.hasMatch(c) || _anjunNovo.hasMatch(c)) {
      return 'Anjun';
    }

    return 'Desconhecida';
  }
}
