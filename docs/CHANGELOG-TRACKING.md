# 🎉 Sistema de Tracking e User-Agent Detalhado - Implementado!

## ✅ O que foi feito

### 1. **User-Agent Automático no EA (DataCollectorPRO.mq5)**

#### Novo parâmetro de configuração:
```mql5
input bool API_AutoGenerate_UserAgent = true;  // ✅ Gera User-Agent detalhado automaticamente
```

#### Nova função implementada:
```mql5
string GenerateDetailedUserAgent()
{
   long account = AccountInfoInteger(ACCOUNT_LOGIN);
   string server = AccountInfoString(ACCOUNT_SERVER);
   int terminal_build = (int)TerminalInfoInteger(TERMINAL_BUILD);
   int symbol_count = ArraySize(G_SYMBOLS);
   
   return StringFormat("PDC/%s (Account:%I64d; Server:%s; Build:%d; Symbols:%d)", 
                      PDC_VER, account, server, terminal_build, symbol_count);
}
```

#### Exemplo de User-Agent gerado:
```
PDC/1.65 (Account:67890; Server:MetaQuotes-Demo; Build:3815; Symbols:12)
```

---

### 2. **Captura Automática no Servidor (API)**

A API já estava capturando (desde commit anterior):
- ✅ `source_ip` - IP de origem da requisição
- ✅ `user_agent` - User-Agent do cabeçalho HTTP
- ✅ `was_duplicate` - Flag indicando se o dado já existia

**Tabela `ingest_log`:**
```sql
CREATE TABLE ingest_log (
    id BIGSERIAL PRIMARY KEY,
    received_at TIMESTAMPTZ DEFAULT NOW(),
    symbol TEXT NOT NULL,
    ts_ms BIGINT NOT NULL,
    open DOUBLE PRECISION,
    high DOUBLE PRECISION,
    low DOUBLE PRECISION,
    close DOUBLE PRECISION,
    volume BIGINT,
    was_duplicate BOOLEAN DEFAULT false,
    source_ip TEXT,           -- ✅ Capturado automaticamente
    user_agent TEXT           -- ✅ User-Agent detalhado do EA
);
```

---

### 3. **Documentação Completa**

#### 📄 **TRACKING-SYSTEM.md** (NOVO)
Guia completo com:
- ✅ Explicação do sistema de tracking
- ✅ **8 queries SQL de análise:**
  1. Listar instâncias ativas (24h)
  2. Dashboard de performance por conta
  3. Detectar contas com múltiplos IPs (auditoria)
  4. Ranking de atividade por servidor
  5. Análise de versões do EA em produção
  6. Histórico de conta específica
  7. Análise horária de atividade (market open/close)
  8. Top 10 IPs mais ativos

- ✅ **Casos de uso práticos:**
  - Monitoramento multi-instância
  - Debugging de problemas
  - Análise de performance comparativa
  - Auditoria de segurança

- ✅ **Orientações de segurança:**
  - LGPD/GDPR compliance
  - Política de retenção de dados (90 dias)
  - Restrição de acesso

- ✅ **Exemplos de dashboard Grafana**

#### 📄 **MT5-INTEGRATION.md** (ATUALIZADO)
- ✅ Nova seção "User-Agent e Tracking de Instâncias"
- ✅ Configuração do EA (modo automático vs manual)
- ✅ Exemplos de queries SQL
- ✅ Casos de uso

---

## 🚀 Como usar

### No EA (MetaTrader 5)

**1. Modo automático (RECOMENDADO):**
```mql5
input bool   API_AutoGenerate_UserAgent = true;  // ✅ Padrão
input string API_UserAgent = "PDC/1.65";         // Ignorado quando AutoGenerate=true
```
✅ User-Agent será: `PDC/1.65 (Account:12345; Server:Broker-Live; Build:3815; Symbols:28)`

