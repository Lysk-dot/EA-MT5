# 📡 MT5 EA Integration Guide - Data Ingestion API

## 🎯 Objetivo
Este guia documenta como configurar o Expert Advisor (EA) no MetaTrader 5 (Windows) para enviar dados de mercado para o servidor de trading API (Linux).

---

## 🌐 Informações do Servidor

### Endereços de Conexão
```
IP do Servidor:    192.168.15.20
Porta da API:      18001
URL Base:          http://192.168.15.20:18001
```

### Variáveis de Ambiente (.env)
```properties
# Configuração de Autenticação
API_KEY=mt5_trading_secure_key_2025_prod

# Configuração da API
API_PORT=18001
API_PORT_INTERNAL=8001

# Banco de Dados
DB_HOST=db
DB_PORT=5432
POSTGRES_USER=trader
POSTGRES_PASSWORD=trader123
POSTGRES_DB=mt5_trading
```

---

## 📍 Endpoints Disponíveis

### 1. Health Check
**Verifica se a API está online**
```
GET http://192.168.15.20:18001/health
```

**Resposta de Sucesso:**
```json
{"status":"ok"}
```

**Exemplo cURL (Windows PowerShell):**
```powershell
curl http://192.168.15.20:18001/health
```

---

### 2. Ingest - Envio de Candle Único
**Endpoint principal para o EA enviar dados**
```
POST http://192.168.15.20:18001/ingest
Content-Type: application/json
X-API-Key: mt5_trading_secure_key_2025_prod
```

**Body JSON:**
```json
{
  "ts": "2025-10-18T14:00:00Z",
  "symbol": "EURUSD",
  "timeframe": "M1",
  "open": 1.0950,
  "high": 1.0955,
  "low": 1.0948,
  "close": 1.0952,
  "volume": 1250
}
```

**Resposta de Sucesso:**
```json
{"ok":true,"inserted":1}
```

**Timeframes Válidos:**
- `M1`, `M5`, `M15`, `M30`, `H1`, `H4`, `D1`

**Exemplo cURL (Windows PowerShell):**
```powershell
curl -X POST "http://192.168.15.20:18001/ingest" `
  -H "Content-Type: application/json" `
  -H "X-API-Key: mt5_trading_secure_key_2025_prod" `
  -d '{\"ts\":\"2025-10-18T14:00:00Z\",\"symbol\":\"EURUSD\",\"timeframe\":\"M1\",\"open\":1.0950,\"high\":1.0955,\"low\":1.0948,\"close\":1.0952,\"volume\":1250}'
```

---

### 3. Ingest - Batch (Múltiplos Candles)
**Para enviar vários candles de uma vez**
```
POST http://192.168.15.20:18001/ingest
Content-Type: application/json
X-API-Key: mt5_trading_secure_key_2025_prod
```

**Body JSON:**
```json
{
  "items": [
    {
      "ts": "2025-10-18T14:00:00Z",
      "symbol": "EURUSD",
      "timeframe": "M1",
      "open": 1.0950,
      "high": 1.0955,
      "low": 1.0948,
      "close": 1.0952,
      "volume": 1250
    },
    {
      "ts": "2025-10-18T14:01:00Z",
      "symbol": "EURUSD",
      "timeframe": "M1",
      "open": 1.0952,
      "high": 1.0958,
      "low": 1.0951,
      "close": 1.0956,
      "volume": 1300
    }
  ]
}
```

**Resposta de Sucesso:**
```json
{"ok":true,"inserted":2}
```

---

### 4. Metrics - Estatísticas
**Verifica estatísticas dos dados recebidos**
```
GET http://192.168.15.20:18001/metrics
```

**Resposta (exemplo):**
```json
{
  "ok": true,
  "data": [
    {
      "symbol": "EURUSD",
      "timeframe": "M1",
      "last_ts": "2025-10-18T14:02:00+00:00",
      "rows_10m": 4
    }
  ]
}
```

---

## 🔐 Autenticação

### Header Obrigatório
Todas as requisições para `/ingest` **DEVEM** incluir o header de autenticação:

```
X-API-Key: mt5_trading_secure_key_2025_prod
```

### Códigos de Erro
- **401 Unauthorized**: API Key ausente ou incorreto
  ```json
  {"detail":"unauthorized"}
  ```
- **422 Validation Error**: Dados inválidos (ex: timeframe errado)
- **429 Too Many Requests**: Rate limit excedido

---

## 💻 Implementação no EA (MQL5)

### Configuração Básica
```mql5
//+------------------------------------------------------------------+
//| MT5 Trading Data Collector EA                                     |
//+------------------------------------------------------------------+

