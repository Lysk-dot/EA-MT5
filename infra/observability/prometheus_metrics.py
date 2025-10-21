"""
Prometheus Metrics for EA-MT5 API
Exporta métricas de RPS, latência e contadores
"""
from prometheus_client import Counter, Histogram, Gauge, Info, generate_latest
from typing import Optional
import time

# ============================================
# Request Metrics
# ============================================

# Counter: Total de requisições por endpoint e status
api_requests_total = Counter(
    'api_requests_total',
    'Total de requisições à API',
    ['endpoint', 'method', 'status']
)

# Histogram: Latência de requisições
api_request_duration = Histogram(
    'api_request_duration_seconds',
    'Duração de requisições à API em segundos',
    ['endpoint', 'method'],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)

# ============================================
# Data Ingestion Metrics
# ============================================

# Counter: Items OHLCV ingeridos
items_ingested_total = Counter(
    'items_ingested_total',
    'Total de items OHLCV ingeridos',
    ['symbol', 'timeframe', 'source']
)

# Counter: Ticks ingeridos
ticks_ingested_total = Counter(
    'ticks_ingested_total',
    'Total de ticks ingeridos',
    ['symbol', 'source']
)

# Counter: Duplicados detectados (idempotência)
duplicates_detected_total = Counter(
    'duplicates_detected_total',
    'Total de duplicados detectados',
    ['endpoint', 'symbol', 'timeframe']
)

# Gauge: Taxa de duplicados (%)
duplicate_rate = Gauge(
    'duplicate_rate_percent',
    'Taxa de duplicados em porcentagem',
    ['endpoint', 'symbol']
)

# ============================================
# Database Metrics
# ============================================

# Histogram: Latência de queries no DB
db_query_duration = Histogram(
    'db_query_duration_seconds',
    'Duração de queries no PostgreSQL',
    ['operation', 'table'],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]
)

# Counter: Operações no DB
db_operations_total = Counter(
    'db_operations_total',
    'Total de operações no banco',
    ['operation', 'table', 'status']
)

# Gauge: Tamanho da fila de inserção
db_insert_queue_size = Gauge(
    'db_insert_queue_size',
    'Tamanho atual da fila de inserção no DB'
)

# ============================================
# Error Metrics
# ============================================

# Counter: Erros por tipo
errors_total = Counter(
    'errors_total',
    'Total de erros',
    ['error_type', 'endpoint', 'symbol']
)

# Counter: Rate limit hits
rate_limit_hits_total = Counter(
    'rate_limit_hits_total',
    'Total de vezes que rate limit foi atingido',
    ['endpoint', 'ip']
)

# ============================================
# Business Metrics
# ============================================

# Gauge: Símbolos ativos (receberam dados recentemente)
active_symbols = Gauge(
    'active_symbols_count',
    'Quantidade de símbolos ativos',
    ['timeframe']
)

# Gauge: Volume total de dados (MB)
data_volume_mb = Gauge(
    'data_volume_mb',
    'Volume de dados armazenados em MB',
    ['table']
)

# Counter: Coletas do EA por modo
ea_collections_total = Counter(
    'ea_collections_total',
    'Total de coletas do EA',
    ['symbol', 'timeframe', 'mode']
)

# ============================================
# System Metrics
# ============================================

# Gauge: Conexões ativas
active_connections = Gauge(
    'active_connections',
    'Número de conexões ativas'
)

# Info: Versão da aplicação
app_info = Info(
    'app',
    'Informações da aplicação'
)

# ============================================
# Helper Functions
# ============================================

class RequestTimer:
    """
    Context manager para medir tempo de requisição
    
    Usage:
        with RequestTimer(api_request_duration, endpoint='/ingest', method='POST'):
            # processo
            pass
    """
    
    def __init__(self, histogram: Histogram, **labels):
        self.histogram = histogram
        self.labels = labels
        self.start_time = None
    
    def __enter__(self):
        self.start_time = time.time()
        return self
    
    def __exit__(self, *args):
        if self.start_time is not None:
            duration = time.time() - self.start_time
            self.histogram.labels(**self.labels).observe(duration)

