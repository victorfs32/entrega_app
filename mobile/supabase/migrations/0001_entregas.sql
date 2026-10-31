-- Esquema do app de entregas (versao React Native + Supabase).
-- Espelha as colecoes do Firestore: motoristas, lancamentos, entregas,
-- pagamentos e configuracoes, com as mesmas regras de acesso (RLS).

-- Perfil do motorista: 1 linha por usuario do Supabase Auth.
create table public.motoristas (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null default '',
  telefone text not null default '',
  email text not null default '',
  admin boolean not null default false,
  ativo boolean not null default true,
  valor_pacote numeric(10,2) not null default 3 check (valor_pacote > 0),
  valor_anjun numeric(10,2) check (valor_anjun > 0),
  valor_imile numeric(10,2) check (valor_imile > 0),
  meta_quinzena numeric(10,2) check (meta_quinzena > 0),
  ultimo_acesso timestamptz,
  criado_em timestamptz not null default now()
);

-- Lancamento diario: quantos pacotes de cada empresa o motorista entregou.
-- Um dia pode ter varios lancamentos (ex.: rota da manha e da tarde).
create table public.lancamentos (
  id uuid primary key default gen_random_uuid(),
  motorista_id uuid not null default auth.uid() references public.motoristas (id) on delete cascade,
  dia date not null,
  anjun integer not null default 0 check (anjun >= 0),
  imile integer not null default 0 check (imile >= 0),
  valor_anjun numeric(10,2) not null default 0,
  valor_imile numeric(10,2) not null default 0,
  rota text,
  atualizado_em timestamptz not null default now()
);
create index lancamentos_motorista_dia_idx on public.lancamentos (motorista_id, dia desc);

-- Baixa de um pacote (comprovante com foto e localizacao).
create table public.entregas (
  id uuid primary key default gen_random_uuid(),
  motorista_id uuid not null default auth.uid() references public.motoristas (id) on delete cascade,
  codigo text not null,
  transportadora text,
  recebedor text,
  entregue boolean not null default true,
  foto_path text,
  foto_path2 text,
  lat double precision,
  lng double precision,
  data_entrega timestamptz not null default now()
);
create index entregas_motorista_data_idx on public.entregas (motorista_id, data_entrega desc);
create index entregas_motorista_codigo_idx on public.entregas (motorista_id, codigo);

-- Quanto o motorista recebeu (ex.: Pix). Nao editavel: corrige apagando.
create table public.pagamentos (
  id uuid primary key default gen_random_uuid(),
  motorista_id uuid not null default auth.uid() references public.motoristas (id) on delete cascade,
  valor numeric(10,2) not null check (valor > 0),
  data date not null default current_date,
  observacao text,
  criado_em timestamptz not null default now()
);
create index pagamentos_motorista_idx on public.pagamentos (motorista_id, data desc);

-- Configuracoes gerais. A chave 'app' e publica (modo manutencao).
create table public.configuracoes (
  chave text primary key,
  dados jsonb not null default '{}'::jsonb
);
insert into public.configuracoes (chave, dados)
values ('app', '{"manutencao": false}'::jsonb);

-- Funcoes auxiliares das politicas. security definer para nao cair em
-- recursao de RLS ao ler a propria tabela motoristas.
create function public.eh_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select coalesce((select admin from public.motoristas where id = (select auth.uid())), false) $$;

create function public.eh_ativo() returns boolean
language sql stable security definer set search_path = ''
as $$ select coalesce((select ativo from public.motoristas where id = (select auth.uid())), false) $$;

revoke execute on function public.eh_admin() from public, anon;
revoke execute on function public.eh_ativo() from public, anon;
grant execute on function public.eh_admin() to authenticated;
grant execute on function public.eh_ativo() to authenticated;

-- O motorista so pode mudar os proprios campos "pessoais"; admin/ativo
-- ficam protegidos (mesma ideia da regra do Firestore).
create function public.proteger_campos_motorista() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.eh_admin() then
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