// Configurações do servidor
input string API_URL = "http://192.168.15.20:18001/ingest";
input string API_KEY = "mt5_trading_secure_key_2025_prod";
input string TIMEFRAME_STR = "M1";  // M1, M5, M15, M30, H1, H4, D1

//+------------------------------------------------------------------+
//| Função para enviar candle ao servidor                             |
//+------------------------------------------------------------------+
bool SendCandleToAPI(datetime time, string symbol, double open, double high, 
                     double low, double close, long volume)
{
   // Preparar headers HTTP
   char post[];
   char result[];
   string headers;
   string json;
   
   // Formatar timestamp ISO 8601
   string timestamp = TimeToString(time, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   StringReplace(timestamp, ".", "-");
   StringReplace(timestamp, " ", "T");
   timestamp += "Z";
   
   // Construir JSON
   json = StringFormat(
      "{\"ts\":\"%s\",\"symbol\":\"%s\",\"timeframe\":\"%s\",\"open\":%.5f,\"high\":%.5f,\"low\":%.5f,\"close\":%.5f,\"volume\":%d}",
      timestamp,
      symbol,
      TIMEFRAME_STR,
      open,
      high,
      low,
      close,
      (int)volume
   );
   
   // Preparar headers (inclui User-Agent para tracking)
   headers = "Content-Type: application/json\r\n";
   headers += "X-API-Key: " + API_KEY + "\r\n";
   headers += "User-Agent: MT5-EA/1.0 (Account:" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ")\r\n";
   
   // Converter JSON para array de bytes
   StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(post, ArraySize(post) - 1); // Remover null terminator
   
   // Enviar requisição HTTP POST
   ResetLastError();
   int timeout = 5000; // 5 segundos
   int res = WebRequest(
      "POST",
      API_URL,
      headers,
      timeout,
      post,
      result,
      headers
   );
   
   // Verificar resultado
   if(res == 200)
   {
      string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("✅ Candle enviado com sucesso: ", symbol, " ", TimeToString(time));
      Print("   Resposta: ", response);
      return true;
   }
   else
   {
      Print("❌ Erro ao enviar candle: ", symbol, " ", TimeToString(time));
      Print("   HTTP Code: ", res);
      Print("   Error: ", GetLastError());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("MT5 Trading Data Collector - INICIADO");
   Print("Servidor: ", API_URL);
   Print("Símbolo: ", _Symbol);
   Print("Timeframe: ", TIMEFRAME_STR);
   Print("========================================");
   
   // Verificar se WebRequest está permitido para este host
   // Adicione 192.168.15.20 na lista de URLs permitidas do MT5:
   // Tools > Options > Expert Advisors > Allow WebRequest for listed URL
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Detectar novo candle
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime != lastBarTime && lastBarTime != 0)
   {
      // Novo candle detectado - enviar o candle anterior (fechado)
      MqlRates rates[];
      if(CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, rates) > 0)
      {
         SendCandleToAPI(
            rates[0].time,
            _Symbol,
            rates[0].open,
            rates[0].high,
            rates[0].low,
            rates[0].close,
            rates[0].tick_volume
         );
      }
   }
   
   lastBarTime = currentBarTime;
}
```

---

## ⚙️ Configuração do MetaTrader 5 (Windows)

### 1. Permitir WebRequest
1. Abra o MetaTrader 5
2. Vá em **Tools** > **Options**
3. Aba **Expert Advisors**
4. Marque: ☑ **Allow WebRequest for listed URL:**
5. Adicione: `http://192.168.15.20:18001`
6. Clique em **OK**

### 2. Compilar e Anexar o EA
1. Abra o **MetaEditor** (F4 no MT5)
2. Crie um novo Expert Advisor ou cole o código acima
3. Compile (F7)
4. Arraste o EA para o gráfico do símbolo desejado
5. Confirme que **Allow WebRequest** está marcado