**2. Modo manual (se precisar customizar):**
```mql5
input bool   API_AutoGenerate_UserAgent = false; // ❌ Desabilita geração automática
input string API_UserAgent = "MyEA/2.0 (Custom)"; // ✅ Valor customizado
```

---

### No Servidor (SQL)

#### Query 1: Listar todas as instâncias ativas (últimas 24h)
```sql
SELECT 
    regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
    regexp_match(user_agent, 'Server:([^;]+)')[1] AS server,
    source_ip,
    COUNT(*) as requests,
    MAX(received_at) as last_activity
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY account, server, source_ip
ORDER BY last_activity DESC;
```

#### Query 2: Detectar contas com múltiplos IPs (auditoria de segurança)
```sql
SELECT 
    regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
    ARRAY_AGG(DISTINCT source_ip) as ips,
    COUNT(DISTINCT source_ip) as ip_count
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '7 days'
GROUP BY account
HAVING COUNT(DISTINCT source_ip) > 1
ORDER BY ip_count DESC;
```

#### Query 3: Dashboard de performance por conta
```sql
SELECT 
    regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
    COUNT(*) as total_requests,
    COUNT(*) FILTER (WHERE NOT was_duplicate) as inserts,
    ROUND(COUNT(*) FILTER (WHERE was_duplicate) * 100.0 / COUNT(*), 2) as dup_rate_pct
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '7 days'
GROUP BY account
ORDER BY total_requests DESC;
```

---

## 🎯 Benefícios

### 1. **Monitoramento Multi-Instância**
- Rastreie múltiplas contas rodando o EA simultaneamente
- Visualize qual instância está ativa/inativa
- Detecte quando uma instância para de enviar dados

### 2. **Debugging Facilitado**
- Identifique qual conta/servidor gerou um erro específico
- Analise o histórico completo de uma instância problemática
- Compare comportamento entre diferentes contas

### 3. **Análise de Mercado**
- Taxa de duplicatas alta (>80%) → Mercado fechado
- Taxa baixa (<10%) → Mercado ativo
- Análise horária de atividade (ex: Forex fecha sexta 17h NY)

### 4. **Auditoria de Segurança**
- Detecte contas sendo usadas em múltiplos locais (IPs diferentes)
- Rastreie origem de todas as requisições
- Compliance com LGPD/GDPR

### 5. **Gestão de Versões**
- Identifique quais contas ainda usam versões antigas do EA
- Planeje rollout de updates
- Analise adoção de novas features

---

## 📊 Exemplo de Dados Capturados

### Registro no `ingest_log`:
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

### Resultado da Query de Instâncias Ativas:
| account | server | source_ip | requests | last_activity |
|---------|--------|-----------|----------|---------------|
| 67890 | MetaQuotes-Demo | 192.168.15.100 | 1440 | 2025-01-18 15:30:00 |
| 12345 | Broker-Live | 192.168.15.101 | 2880 | 2025-01-18 15:29:45 |

---

## 🔒 Segurança e Privacidade

### Dados capturados:
- ✅ **Número da conta MT5** (necessário para tracking)
- ✅ **Nome do servidor** (sem credenciais)
- ✅ **IP de origem** (rede interna)
- ❌ **SEM senhas ou API keys** no User-Agent

### Recomendações:
1. **Restrinja acesso ao DB** → Apenas administradores
2. **Use rede privada/VPN** → IPs não expostos publicamente
3. **Rotação de API keys** → A cada 90 dias
4. **Política de retenção:**
```sql
-- Deletar logs > 90 dias (compliance LGPD/GDPR)
DELETE FROM ingest_log
WHERE received_at < NOW() - INTERVAL '90 days';
```

---

## 📚 Arquivos Criados/Modificados

### Código do EA:
- ✅ `EA/DataCollectorPRO.mq5`
  - Adicionado parâmetro `API_AutoGenerate_UserAgent`
  - Nova função `GenerateDetailedUserAgent()`
  - Atualizada `BuildApiHeaders()` para usar User-Agent automático

