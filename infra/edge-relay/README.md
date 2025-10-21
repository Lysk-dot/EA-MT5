# Edge Relay - Arquitetura Local com Fila

## Visão Geral

O **Edge Relay** é um microsserviço local que recebe dados do EA via `localhost` e encaminha ao servidor remoto com fila persistente em disco e retries automáticos.

## Arquitetura

```
MT5 EA (DataCollectorRebuild)
    ↓ WebRequest http://127.0.0.1:18001 (latência ~1ms)
Edge Relay Local (FastAPI)
    ↓ HTTP POST http://192.168.15.20:18001 (remoto)
API Remota (infra/api)
    ↓ PostgreSQL/TimescaleDB
```

## Vantagens

✅ **Latência mínima**: EA envia para localhost (< 2ms típico)  
✅ **Resiliência**: Se o servidor remoto cair, dados são salvos em disco  
✅ **Retry automático**: Background worker tenta reenviar até conseguir  
✅ **Zero perda**: Fila persiste em `infra/edge-relay/queue/*.json`  
✅ **Simplicidade**: Transparente para o EA (mesmos endpoints)

## Como Funciona

### Fluxo Normal (servidor remoto online)
1. EA envia POST → localhost:18001
2. Relay encaminha → servidor remoto
3. Retorna resposta imediata ao EA

### Fluxo com Falha (servidor remoto offline)
1. EA envia POST → localhost:18001
2. Relay tenta enviar → falha (timeout/connection refused)
3. Relay salva payload em `queue/ingest-{timestamp}-{uuid}.json`
4. Retorna `{"queued": true}` ao EA
5. Background worker varre a pasta a cada 2s e reenvia pendentes
6. Quando consegue enviar, apaga o arquivo da fila

## Instalação

### Opção A: Docker (Recomendado)

```powershell
cd infra/edge-relay
docker compose up -d --build
```

**Configurar variáveis** (opcional, edite `.env` ou export antes do up):
```bash
REMOTE_INGEST=http://192.168.15.20:18001/ingest
REMOTE_TICK=http://192.168.15.20:18001/ingest/tick
REMOTE_TOKEN=changeme
```

### Opção B: Python Local

```powershell
# Da raiz do projeto
.\setup-edge-relay.ps1
```

Ou manualmente:
```powershell
cd infra/edge-relay
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 18001
```

## Configuração do MT5

1. **Whitelist**:
   - Tools > Options > Expert Advisors > Allow WebRequest
   - Adicionar: `http://127.0.0.1:18001`

2. **Inputs do EA**:
   ```
   API_URL = http://127.0.0.1:18001/ingest
   API_TICK_URL = http://127.0.0.1:18001/ingest/tick
   ```

## Endpoints

### `GET /health`
Retorna status do relay e tamanho da fila:
```json
{"ok": true, "queue": 3}
```

### `POST /ingest`
Recebe batch de candles, encaminha ao remoto ou enfileira.

### `POST /ingest/tick`
Recebe ticks individuais ou batches, encaminha ao remoto ou enfileira.

## Monitoramento

**Verificar fila de pendentes:**
```powershell
ls infra/edge-relay/queue/*.json | Measure-Object
```

**Logs do relay:**
- Docker: `docker compose logs -f edge-relay`
- Python: Stdout do terminal onde rodou `setup-edge-relay.ps1`

**Health check:**
```powershell
Invoke-RestMethod http://127.0.0.1:18001/health
```

## Solução de Problemas

### EA retorna `code=0` ou timeout
- Verifique se o relay está rodando: `Invoke-RestMethod http://127.0.0.1:18001/health`
- Confirme whitelist no MT5: `http://127.0.0.1:18001`

### Relay não encaminha (fila cresce)
- Verifique conectividade com o servidor remoto:
  ```powershell
  Invoke-RestMethod http://192.168.15.20:18001/health
  ```
- Confira REMOTE_TOKEN no relay = ALLOWED_TOKEN no servidor remoto

### Python não encontrado ao rodar setup
- Instale Python 3.12+: `.\install-python.ps1` ou Docker Desktop

## Arquivos

```
infra/edge-relay/
├── app/
│   └── main.py          # FastAPI app (endpoints + queue worker)
├── queue/               # Fila em disco (*.json)
├── requirements.txt     # Deps Python
├── Dockerfile           # Imagem Docker
├── docker-compose.yml   # Compose config
└── README.md            # Este arquivo
```

## Segurança

- **Relay local** não valida `x-api-key` do EA (conexão local)
- **Relay → Remoto** injeta `REMOTE_TOKEN` como `x-api-key`
- Servidor remoto valida com `ALLOWED_TOKEN`

## Performance

- **Latência típica** (EA → relay): 1-3ms
- **Overhead de disco** (quando offline): ~1ms por item
- **Limite de fila**: Sem limite (depende do disco)

---

**Próximos Passos:**
1. Inicie o relay (Docker ou Python)
2. Configure whitelist no MT5
3. Recompile e anexe o EA com inputs localhost
4. Verifique logs: `[INGEST] ok` e `[TICK] flush ok`