### 3. Verificar Logs
1. Abra a aba **Experts** no MT5
2. Verifique mensagens como:
   - ✅ "Candle enviado com sucesso"
   - ❌ Erros de conexão ou autenticação

---

## 🧪 Testes de Validação

### Teste 1: Health Check (Windows PowerShell)
```powershell
curl http://192.168.15.20:18001/health
```
**Esperado:** `{"status":"ok"}`

### Teste 2: Enviar Candle Manual
```powershell
curl -X POST "http://192.168.15.20:18001/ingest" `
  -H "Content-Type: application/json" `
  -H "X-API-Key: mt5_trading_secure_key_2025_prod" `
  -d '{\"ts\":\"2025-10-18T14:00:00Z\",\"symbol\":\"EURUSD\",\"timeframe\":\"M1\",\"open\":1.0950,\"high\":1.0955,\"low\":1.0948,\"close\":1.0952,\"volume\":1250}'
```
**Esperado:** `{"ok":true,"inserted":1}`

### Teste 3: Verificar Métricas
```powershell
curl http://192.168.15.20:18001/metrics
```
**Esperado:** Lista de símbolos com estatísticas

### Teste 4: Enviar sem API Key (deve falhar)
```powershell
curl -X POST "http://192.168.15.20:18001/ingest" `
  -H "Content-Type: application/json" `
  -d '{\"ts\":\"2025-10-18T14:00:00Z\",\"symbol\":\"EURUSD\",\"timeframe\":\"M1\",\"open\":1.0950,\"high\":1.0955,\"low\":1.0948,\"close\":1.0952,\"volume\":1250}'
```
**Esperado:** `{"detail":"unauthorized"}`


## 🔖 User-Agent e Tracking de Instâncias

### Identificação Automática de EAs
O DataCollectorPRO (v1.65+) envia automaticamente um **User-Agent** detalhado para facilitar:
- **Rastreamento de múltiplas instâncias** rodando em diferentes contas/servidores
- **Análise de atividade de mercado** (horários de maior/menor atividade)
- **Debugging e suporte** (identificar qual terminal/conta gerou determinado dado)

### Formato do User-Agent
```
PDC/1.65 (Account:12345; Server:Broker-Live; Build:3815; Symbols:28)
```

**Componentes:**
- `PDC/1.65`: Nome e versão do EA
- `Account:12345`: Número da conta MT5
- `Server:Broker-Live`: Nome do servidor da corretora
- `Build:3815`: Build do terminal MT5
- `Symbols:28`: Quantidade de símbolos sendo coletados

### Configuração no EA
O EA possui dois modos de operação:

**1. Modo Automático (Recomendado):**
```mql5
input bool API_AutoGenerate_UserAgent = true;  // ✅ Gera User-Agent detalhado automaticamente
input string API_UserAgent = "PDC/1.65";       // Ignorado quando AutoGenerate=true
```

**2. Modo Manual (Custom):**
```mql5
input bool API_AutoGenerate_UserAgent = false; // ❌ Usa User-Agent manual
input string API_UserAgent = "MyCustomEA/2.0"; // ✅ Valor customizado
```

### Captura de Dados no Servidor
A API registra automaticamente para cada requisição:

**1. Tabela `ingest_log` (tracking completo):**
```sql
SELECT received_at, symbol, source_ip, user_agent, was_duplicate
FROM ingest_log
WHERE user_agent LIKE '%Account:12345%'
ORDER BY received_at DESC
LIMIT 10;
```

**2. Análise de múltiplas instâncias:**
```sql
-- Contas ativas nas últimas 24h
SELECT DISTINCT 
  regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
  regexp_match(user_agent, 'Server:([^;]+)')[1] AS server,
  COUNT(*) as requests
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY account, server
ORDER BY requests DESC;
```

**3. Detectar atividade por IP:**
```sql
-- Rastrear origem das requisições
SELECT source_ip, user_agent, COUNT(*) as total
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '1 hour'
GROUP BY source_ip, user_agent
ORDER BY total DESC;
```

### Exemplo de Log Completo
```json
{
  "id": 12345,
  "received_at": "2025-01-18T15:30:00.123Z",
  "symbol": "EURUSD",
  "ts_ms": 1737216600000,
  "source_ip": "192.168.15.100",
  "user_agent": "PDC/1.65 (Account:67890; Server:MetaQuotes-Demo; Build:3815; Symbols:12)",
  "was_duplicate": false
}
```

### Casos de Uso

**1. Monitorar múltiplas contas:**
```sql
-- Dashboard de contas ativas
SELECT 
  regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
  COUNT(*) as candles_sent,
  MAX(received_at) as last_activity
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '1 day'
GROUP BY account
ORDER BY last_activity DESC;
```

**2. Detectar problemas em conta específica:**
```sql
-- Taxa de duplicatas por conta (indica mercado fechado)
SELECT 
  regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
  COUNT(*) FILTER (WHERE was_duplicate) * 100.0 / COUNT(*) as duplicate_rate
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '1 hour'
GROUP BY account
HAVING COUNT(*) > 10;
```

**3. Auditoria de segurança:**
```sql
-- IPs diferentes usando mesma conta (possível problema)
SELECT 
  regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
  ARRAY_AGG(DISTINCT source_ip) as ips
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '7 days'
GROUP BY account
HAVING COUNT(DISTINCT source_ip) > 1;
```

---

## 🔍 Troubleshooting

### Problema: "URL not allowed"
**Solução:** Adicione `http://192.168.15.20:18001` nas URLs permitidas do MT5 (Tools > Options > Expert Advisors)

