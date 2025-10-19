# 🔭 Observability Stack - EA MT5

Stack completa de observabilidade com **Prometheus**, **Loki**, **Jaeger** e **Grafana**.

## 📦 Componentes

| Serviço | Tipo | Porta | URL | Descrição |
|---------|------|-------|-----|-----------|
| **Prometheus** | Métricas | 9090 | http://localhost:9090 | Agregação de métricas (CPU, req/s, latência) |
| **Loki** | Logs | 3100 | http://localhost:3100 | Agregação de logs estruturados |
| **Promtail** | Agent | 9080 | - | Coleta logs (MT5, EA, scripts, Docker) |
| **Jaeger** | Traces | 16686 | http://localhost:16686 | Distributed tracing (fluxo de requests) |
| **Grafana** | Dashboard | 3000 | http://localhost:3000 | Visualização unificada |

---

## 🚀 Quick Start

### 1. Iniciar Stack
```powershell
cd infra/observability
docker-compose up -d
```

### 2. Verificar Status
```powershell
docker-compose ps
docker-compose logs -f
```

### 3. Acessar Interfaces

**Grafana** (Dashboard principal):
- URL: http://localhost:3000
- User: `admin`
- Password: `admin123`

**Prometheus** (Métricas):
- URL: http://localhost:9090
- Query: `rate(api_requests_total[5m])`

**Jaeger UI** (Traces):
- URL: http://localhost:16686
- Service: `ea-api`

**Loki** (Logs - via Grafana):
- Acessar Grafana → Explore → Loki
- Query: `{job="mt5"} |= "error"`

---

## 📊 Exemplos de Queries

### **Prometheus (Métricas)**

```promql
# Taxa de requests por segundo
rate(api_requests_total[5m])

# Latência P95
histogram_quantile(0.95, rate(api_request_latency_seconds_bucket[5m]))

# Taxa de duplicatas
sum(rate(api_requests_total{was_duplicate="true"}[5m])) / sum(rate(api_requests_total[5m]))

# CPU do container
rate(container_cpu_usage_seconds_total{name="ea-api"}[1m])
```

---

### **Loki (Logs)**

```logql
# Erros do EA
{job="ea-datacollector"} |= "error" or "ERROR"

# Logs de compilação falhada
{job="automation", script="compile-ea.ps1"} |= "FAIL"

# Latência alta no API
{job="docker-logs", container="ea-api"} | json | latency_ms > 1000

# Duplicatas altas (mercado fechado?)
{job="docker-logs"} |= "was_duplicate=true" | rate[5m] > 0.8

# Logs por símbolo
{job="ea-datacollector", symbol="EURUSD"} | json

# Logs por conta
{job="ea-datacollector", account="12345"} | json

# Últimas 100 linhas de um script
{job="automation", script="verify-ea-data.ps1"} | tail 100
```

---

### **Jaeger (Traces)**

