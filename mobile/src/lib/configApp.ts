import Constants from 'expo-constants';
import { useEffect, useState } from 'react';
import { supabase } from './supabase';

/**
 * Linha 'app' da tabela configuracoes (pública). O GitHub Actions grava aqui
 * a última versão e o link do APK a cada release; o admin pode ligar o modo
 * de manutenção.
 */
export type ConfigApp = {
  manutencao: boolean;
  mensagemManutencao: string | null;
  ultimaVersao: string | null;
  apkUrl: string | null;
  notasAtualizacao: string | null;
};

export const versaoAtual = Constants.expoConfig?.version ?? '0.0.0';

/** >0 se `a` for mais nova que `b` (compara 1.2.10 com 1.2.9 corretamente). */
export function compararVersoes(a: string, b: string): number {
  const pa = a.split('.').map((n) => parseInt(n, 10) || 0);
  const pb = b.split('.').map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0) return d;
  }
  return 0;
}

export async function buscarConfigApp(): Promise<ConfigApp | null> {
  const { data, error } = await supabase.from('configuracoes').select('dados').eq('chave', 'app').maybeSingle();
  if (error || !data) return null;
  const d = (data.dados ?? {}) as Record<string, unknown>;
  const texto = (v: unknown) => (typeof v === 'string' && v.trim() ? v.trim() : null);
  return {
    manutencao: d.manutencao === true,
    mensagemManutencao: texto(d.mensagemManutencao),
    ultimaVersao: texto(d.ultimaVersao),
    apkUrl: texto(d.apkUrl),
    notasAtualizacao: texto(d.notasAtualizacao),
  };
}

/** Busca a configuração ao abrir o app (falha aberta: sem rede, segue normal). */
export function useConfigApp() {
  const [config, setConfig] = useState<ConfigApp | null>(null);
  const [carregando, setCarregando] = useState(true);
  useEffect(() => {
    buscarConfigApp()
      .then(setConfig)
      .finally(() => setCarregando(false));
  }, []);
  return { config, carregando };
}

export function temAtualizacao(config: ConfigApp | null): boolean {
  return !!config?.ultimaVersao && !!config.apkUrl && compararVersoes(config.ultimaVersao, versaoAtual) > 0;
}
