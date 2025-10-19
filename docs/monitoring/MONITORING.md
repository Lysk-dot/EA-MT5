# EA-MT5 Monitoring Documentation

## 📊 Dashboards Disponíveis

### 1. EA API Overview
Dashboard principal com visão geral da API:
- Request rate por endpoint
- Latências (p50, p95, p99)
- Taxa de forwards
- DB writes/s
- Status geral

### 2. EA Pipeline Health
Monitoramento de saúde do pipeline de dados:
- **Status dos serviços** (API, DB)
- **Símbolos ativos** nos últimos 5 minutos
- **Data age** por símbolo (detecta símbolos sem dados)
- **Taxa de duplicatas** (ON CONFLICT)
- **Pendências de confirmação** (total e > 5min)
- **Success rate** de forwards
- **Erros da API** por tipo
- **Latência de confirmação** (p50, p95, p99)
- **Distribuição de batch size**
- **Uso de memória e CPU**

### 3. TimescaleDB Overview
Monitoramento do banco de dados:
- Conexões ativas
- Query performance
- Cache hit ratio
- Disk usage
- Index efficiency

## 🚨 Alertas Configurados

### Críticos (severity: critical)
1. **APIDown**: API offline por > 1min
2. **DatabaseDown**: PostgreSQL offline por > 1min
3. **PendingConfirmationsOlderThan5m**: Dados sem confirmação há > 5min

### Avisos (severity: warning)
4. **HighForwardErrorRate**: > 10% de erros de forward (10min)
5. **LowForwardSuccessRate**: < 80% de sucesso de forward (10min)
6. **APIHighLatency**: P95 de latência > 2s (5min)
7. **NoDataIngested**: Sem dados sendo inseridos (10min)
8. **HighMemoryUsage**: API usando > 500MB de RAM (10min)
9. **ConfirmLatencyHigh**: Confirmações demorando > 5s P95 (5min)

### Informativos (severity: info)
10. **BatchSizeTooLarge**: P95 de batch > 1000 itens (5min)
11. **DuplicateDataHigh**: > 50% de duplicatas (10min) - Normal se EA reenviar

## 📈 Métricas Principais

### Métricas de Request
- `api_requests_total{endpoint}` - Total de requests por endpoint
- `api_request_latency_seconds{endpoint}` - Latência por endpoint (histogram)
- `api_errors_total{endpoint, error_type}` - Erros por tipo

### Métricas de Forward
- `forward_requests_total{endpoint, status}` - Forwards por status HTTP
- `forward_items_total{endpoint}` - Total de itens encaminhados
- `forward_confirm_total{endpoint, status}` - Tentativas de confirmação
- `forward_confirm_latency_seconds{endpoint}` - Latência de confirmação
- `pending_forward_total` - Total de forwards pendentes
- `pending_forward_older_5m_total` - Pendentes há > 5min

### Métricas de Dados
- `db_writes_total` - Total de escritas no banco
- `duplicate_inserts_total` - Total de inserções duplicadas (ON CONFLICT)
- `ingest_batch_size` - Tamanho dos batches (histogram)
- `symbols_active_total` - Número de símbolos ativos (últimos 5min)
- `data_age_seconds{symbol}` - Idade do último dado por símbolo

### Métricas de Sistema
- `process_resident_memory_bytes` - Uso de memória da API
- `process_cpu_seconds_total` - Uso de CPU
- `up{job}` - Status dos serviços (1=up, 0=down)

## 🔍 Queries Úteis (PromQL)

### Taxa de sucesso de forwards
```promql
sum(rate(forward_requests_total{status=~"2.."}[5m])) by (endpoint) 
/ 
sum(rate(forward_requests_total[5m])) by (endpoint) * 100
```

### Taxa de duplicatas
```promql
rate(duplicate_inserts_total[5m]) 
/ 
(rate(duplicate_inserts_total[5m]) + rate(db_writes_total[5m])) * 100
```

### Latência P95 por endpoint
```promql
histogram_quantile(0.95, 
  sum(rate(api_request_latency_seconds_bucket[5m])) by (le, endpoint)
)
```

### Símbolos sem dados há > 5min
```promql
data_age_seconds > 300
```

### Throughput total (requests/s)
```promql
sum(rate(api_requests_total[1m]))
```

### Memory leak detection
```promql
delta(process_resident_memory_bytes[1h]) > 100000000  # > 100MB em 1h
```

## 🎯 SLOs Recomendados

### Availability
- **API**: > 99.5% uptime
- **Database**: > 99.9% uptime

### Performance
- **Latência P95**: < 500ms
- **Latência P99**: < 2s
- **Forward success rate**: > 95%

### Data Quality
- **Data age**: < 60s para símbolos ativos
- **Confirmação**: < 5s para 95% dos forwards
- **Duplicate rate**: < 20% (aceitável se EA reenviar)

## 🔔 Configuração de Notificações

Para receber alertas, configure um receiver no Prometheus Alertmanager:

```yaml
# alertmanager.yml
receivers:
  - name: 'email'
    email_configs:
      - to: 'seu-email@exemplo.com'
        from: 'alertas@ea-mt5.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'seu-email@gmail.com'
        auth_password: 'sua-senha-app'

  - name: 'slack'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/SEU/WEBHOOK/AQUI'
        channel: '#alerts-ea'
        title: 'EA-MT5 Alert'

route:
  receiver: 'email'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - match:
        severity: critical
      receiver: 'slack'
```

## 📱 Acesso aos Dashboards

Após subir os containers com Docker:

- **Grafana**: http://localhost:3000
  - User: `admin`
  - Pass: `admin` (altere no primeiro login)

- **Prometheus**: http://localhost:9090
  - Acesso direto às métricas e queries

- **API Metrics**: http://localhost:8000/metrics
  - Endpoint raw de métricas Prometheus

## 🛠️ Troubleshooting

### Dashboard vazio?
1. Verifique se a API está rodando: `curl http://localhost:8000/health`
2. Verifique se Prometheus está coletando: http://localhost:9090/targets
3. Verifique datasource no Grafana: Settings → Data Sources → Prometheus

### Alertas não disparam?
1. Verifique regras: http://localhost:9090/rules
2. Verifique se Alertmanager está configurado
3. Teste query manualmente no Prometheus

### Métricas faltando?
1. Envie alguns dados de teste para a API
2. Aguarde 1-2 minutos para scrape do Prometheus
3. Execute `refresh_gauges()` via `/metrics` endpoint