create trigger motoristas_proteger_campos
before insert or update on public.motoristas
for each row execute function public.proteger_campos_motorista();

alter table public.motoristas enable row level security;
alter table public.lancamentos enable row level security;
alter table public.entregas enable row level security;
alter table public.pagamentos enable row level security;
alter table public.configuracoes enable row level security;

-- motoristas
create policy "motorista le o proprio perfil" on public.motoristas
  for select to authenticated using (id = (select auth.uid()) or (select public.eh_admin()));
create policy "motorista cria o proprio perfil" on public.motoristas
  for insert to authenticated with check (id = (select auth.uid()) or (select public.eh_admin()));
create policy "motorista atualiza o proprio perfil" on public.motoristas
  for update to authenticated using (id = (select auth.uid()) or (select public.eh_admin()))
  with check (id = (select auth.uid()) or (select public.eh_admin()));
create policy "admin apaga motorista" on public.motoristas
  for delete to authenticated using ((select public.eh_admin()));

-- lancamentos, entregas e pagamentos: dono ativo ou admin
create policy "lancamentos do dono" on public.lancamentos
  for all to authenticated
  using ((select public.eh_admin()) or ((select public.eh_ativo()) and motorista_id = (select auth.uid())))
  with check ((select public.eh_admin()) or ((select public.eh_ativo()) and motorista_id = (select auth.uid())));

create policy "entregas: ler" on public.entregas
  for select to authenticated
  using ((select public.eh_admin()) or ((select public.eh_ativo()) and motorista_id = (select auth.uid())));
create policy "entregas: criar" on public.entregas
  for insert to authenticated
  with check ((select public.eh_admin()) or ((select public.eh_ativo()) and motorista_id = (select auth.uid())));
create policy "entregas: atualizar" on public.entregas
  for update to authenticated
  using ((select public.eh_admin()) or ((select public.eh_ativo()) and motorista_id = (select auth.uid())))
  with check ((select public.eh_admin()) or ((select public.eh_ativo()) and motorista_id = (select auth.uid())));
create policy "entregas: admin apaga" on public.entregas
  for delete to authenticated using ((select public.eh_admin()));

create policy "pagamentos: ler" on public.pagamentos
  for select to authenticated
  using ((select public.eh_admin()) or ((select public.eh_ativo()) and motorista_id = (select auth.uid())));
create policy "pagamentos: criar" on public.pagamentos
  for insert to authenticated
  with check ((select public.eh_admin()) or ((select public.eh_ativo()) and motorista_id = (select auth.uid())));
create policy "pagamentos: apagar" on public.pagamentos
  for delete to authenticated
  using ((select public.eh_admin()) or ((select public.eh_ativo()) and motorista_id = (select auth.uid())));

-- configuracoes
create policy "config app publica" on public.configuracoes
  for select to anon, authenticated using (chave = 'app' or (select public.eh_admin()));
create policy "admin escreve config" on public.configuracoes
  for all to authenticated using ((select public.eh_admin())) with check ((select public.eh_admin()));

-- Fotos das entregas: bucket privado, cada motorista na pasta <uid>/...
insert into storage.buckets (id, name, public)
values ('fotos-entregas', 'fotos-entregas', false)
on conflict (id) do nothing;

create policy "fotos: motorista envia na propria pasta" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'fotos-entregas' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "fotos: motorista ou admin le" on storage.objects
  for select to authenticated
  using (bucket_id = 'fotos-entregas' and ((storage.foldername(name))[1] = (select auth.uid())::text or (select public.eh_admin())));

-- Cadastro: ao criar o usuario no Auth, cria o perfil do motorista com o
-- nome/telefone enviados no signUp. Funciona mesmo com confirmacao de
-- e-mail ligada (quando o app ainda nao tem sessao).
create function public.criar_perfil_motorista() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.motoristas (id, nome, telefone, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nome', ''),
    coalesce(new.raw_user_meta_data ->> 'telefone', ''),
    coalesce(new.email, '')
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger ao_criar_usuario
after insert on auth.users
for each row execute function public.criar_perfil_motorista();
