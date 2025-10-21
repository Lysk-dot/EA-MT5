import time
from infra.observability.prometheus_metrics import (
    api_requests_total, api_request_duration, record_request, RequestTimer
)

def test_record_request():
    # Simula uma requisição
    record_request(endpoint="/ingest", method="POST", status=200, duration=0.05)
    # Verifica se o contador foi incrementado
    assert api_requests_total.labels(endpoint="/ingest", method="POST", status="200")._value.get() >= 1
    # Verifica se o histograma registrou a duração
    buckets = api_request_duration.labels(endpoint="/ingest", method="POST")._sum.get()
    assert buckets > 0

def test_request_timer():
    # Testa o context manager de tempo
    with RequestTimer(api_request_duration, endpoint="/ingest", method="POST"):
        time.sleep(0.01)
    # Verifica se o histograma registrou
    buckets = api_request_duration.labels(endpoint="/ingest", method="POST")._sum.get()
    assert buckets > 0