**Via UI (http://localhost:16686):**

1. Service: `ea-api`
2. Operation: `POST /ingest`
3. Tags:
   - `symbol=EURUSD`
   - `account=12345`
   - `error=true` (para traces com erro)
4. Lookback: Last 1 hour
5. Min Duration: 500ms (para slow traces)

**Via Grafana:**
- Explore → Jaeger
- Query: `{service.name="ea-api"}`

---

## 🔧 Configuração da API (Instrumentação)

### **Python FastAPI - OpenTelemetry**

```python
# infra/api/app/main.py
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.jaeger.thrift import JaegerExporter

# Setup tracing
trace.set_tracer_provider(TracerProvider())
jaeger_exporter = JaegerExporter(
    agent_host_name="localhost",
    agent_port=6831,
)
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(jaeger_exporter)
)

# Instrumentar FastAPI automaticamente
FastAPIInstrumentor.instrument_app(app)

# Uso manual de spans
@app.post("/ingest")
async def ingest(candle: Candle):
    tracer = trace.get_tracer(__name__)
    
    with tracer.start_as_current_span("validate_candle") as span:
        span.set_attribute("symbol", candle.symbol)
        span.set_attribute("timeframe", candle.timeframe)
        # ... validação
    
    with tracer.start_as_current_span("check_duplicate"):
        # ... query DB
        pass
    
    with tracer.start_as_current_span("insert_candle"):
        # ... INSERT
        pass
    
    return {"inserted": True}
```

---

### **PowerShell - Log Structured**

```powershell
# compile-ea.ps1
function Write-StructuredLog {
    param([string]$Level, [string]$Message, [hashtable]$Context)
    
    $log = @{
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        level = $Level
        script = $MyInvocation.ScriptName
        message = $Message
    } + $Context
    
    $log | ConvertTo-Json -Compress | Out-File -Append logs/automation.log
}

# Uso
Write-StructuredLog -Level "INFO" -Message "Compilação iniciada" -Context @{ea="DataCollectorPRO"; version="1.65"}
Write-StructuredLog -Level "ERROR" -Message "Falha na compilação" -Context @{exit_code=1; duration_ms=5234}
```

---

### **MQL5 EA - Trace Context**

```mql5
// EA/DataCollectorPRO.mq5
#property description "Envia trace_id no User-Agent para correlação"

string GenerateTraceId() {
    // UUID simples (32 chars hex)
    return StringFormat("%08x%08x%08x%08x", 
        MathRand(), MathRand(), MathRand(), MathRand());
}

void SendCandle(Candle &candle) {
    string trace_id = GenerateTraceId();
    
    string user_agent = StringFormat(
        "DataCollectorPRO/PDC/%s (Account:%d; Server:%s; Build:%d; trace_id:%s)",
        PDC_VER, AccountInfoInteger(ACCOUNT_LOGIN), 
        AccountInfoString(ACCOUNT_SERVER), 
        TerminalInfoInteger(TERMINAL_BUILD),
        trace_id
    );
    
    string headers = "User-Agent: " + user_agent + "\r\n" +
                     "X-API-Key: " + API_Key + "\r\n" +
                     "X-Trace-Id: " + trace_id + "\r\n";
    
    WebRequest("POST", API_URL, headers, 0, payload, result, result_headers);
}
```

Agora o trace aparecerá no Jaeger correlacionado com logs no Loki! 🔗

---

## 📁 Estrutura de Logs

```
workspace/
├── logs/
│   ├── automation.log        # Scripts PowerShell (JSON)
│   ├── compile-ea.log         # Logs de compilação
│   ├── verify-ea.log          # Logs de verificação
│   └── repo-health.log        # Logs de health checks
│
C:/Program Files/MetaTrader 5/Logs/
├── 20251018.log               # MT5 platform logs
└── Experts/
    └── DataCollectorPRO.log   # EA journal logs
```

**Promtail coleta automaticamente** todos esses logs!

---

## 🎯 Dashboards Recomendados

### **1. Observability Overview**
- **Metrics**: Request rate, latency P95, error rate
- **Logs**: Recent errors (últimas 50 linhas)
- **Traces**: Slowest traces (P99)

### **2. EA Health**
- Candles/min por símbolo
- Taxa de duplicatas (heatmap)
- Latência de ingestão (end-to-end)
- Alertas de contas offline

### **3. Trace Analysis**
- Service map (EA → API → DB → Analytics)
- Latency breakdown por span
- Error traces (status=500)
- Dependency graph

### **4. Logs Explorer**
- Search logs por: job, level, script, symbol, account
- Tail logs em tempo real
- Pattern detection (regex)
- Log volume (lines/sec)

---

## 🔔 Alertas (Opcional)

### **Prometheus Alertmanager**

```yaml
# prometheus/alerts.yml
groups:
  - name: ea-alerts
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: rate(api_errors_total[5m]) > 0.05
        for: 2m
        annotations:
          summary: "Taxa de erros alta (>5%)"
      
      - alert: APIDown
        expr: up{job="ea-api"} == 0
        for: 1m
        annotations:
          summary: "API offline"
      
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(api_request_latency_seconds_bucket[5m])) > 1
        for: 5m
        annotations:
          summary: "Latência P95 > 1s"
```

---

## 🧹 Manutenção

### **Limpar Dados Antigos**
```powershell
# Parar stack
docker-compose down

# Remover volumes (CUIDADO: apaga todos os dados)
docker volume rm observability_prometheus-data observability_loki-data observability_grafana-data

# Reiniciar
docker-compose up -d
```

### **Rotação de Logs**
```powershell
# Criar script de rotação
# logs/rotate-logs.ps1
Get-ChildItem logs/*.log | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item
```

### **Backup de Dashboards**
```powershell
# Exportar dashboards do Grafana
curl -u admin:admin123 http://localhost:3000/api/search | ConvertFrom-Json | ForEach-Object {
    $uid = $_.uid
    curl -u admin:admin123 "http://localhost:3000/api/dashboards/uid/$uid" | Out-File "dashboards/backup/$uid.json"
}
```

---

## 🐛 Troubleshooting

### **Promtail não coleta logs**
```powershell
# Verificar configuração
docker exec ea-promtail cat /etc/promtail/config.yml

# Logs do Promtail
docker logs ea-promtail -f

# Testar manualmente
curl -i http://localhost:9080/ready
```

### **Jaeger não recebe traces**
```bash
# Verificar portas abertas
docker exec ea-jaeger netstat -tulpn

# Testar envio manual
curl -X POST http://localhost:14268/api/traces -H "Content-Type: application/json" -d '{...}'
```

### **Grafana não conecta datasources**
```powershell
# Verificar rede
docker network inspect observability_observability

# Testar conectividade
docker exec ea-grafana curl http://prometheus:9090/-/healthy
docker exec ea-grafana curl http://loki:3100/ready
docker exec ea-grafana curl http://jaeger:16686/
```

---

## 📚 Documentação Adicional

- **Prometheus**: https://prometheus.io/docs/
- **Loki**: https://grafana.com/docs/loki/latest/
- **Jaeger**: https://www.jaegertracing.io/docs/
- **Grafana**: https://grafana.com/docs/grafana/latest/
- **OpenTelemetry**: https://opentelemetry.io/docs/

---

## 🎓 Treinamento

### **1. Métricas (Prometheus)**
- RED Method: Rate, Errors, Duration
- USE Method: Utilization, Saturation, Errors
- Golden Signals: Latency, Traffic, Errors, Saturation

### **2. Logs (Loki)**
- Structured logging (JSON)
- Labels vs content
- LogQL aggregations

### **3. Traces (Jaeger)**
- Spans e context propagation
- Service mesh integration
- Trace sampling (1%, 10%, 100%)

---

Criado em: 2025-10-18  
Autor: AI Assistant  
Versão: 1.0