### Problema: "Error 4060" (Function not allowed)
**Solução:** Marque "Allow WebRequest" nas configurações do EA ao anexá-lo ao gráfico

### Problema: HTTP 401 Unauthorized
**Solução:** Verifique se o API_KEY no EA está correto: `mt5_trading_secure_key_2025_prod`

### Problema: HTTP 422 Validation Error
**Solução:** Verifique se o timeframe está correto (M1, M5, M15, M30, H1, H4, D1)

### Problema: Timeout / Sem resposta
**Solução:** 
- Verifique conectividade de rede: `ping 192.168.15.20`
- Verifique se o firewall do servidor permite conexões na porta 18001
- Confirme que os containers Docker estão rodando

---

## 📊 Monitoramento no Servidor (Linux)

### Verificar Status dos Containers
```bash
docker compose ps
```

### Verificar Logs da API
```bash
docker compose logs -f api
```

### Verificar Últimos Dados Recebidos
```bash
docker compose exec db psql -U trader -d mt5_trading -c "SELECT symbol, timeframe, MAX(ts) AS ultimo_envio FROM market_data GROUP BY symbol, timeframe ORDER BY ultimo_envio DESC LIMIT 10;"
```

### Verificar Métricas via cURL (do servidor)
```bash
curl -sS http://localhost:18001/metrics | jq '.data[] | select(.symbol=="EURUSD")'
```

---

## 📝 Notas Importantes

1. **Formato de Data**: Use ISO 8601 UTC (`2025-10-18T14:00:00Z`)
2. **Timeframes Válidos**: Apenas M1, M5, M15, M30, H1, H4, D1
3. **Rate Limit**: A API possui proteção contra excesso de requisições
4. **Persistência**: Dados são salvos na tabela `market_data` com constraint de unicidade `(symbol, timeframe, ts)`
5. **Duplicatas**: Candles duplicados são ignorados automaticamente (`ON CONFLICT DO NOTHING`)

---

## 🎯 Resumo Rápido para Copiar no Copilot

```
CONFIGURAÇÃO DO EA MT5 - DATA INGESTION API

Servidor: 192.168.15.20:18001
API Key: mt5_trading_secure_key_2025_prod
Endpoint: POST http://192.168.15.20:18001/ingest
Header: X-API-Key: mt5_trading_secure_key_2025_prod
Content-Type: application/json

JSON Format:
{
  "ts": "2025-10-18T14:00:00Z",
  "symbol": "EURUSD",
  "timeframe": "M1",
  "open": 1.0950,
  "high": 1.0955,
  "low": 1.0948,
  "close": 1.0952,
  "volume": 1250
}

Timeframes válidos: M1, M5, M15, M30, H1, H4, D1

Configuração MT5:
- Tools > Options > Expert Advisors
- Allow WebRequest for: http://192.168.15.20:18001

Teste Health: curl http://192.168.15.20:18001/health
Resposta OK: {"status":"ok"}
```

---

**Versão:** 1.0  
**Data:** 2025-10-18  
**Status:** ✅ Testado e Validado
