> (c) 2025 Felipe Petracco Carmo <kuramopr@gmail.com> — Documento proprietário, distribuição restrita.

# Simulação do Fluxo de Envio de Dados - DataCollectorPRO.mq5 → API Linux

## 📋 Visão Geral
Este documento simula o fluxo completo de como o EA `DataCollectorPRO.mq5` coleta e envia dados de símbolos do MT5 para a API de ingest do servidor Linux.

---

## 🔄 Fluxo Completo (Passo a Passo)

### **ETAPA 1: Timer Dispara (a cada 60 segundos)**
```
OnTimer() é chamado automaticamente
↓
Carrega lista de símbolos Forex do Market Watch (ex: 28 pares)
↓
Para cada símbolo, executa BuildAPIMinItemForSymbol()
```

---

### **ETAPA 2: Coleta de Dados por Símbolo**

**Exemplo com EURUSD:**

```cpp
// 1. Busca último tick
MqlTick tick;
SymbolInfoTick("EURUSD", tick);
// tick.bid = 1.08543
// tick.ask = 1.08548
// tick.time = 2025-10-18 14:32:15

// 2. Busca dados da barra (timeframe configurado, ex: M1)
MqlRates r[1];
CopyRates("EURUSD", PERIOD_M1, 0, 1, r);
// r[0].time = 2025-10-18 14:32:00
// r[0].open = 1.08540
// r[0].high = 1.08550
// r[0].low = 1.08538
// r[0].close = 1.08545
// r[0].tick_volume = 142

// 3. Calcula timestamp (depende da configuração)
// Se Timestamp_Source = TS_COLLECTION_MINUTE:
datetime use_ts = FloorToMinute(TimeCurrent());
// use_ts = 2025-10-18 14:32:00

// 4. Monta o JSON do item
string item = {
  "ts": "2025-10-18T14:32:00Z",
  "symbol": "EURUSD",
  "timeframe": "M1",
  "open": 1.08540,
  "high": 1.08550,
  "low": 1.08538,
  "close": 1.08545,
  "volume": 142,
  "spread": 0.000050,
  "meta": {
    "ea": "PDC",
    "ver": "1.65",
    "src": "timer",
    "term": "MetaTrader 5",
    "collected_at": "2025-10-18T14:32:00Z",
    "bar_time": "2025-10-18T14:32:00Z",
    "last_tick": "2025-10-18T14:32:15Z"
  }
}

// 5. Gera assinatura para detecção de mudança
string sig = "2025-10-18T14:32:00Z|1.08540|1.08550|1.08538|1.08545|142|2025-10-18T14:32:15Z";
```

**Filtros aplicados:**
- ✅ Se `Send_Only_On_Change=true`: compara assinatura com último envio
- ✅ Se `Skip_Duplicate_TS=true`: verifica se timestamp já foi enviado
- ✅ Se filtros passarem: adiciona item ao array de envio

---

### **ETAPA 3: Montagem do Lote (Batch)**

Após coletar todos os símbolos, o EA monta um array de itens:

```json
[
  {"ts":"2025-10-18T14:32:00Z","symbol":"EURUSD","timeframe":"M1",...},
  {"ts":"2025-10-18T14:32:00Z","symbol":"GBPUSD","timeframe":"M1",...},
  {"ts":"2025-10-18T14:32:00Z","symbol":"USDJPY","timeframe":"M1",...},
  ... (até 28 símbolos)
]
```

**Divisão em chunks:**
- Se total de itens > `MaxItemsPerBatch` (padrão: 500), divide em múltiplos lotes
- Cada chunk é enviado separadamente

---

### **ETAPA 4: Construção dos Headers HTTP**

Função `BuildApiHeaders()` monta:

```http
Content-Type: application/json
Accept: application/json
Connection: keep-alive
User-Agent: PDC/1.65
X-API-Key: mt5_trading_secure_key_2025_prod
```

**Lógica de autenticação:**
- Se `API_Use_Bearer_Token=true`: usa `Authorization: Bearer <token>`
- Caso contrário: usa `X-API-Key: <chave>`
- Headers extras (API_Extra_Header1/2) também são incluídos se configurados

---

### **ETAPA 5: Envio via WebRequest (POST)**

```cpp
// URL configurada
string url = "http://SEU_SERVIDOR_LINUX:18001/ingest";

// Payload do lote (exemplo com 28 símbolos)
string body = {
  "items": [
    {"ts":"2025-10-18T14:32:00Z","symbol":"EURUSD",...},
    {"ts":"2025-10-18T14:32:00Z","symbol":"GBPUSD",...},
    ... (28 itens)
  ]
}

// Converte para UTF-8 bytes
uchar post[];
StringToCharArray(body, post, 0, StringLen(body), CP_UTF8);

// Faz a requisição HTTP POST
uchar response[];
string response_headers;
int sz = WebRequest(
  "POST",
  url,
  headers,
  6000,  // timeout 6s
  post,
  response,
  response_headers
);
```

