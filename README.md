﻿# EA-MT5 - Expert Advisor com Pipeline de Dados
---

## 📦 Estrutura do Repositório

```text
EA-MT5/
├── infra/
│   ├── api/
│   ├── edge-relay/
│   ├── logs/
│   ├── monitoring/
│   ├── observability/
│   │   ├── structured_logging.py
│   │   ├── prometheus_metrics.py
│   ├── sql/
│   └── docker-compose.yml
├── EA/
│   ├── DataCollectorPRO.mq5
│   ├── Execution/
│   └── Obsoleto/
├── licenses/
│   └── license_5040621271.txt
├── logs/
├── scripts/
│   ├── auto-commit.ps1
│   ├── bump-version.ps1
│   ├── compile-ea.ps1
│   ├── ...
│   └── util/
├── docs/
│   ├── README-COMPLETO.md
│   ├── DATA-FLOW.md
│   ├── INDEX.md
│   ├── ...
├── tests/
│   ├── test_structured_logging.py
│   ├── test_prometheus_metrics.py
│   ├── test_connections.py
│   └── ...
├── run-all-tests.ps1
├── README.md
└── ...
```

---

[![License](https://img.shields.io/badge/license-Proprietary-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-green.svg)](https://fastapi.tiangolo.com/)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)

Expert Advisor profissional para MetaTrader 5 com pipeline completo de dados, API REST, monitoramento e infraestrutura cloud-ready.

---

## 📖 Documentação Completa

### ⭐ Comece Aqui:
- **[README-COMPLETO.md](docs/README-COMPLETO.md)** - Documentação principal do sistema
- **[DATA-FLOW.md](docs/DATA-FLOW.md)** - Fluxo de dados detalhado
- **[INDEX.md](docs/INDEX.md)** - Índice de toda documentação

---

## 🚀 Quick Start
```powershell
# 1. Exportar dados coletados
cd infra\api\tools
.\run-exporter.ps1

# 2. Ver dados no servidor
python query-db.py 1

# 3. Verificar sistema
.\run-verify-sql.ps1
```

---

---

## 🎯 Visão Geral

Sistema completo de coleta, processamento e análise de dados de mercado:

```
MT5 (EA) → SQLite Local → Exportador → PostgreSQL Servidor → Análise SQL
```

### Componentes
- ✅ **EA (MQL5)**: Coleta ticks em tempo real
- ✅ **API Lite**: Buffer local (SQLite)
- ✅ **Exporter**: Agregação e envio para servidor
- ✅ **API Main**: Servidor Linux (PostgreSQL/TimescaleDB)
- ✅ **Query Tools**: Análise via SQL (VS Code + Python)

---

---

## 📊 Status do Sistema

```
✅ EA coletando ticks
✅ API Local funcionando (porta 18000)
✅ Dados armazenados em SQLite
✅ Exportador configurado
✅ API Servidor rodando (192.168.15.20:18001)
✅ PostgreSQL armazenando em market_data
✅ Queries SQL funcionando
✅ 10+ queries prontas para análise
```

---

---

## 🔧 Ferramentas Disponíveis

### Scripts Python:
- `query-db.py` - Executar queries SQL
- `export_to_main.py` - Exportar dados
- `verify_main.py` - Verificar sistema

### Scripts PowerShell:
- `run-exporter.ps1` - Exportar dados
- `run-verify-sql.ps1` - Verificar saúde
- `query.ps1` - Executar queries

### Queries SQL (10 prontas):
- Últimos registros
- Resumo por símbolo
- Análise de volume
- Volatilidade
- Latência de dados
- Qualidade dos dados
- E mais...

---

---

## 🌐 Conexões

```
API Local:    http://localhost:18000
API Servidor: http://192.168.15.20:18001
PostgreSQL:   postgresql://trader:trader123@192.168.15.20:5432/mt5_trading
```

---
	- `Collection_Interval` (segundos)
	- `Collection_Timeframe` e `Use_Previous_Closed_Bar`
	- `Timestamp_Source` (COLLECTION_MINUTE, BAR_OPEN, TICK_TIME)
	- Segunda via (cópia local)
		- Save_Outbound_Copy (default ON)

---

## ⚙️ Como funciona
	- Timer (minuto): constrói `{ "items": [ ... ] }` com OHLCV + spread + meta e envia em lotes (respeita `MaxItemsPerBatch`) para `API_URL`.
	- Tick:
		- TICK_PER_TICK: envia `{ "ticks": [ t ] }` por tick até `Tick_Max_RPS`. Excedente vai para buffer e é enviado em lote.
		- TICK_BATCHED: acumula ticks e envia `{ "ticks": [ ... ] }` ao atingir `Tick_Batch_Max` ou `Tick_Flush_IntervalMs`.
	- Sucesso é considerado para HTTP 2xx ou quando `code==0` com corpo recebido (para compatibilidade com alguns servidores uvicorn).
	- Duplicados (HTTP 409 ou mensagem) são tratados como sucesso (idempotência).

---

## 🗂️ Cópia local (segunda via)
	- Arquivo diário JSONL: `PDC_outbound_YYYYMMDD.jsonl` (pasta FILE_COMMON do MT5)
	- Linhas por tipo:
		- {"ts":"...","kind":"items:batch","body":{...}}
		- {"ts":"...","kind":"tick:batch","body":{...}}
		- {"ts":"...","kind":"tick:1","body":{...}}
	- Somente grava quando o envio foi bem-sucedido.

---

### Como abrir a pasta FILE_COMMON
	- MT5: File > Open Data Folder > navegue para a pasta "MQL5" > "Files" (Common Files). O EA grava usando `FILE_COMMON`.

---

## 📝 Logs e diagnóstico
	- Ative `Enable_RealTime_Logging` para mensagens detalhadas no Experts log.
	- Opções de debug de rede: `Debug_Log_Headers`, `Debug_Log_Body`, `Debug_First_Attempt_Only`, `Debug_Log_Snippet_Chars`.
	- Mensagens típicas:
		- `[INGEST] try=1 code=0 err=0 bytes=200 url=...`
		- `[NETDBG] ctx=BATCH[0-134] body: {"ok":true,"inserted":0}`

---

## 💡 Dicas de operação
	- Se desejar reduzir tráfego duplicado: `Send_Only_On_Change=true` ou `Skip_Duplicate_TS=true` (o padrão é enviar sempre e o servidor deduplica).
	- Para testar o throttle de RPS, coloque `Tick_Send_Mode=TICK_PER_TICK` e `Tick_Max_RPS` baixo (ex.: 3). Veja TICK[1] até o limite e TICKBATCH para excedentes.

---

## 🛠️ Troubleshooting
	- `CopyRates retornou -1`: símbolo sem dados no timeframe; é esperado e ignorado no ciclo.
	- Sem resposta HTTP padrão (`code=0`): compatibilidade com uvicorn; verifique cabeçalhos e corpo — o EA já trata como sucesso se houver corpo.
	- WebRequest bloqueado: confirme a whitelist nas opções do MT5.

---

## 🤖 Automação / Git (resumo)
	- Commits no padrão `X.Y ++` (ex.: `0.11 ++`)
	- Scripts auxiliares (opcional): auto-commit agendado, whitelisting de WebRequest, notificação por email
	- Versão no código: macro `PDC_VER` usada em logs/metadados; um script de bump pode atualizar `PDC_VER` e `#property version` automaticamente (+0.01)

---

## 📄 Licença
Uso interno.

---

## 🔒 Licenciamento do EA
Este EA possui verificação de licença leve no `OnInit`.

### Inputs
	- License_Enabled (bool, ON por padrão)
	- License_Bind_Account (bool, vincula ao número da conta MT5)
	- License_Key (string no formato `PDC|ACCOUNT|YYYYMMDD|SIG`)

### Como funciona
1) Ao iniciar, o EA valida:
	- Prefixo `PDC`
	- Conta (se `License_Bind_Account=true`)
	- Data de expiração (deve ser >= hoje)
	- Assinatura `SIG` calculada como FNV-1a 32-bit em `ACCOUNT|YYYYMMDD|PEPPER`

### Formato da chave
```
PDC|12345678|20251231|AB12CD34
```

### Geração de chave (exemplo em PowerShell)
```powershell
$acct=12345678; $exp=20251231; $pep='PDC-LIC-2025-$k39'
function fnv1a32([string]$s){
	[uint32]$h=2166136261; $s.ToCharArray() | ForEach-Object { $h=$h -bxor ([byte]$_); $h=[uint32]($h*16777619) }
	return ('{0:X8}' -f $h)
}
$sig = fnv1a32("$acct|$exp|$pep")
"PDC|$acct|$exp|$sig"
```

---

Se a licença falhar, o EA retorna `INIT_FAILED` e não opera.
```powershell
$acct=12345678; $exp=20251231; $pep='PDC-LIC-2025-$k39'
function fnv1a32([string]$s){
	[uint32]$h=2166136261; $s.ToCharArray() | ForEach-Object { $h=$h -bxor ([byte]$_); $h=[uint32]($h*16777619) }
	return ('{0:X8}' -f $h)
}
$sig = fnv1a32("$acct|$exp|$pep")
"PDC|$acct|$exp|$sig"
```

Se a licenÃ§a falhar, o EA retorna `INIT_FAILED` e nÃ£o opera.

---

<!-- AUTO-INPUTS:START -->
## Inputs (gerado automaticamente)

### === COLETA / ENVIO ===
- int      Collection_Interval    = 60
- int      InterSymbol_DelayMs    = 60
- bool     Enable_API_Integration = true
- bool     Enable_RealTime_Logging= true
- ENUM_TIMEFRAMES Collection_Timeframe = PERIOD_CURRENT
- bool     Use_Previous_Closed_Bar = false

### === API ===
- string   API_URL                = "http://192.168.15.20:18001/ingest"
- string   API_Key                = "mt5_trading_secure_key_2025_prod"
- int      API_Timeout            = 6000
- bool     API_Fallback_To_File   = true
- bool     Enable_JSON_Validation = true

### === API HEADERS/AUTH ===
- bool     API_Use_Bearer_Token   = false
- string   API_Bearer_Token       = ""
- string   API_UserAgent          = "PDC/1.65"
- string   API_Extra_Header1      = ""
- string   API_Extra_Header2      = ""

### === DEBUG REDE ===
- bool     Debug_Log_Headers      = true
- bool     Debug_Log_Body         = true
- bool     Debug_First_Attempt_Only = true
- int      Debug_Log_Snippet_Chars  = 200

### === DUPLICADOS / TS ===
- bool     Skip_Duplicate_TS      = false
- ENUM_TS_SOURCE Timestamp_Source = TS_COLLECTION_MINUTE
- bool     Send_Only_On_Change    = false

### === FILTROS DE ATUALIZAÇÃO ===
- bool     Include_Stale_Symbols  = true
- int      MinRecentTickSec       = 600

### === BATCHING ===
- int      MaxItemsPerBatch       = 500
- bool     SplitOnPayloadTooLarge = true

### === OUTBOUND COPY/LOG ===
- bool     Save_Outbound_Copy     = true

### === TICKS (TEMPO REAL) ===
- bool     Enable_Tick_Stream     = true
- ENUM_TICK_MODE Tick_Send_Mode   = TICK_BATCHED
- int      Tick_Batch_Max         = 200
- int      Tick_Flush_IntervalMs  = 1000
- string   API_Tick_URL           = "http://192.168.15.20:18001/ingest/tick"
- int      Tick_Max_RPS           = 20

<!-- AUTO-INPUTS:END -->


#   E A - M T 5 
 
 #   E A - M T 5 
 
 