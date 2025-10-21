# Observabilidade: Logging Estruturado e Métricas

Este documento detalha a implementação de logging estruturado e métricas Prometheus no projeto EA-MT5.

## Logging Estruturado

- **Arquivo:** `infra/observability/structured_logging.py`
- **Funcionalidade:**
  - Formata logs em JSON para facilitar análise e integração com sistemas de observabilidade (ex: Loki).
  - Utiliza contexto de log para rastrear execuções e correlações.
  - Exemplo de uso:
    ```python
    from infra.observability.structured_logging import log_with_metrics, LogContext
    LogContext.set('request_id', 'abc123')
    log_with_metrics('info', 'Mensagem de teste', {'foo': 'bar'})
    ```

## Métricas Prometheus

- **Arquivo:** `infra/observability/prometheus_metrics.py`
- **Funcionalidade:**
  - Helpers para registro de métricas customizadas (contadores, timers).
  - Integração com Prometheus para coleta automática.
  - Exemplo de uso:
    ```python
    from infra.observability.prometheus_metrics import record_request, RequestTimer
    record_request('endpoint', 200)
    with RequestTimer('endpoint'):
        # código monitorado
    ```

## Testes

- Testes automatizados garantem funcionamento dos módulos:
  - `tests/test_structured_logging.py`
  - `tests/test_prometheus_metrics.py`

## Observações

- O formato JSON dos logs facilita integração com sistemas de monitoramento e análise.
- As métricas customizadas permitem rastreamento detalhado de performance e disponibilidade.
