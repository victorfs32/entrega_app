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

Ainda falta portar do app Flutter: scanner de código de barras, leitura da
etiqueta (OCR) e "acha parada", entrega em massa, fotos offline pendentes,
financeiro/relatórios, assinatura Pix e atualização automática.

## Como rodar

1. Aplique `supabase/migrations/0001_entregas.sql` no projeto Supabase
   (SQL Editor > colar e executar, ou `supabase db push`).
2. Copie `.env.example` para `.env` e preencha a URL e a chave pública do projeto.
3. `npm install`
4. `npx expo start` e abra no celular com o app **Expo Go** (lendo o QR code).

Para gerar o APK: `npx eas-cli@latest build -p android --profile preview`.

## Estrutura

- `src/app/` — telas (Expo Router; `(app)/` só aparece para quem está logado)
- `src/lib/` — Supabase, autenticação, lançamentos, entregas e regras da quinzena
- `src/ui/` — tema e componentes
- `supabase/migrations/` — tabelas, regras de acesso (RLS) e bucket de fotos