---

### **ETAPA 6: Interpretação da Resposta**

**6.1 Parse do código HTTP**
```cpp
// Função ParseHttpCode() extrai o último HTTP/X.X NNN
// Exemplo de response_headers:
"HTTP/1.1 100 Continue\r\nHTTP/1.1 200 OK\r\nContent-Type: application/json\r\n..."

int code = ParseHttpCode(response_headers);
// code = 200
```

**6.2 Critérios de sucesso**
```cpp
// Sucesso: qualquer código 2xx
bool is_success = (code >= 200 && code < 300);

// Duplicata: código 409 ou corpo contém "duplicate key value"
bool is_duplicate = (code == 409) || 
                    (body_lower.contains("duplicate key value")) ||
                    (body_lower.contains("already exists"));

// Duplicata é tratada como sucesso (idempotência)
if (is_success || is_duplicate) {
  api_success_count++;
  return true;
}
```

**6.3 Códigos especiais**
- **429 (Too Many Requests)**: Backoff exponencial com jitter; retry
- **503 (Service Unavailable)**: Backoff exponencial; retry
- **413/414 (Payload Too Large)**: Se `SplitOnPayloadTooLarge=true`, divide lote ao meio recursivamente
- **Outros erros (4xx/5xx)**: Retry até 3x com backoff

---

### **ETAPA 7: Retry com Backoff**

```cpp
int attempts = 0;
int max_attempts = 3;
int wait_ms = 600;

while (attempts < max_attempts) {
  attempts++;
  
  // Faz a requisição
  int code = WebRequest(...);
  
  // Se sucesso: return true
  if (code >= 200 && code < 300) {
    return true;
  }
  
  // Se falhou e ainda há tentativas
  if (attempts < max_attempts) {
    // Jitter aleatório de 0-300ms
    int jitter = MathRand() % 300;
    
    // Backoff especial para 429/503
    if (code == 429 || code == 503) {
      wait_ms = MathMax(wait_ms * 2, 1500);
    }
    
    // Aguarda com jitter
    Sleep(wait_ms + jitter);
    
    // Dobra o wait para próxima tentativa (max 8s)
    wait_ms = MathMin(wait_ms * 2, 8000);
  }
}

return false; // Falhou após 3 tentativas
```

---

### **ETAPA 8: Fallback para Arquivo (se falhar)**

Se `API_Fallback_To_File=true` e o envio falhar:

```cpp
// Salva o lote em arquivo JSONL local
string filename = "PDC_batch_fallback_20251018.jsonl";
string line = "{\"items\":[...]}";

// Append UTF-8 com BOM
AppendUTF8LineCommon(filename, line);
```

Arquivo gerado em:
```
MQL5/Files/PDC_batch_fallback_20251018.jsonl
```

---

## 📊 Exemplo Completo de Requisição Real

### **Request**
```http
POST /ingest HTTP/1.1
Host: SEU_SERVIDOR_LINUX:18001
Content-Type: application/json
Accept: application/json
Connection: keep-alive
User-Agent: PDC/1.65
X-API-Key: mt5_trading_secure_key_2025_prod
Content-Length: 3456

{
  "items": [
    {
      "ts": "2025-10-18T14:32:00Z",
      "symbol": "EURUSD",
      "timeframe": "M1",
      "open": 1.08540,
      "high": 1.08550,
      "low": 1.08538,
      "close": 1.08545,
      "volume": 142,
      "spread": 0.000050,
      "meta": {
        "ea": "PDC",
        "ver": "1.65",
        "src": "timer",
        "term": "MetaTrader 5",
        "collected_at": "2025-10-18T14:32:00Z",
        "bar_time": "2025-10-18T14:32:00Z",
        "last_tick": "2025-10-18T14:32:15Z"
      }
    },
    {
      "ts": "2025-10-18T14:32:00Z",
      "symbol": "GBPUSD",
      "timeframe": "M1",
      "open": 1.26234,
      "high": 1.26245,
      "low": 1.26230,
      "close": 1.26240,
      "volume": 98,
      "spread": 0.000060,
      "meta": {
        "ea": "PDC",
        "ver": "1.65",
        "src": "timer",
        "term": "MetaTrader 5",
        "collected_at": "2025-10-18T14:32:00Z",
        "bar_time": "2025-10-18T14:32:00Z",
        "last_tick": "2025-10-18T14:32:12Z"
      }
    }
    ... (até 28 símbolos)
  ]
}
```

