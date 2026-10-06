/// Pagamento é quinzenal: dia 1 ao 15, e dia 16 até o fim do mês. O
/// dinheiro da quinzena não cai na hora — leva até 5 dias úteis depois
/// do fim de cada quinzena (em geral perto do dia 20 pra 1ª quinzena, e do
/// dia 5 do mês seguinte pra 2ª). Compartilhado entre as telas de Financeiro e
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

/// Fim da quinzena + 5 dias ÚTEIS (sábado e domingo não contam). Feriados
/// não são considerados.
DateTime previsaoPagamento(DateTime fimQuinzena) {
  var data = DateTime(fimQuinzena.year, fimQuinzena.month, fimQuinzena.day);
  var restantes = 5;

  while (restantes > 0) {
    data = DateTime(data.year, data.month, data.day + 1);

    if (data.weekday != DateTime.saturday && data.weekday != DateTime.sunday) {
      restantes--;
    }
  }

  return data;
}

bool mesmoDia(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
