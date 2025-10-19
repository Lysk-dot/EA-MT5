# EA-MT5 API - Startup Script for Windows (sem Docker)

## Pré-requisitos
- Python 3.11+ instalado ✓
- PostgreSQL acessível (local ou remoto)
- Dependências instaladas via `pip install -r requirements.txt` ✓

## Configuração

1. **Edite o arquivo `.env`** com as credenciais do banco:
   ```
   DATABASE_URL=postgresql+psycopg2://usuario:senha@host:porta/database
   ALLOWED_TOKEN=seu_token_aqui
   ```

2. **Configure os endpoints de forward** (opcional, para enviar dados ao servidor Linux):
   ```
   FORWARD_INGEST_URL=http://servidor-linux:8000/ingest
   FORWARD_TICK_URL=http://servidor-linux:8000/ingest/tick
   FORWARD_TOKEN=token_do_servidor_remoto
   FORWARD_CONFIRM_URL=http://servidor-linux:8000/confirm
   ```

## Rodar a API

### Desenvolvimento (com reload automático):
```powershell
cd infra\api
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Produção:
```powershell
cd infra\api
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

## Testar a API

```powershell
# Health check
Invoke-WebRequest -Uri "http://localhost:8000/health"

# Enviar tick
Invoke-WebRequest -Uri "http://localhost:8000/ingest" -Method POST -Headers @{"Content-Type"="application/json"; "x-api-key"="changeme"} -Body '{"symbol":"EURUSD","ts":1729252800000,"open":1.1,"high":1.2,"low":1.09,"close":1.15,"volume":1000,"kind":"TICK"}'

# Ver métricas
Invoke-WebRequest -Uri "http://localhost:8000/metrics"
```

## Quando trocar a placa-mãe:

Após instalar o hardware com suporte a virtualização:

```powershell
# Instalar Docker Desktop
# https://www.docker.com/products/docker-desktop/

# Subir todos os containers
cd infra
docker compose up --build -d

# Verificar status
docker compose ps

# Ver logs
docker compose logs -f api
```

## Endpoints disponíveis:

- `GET /health` - Health check
- `GET /metrics` - Métricas Prometheus
- `POST /ingest` - Ingest de ticks/candles (single ou batch)
- `POST /ingest/tick` - Ingest de tick individual
- `GET /signals/next?symbol=EURUSD` - Próximo sinal para símbolo
- `GET /signals/latest?symbol=EURUSD` - Último sinal para símbolo
- `POST /signals/ack` - Confirmar recebimento de sinais
- `POST /orders/feedback` - Enviar feedback de ordem
- `GET /debug/recent?limit=10` - Ver últimos ticks e forwards
- `GET /debug/pending?limit=50` - Ver forwards pendentes de confirmação

## Monitoramento (após Docker):

- **API**: http://localhost:8000
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **pgAdmin**: http://localhost:5050 (admin@admin.com/admin)

## Troubleshooting

### Erro de conexão com banco:
- Verifique se PostgreSQL está rodando
- Confirme credenciais no `.env`
- Teste conexão: `Test-NetConnection -ComputerName host -Port 5432`

### Porta 8000 já em uso:
```powershell
# Ver o que está usando a porta
Get-NetTCPConnection -LocalPort 8000

# Matar processo
Stop-Process -Id <PID> -Force

# Ou use outra porta
python -m uvicorn app.main:app --host 0.0.0.0 --port 8001
```