### Documentação:
- ✅ `docs/api/TRACKING-SYSTEM.md` (NOVO - 400 linhas)
  - 8 queries SQL de análise
  - 4 casos de uso detalhados
  - Orientações LGPD/GDPR
  - Exemplos Grafana

- ✅ `docs/api/MT5-INTEGRATION.md` (ATUALIZADO)
  - Seção "User-Agent e Tracking" adicionada
  - Exemplos de configuração do EA
  - Queries SQL inline

---

## 🧪 Como Testar

### 1. Recompilar o EA
No MetaEditor (MT5):
```
1. Abra DataCollectorPRO.mq5
2. Pressione F7 (compilar)
3. Verifique se não há erros
```

### 2. Recarregar no gráfico
```
1. Remova o EA do gráfico atual
2. Arraste novamente do Navigator
3. Nas configurações, verifique:
   ☑ API_AutoGenerate_UserAgent = true
```

### 3. Verificar User-Agent sendo enviado
**No terminal do EA (aba Experts):**
```
[Debug] Headers: User-Agent: PDC/1.65 (Account:12345; Server:Broker-Live; Build:3815; Symbols:28)
```

### 4. Consultar no banco de dados
```sql
-- Ver últimos 10 registros com User-Agent
SELECT received_at, symbol, source_ip, user_agent
FROM ingest_log
ORDER BY received_at DESC
LIMIT 10;
```

---

## ✅ Checklist de Implementação

- [x] Adicionar parâmetro `API_AutoGenerate_UserAgent` no EA
- [x] Implementar função `GenerateDetailedUserAgent()`
- [x] Atualizar `BuildApiHeaders()` para usar User-Agent automático
- [x] Criar documentação `TRACKING-SYSTEM.md` com queries SQL
- [x] Atualizar `MT5-INTEGRATION.md` com seção de tracking
- [x] Fazer commit com mensagem descritiva
- [ ] **Recompilar EA no MT5** ← PRÓXIMO PASSO
- [ ] **Testar User-Agent no servidor** ← VALIDAÇÃO
- [ ] **Criar dashboards Grafana** (opcional)

---

## 📖 Referências

- [TRACKING-SYSTEM.md](../docs/api/TRACKING-SYSTEM.md) - Documentação completa do sistema
- [MT5-INTEGRATION.md](../docs/api/MT5-INTEGRATION.md) - Guia de integração do EA
- [MARKET-ACTIVITY-ANALYSIS.md](../docs/infra/MARKET-ACTIVITY-ANALYSIS.md) - Análise de atividade do mercado

---

**Commit:** `1fad820`  
**Data:** 18/01/2025  
**Status:** ✅ Implementado e documentado

---

## 🎓 Próximos Passos Sugeridos

1. **Recompilar e testar** o EA com User-Agent automático
2. **Executar queries SQL** para validar captura de dados
3. **Criar alertas** (Slack/Discord) quando instância ficar offline
4. **Dashboard Grafana** para monitoramento em tempo real
5. **Machine Learning** para detectar padrões anômalos de uso

---

# 2025-10-18 - Infra Hardening, Backup/Replication, Compose Improvements

## Infra Stack
- docker-compose.yml: containers run as non-root, read-only, all capabilities dropped, resource limits set, API with no-new-privileges
- .env: template now recommends strong secrets, comments for production use
- SECURITY-HARDENING.md: guia de melhores práticas para segurança do stack
- BACKUP-REPLICATION.md: guia para backup automatizado e replicação física (Postgres/Timescale)
- Compose e scripts preparados para rodar em VM Debian/Linux com firewall restrito

## Scripts
- manage-observability.ps1: já suporta stack "infra" e auto-detecta compose/docker
- Pronto para integração com VM MT5 e DB reserva

## Recomendações
- Rodar containers Linux em VM Debian para máxima segurança e compatibilidade
- Manter MT5/EA em VM Windows Server 2025
- Backup automatizado e replicação física para alta disponibilidade

---