def record_request(
    endpoint: str,
    method: str,
    status: int,
    duration: float,
    symbol: Optional[str] = None,
    timeframe: Optional[str] = None
):
    """
    Registra métricas de uma requisição
    
    Args:
        endpoint: Path do endpoint (/ingest, /ingest/tick)
        method: HTTP method (POST, GET)
        status: HTTP status code
        duration: Duração em segundos
        symbol: Símbolo processado (opcional)
        timeframe: Timeframe (opcional)
    """
    # Request counter
    api_requests_total.labels(
        endpoint=endpoint,
        method=method,
        status=str(status)
    ).inc()
    
    # Duration histogram
    api_request_duration.labels(
        endpoint=endpoint,
        method=method
    ).observe(duration)

def record_ingest(
    endpoint: str,
    items_count: int,
    duplicates_count: int,
    symbol: str,
    timeframe: Optional[str] = None,
    source: str = 'MT5'
):
    """
    Registra métricas de ingestão de dados
    
    Args:
        endpoint: /ingest ou /ingest/tick
        items_count: Quantidade de items/ticks
        duplicates_count: Quantidade de duplicados
        symbol: Símbolo
        timeframe: Timeframe (apenas para OHLCV)
        source: Origem dos dados
    """
    if endpoint == '/ingest' and timeframe:
        items_ingested_total.labels(
            symbol=symbol,
            timeframe=timeframe,
            source=source
        ).inc(items_count)
    elif endpoint == '/ingest/tick':
        ticks_ingested_total.labels(
            symbol=symbol,
            source=source
        ).inc(items_count)
    
    # Duplicados
    if duplicates_count > 0:
        duplicates_detected_total.labels(
            endpoint=endpoint,
            symbol=symbol,
            timeframe=timeframe or 'tick'
        ).inc(duplicates_count)
        
        # Calcular taxa de duplicados
        total = items_count + duplicates_count
        rate = (duplicates_count / total * 100) if total > 0 else 0
        duplicate_rate.labels(
            endpoint=endpoint,
            symbol=symbol
        ).set(rate)

def record_db_operation(
    operation: str,
    table: str,
    duration: float,
    status: str = 'success'
):
    """
    Registra operação no banco
    
    Args:
        operation: insert, select, update, delete
        table: Nome da tabela
        duration: Duração em segundos
        status: success ou error
    """
    db_operations_total.labels(
        operation=operation,
        table=table,
        status=status
    ).inc()
    
    db_query_duration.labels(
        operation=operation,
        table=table
    ).observe(duration)

def record_error(
    error_type: str,
    endpoint: str,
    symbol: Optional[str] = None
):
    """
    Registra erro
    
    Args:
        error_type: validation, database, network, etc
        endpoint: Endpoint onde ocorreu
        symbol: Símbolo relacionado (opcional)
    """
    errors_total.labels(
        error_type=error_type,
        endpoint=endpoint,
        symbol=symbol or 'unknown'
    ).inc()

# ============================================
# Exemplo de integração com FastAPI
# ============================================

"""
from fastapi import FastAPI, Request, Response
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
import time

app = FastAPI()

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    
    try:
        response = await call_next(request)
        duration = time.time() - start_time
        
        record_request(
            endpoint=request.url.path,
            method=request.method,
            status=response.status_code,
            duration=duration
        )
        
        return response
    except Exception as e:
        duration = time.time() - start_time
        record_request(
            endpoint=request.url.path,
            method=request.method,
            status=500,
            duration=duration
        )
        record_error(
            error_type='internal',
            endpoint=request.url.path
        )
        raise

@app.get("/metrics")
async def metrics():
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )

@app.post("/ingest")
async def ingest(data: dict):
    items = data.get('items', [])
    
    for item in items:
        record_ingest(
            endpoint='/ingest',
            items_count=1,
            duplicates_count=0,
            symbol=item['symbol'],
            timeframe=item['timeframe'],
            source=item.get('source', 'MT5')
        )
    
    return {"ok": True, "inserted": len(items)}
"""

# ============================================
# Queries úteis para Grafana
# ============================================

"""
# RPS por endpoint
rate(api_requests_total[1m])

# Latência P95
histogram_quantile(0.95, rate(api_request_duration_seconds_bucket[5m]))

# Taxa de erro
rate(api_requests_total{status=~"5.."}[5m]) / rate(api_requests_total[5m]) * 100

# Top símbolos por volume
topk(10, rate(items_ingested_total[5m]))

# Taxa de duplicados
avg(duplicate_rate_percent) by (symbol, endpoint)

# Latência do banco P99
histogram_quantile(0.99, rate(db_query_duration_seconds_bucket[5m]))

# Items/s por timeframe
sum(rate(items_ingested_total[1m])) by (timeframe)

# Erros por tipo
sum(rate(errors_total[5m])) by (error_type)
"""
