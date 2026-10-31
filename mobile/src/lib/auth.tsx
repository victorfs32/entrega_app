import type { Session } from '@supabase/supabase-js';
import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { supabase } from './supabase';

export type Motorista = {
  id: string;
  nome: string;
  telefone: string;
  email: string;
  admin: boolean;
  ativo: boolean;
  valorAnjun: number | null;
  valorImile: number | null;
  metaQuinzena: number | null;
};

type Contexto = {
  carregando: boolean;
  sessao: Session | null;
  motorista: Motorista | null;
  recarregarMotorista: () => Promise<void>;
  sair: () => Promise<void>;
};

const AuthContext = createContext<Contexto | null>(null);

async function buscarMotorista(uid: string): Promise<Motorista | null> {
  const { data } = await supabase
    .from('motoristas')
    .select('id, nome, telefone, email, admin, ativo, valor_anjun, valor_imile, meta_quinzena')
    .eq('id', uid)
    .maybeSingle();
  if (!data) return null;
  const num = (v: unknown) => (v == null ? null : Number(v));
  return {
    id: data.id,
    nome: data.nome,
    telefone: data.telefone,
    email: data.email,
    admin: data.admin,
    ativo: data.ativo,
    valorAnjun: num(data.valor_anjun),
    valorImile: num(data.valor_imile),
    metaQuinzena: num(data.meta_quinzena),
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [carregando, setCarregando] = useState(true);
  const [sessao, setSessao] = useState<Session | null>(null);
  const [motorista, setMotorista] = useState<Motorista | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSessao(data.session);
      if (!data.session) setCarregando(false);
    });
    const { data } = supabase.auth.onAuthStateChange((_evento, nova) => setSessao(nova));
    return () => data.subscription.unsubscribe();
  }, []);

  const uid = sessao?.user.id;

  useEffect(() => {
    if (!uid) {
      setMotorista(null);
      return;
    }
    let cancelado = false;
    setCarregando(true);
    buscarMotorista(uid).then((m) => {
      if (cancelado) return;
      setMotorista(m);
      setCarregando(false);
      // Marca o último acesso (saber quem realmente usa o app).
      supabase.from('motoristas').update({ ultimo_acesso: new Date().toISOString() }).eq('id', uid).then();
    });
    return () => {
      cancelado = true;
    };
  }, [uid]);

  const recarregarMotorista = useCallback(async () => {
    if (uid) setMotorista(await buscarMotorista(uid));
  }, [uid]);

  const sair = useCallback(async () => {
    await supabase.auth.signOut();
  }, []);

  return (
    <AuthContext.Provider value={{ carregando, sessao, motorista, recarregarMotorista, sair }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): Contexto {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth fora do AuthProvider');
  return ctx;
}
