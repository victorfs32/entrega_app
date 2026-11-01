-- Funcoes de apoio saem do schema exposto pela API (nao viram /rpc).
create schema if not exists privado;
grant usage on schema privado to authenticated;

alter function public.eh_admin() set schema privado;
alter function public.eh_ativo() set schema privado;
alter function public.proteger_campos_motorista() set schema privado;
alter function public.criar_perfil_motorista() set schema privado;

-- Trigger functions: ninguem chama direto.
revoke execute on function privado.proteger_campos_motorista() from public, anon, authenticated;
revoke execute on function privado.criar_perfil_motorista() from public, anon, authenticated;

-- O corpo do trigger referenciava public.eh_admin(); recria apontando pro novo schema.
create or replace function privado.proteger_campos_motorista() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null or privado.eh_admin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.admin := false;
    new.ativo := true;
  else
    new.admin := old.admin;
    new.ativo := old.ativo;
    new.id := old.id;
  end if;
  return new;
end $$;

-- Configuracoes: uma politica por acao (sem SELECT duplicado).
drop policy "admin escreve config" on public.configuracoes;
create policy "admin cria config" on public.configuracoes
  for insert to authenticated with check ((select privado.eh_admin()));
create policy "admin altera config" on public.configuracoes
  for update to authenticated using ((select privado.eh_admin())) with check ((select privado.eh_admin()));
create policy "admin apaga config" on public.configuracoes
  for delete to authenticated using ((select privado.eh_admin()));
