# 📚 Documentação Completa do Sistema MT5 Trading

## 📑 Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura do Sistema](#arquitetura-do-sistema)
3. [Componentes](#componentes)
4. [Fluxo de Dados](#fluxo-de-dados)
5. [Configuração](#configuração)
6. [Uso Diário](#uso-diário)
7. [Monitoramento](#monitoramento)
8. [Troubleshooting](#troubleshooting)
9. [Referências Rápidas](#referências-rápidas)

---

## 🎯 Visão Geral

Sistema completo de coleta, processamento e armazenamento de dados de mercado do MetaTrader 5 (MT5) para análise quantitativa e trading algorítmico.

### Objetivos:
- ✅ Coletar ticks em tempo real do MT5
- ✅ Armazenar localmente (backup/fallback)
- ✅ Exportar para servidor centralizado (análise)
- ✅ Monitorar qualidade e latência dos dados
- ✅ Permitir consultas e análises via SQL

### Stack Tecnológico:
- **EA (Expert Advisor)**: MQL5
- **API Local**: FastAPI + SQLite
- **API Servidor**: FastAPI + PostgreSQL (TimescaleDB)
- **Exportação**: Python 3.12
- **Automação**: PowerShell
- **Monitoramento**: Prometheus + Grafana (opcional)

---

## 🏗️ Arquitetura do Sistema

```
┌─────────────────────────────────────────────────────────────────────────┐
│ CAMADA DE COLETA (Windows - MT5)                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ MetaTrader 5 (MT5)                                                │  │
│  │ - Expert Advisor: DataCollectorPRO.mq5                           │  │
│  │ - Coleta: EURUSD, GBPUSD, USDJPY, etc.                          │  │
│  │ - Frequência: A cada tick (tempo real)                           │  │
│  └────────────────────┬─────────────────────────────────────────────┘  │
│                       │ HTTP POST                                       │
│                       ▼                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ API Lite (Local Endpoint)                                         │  │
│  │ - Framework: FastAPI                                              │  │
│  │ - Porta: 18000                                                    │  │
│  │ - Endpoint: /ingest/tick                                          │  │
│  │ - Storage: SQLite (ea.db)                                         │  │
│  │ - Função: Buffer local + fallback                                │  │
│  └────────────────────┬─────────────────────────────────────────────┘  │
│                       │                                                 │
└───────────────────────┼─────────────────────────────────────────────────┘
                        │
                        │ Manual/Scheduled Export
                        │
┌───────────────────────┼─────────────────────────────────────────────────┐
│ CAMADA DE EXPORTAÇÃO  │                                                 │
├───────────────────────┼─────────────────────────────────────────────────┤
│                       ▼                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Exporter Tool (Python)                                            │  │
│  │ - Script: export_to_main.py                                       │  │
│  │ - Origem: SQLite local (ea.db)                                    │  │
│  │ - Destino: API Main (servidor Linux)                             │  │
│  │ - Processamento:                                                  │  │
│  │   • Lê dados locais                                               │  │
│  │   • Agrega ticks → candles M1 (OHLCV)                            │  │
│  │   • Envia em batches (200 por vez)                               │  │
│  │   • Retry automático em caso de falha                            │  │
│  └────────────────────┬─────────────────────────────────────────────┘  │
│                       │ HTTP POST                                       │
└───────────────────────┼─────────────────────────────────────────────────┘
                        │
                        │ LAN: http://192.168.15.20:18001/ingest
                        │
┌───────────────────────┼─────────────────────────────────────────────────┐
│ CAMADA DE PERSISTÊNCIA│ (Linux Server - 192.168.15.20)                 │
├───────────────────────┼─────────────────────────────────────────────────┤
│                       ▼                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ API Main (Production Endpoint)                                    │  │
│  │ - Framework: FastAPI                                              │  │
│  │ - Porta: 18001                                                    │  │
│  │ - Endpoints:                                                      │  │
│  │   • POST /ingest - Recebe candles OHLCV                          │  │
│  │   • GET  /health - Health check                                  │  │
│  │   • GET  /metrics - Prometheus metrics                           │  │
│  │ - Autenticação: Bearer token                                      │  │
│  └────────────────────┬─────────────────────────────────────────────┘  │
│                       │                                                 │
│                       ▼                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ PostgreSQL 16 + TimescaleDB                                       │  │
│  │ - Porta: 5432                                                     │  │
│  │ - Database: mt5_trading                                           │  │
│  │ - User: trader / Pass: trader123                                 │  │
│  │ - Tabelas:                                                        │  │
│  │   • market_data - Dados OHLCV                                    │  │
│  │   • market_data_raw - Ticks brutos                               │  │
│  │   • trade_logs - Logs de trades                                  │  │
│  │   • signals - Sinais de trading                                  │  │
│  │   • fills - Execuções                                             │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ CAMADA DE ANÁLISE (VS Code + SQL)                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ VS Code PostgreSQL Extension                                      │  │
│  │ - Extensão: ckolkman.vscode-postgres                             │  │
│  │ - Queries prontas: infra/api/tools/queries/                      │  │
│  │ - Script Python: query-db.py                                      │  │
│  │ - Análises: Volume, volatilidade, latência, qualidade            │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Componentes

### 1. Expert Advisor (EA)

**Arquivo**: `EA/DataCollectorPRO.mq5`

**Função**: Coletar ticks em tempo real do MT5 e enviar para API local.

**Configuração**:
```mql5
// Parâmetros principais
input string API_URL = "http://localhost:18000/ingest/tick";
input string API_TOKEN = "changeme";
input int BATCH_SIZE = 10;
input bool ENABLE_LOGGING = true;
```

**Funcionalidades**:
- ✅ Coleta de ticks em tempo real
- ✅ Batching (agrupa múltiplos ticks)
- ✅ Retry automático em caso de falha
- ✅ Logging detalhado (opcional)
- ✅ Suporte a múltiplos símbolos
- ✅ Fallback: salva em arquivo se API offline

**Logs**: `MQL5/Files/DataCollector_*.log`

---

### 2. API Lite (Local Buffer)

**Localização**: `infra/api/`

**Tecnologia**: FastAPI + SQLite

**Porta**: `18000`

**Banco de Dados**: `infra/api/data/ea.db`

**Endpoints**:
```
POST /ingest/tick   - Recebe ticks do EA
POST /ingest        - Recebe candles agregados
GET  /health        - Health check
GET  /stats         - Estatísticas do banco local
```

**Tabela SQLite**:
```sql
CREATE TABLE ticks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    ts_ms INTEGER NOT NULL,
    timeframe TEXT,
    open REAL,
    high REAL,
    low REAL,
    close REAL,
    volume REAL,
    kind TEXT,
    meta TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

**Executar API**:
```powershell
cd infra/api
python -m uvicorn main:app --host 0.0.0.0 --port 18000
```

---

### 3. Exporter Tool

**Script**: `infra/api/tools/export_to_main.py`

**Função**: Exportar dados do SQLite local para PostgreSQL servidor.

**Uso**:
```powershell
# Exportar últimos 200 registros
python export_to_main.py --limit 200

# Exportar últimos 60 minutos
python export_to_main.py --since-minutes 60

# Exportar TUDO (paginado)
python export_to_main.py --all --page-size 1000

# Dry-run (não envia, apenas mostra o que seria enviado)
python export_to_main.py --dry-run --limit 10
```

**Parâmetros**:
```
--db              Caminho do SQLite (padrão: ../data/ea.db)
--api             URL da API principal (padrão: http://192.168.15.20:18001)
--token           Token de autenticação
--limit           Máximo de registros a exportar
--since-minutes   Exportar apenas dados dos últimos N minutos
--batch           Tamanho do batch (padrão: 200)
--all             Exportar TUDO usando paginação
--page-size       Registros por página quando usando --all
--dry-run         Simular sem enviar
--aggregate-to    Agregar ticks para candles (auto/none/M1)
```

**PowerShell Wrapper**:
```powershell
# Wrapper simplificado
.\infra\api\tools\run-exporter.ps1

# Com parâmetros customizados
.\infra\api\tools\run-exporter.ps1 -Limit 500 -SinceMinutes 30
```

**Processamento**:
1. Lê dados do SQLite local
2. Agrega ticks em candles M1 (OHLCV)
3. Envia em batches para API principal
4. Fallback: se `/ingest/tick` retornar 404, tenta `/ingest` com candles

---

### 4. API Main (Servidor Linux)

**Server**: `192.168.15.20`

**Porta API**: `18001`

**Porta DB**: `5432`

**Tecnologia**: FastAPI + PostgreSQL 16 + TimescaleDB

**Endpoints**:
```
POST /ingest                - Recebe candles OHLCV
POST /ingest/tick           - Recebe ticks (opcional)
GET  /health                - Health check
GET  /metrics               - Prometheus metrics
```

**Autenticação**:
```
Header: Authorization: Bearer mt5_trading_secure_key_2025_prod
```

**Banco de Dados**:
```
Host: 192.168.15.20
Port: 5432
Database: mt5_trading
User: trader
Password: trader123
```

**Tabela Principal**:
```sql
-- Tabela market_data (candles OHLCV)
CREATE TABLE market_data (
    ts TIMESTAMPTZ NOT NULL,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    open DOUBLE PRECISION,
    high DOUBLE PRECISION,
    low DOUBLE PRECISION,
    close DOUBLE PRECISION,
    volume DOUBLE PRECISION,
    tick_count DOUBLE PRECISION,
    -- Campos adicionais (nullable)
    bid DOUBLE PRECISION,
    ask DOUBLE PRECISION,
    spread DOUBLE PRECISION,
    ...
);

-- Índices TimescaleDB
SELECT create_hypertable('market_data', 'ts');
CREATE INDEX ON market_data (symbol, ts DESC);
```

---

### 5. Query Tools (Análise SQL)

**Localização**: `infra/api/tools/`

**Scripts**:
- `query-db.py` - Script Python para executar queries
- `query.ps1` - Wrapper PowerShell
- `queries/` - Pasta com queries SQL prontas

**Queries Disponíveis**:

#### Via Python:
```powershell
python query-db.py 1    # Últimos 20 registros
python query-db.py 2    # Resumo por símbolo (24h)
python query-db.py 3    # Latência de dados
python query-db.py 4    # Estrutura da tabela
python query-db.py 5    # Timeline completa
```

#### Via PowerShell:
```powershell
.\query.ps1 -Query 1
.\query.ps1 -Query 2
```

#### Arquivos SQL (VS Code):
```
queries/
├── MT5-Trading-Analysis.sql      - Análise completa (10 queries)
├── 01-verificacao-basica.sql     - Verificações básicas
├── 02-analise-volume.sql         - Análise de volume
├── 03-monitoramento-pipeline.sql - Monitoramento de saúde
└── README-COMO-USAR.md           - Guia de uso
```

---

### 6. Verificadores

**Script**: `infra/api/tools/verify_main.py`

**Função**: Verificar saúde da API e do banco PostgreSQL.

**Uso**:
```powershell
# Verificar API + Métricas
.\infra\api\tools\run-verify.ps1

# Verificar API + SQL
.\infra\api\tools\run-verify-sql.ps1
```

**Checagens**:
- ✅ API `/health` retorna 200 OK
- ✅ API `/metrics` retorna métricas Prometheus
- ✅ PostgreSQL aceita conexões
- ✅ Tabelas existem e têm dados
- ✅ Dados recentes (últimos 60 minutos)

---

## 📊 Fluxo de Dados

### Passo a Passo:

1. **Coleta (Tempo Real)**:
   - EA executa a cada tick no MT5
   - Coleta: symbol, timestamp, OHLC, volume
   - Envia HTTP POST para `http://localhost:18000/ingest/tick`

2. **Armazenamento Local**:
   - API Lite recebe o tick
   - Valida e normaliza dados
   - Insere no SQLite (`ea.db`)
   - Responde 200 OK ao EA

3. **Exportação (Manual ou Agendada)**:
   - Script `export_to_main.py` executa
   - Lê últimos dados do SQLite
   - Agrega ticks em candles M1 (OHLCV)
   - Envia batches para API Main

4. **Persistência Servidor**:
   - API Main recebe POST `/ingest`
   - Valida autenticação (Bearer token)
   - Insere em PostgreSQL (`market_data`)
   - Retorna 200 OK ou erro

5. **Análise**:
   - Conectar ao PostgreSQL via VS Code ou Python
   - Executar queries SQL
   - Visualizar dados, calcular métricas

---

## ⚙️ Configuração

### Pré-requisitos:

**Windows (MT5)**:
- MetaTrader 5 instalado
- Python 3.12+
- PowerShell 5.1+

**Linux (Servidor)**:
- PostgreSQL 16 + TimescaleDB
- Python 3.11+
- FastAPI + Uvicorn

### Instalação:

#### 1. Configurar EA no MT5

```
1. Copiar EA/DataCollectorPRO.mq5 para: MQL5/Experts/
2. Compilar no MetaEditor (F7)
3. Adicionar ao gráfico
4. Configurar parâmetros:
   - API_URL: http://localhost:18000/ingest/tick
   - API_TOKEN: changeme
5. Ativar AutoTrading (Ctrl+E)
```

#### 2. Instalar API Lite (Windows)

```powershell
cd infra/api

# Criar ambiente virtual
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Instalar dependências
pip install fastapi uvicorn sqlalchemy aiosqlite

# Executar API
python -m uvicorn main:app --host 0.0.0.0 --port 18000
```

#### 3. Configurar Servidor Linux

```bash
# Instalar PostgreSQL + TimescaleDB
sudo apt-get install postgresql-16 timescaledb-postgresql-16

# Criar banco
sudo -u postgres psql
CREATE DATABASE mt5_trading;
CREATE USER trader WITH PASSWORD 'trader123';
GRANT ALL PRIVILEGES ON DATABASE mt5_trading TO trader;

# Ativar TimescaleDB
\c mt5_trading
CREATE EXTENSION timescaledb;

# Executar API Main
cd infra/api
python -m uvicorn main:app --host 0.0.0.0 --port 18001
```

#### 4. Instalar VS Code Extension

```
1. Abrir VS Code
2. Extensions (Ctrl+Shift+X)
3. Buscar: "PostgreSQL"
4. Instalar: ckolkman.vscode-postgres
5. Adicionar conexão:
   - Host: 192.168.15.20
   - Port: 5432
   - Database: mt5_trading
   - User: trader
   - Password: trader123
```

---

## 🚀 Uso Diário

### Manhã (Iniciar Sistema):

```powershell
# 1. Verificar MT5 está rodando
# 2. Verificar EA está ativo (AutoTrading ON)

# 3. Iniciar API Lite (se não estiver rodando)
cd infra/api
python -m uvicorn main:app --host 0.0.0.0 --port 18000
```

### Durante o Dia (Exportar Dados):

```powershell
# Exportar dados coletados (executar a cada 5-30 minutos)
cd infra/api/tools
.\run-exporter.ps1

# Ou com parâmetros:
python export_to_main.py --since-minutes 30 --batch 200
```

### Final do Dia (Verificações):

```powershell
# 1. Verificar saúde do sistema
cd infra/api/tools
.\run-verify-sql.ps1

# 2. Ver resumo dos dados coletados
python query-db.py 2    # Resumo por símbolo

# 3. Verificar latência
python query-db.py 3    # Latência de dados
```

---

## 📈 Monitoramento

### Verificar Status da API:

```powershell
# Health check API Lite
curl http://localhost:18000/health

# Health check API Main
curl http://192.168.15.20:18001/health

# Métricas Prometheus
curl http://192.168.15.20:18001/metrics
```

### Ver Estatísticas:

```powershell
# API Lite
curl http://localhost:18000/stats

# SQL - Resumo
python query-db.py 2
```

### Logs:

**EA (MT5)**:
```
MQL5/Files/DataCollector_YYYYMMDD.log
```

**API Lite**:
```
Console output (Uvicorn logs)
```

**API Main**:
```
/var/log/api-main/ (servidor Linux)
```

---

## 🔍 Troubleshooting

### Problema: EA não envia dados

**Diagnóstico**:
```
1. Verificar logs: MQL5/Files/DataCollector_*.log
2. Verificar AutoTrading está ON
3. Verificar URL da API: http://localhost:18000/ingest/tick
4. Testar API manualmente:
   curl -X POST http://localhost:18000/ingest/tick -H "Content-Type: application/json" -d '{"symbol":"TEST","ts":1234567890,"open":1.0,"high":1.0,"low":1.0,"close":1.0,"volume":100}'
```

**Soluções**:
- Recompilar EA
- Reiniciar MT5
- Verificar firewall/antivírus
- Checar se API Lite está rodando

---

### Problema: Exporter falha ao enviar dados

**Diagnóstico**:
```powershell
# Verificar conectividade
ping 192.168.15.20

# Testar API Main
curl http://192.168.15.20:18001/health

# Verificar token
# Token correto: mt5_trading_secure_key_2025_prod

# Testar manualmente
python export_to_main.py --dry-run --limit 5
```

**Soluções**:
- Verificar firewall no servidor Linux
- Confirmar API Main está rodando
- Validar token de autenticação
- Checar logs do servidor

---

### Problema: Queries SQL retornam vazio

**Diagnóstico**:
```powershell
# Verificar se dados foram exportados
python -c "import sqlite3; conn=sqlite3.connect('infra/api/data/ea.db'); print('Ticks locais:', conn.execute('SELECT COUNT(*) FROM ticks').fetchone()[0]); conn.close()"

# Verificar dados no servidor
python query-db.py 1
```

**Soluções**:
- Executar exporter
- Verificar EA está coletando
- Checar se PostgreSQL está online

---

## 📚 Referências Rápidas

### Comandos Essenciais:

```powershell
# Exportar dados
cd infra/api/tools; .\run-exporter.ps1

# Ver dados no servidor
python query-db.py 1

# Verificar saúde
.\run-verify-sql.ps1

# Iniciar API Lite
cd infra/api; python -m uvicorn main:app --port 18000
```

### Conexões:

```
API Lite:    http://localhost:18000
API Main:    http://192.168.15.20:18001
PostgreSQL:  postgresql://trader:trader123@192.168.15.20:5432/mt5_trading
```

### Arquivos Importantes:

```
EA/DataCollectorPRO.mq5              - Expert Advisor
infra/api/data/ea.db                 - SQLite local
infra/api/tools/export_to_main.py    - Exporter
infra/api/tools/query-db.py          - Query tool
infra/api/tools/queries/             - SQL queries prontas
docs/DATA-FLOW.md                    - Fluxo de dados detalhado
```

---

## 📞 Suporte

### Documentos Relacionados:

- [DATA-FLOW.md](./DATA-FLOW.md) - Fluxo de dados detalhado
- [queries/README-COMO-USAR.md](../infra/api/tools/queries/README-COMO-USAR.md) - Guia de queries SQL
- [API_FLOW_SIMULATION.md](../API_FLOW_SIMULATION.md) - Simulação do fluxo de API

### Verificações Rápidas:

```powershell
# Sistema está funcionando?
.\infra\api\tools\run-verify-sql.ps1

# Quantos dados coletados localmente?
python -c "import sqlite3; c=sqlite3.connect('infra/api/data/ea.db'); print(c.execute('SELECT COUNT(*) FROM ticks').fetchone()[0]); c.close()"

# Quantos dados no servidor?
python query-db.py 5
```

---

**Última atualização**: 2025-10-20
**Versão**: 1.0
**Status**: ✅ Produção
