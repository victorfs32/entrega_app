# Entregas — versão React Native (Expo) + Supabase

Nova versão do `entrega_app` (Flutter + Firebase), escrita em React Native com
Expo e usando o Supabase (Auth, Postgres e Storage).

## O que já tem nesta primeira versão

- Login e cadastro de motorista (o perfil é criado no banco automaticamente)
- Bloqueio de conta desativada pelo admin
- Tela inicial com o ganho da quinzena, a meta e a previsão de pagamento
- Lançamento diário com rota (Eusébio R$ 2,80 / Aquiraz R$ 3,20), Anjun e
  iMile; editar e apagar lançamentos
- Registrar entrega: código, transportadora, quem recebeu, foto (enviada ao
  Storage) e localização GPS; bloqueia pacote já entregue
- Lista de entregas com foto e link para o mapa
- Aviso de nova versão (link publicado pelo GitHub Actions) e modo manutenção

Ainda falta portar do app Flutter: scanner de código de barras, leitura da
etiqueta (OCR) e "acha parada", entrega em massa, fotos offline pendentes,
financeiro/relatórios e assinatura Pix.

## Como rodar

1. O banco já está no projeto Supabase **entregas**. Num projeto novo, aplique
   os arquivos de `supabase/migrations/` em ordem
   (SQL Editor > colar e executar, ou `supabase db push`).
2. O `.env` já aponta para o projeto **entregas** (só a chave pública).
3. `npm install`
4. `npx expo start` e abra no celular com o app **Expo Go** (lendo o QR code).

## Atualização automática (GitHub Actions)

A cada push na `main` que mexa em `mobile/`, o workflow
`.github/workflows/release-apk-mobile.yml`:

1. gera o APK assinado (mesma chave do app Flutter: secrets
   `ANDROID_KEYSTORE_BASE64` e `ANDROID_KEY_PROPERTIES`);
2. publica no GitHub Releases com a tag `mobile-v<versão>`;
3. grava `ultimaVersao`, `apkUrl` e `notasAtualizacao` na linha `app` da
   tabela `configuracoes` do Supabase (precisa do secret
   `SUPABASE_SERVICE_ROLE_KEY`).

Ao abrir, o app compara a versão dele com `ultimaVersao` e oferece baixar o
APK novo. **Para lançar uma versão, suba o `version` no `app.json`** (ex.:
2.0.0 → 2.0.1); o `versionCode` é ajustado sozinho pelo workflow.

Modo manutenção: no Supabase, mude `dados.manutencao` para `true` na linha
`app` de `configuracoes` (opcional: `dados.mensagemManutencao`).

## Estrutura

- `src/app/` — telas (Expo Router; `(app)/` só aparece para quem está logado)
- `src/lib/` — Supabase, autenticação, lançamentos, entregas e regras da quinzena
- `src/ui/` — tema e componentes
- `supabase/migrations/` — tabelas, regras de acesso (RLS) e bucket de fotos
