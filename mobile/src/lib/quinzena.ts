// Pagamento é quinzenal: dia 1 ao 15, e dia 16 até o fim do mês. O dinheiro
// cai até 5 dias úteis depois do fim de cada quinzena.

export function inicioDaQuinzena(data: Date): Date {
  return new Date(data.getFullYear(), data.getMonth(), data.getDate() <= 15 ? 1 : 16);
}

export function fimDaQuinzena(data: Date): Date {
  if (data.getDate() <= 15) return new Date(data.getFullYear(), data.getMonth(), 15);
  // Dia 0 do mês seguinte = último dia do mês atual.
  return new Date(data.getFullYear(), data.getMonth() + 1, 0);
}

/** Fim da quinzena + 5 dias úteis (sábado e domingo não contam). */
export function previsaoPagamento(fimQuinzena: Date): Date {
  const data = new Date(fimQuinzena.getFullYear(), fimQuinzena.getMonth(), fimQuinzena.getDate());
  let restantes = 5;
  while (restantes > 0) {
    data.setDate(data.getDate() + 1);
    const semana = data.getDay();
    if (semana !== 0 && semana !== 6) restantes--;
  }
  return data;
}

/** 'yyyy-MM-dd' no fuso local (o formato da coluna date do banco). */
export function chaveDoDia(data: Date): string {
  const m = String(data.getMonth() + 1).padStart(2, '0');
  const d = String(data.getDate()).padStart(2, '0');
  return `${data.getFullYear()}-${m}-${d}`;
}

/** Lê 'yyyy-MM-dd' como data local (sem o deslocamento de fuso do Date.parse). */
export function lerDia(texto: string): Date {
  const [a, m, d] = texto.split('-').map(Number);
  return new Date(a, m - 1, d);
}

export function formatarDia(data: Date): string {
  return data.toLocaleDateString('pt-BR');
}

export function formatarReais(valor: number): string {
  return valor.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}
