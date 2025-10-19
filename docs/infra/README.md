# Infra local (Windows Server 2019)

Esta pasta provê um stack local com Postgres + API de ingest (FastAPI) via Docker Compose. Útil para testar o EA sem depender do servidor Linux.

## Pré-requisitos
- Windows Server 2019 com Docker Desktop (ou Docker Engine) instalado
- Suporte a Linux containers habilitado

## Configuração
1. Copie `.env.example` para `.env` e ajuste variáveis (token, portas, etc.)
2. Libere as portas no firewall (padrão: 18001 para API e 5432 para Postgres)

## Subir os serviços
```
powershell -ExecutionPolicy Bypass -Command "cd infra; docker compose up -d --build"
```

- API: http://localhost:18001
- Healthcheck: http://localhost:18001/health
- Postgres: localhost:5432 (db=ea, user=ea, pass=ea123 por padrão)

## Apontar o EA
- Em `DataCollectorPRO.mq5`, use:
  - API_URL: `http://127.0.0.1:18001/ingest`
  - API_Tick_URL: `http://127.0.0.1:18001/ingest/tick`
- Adicione os endpoints na whitelist do WebRequest do MT5.

## Observações
- O banco inicia com a tabela `ticks` (chave primária: symbol+ts), lidando bem com dedupe.
- O header `x-api-key` deve bater com `ALLOWED_TOKEN` do `.env`.
- Para logs da API: `docker compose logs -f api`
- Para acessar o banco: use qualquer cliente Postgres com as credenciais do .env.
