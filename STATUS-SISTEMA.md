# SISTEMA DE COLETA - STATUS FINAL

## ✅ O QUE ESTÁ RODANDO

### 1. Edge Relay Local (porta 18001)
- **Status**: ONLINE
- **Recebe de**: MT5 EA (http://127.0.0.1:18001/ingest e /ingest/tick)
- **Envia para**: API Local (http://127.0.0.1:18002)
- **Fila**: Arquivos em `infra/edge-relay/queue/`
- **Janela**: Minimizada (start-relay-local.bat)

### 2. API Local SQLite (porta 18002)
- **Status**: ONLINE
- **Database**: `infra/api/data/ea.db` (SQLite)
- **Endpoints**: `/health`, `/ingest`, `/ingest/tick`, `/stats`
- **Janela**: Minimizada (PowerShell com uvicorn)

### 3. EA DataCollectorRebuild
- **Status**: Deve estar rodando no MT5
- **Coleta**: Candles M1 + Ticks multi-símbolo
- **Envia para**: http://127.0.0.1:18001 (relay)
- **Auto-pause**: Após 15 falhas consecutivas

## 📋 PRÓXIMOS PASSOS

### 1. Verificar EA no MT5
O EA pode estar pausado. Verifique nos logs (aba Expert):
- Se ver `[TICK] auto-paused`, **remova e recoloque o EA** no gráfico
- Deve aparecer: `[INGEST] ok code=200` e `[TICK] flush ok`

### 2. Limpar fila antiga (se necessário)
A fila tem arquivos com URL antiga. Para limpar:
```powershell
Remove-Item "C:\Users\lysk9\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\infra\edge-relay\queue\*.json" -Force
```

### 3. Verificar dados no banco
```powershell
# Health check
Invoke-RestMethod http://127.0.0.1:18002/health

# Estatísticas detalhadas
Invoke-RestMethod http://127.0.0.1:18002/stats
```

### 4. Consultar dados salvos (SQLite)
```powershell
cd "C:\Users\lysk9\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\infra\api"
sqlite3 data\ea.db "SELECT COUNT(*) FROM ticks;"
sqlite3 data\ea.db "SELECT symbol, COUNT(*) FROM ticks GROUP BY symbol;"
```

## 🔧 GERENCIAMENTO

### Parar tudo
```powershell
# Parar relay
Get-Process python | Where-Object {$_.CommandLine -match 'app.main:app'} | Stop-Process -Force

# Parar API
Get-Process python | Where-Object {$_.CommandLine -match 'main_lite'} | Stop-Process -Force
```

### Reiniciar relay
```powershell
cd "C:\Users\lysk9\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts"
.\start-relay-local.bat
```

### Reiniciar API
```powershell
cd "C:\Users\lysk9\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\infra\api"
.\.venv\Scripts\Activate.ps1
$env:ALLOWED_TOKEN = "changeme"
$env:DB_PATH = "./data/ea.db"
uvicorn app.main_lite:app --host 127.0.0.1 --port 18002
```

## 📊 MONITORAMENTO

### Relay
```powershell
Invoke-RestMethod http://127.0.0.1:18001/health
```

### API
```powershell
Invoke-RestMethod http://127.0.0.1:18002/health
Invoke-RestMethod http://127.0.0.1:18002/stats
```

### Fila
```powershell
Get-ChildItem "infra\edge-relay\queue\*.json" | Measure-Object
```

## 🎯 TESTE MANUAL

Enviar tick de teste:
```powershell
$payload = @{
    symbol = "EURUSD"
    ts = "2025-10-20T02:00:00Z"
    timeframe = "M1"
    open = 1.0850
    high = 1.0851
    low = 1.0849
    close = 1.0850
    volume = 100
} | ConvertTo-Json

$headers = @{
    "x-api-key" = "changeme"
    "Content-Type" = "application/json"
}

Invoke-RestMethod -Uri "http://127.0.0.1:18001/ingest" -Method Post -Body $payload -Headers $headers -ContentType "application/json"
```

## ⚠️ TROUBLESHOOTING

### EA não envia (code=0, err=4006)
- Whitelist: Tools > Options > Expert Advisors > Allow WebRequest
- Adicionar: `http://127.0.0.1:18001`
- Remover e recolocar EA

### Relay não processa fila
- Arquivos têm URL antiga (192.168.15.20)
- Solução: Limpar fila e deixar EA gerar novos dados

### API não grava dados
- Verificar se main_lite.py está rodando
- Verificar se pasta `data/` existe e tem permissões
- Ver logs na janela do uvicorn

## 📁 ESTRUTURA DE ARQUIVOS

```
infra/
├── edge-relay/
│   ├── app/main.py          # Relay FastAPI
│   ├── queue/               # Fila de dados pendentes
│   └── requirements.txt
├── api/
│   ├── app/
│   │   ├── main.py          # API completa (PostgreSQL)
│   │   ├── main_lite.py     # API simplificada (SQLite) ✅
│   │   └── requirements.txt
│   ├── data/
│   │   └── ea.db            # Banco SQLite ✅
│   └── .venv/               # Ambiente Python ✅

EA/
└── DataCollectorRebuild.mq5  # Expert Advisor ✅
```

## ✅ FINALIZAÇÃO

O sistema está **funcional** e pronto para coletar dados:
1. Relay recebendo do EA (porta 18001)
2. API gravando em SQLite (porta 18002)
3. Fila para resiliência offline

**Próxima ação**: Remover e recolocar o EA no gráfico do MT5 para retomar coleta!
