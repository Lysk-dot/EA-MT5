# 📡 Fluxo de Dados: Windows (MT5) → Linux (Servidor Principal)

## 🔄 Arquitetura Atual

```
┌─────────────────────────────────────────────────────────────────────────┐
│ WINDOWS (Sua Máquina Local)                                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐                                                       │
│  │  EA (MT5)    │  Coleta ticks em tempo real                          │
│  │ DataCollector│  - EURUSD, GBPUSD, etc.                              │
│  └──────┬───────┘  - Executa a cada tick                               │
│         │                                                               │
│         │ HTTP POST                                                     │
│         ▼                                                               │
│  ┌──────────────┐                                                       │
│  │  API Lite    │  SQLite Local (infra/api/data/ea.db)                │
│  │ Port: 18000  │  - Recebe /ingest/tick                               │
│  └──────┬───────┘  - Armazena localmente                               │
│         │          - Endpoint: http://localhost:18000                   │
│         │                                                               │
│         │ Manual Export (script Python)                                │
│         ▼                                                               │
│  ┌──────────────┐                                                       │
│  │  Exporter    │  Script: export_to_main.py                           │
│  │   Tool       │  - Lê do SQLite local                                │
│  └──────┬───────┘  - Agrega ticks para M1                              │
│         │          - Envia batches para servidor                        │
│         │                                                               │
└─────────┼─────────────────────────────────────────────────────────────┘
          │
          │ HTTP POST (via LAN)
          │ http://192.168.15.20:18001/ingest
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ LINUX (Servidor Principal - 192.168.15.20)                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐                                                       │
│  │  API Main    │  FastAPI + PostgreSQL (TimescaleDB)                  │
│  │ Port: 18001  │  - Recebe /ingest                                    │
│  └──────┬───────┘  - Armazena em market_data                           │
│         │          - Métricas: /metrics (Prometheus)                    │
│         │                                                               │
│         ▼                                                               │
│  ┌──────────────┐                                                       │
│  │ PostgreSQL   │  Banco: mt5_trading                                  │
│  │ TimescaleDB  │  Tabela: market_data                                 │
│  └──────────────┘  User: trader / Pass: trader123                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## ✅ Status Atual

### 1. EA → API Lite (LOCAL) ✅ FUNCIONANDO
- **EA**: `DataCollectorPRO.mq5` ou similar
- **Endpoint**: `http://localhost:18000/ingest/tick`
- **Status**: ✅ Coletando ticks e salvando no SQLite local

### 2. API Lite (SQLite Local) ✅ FUNCIONANDO
- **Banco**: `infra/api/data/ea.db`
- **Tabela**: `ticks`
- **Status**: ✅ Armazenando dados localmente

### 3. Exporter → API Main (LINUX) ✅ FUNCIONANDO
- **Script**: `infra/api/tools/export_to_main.py`
- **Destino**: `http://192.168.15.20:18001/ingest`
- **Token**: `mt5_trading_secure_key_2025_prod`
- **Status**: ✅ Exportou dados com sucesso (confirmado por HTTP 200)

### 4. API Main (PostgreSQL Linux) ✅ FUNCIONANDO
- **Server**: `192.168.15.20:5432`
- **Database**: `mt5_trading`
- **Tabela**: `market_data`
- **Status**: ✅ Recebendo e armazenando dados (confirmado por query SQL)

---

## 🚀 Como os Dados São Enviados

### Método Atual: Export Manual (Script Python)

```powershell
# Exportar últimos 200 registros
cd infra\api\tools
.\run-exporter.ps1

# Ou diretamente:
python export_to_main.py --limit 200

# Exportar últimos 60 minutos
python export_to_main.py --since-minutes 60

# Exportar TUDO (paginado)
python export_to_main.py --all --page-size 1000
```

### O que o Exporter Faz:
1. ✅ Lê dados do SQLite local (`ea.db`)
2. ✅ Agrega ticks em candles M1 (OHLCV)
3. ✅ Envia em batches de 200 para `http://192.168.15.20:18001/ingest`
4. ✅ Usa token de autenticação: `mt5_trading_secure_key_2025_prod`
5. ✅ Fallback: se `/ingest/tick` falhar (404), tenta `/ingest` com candles agregados

---

## 🔄 Opções para Envio Automático

### Opção 1: Agendamento via Task Scheduler (Recomendado)
Exportar dados a cada X minutos automaticamente:

```powershell
# Criar tarefa agendada para exportar a cada 5 minutos
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File 'C:\Users\lysk9\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\infra\api\tools\run-exporter.ps1'"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName "MT5-DataExport" -Action $action -Trigger $trigger
```

### Opção 2: Script de Loop Contínuo
Criar um script que fica rodando e exporta periodicamente:

```python
# export_continuous.py
import time
import subprocess

while True:
    print("Exportando dados...")
    subprocess.run(['python', 'export_to_main.py', '--since-minutes', '10'])
    print("Aguardando 5 minutos...")
    time.sleep(300)  # 5 minutos
```

### Opção 3: Relay com Forward Automático (Mais Complexo)
Usar o componente Relay para fazer forward automático em tempo real.

---

## 📊 Verificação de Dados

### Ver dados no banco Linux:
```powershell
# Via Python
python infra\api\tools\query-db.py 1

# Ver últimos dados
python infra\api\tools\query-db.py 2

# Ver latência
python infra\api\tools\query-db.py 3
```

### Verificar exportação:
```powershell
# Ver quantos dados estão no SQLite local
cd infra\api\tools
python -c "import sqlite3; conn=sqlite3.connect('../data/ea.db'); print('Total ticks:', conn.execute('SELECT COUNT(*) FROM ticks').fetchone()[0]); conn.close()"
```

---

## 🎯 Configuração Atual (FUNCIONANDO)

**Resumo**: Você já exportou dados para o servidor Linux com sucesso!

✅ Confirmações:
1. Query SQL mostrou 2 registros de EURUSD no banco `market_data`
2. Timestamps: 2025-10-20 02:20 e 02:21
3. Servidor: 192.168.15.20:5432
4. API funcionando em: http://192.168.15.20:18001

---

## 🔧 Próximos Passos (Opcional)

### Para Envio Automático:
1. **Agendar exportação a cada 5 minutos**
2. **Configurar Relay para forward em tempo real** (mais avançado)
3. **Configurar EA para enviar direto ao servidor Linux** (requer network setup no MT5)

### Para Monitoramento:
1. ✅ Já pode usar `query-db.py` para ver dados
2. ✅ Já pode usar extensão PostgreSQL do VS Code
3. ✅ API Main tem `/metrics` para Prometheus/Grafana

---

## 📝 Comandos Úteis

```powershell
# Exportar dados (manual)
cd infra\api\tools
.\run-exporter.ps1

# Ver dados exportados
python query-db.py 1

# Ver status do pipeline
.\run-verify-sql.ps1

# Ver quantos dados estão no SQLite local
python -c "import sqlite3; conn=sqlite3.connect('../data/ea.db'); print('Ticks locais:', conn.execute('SELECT COUNT(*) FROM ticks').fetchone()[0]); conn.close()"
```

---

## 🎉 Conclusão

**Resposta curta**: Os dados JÁ ESTÃO sendo enviados para o servidor Linux! 

Você só precisa executar o exporter (`.\run-exporter.ps1`) quando quiser enviar os dados coletados localmente.

Se quiser **automatizar** isso, posso criar um agendamento via Task Scheduler ou um script contínuo. Qual você prefere?
