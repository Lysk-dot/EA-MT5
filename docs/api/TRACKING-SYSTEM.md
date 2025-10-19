# 🔍 Sistema de Tracking e Identificação de Instâncias

## 📋 Índice
- [Visão Geral](#visão-geral)
- [User-Agent Detalhado](#user-agent-detalhado)
- [Captura de Metadados](#captura-de-metadados)
- [Queries SQL de Análise](#queries-sql-de-análise)
- [Casos de Uso](#casos-de-uso)
- [Segurança e Privacidade](#segurança-e-privacidade)

---

## 🎯 Visão Geral

O sistema de tracking permite identificar e rastrear **múltiplas instâncias do EA** rodando simultaneamente em diferentes:
- Contas MT5
- Servidores de corretoras
- Terminais/máquinas
- Conjuntos de símbolos

### Benefícios
✅ **Monitoramento centralizado** de todas as instâncias  
✅ **Detecção de anomalias** (conta com múltiplos IPs, etc)  
✅ **Análise de performance** por conta/servidor  
✅ **Debugging facilitado** (qual instância gerou erro)  
✅ **Auditoria completa** de todas as requisições  

---

## 🏷️ User-Agent Detalhado

### Geração Automática
O EA gera automaticamente um User-Agent informativo:

```
PDC/1.65 (Account:67890; Server:MetaQuotes-Demo; Build:3815; Symbols:12)
```

### Componentes
| Campo | Descrição | Exemplo |
|-------|-----------|---------|
| `PDC/1.65` | Nome e versão do EA | PDC/1.65 |
| `Account` | Número da conta MT5 | 67890 |
| `Server` | Nome do servidor da corretora | MetaQuotes-Demo |
| `Build` | Build do terminal MT5 | 3815 |
| `Symbols` | Quantidade de símbolos coletados | 12 |

### Implementação (MQL5)
```mql5
string GenerateDetailedUserAgent()
{
   long account = AccountInfoInteger(ACCOUNT_LOGIN);
   string server = AccountInfoString(ACCOUNT_SERVER);
   int terminal_build = (int)TerminalInfoInteger(TERMINAL_BUILD);
   int symbol_count = ArraySize(G_SYMBOLS);
   
   string ua = StringFormat("PDC/%s (Account:%I64d; Server:%s; Build:%d; Symbols:%d)", 
                           PDC_VER, account, server, terminal_build, symbol_count);
   return ua;
}
```

### Configuração no EA
```mql5
// Modo Automático (RECOMENDADO)
input bool   API_AutoGenerate_UserAgent = true;  // ✅ Gera automático
input string API_UserAgent = "PDC/1.65";         // Ignorado

// Modo Manual (se precisar customizar)
input bool   API_AutoGenerate_UserAgent = false; // ❌ Usa manual
input string API_UserAgent = "MyEA/2.0 (Custom)"; // ✅ Valor custom
```

---

## 📊 Captura de Metadados

### Tabela `ingest_log`
Toda requisição é registrada com metadados completos:

```sql
CREATE TABLE ingest_log (
    id BIGSERIAL PRIMARY KEY,
    received_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Dados do candle
    symbol TEXT NOT NULL,
    ts_ms BIGINT NOT NULL,
    open DOUBLE PRECISION,
    high DOUBLE PRECISION,
    low DOUBLE PRECISION,
    close DOUBLE PRECISION,
    volume BIGINT,
    
    -- Metadados de tracking
    was_duplicate BOOLEAN DEFAULT false,
    source_ip TEXT,           -- ✅ IP de origem (192.168.15.100)
    user_agent TEXT           -- ✅ User-Agent completo
);

-- Indexar para queries rápidas
CREATE INDEX idx_ingest_log_received_at ON ingest_log(received_at DESC);
CREATE INDEX idx_ingest_log_user_agent ON ingest_log USING gin(user_agent gin_trgm_ops);
CREATE INDEX idx_ingest_log_source_ip ON ingest_log(source_ip);
```

### Exemplo de Registro
```json
{
  "id": 123456,
  "received_at": "2025-01-18T15:30:00.123Z",
  "symbol": "EURUSD",
  "ts_ms": 1737216600000,
  "open": 1.0950,
  "high": 1.0955,
  "low": 1.0948,
  "close": 1.0952,
  "volume": 1250,
  "was_duplicate": false,
  "source_ip": "192.168.15.100",
  "user_agent": "PDC/1.65 (Account:67890; Server:MetaQuotes-Demo; Build:3815; Symbols:12)"
}
```

---

## 🔎 Queries SQL de Análise

### 1. Listar Todas as Instâncias Ativas (24h)
```sql
SELECT 
    regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
    regexp_match(user_agent, 'Server:([^;]+)')[1] AS server,
    regexp_match(user_agent, 'Build:(\d+)')[1] AS build,
    regexp_match(user_agent, 'Symbols:(\d+)')[1] AS symbols,
    source_ip,
    COUNT(*) as requests,
    COUNT(*) FILTER (WHERE was_duplicate) as duplicates,
    MAX(received_at) as last_activity
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY account, server, build, symbols, source_ip
ORDER BY last_activity DESC;
```

**Exemplo de Resultado:**
| account | server | build | symbols | source_ip | requests | duplicates | last_activity |
|---------|--------|-------|---------|-----------|----------|------------|---------------|
| 67890 | MetaQuotes-Demo | 3815 | 12 | 192.168.15.100 | 1440 | 980 | 2025-01-18 15:30:00 |
| 12345 | Broker-Live | 3810 | 28 | 192.168.15.101 | 2880 | 1200 | 2025-01-18 15:29:45 |

---

### 2. Dashboard de Performance por Conta
```sql
SELECT 
    regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
    COUNT(*) as total_requests,
    COUNT(*) FILTER (WHERE was_duplicate) as duplicates,
    COUNT(*) FILTER (WHERE NOT was_duplicate) as inserts,
    ROUND(COUNT(*) FILTER (WHERE was_duplicate) * 100.0 / COUNT(*), 2) as duplicate_rate_pct,
    COUNT(DISTINCT symbol) as symbols_count,
    MIN(received_at) as first_seen,
    MAX(received_at) as last_seen
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '7 days'
GROUP BY account
ORDER BY total_requests DESC;
```

---

### 3. Detectar Contas com Múltiplos IPs (Auditoria de Segurança)
```sql
-- Detecta se uma conta está sendo usada em múltiplos locais
SELECT 
    regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
    ARRAY_AGG(DISTINCT source_ip ORDER BY source_ip) as ips,
    COUNT(DISTINCT source_ip) as ip_count,
    MAX(received_at) as last_activity
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '7 days'
GROUP BY account
HAVING COUNT(DISTINCT source_ip) > 1
ORDER BY ip_count DESC;
```

**⚠️ Alerta:** Se uma conta aparecer em múltiplos IPs, pode indicar:
- Backup/failover legítimo
- VPN/proxy em uso
- **Possível uso não autorizado da conta**

---

### 4. Ranking de Atividade por Servidor de Corretora
```sql
SELECT 
    regexp_match(user_agent, 'Server:([^;]+)')[1] AS broker_server,
    COUNT(DISTINCT regexp_match(user_agent, 'Account:(\d+)')[1]) as accounts,
    COUNT(*) as total_requests,
    MAX(received_at) as last_activity
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '30 days'
GROUP BY broker_server
ORDER BY total_requests DESC;
```

---

### 5. Análise de Versões do EA em Produção
```sql
SELECT 
    regexp_match(user_agent, 'PDC/([0-9.]+)')[1] AS ea_version,
    COUNT(DISTINCT regexp_match(user_agent, 'Account:(\d+)')[1]) as accounts,
    COUNT(*) as requests,
    MAX(received_at) as last_seen
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '7 days'
GROUP BY ea_version
ORDER BY last_seen DESC;
```

**Uso:** Identificar contas rodando versões antigas do EA que precisam de update.

---

### 6. Histórico de uma Conta Específica
```sql
-- Histórico completo de uma conta (exemplo: 67890)
SELECT 
    received_at,
    symbol,
    source_ip,
    was_duplicate,
    user_agent
FROM ingest_log
WHERE user_agent LIKE '%Account:67890%'
ORDER BY received_at DESC
LIMIT 100;
```

---

### 7. Análise Horária de Atividade (Market Open/Close)
```sql
-- Distribuição de requisições por hora do dia
SELECT 
    EXTRACT(HOUR FROM received_at) as hour_utc,
    COUNT(*) as requests,
    COUNT(*) FILTER (WHERE was_duplicate) as duplicates,
    ROUND(COUNT(*) FILTER (WHERE was_duplicate) * 100.0 / COUNT(*), 2) as dup_rate_pct
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '7 days'
GROUP BY hour_utc
ORDER BY hour_utc;
```

**Padrão esperado:**
- **Alta taxa de duplicatas (>80%)** → Mercado fechado
- **Baixa taxa (<10%)** → Mercado ativo

---

### 8. Top 10 IPs Mais Ativos
```sql
SELECT 
    source_ip,
    COUNT(DISTINCT regexp_match(user_agent, 'Account:(\d+)')[1]) as accounts,
    COUNT(*) as requests,
    MAX(received_at) as last_activity
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY source_ip
ORDER BY requests DESC
LIMIT 10;
```

---

## 💼 Casos de Uso

### 1. Monitoramento Multi-Instância
**Cenário:** Você roda o EA em 5 contas diferentes.

**Query:**
```sql
SELECT 
    regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
    MAX(received_at) as last_ping,
    NOW() - MAX(received_at) as offline_duration
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '1 hour'
GROUP BY account
ORDER BY last_ping DESC;
```

**Alerta:** Se `offline_duration > 5 minutes`, a instância pode estar offline.

---

### 2. Debugging de Problema em Conta Específica
**Cenário:** Conta 12345 reporta erro.

```sql
-- Últimas 50 requisições da conta
SELECT received_at, symbol, was_duplicate, source_ip
FROM ingest_log
WHERE user_agent LIKE '%Account:12345%'
ORDER BY received_at DESC
LIMIT 50;
```

---

### 3. Análise de Performance Comparativa
**Cenário:** Comparar taxa de duplicatas entre contas (indicador de qualidade dos dados).

```sql
SELECT 
    regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
    ROUND(COUNT(*) FILTER (WHERE was_duplicate) * 100.0 / COUNT(*), 2) as dup_rate_pct
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY account
HAVING COUNT(*) > 100
ORDER BY dup_rate_pct;
```

---

### 4. Auditoria de Segurança
**Cenário:** Detectar atividade suspeita.

```sql
-- Contas com mudança de IP recente
WITH recent_ips AS (
    SELECT DISTINCT
        regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
        source_ip,
        DATE(received_at) as day
    FROM ingest_log
    WHERE received_at > NOW() - INTERVAL '7 days'
)
SELECT account, COUNT(DISTINCT source_ip) as ip_changes
FROM recent_ips
GROUP BY account
HAVING COUNT(DISTINCT source_ip) > 2
ORDER BY ip_changes DESC;
```

---

## 🔒 Segurança e Privacidade

### Dados Sensíveis Capturados
- ✅ **Número da conta MT5** (necessário para tracking)
- ✅ **Nome do servidor** (sem credenciais)
- ✅ **IP de origem** (infraestrutura interna)
- ❌ **Sem senhas ou API keys** no User-Agent

### Recomendações
1. **Restrinja acesso ao banco de dados** → Apenas administradores
2. **Use VPN/rede privada** → IPs não ficam expostos publicamente
3. **Rotacione API keys** → Periodicamente (a cada 90 dias)
4. **Monitore logs** → Alertas para IPs desconhecidos

### LGPD/GDPR
Se seus clientes usam o EA:
- Informe na política de privacidade que **número da conta e IP** são coletados
- Permita que usuários **desabilitem tracking** (modo manual sem conta no User-Agent)
- Implemente **retenção de dados** (deletar logs após 90 dias)

```sql
-- Política de retenção: deletar logs > 90 dias
DELETE FROM ingest_log
WHERE received_at < NOW() - INTERVAL '90 days';
```

---

## 📈 Dashboard de Exemplo (Grafana)

### Painel 1: Instâncias Ativas
```sql
-- Prometheus metric ou Grafana query
SELECT 
    COUNT(DISTINCT regexp_match(user_agent, 'Account:(\d+)')[1]) as active_accounts
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '5 minutes';
```

### Painel 2: Mapa de IPs
```sql
-- Top 5 IPs nas últimas 24h
SELECT source_ip, COUNT(*) as requests
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY source_ip
ORDER BY requests DESC
LIMIT 5;
```

---

## 🚀 Próximos Passos

1. **Integre com Grafana** → Painéis de monitoramento em tempo real
2. **Adicione alertas** → Slack/Discord quando conta ficar offline
3. **Exporte para BI** → Power BI / Tableau para análises avançadas
4. **Machine Learning** → Detectar padrões anômalos de uso

---

## 📚 Referências
- [MT5 Integration Guide](./MT5-INTEGRATION.md)
- [Market Activity Analysis](../infra/MARKET-ACTIVITY-ANALYSIS.md)
- [API Documentation](./API.md)
