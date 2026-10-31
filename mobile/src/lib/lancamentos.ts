import { supabase } from './supabase';
import { chaveDoDia, lerDia } from './quinzena';

/**
 * Lançamento diário feito à mão: quantos pacotes de cada empresa o motorista
 * entregou. Os valores por pacote ficam gravados no próprio lançamento, então
 * mudar o valor depois não reescreve dias já lançados.
 */
export type Lancamento = {
  id: string;
  dia: Date;
  anjun: number;
  imile: number;
  valorAnjun: number;
  valorImile: number;
  rota: string | null;
};

/** Rotas e o valor pago por pacote em cada uma. */
export const valoresPorRota: Record<string, number> = { 'Eusébio': 2.8, Aquiraz: 3.2 };

export const ganhoDe = (l: Lancamento) => l.anjun * l.valorAnjun + l.imile * l.valorImile;

type Linha = {
  id: string;
  dia: string;
  anjun: number;
  imile: number;
  valor_anjun: number | string;
  valor_imile: number | string;
  rota: string | null;
};

function deLinha(l: Linha): Lancamento {
  return {
    id: l.id,
    dia: lerDia(l.dia),
    anjun: l.anjun,
    imile: l.imile,
    valorAnjun: Number(l.valor_anjun),
    valorImile: Number(l.valor_imile),
    rota: l.rota || null,
  };
}

export async function listarLancamentos(): Promise<Lancamento[]> {
  const { data, error } = await supabase
    .from('lancamentos')
    .select('id, dia, anjun, imile, valor_anjun, valor_imile, rota')
    .order('dia', { ascending: false })
    .order('atualizado_em', { ascending: false });
  if (error) throw error;
  return (data as Linha[]).map(deLinha);
}

export async function salvarLancamento(l: Omit<Lancamento, 'id'> & { id?: string }) {
  const dados = {
    dia: chaveDoDia(l.dia),
    anjun: l.anjun,
    imile: l.imile,
    valor_anjun: l.valorAnjun,
    valor_imile: l.valorImile,
    rota: l.rota,
    atualizado_em: new Date().toISOString(),
  };
  const { error } = l.id
    ? await supabase.from('lancamentos').update(dados).eq('id', l.id)
    : await supabase.from('lancamentos').insert(dados);
  if (error) throw error;
}

export async function apagarLancamento(id: string) {
  const { error } = await supabase.from('lancamentos').delete().eq('id', id);
  if (error) throw error;
}

export type Resumo = { anjun: number; imile: number; ganho: number; total: number };

/** Soma dos lançamentos cujo dia cai em inicio..fim (inclusive). */
export function somar(lista: Lancamento[], inicio?: Date, fim?: Date): Resumo {
  let anjun = 0;
  let imile = 0;
  let ganho = 0;
  for (const l of lista) {
    if (inicio && l.dia < inicio) continue;
    if (fim && l.dia > fim) continue;
    anjun += l.anjun;
    imile += l.imile;
    ganho += ganhoDe(l);
  }
  return { anjun, imile, ganho, total: anjun + imile };
}
