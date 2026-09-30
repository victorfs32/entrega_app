/// Pagamento é quinzenal: dia 1 ao 15, e dia 16 até o fim do mês. O
/// dinheiro da quinzena não cai na hora — leva até 5 dias corridos depois
/// do fim de cada quinzena (então até dia 20 pra 1ª quinzena, e até dia 5
/// do mês seguinte pra 2ª). Compartilhado entre as telas de Financeiro e
/// Relatórios pra não duplicar essa conta em mais de um lugar.
library;

DateTime inicioDaQuinzena(DateTime data) {
  final dia = data.day <= 15 ? 1 : 16;
  return DateTime(data.year, data.month, dia);
}

DateTime fimDaQuinzena(DateTime data) {
  if (data.day <= 15) {
    return DateTime(data.year, data.month, 15);
  }

  // Dia 0 do mês seguinte = último dia do mês atual, lida sozinho com
  // meses de 28, 29, 30 ou 31 dias.
  final ultimoDia = DateTime(data.year, data.month + 1, 0);
  return DateTime(ultimoDia.year, ultimoDia.month, ultimoDia.day);
}

DateTime previsaoPagamento(DateTime fimQuinzena) {
  return fimQuinzena.add(const Duration(days: 5));
}

bool mesmoDia(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