### **Response (Sucesso)**
```http
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 45

{"status":"ok","inserted":28,"duplicates":0}
```

### **Response (Duplicata - tratada como sucesso)**
```http
HTTP/1.1 409 Conflict
Content-Type: application/json
Content-Length: 78

{"status":"error","message":"duplicate key value violates unique constraint"}
```

### **Response (Erro Temporário - retry)**
```http
HTTP/1.1 503 Service Unavailable
Content-Type: application/json
Content-Length: 52

{"status":"error","message":"database temporarily unavailable"}
```

---

## 🔍 Logs no MT5 Journal (Exemplo Real)

```
2025.10.18 14:32:00 DataCollectorPRO EURUSD,M1: TIMER: Coletando dados de 28 símbolos...
2025.10.18 14:32:01 DataCollectorPRO EURUSD,M1: [INGEST] try=1 code=200 err=0 bytes=45 url=http://SEU_SERVIDOR_LINUX:18001/ingest
2025.10.18 14:32:01 DataCollectorPRO EURUSD,M1: [NETDBG] ctx=BATCH[0-27] try=1 sz=45 code=200 last_err=0 | hdr: HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 45

2025.10.18 14:32:01 DataCollectorPRO EURUSD,M1: API [BATCH[0-27]]: 200 (45 bytes)
2025.10.18 14:32:01 DataCollectorPRO EURUSD,M1: BATCH: 1 sub-lotes enviados
2025.10.18 14:32:01 DataCollectorPRO EURUSD,M1: TIMER: Coleta concluída (28 itens enviados)
```

---

## ⚙️ Configurações Importantes no EA

### **Para o servidor de ingest funcionar corretamente:**

1. **Whitelist WebRequest** (MT5 → Tools → Options → Expert Advisors)
   ```
   http://SEU_SERVIDOR_LINUX:18001
   ```

2. **Configurações recomendadas no EA:**
   ```
   Collection_Interval = 60          // Coleta a cada 1 minuto
   MaxItemsPerBatch = 500            // Máx 500 símbolos por request
   API_Timeout = 6000                // Timeout de 6s
   Send_Only_On_Change = true        // Só envia se OHLC mudar
   Skip_Duplicate_TS = false         // OFF (envia sempre, servidor decide)
   API_Fallback_To_File = true       // Salva em arquivo se API falhar
   SplitOnPayloadTooLarge = true     // Divide lote se 413/414
   ```

3. **Credenciais (já configuradas):**
   ```
   API_URL = "http://SEU_SERVIDOR_LINUX:18001/ingest"
   API_Key = "mt5_trading_secure_key_2025_prod"
   ```

---

## 🛡️ Proteções e Garantias

### **Idempotência**
- EA envia sempre com `ts` (timestamp único por símbolo/timeframe)
- Servidor deve ter constraint UNIQUE em `(symbol, timeframe, ts)`
- Duplicatas retornam 409 → EA trata como sucesso

### **Resiliência**
- ✅ 3 tentativas com backoff exponencial
- ✅ Jitter aleatório para evitar thundering herd
- ✅ Backoff especial para 429/503
- ✅ Fallback para arquivo local se API cair
- ✅ Divisão automática de lotes grandes (413/414)

### **Observabilidade**
- ✅ Logs detalhados no MT5 Journal
- ✅ Contadores de sucesso/erro
- ✅ Debug de headers e body (configurável)
- ✅ Estatísticas a cada 10 coletas

---

## 🎯 Próximos Passos para Testes

1. **Teste de conectividade:**
   ```powershell
   curl -X POST http://SEU_SERVIDOR_LINUX:18001/ingest `
     -H "Content-Type: application/json" `
     -H "X-API-Key: mt5_trading_secure_key_2025_prod" `
     -d '{"items":[{"ts":"2025-10-18T14:00:00Z","symbol":"TEST"}]}'
   ```

2. **Anexe o EA ao gráfico EURUSD M1**

3. **Monitore o Journal:**
   - View → Toolbox → Experts
   - Procure por `[INGEST]` e `API [BATCH`

4. **Verifique no servidor Linux:**
   - Cheque logs da API de ingest
   - Confirme inserção no banco de dados

---

## 📝 Notas Finais

- O EA envia **sempre em lote** (`{"items":[...]}`)
- Nunca envia item individual
- Headers incluem `X-API-Key` automaticamente
- Timestamp é ISO 8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`)
- Todos os números usam dígitos do símbolo (precisão correta)
- JSON é escapado corretamente (sem quebras)

---

**Versão do EA:** 1.65  
**Última atualização:** 2025-10-18  
**Commit:** 0.3 ++
