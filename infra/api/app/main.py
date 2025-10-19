from fastapi import FastAPI, Request, HTTPException, Response
from pydantic import BaseModel, field_validator
from typing import List, Optional
from sqlalchemy import create_engine, text
import os, json, httpx, time, logging
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

# OpenTelemetry imports
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.sdk.resources import SERVICE_NAME, Resource

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+psycopg2://ea:ea123@db:5432/ea")
ALLOWED_TOKEN = os.getenv("ALLOWED_TOKEN", "changeme")

engine = create_engine(DATABASE_URL, pool_pre_ping=True)

# Instrument SQLAlchemy engine
SQLAlchemyInstrumentor().instrument(engine=engine)
FWD_ING = os.getenv("FORWARD_INGEST_URL")
FWD_TICK = os.getenv("FORWARD_TICK_URL")
FWD_TOKEN = os.getenv("FORWARD_TOKEN")
FWD_CONFIRM = os.getenv("FORWARD_CONFIRM_URL")

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger("ea-api")

# ============================================
# OpenTelemetry Setup
# ============================================
JAEGER_HOST = os.getenv("JAEGER_HOST", "jaeger")
JAEGER_PORT = int(os.getenv("JAEGER_PORT", "6831"))

# Configure resource (service identification)
resource = Resource(attributes={
    SERVICE_NAME: "ea-api",
    "service.version": "1.0.0",
    "deployment.environment": os.getenv("ENVIRONMENT", "production")
})

# Setup tracer provider
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer_provider = trace.get_tracer_provider()

# Setup Jaeger exporter
jaeger_exporter = JaegerExporter(
    agent_host_name=JAEGER_HOST,
    agent_port=JAEGER_PORT,
)

# Add span processor
tracer_provider.add_span_processor(BatchSpanProcessor(jaeger_exporter))

# Get tracer
tracer = trace.get_tracer(__name__)

# ============================================
# FastAPI App
# ============================================
app = FastAPI(title="EA Ingest API", version="0.1")

# Instrument FastAPI automatically
FastAPIInstrumentor.instrument_app(app)

# Instrument SQLAlchemy (after engine creation, done below)
# Instrument HTTPX client
HTTPXClientInstrumentor().instrument()


# --- Models ---
class IngestItem(BaseModel):
    symbol: str
    timeframe: Optional[str] = None
    ts: int | str
    open: Optional[float] = None
    high: Optional[float] = None
    low: Optional[float] = None
    close: Optional[float] = None
    volume: Optional[float] = None
    kind: Optional[str] = None
    meta: Optional[dict] = None

    @field_validator('symbol')
    @classmethod
    def sym_ok(cls, v):
        if not v or len(v) < 3:
            raise ValueError("invalid symbol")
        return v

    @field_validator('ts')
    @classmethod
    def ts_ok(cls, v):
        # Accept ISO8601 or epoch ms
        if isinstance(v, int):
            return v
        if isinstance(v, str):
            try:
                # Try ISO8601
                import dateutil.parser
                dt = dateutil.parser.isoparse(v)
                return int(dt.timestamp() * 1000)
            except Exception:
                try:
                    return int(v)
                except Exception:
                    raise ValueError("invalid ts format")
        raise ValueError("invalid ts type")

class AckRequest(BaseModel):
    keys: List[dict]

class FeedbackRequest(BaseModel):
    order_id: str
    feedback: str

# --- Endpoints ---
# --- Signals Endpoints ---
@app.get("/signals/next")
async def signals_next(symbol: str):
    # Return next signal for symbol (stub)
    # TODO: Implement actual logic
    return {"symbol": symbol, "signal": "buy", "ts": int(time.time()*1000)}

@app.get("/signals/latest")
async def signals_latest(symbol: str):
    # Return latest signal for symbol (stub)
    # TODO: Implement actual logic
    return {"symbol": symbol, "signal": "sell", "ts": int(time.time()*1000)}

@app.post("/signals/ack")
async def signals_ack(payload: AckRequest):
    # Mark signals as acknowledged (stub)
    # TODO: Implement actual logic
    return {"acknowledged": len(payload.keys)}

@app.post("/orders/feedback")
async def orders_feedback(payload: FeedbackRequest):
    # Accept feedback for an order (stub)
    # TODO: Implement actual logic
    return {"order_id": payload.order_id, "status": "feedback received"}

# metrics
REQ_COUNT = Counter('api_requests_total', 'Total API requests', ['endpoint'])
FWD_COUNT = Counter('forward_requests_total', 'Total forward attempts', ['endpoint','status'])
DB_WRITE = Counter('db_writes_total', 'Total DB rows written')
REQ_LAT = Histogram('api_request_latency_seconds', 'API request latency', ['endpoint'])
# additional visibility
INGEST_BATCH = Histogram('ingest_batch_size', 'Items per /ingest batch')
FWD_ITEMS = Counter('forward_items_total', 'Total items forwarded', ['endpoint'])
CONFIRM_COUNT = Counter('forward_confirm_total', 'Forward confirm attempts', ['endpoint','status'])
PENDING_FWD = Gauge('pending_forward_total', 'Pending forwards not confirmed')
PENDING_FWD_5M = Gauge('pending_forward_older_5m_total', 'Pending forwards older than 5 minutes')
CONFIRM_LAT = Histogram('forward_confirm_latency_seconds', 'Latency between forward and confirm', ['endpoint'])
# Métricas adicionais para monitoramento avançado
DUPLICATE_COUNT = Counter('duplicate_inserts_total', 'Total duplicate inserts (ON CONFLICT)')
API_ERRORS = Counter('api_errors_total', 'API errors by type', ['endpoint', 'error_type'])
SYMBOLS_ACTIVE = Gauge('symbols_active_total', 'Number of active symbols in last 5m')
DATA_AGE = Gauge('data_age_seconds', 'Age of most recent data point by symbol', ['symbol'])

@app.get("/health")
async def health():
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"ok": True}

def refresh_gauges():
    try:
        with engine.connect() as conn:
            # Pending forwards
            total = conn.execute(text("SELECT count(*) FROM forward_audit WHERE status <> 'confirmed'"))
            total_val = list(total)[0][0]
            PENDING_FWD.set(total_val)
            older = conn.execute(text("SELECT count(*) FROM forward_audit WHERE status <> 'confirmed' AND sent_at < now() - interval '5 minutes'"))
            older_val = list(older)[0][0]
            PENDING_FWD_5M.set(older_val)
            
            # Active symbols (últimos 5 minutos)
            symbols = conn.execute(text("SELECT count(DISTINCT symbol) FROM ticks WHERE ts > now() - interval '5 minutes'"))
            symbols_val = list(symbols)[0][0]
            SYMBOLS_ACTIVE.set(symbols_val)
            
            # Data age por símbolo (top 5 mais ativos)
            ages = conn.execute(text("""
                SELECT symbol, EXTRACT(EPOCH FROM (now() - MAX(ts))) as age_seconds
                FROM ticks
                WHERE ts > now() - interval '1 hour'
                GROUP BY symbol
                ORDER BY MAX(ts) DESC
                LIMIT 5
            """)).fetchall()
            for row in ages:
                DATA_AGE.labels(symbol=row[0]).set(row[1])
    except Exception:
        pass

@app.get('/metrics')
async def metrics():
    refresh_gauges()
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get('/debug/recent')
async def debug_recent(limit: int = 10):
    # Retorna últimas N linhas de ticks e forwards para inspeção rápida
    with engine.connect() as conn:
        ticks = conn.execute(text("""
            SELECT symbol, ts_ms, timeframe, open, high, low, close, volume, kind
            FROM ticks
            ORDER BY ts DESC
            LIMIT :limit
        """), { 'limit': limit }).mappings().all()
        fwd = conn.execute(text("""
            SELECT symbol, ts_ms, endpoint, status, sent_at, confirm_at, last_status_code
            FROM forward_audit
            ORDER BY sent_at DESC
            LIMIT :limit
        """), { 'limit': limit }).mappings().all()
    return { 'ticks': [dict(r) for r in ticks], 'forward': [dict(r) for r in fwd] }

@app.get('/debug/pending')
async def debug_pending(limit: int = 50):
    with engine.connect() as conn:
        rows = conn.execute(text("""
            SELECT symbol, ts_ms, endpoint, status, sent_at, last_status_code
            FROM forward_audit
            WHERE status <> 'confirmed'
            ORDER BY sent_at DESC
            LIMIT :limit
        """), { 'limit': limit }).mappings().all()
    return { 'pending': [dict(r) for r in rows] }

@app.post("/ingest")
async def ingest(request: Request):
    start = time.time()
    REQ_COUNT.labels('/ingest').inc()
    
    # Extract trace context from headers
    trace_id = request.headers.get("x-trace-id", "")
    span_context = trace.get_current_span().get_span_context()
    
    # Start main span
    with tracer.start_as_current_span("ingest_request") as span:
        span.set_attribute("http.method", "POST")
        span.set_attribute("http.url", str(request.url))
        span.set_attribute("http.client_ip", request.client.host if request.client else "unknown")
        span.set_attribute("ea.trace_id", trace_id)
        
        # Validate authentication
        with tracer.start_as_current_span("validate_auth"):
            token = request.headers.get("x-api-key")
            if ALLOWED_TOKEN and token != ALLOWED_TOKEN:
                span.set_attribute("error", True)
                span.set_attribute("error.type", "auth_failed")
                raise HTTPException(status_code=401, detail="invalid token")
        
        # Parse request body
        with tracer.start_as_current_span("parse_json") as parse_span:
            body = await request.body()
            parse_span.set_attribute("body.size_bytes", len(body))
            try:
                data = json.loads(body.decode('utf-8'))
            except Exception as e:
                parse_span.set_attribute("error", True)
                parse_span.set_attribute("error.message", str(e))
                raise HTTPException(status_code=400, detail="invalid json")

        if isinstance(data, dict):
            items = [data]
        elif isinstance(data, list):
            items = data
        else:
            raise HTTPException(status_code=400, detail="invalid payload type")

        inserted = 0
        duplicates = 0
        
        # Set span attributes for batch
        span.set_attribute("ingest.batch_size", len(items))
        
        # observe batch size
        try:
            INGEST_BATCH.observe(len(items))
        except Exception:
            pass
        
        # Capturar info da requisição para log
        source_ip = request.client.host if request.client else None
        user_agent = request.headers.get("user-agent", "unknown")
        span.set_attribute("http.user_agent", user_agent)
        
        # Extract EA metadata from User-Agent
        with tracer.start_as_current_span("extract_ea_metadata") as meta_span:
            try:
                # Parse: DataCollectorPRO/PDC/1.65 (Account:12345; Server:Broker-Demo; Build:3850; trace_id:xxx)
                if "PDC/" in user_agent:
                    parts = user_agent.split("(")
                    if len(parts) > 1:
                        metadata = parts[1].rstrip(")").split(";")
                        for item in metadata:
                            if ":" in item:
                                key, value = item.split(":", 1)
                                key = key.strip().lower()
                                value = value.strip()
                                meta_span.set_attribute(f"ea.{key}", value)
                                span.set_attribute(f"ea.{key}", value)
            except Exception:
                pass
        
        # Database operations
        with tracer.start_as_current_span("database_insert") as db_span:
            with engine.begin() as conn:
                for it in items:
                    was_duplicate = False
                    symbol = it.get('symbol', 'unknown')
                    
                    # Create span per symbol (only for first few to avoid span explosion)
                    if inserted + duplicates < 5:
                        item_span = tracer.start_span(f"insert_item_{symbol}")
                        item_span.set_attribute("symbol", symbol)
                        item_span.set_attribute("timeframe", it.get('timeframe', ''))
                    else:
                        item_span = None
                    
                    try:
                        # Tentar inserir na tabela principal
                        result = conn.execute(
                            text("""
                            INSERT INTO ticks(symbol, ts_ms, timeframe, open, high, low, close, volume, kind, meta)
                            VALUES (:symbol, :ts_ms, :timeframe, :open, :high, :low, :close, :volume, :kind, :meta)
                            ON CONFLICT (symbol, ts_ms) DO NOTHING
                            RETURNING symbol
                            """),
                            {
                                'symbol': symbol,
                                'ts_ms': it.get('ts'),
                                'timeframe': it.get('timeframe'),
                                'open': it.get('open'),
                                'high': it.get('high'),
                                'low': it.get('low'),
                                'close': it.get('close'),
                                'volume': it.get('volume'),
                                'kind': it.get('kind'),
                                'meta': json.dumps(it.get('meta', {})),
                            }
                        )
                        
                        # Verificar se foi inserido ou foi duplicata
                        if result.rowcount > 0:
                            inserted += 1
                            if item_span:
                                item_span.set_attribute("inserted", True)
                        else:
                            duplicates += 1
                            was_duplicate = True
                            DUPLICATE_COUNT.inc()
                            if item_span:
                                item_span.set_attribute("inserted", False)
                                item_span.set_attribute("duplicate", True)
                
                        # SEMPRE registrar no log (incluindo duplicatas)
                        conn.execute(
                            text("""
                            INSERT INTO ingest_log(symbol, ts_ms, timeframe, open, high, low, close, volume, kind, was_duplicate, source_ip, user_agent)
                            VALUES (:symbol, :ts_ms, :timeframe, :open, :high, :low, :close, :volume, :kind, :duplicate, :ip, :ua)
                            """),
                            {
                                'symbol': it.get('symbol'),
                                'ts_ms': it.get('ts'),
                                'timeframe': it.get('timeframe'),
                                'open': it.get('open'),
                                'high': it.get('high'),
                                'low': it.get('low'),
                                'close': it.get('close'),
                                'volume': it.get('volume'),
                                'kind': it.get('kind'),
                                'duplicate': was_duplicate,
                                'ip': source_ip,
                                'ua': user_agent
                            }
                        )
                        
                    except Exception as e:
                        # ignore bad rows; EA trata dedupe como sucesso
                        API_ERRORS.labels(endpoint='/ingest', error_type='insert_failed').inc()
                        if item_span:
                            item_span.set_attribute("error", True)
                            item_span.set_attribute("error.message", str(e))
                    finally:
                        if item_span:
                            item_span.end()
            
            db_span.set_attribute("db.inserted", inserted)
            db_span.set_attribute("db.duplicates", duplicates)
        DB_WRITE.inc(inserted)
        
        # Forward para servidor remoto se configurado
        if FWD_ING:
            with tracer.start_as_current_span("forward_to_remote") as fwd_span:
                fwd_span.set_attribute("forward.url", FWD_ING)
                fwd_span.set_attribute("forward.items", len(items))
                headers = {"Content-Type": "application/json"}
                if FWD_TOKEN:
                    headers["x-api-key"] = FWD_TOKEN
                try:
                    keys = [{"symbol": it.get('symbol'), "ts_ms": it.get('ts')} for it in items][:10]
                    r = httpx.post(FWD_ING, json=items, headers=headers, timeout=5.0)
                    FWD_COUNT.labels('/ingest', str(r.status_code)).inc()
                    fwd_span.set_attribute("http.status_code", r.status_code)
                    fwd_span.set_attribute("forward.success", 200 <= r.status_code < 400)
            try:
                if 200 <= r.status_code < 400:
                    FWD_ITEMS.labels('/ingest').inc(len(items))
            except Exception:
                pass
            # audit sent rows
            try:
                with engine.begin() as conn:
                    for it in items:
                        conn.execute(text("""
                          INSERT INTO forward_audit(symbol, ts_ms, endpoint, status, last_status_code)
                          VALUES (:symbol, :ts_ms, '/ingest', :status, :code)
                          ON CONFLICT (symbol, ts_ms, endpoint) DO UPDATE SET status=:status, last_status_code=:code
                        """), {
                          'symbol': it.get('symbol'), 'ts_ms': it.get('ts'), 'status': 'sent' if 200 <= r.status_code < 400 else 'error', 'code': r.status_code
                        })
            except Exception:
                pass
            body = None
            try:
                body = r.json()
            except Exception:
                body = {"_raw": (r.text[:200] if r.text else "")}
            log.info("FORWARD /ingest -> %s | sz=%d | status=%s | resp=%s | sample_keys=%s",
                     FWD_ING, len(items), r.status_code, body, keys)
            # confirmação opcional
            if FWD_CONFIRM and isinstance(body, dict):
                try:
                    cstart = time.time()
                    cr = httpx.post(FWD_CONFIRM, json={"keys": keys}, headers=headers, timeout=5.0)
                    try:
                        CONFIRM_COUNT.labels('/ingest', str(cr.status_code)).inc()
                    except Exception:
                        pass
                    clog = None
                    try:
                        clog = cr.json()
                    except Exception:
                        clog = {"_raw": (cr.text[:200] if cr.text else "")}
                    log.info("CONFIRM /ingest -> %s | status=%s | resp=%s", FWD_CONFIRM, cr.status_code, clog)
                    try:
                        CONFIRM_LAT.labels('/ingest').observe(time.time()-cstart)
                        if cr.status_code >= 200 and cr.status_code < 400:
                            with engine.begin() as conn:
                                for k in keys:
                                    conn.execute(text("""
                                      UPDATE forward_audit
                                      SET status='confirmed', confirm_at=now(), last_status_code=:code
                                      WHERE symbol=:symbol AND ts_ms=:ts_ms AND endpoint='/ingest'
                                    """), {'symbol': k['symbol'], 'ts_ms': k['ts_ms'], 'code': cr.status_code})
                    except Exception:
                        pass
                    except Exception as e:
                        log.warning("CONFIRM failed: %s", str(e))
                except Exception as e:
                    fwd_span.set_attribute("error", True)
                    fwd_span.set_attribute("error.message", str(e))
                    FWD_COUNT.labels('/ingest', 'error').inc()
        
        # Set final span attributes
        span.set_attribute("ingest.inserted", inserted)
        span.set_attribute("ingest.duplicates", duplicates)
        span.set_attribute("ingest.success", True)
        
        REQ_LAT.labels('/ingest').observe(time.time()-start)
        return {"inserted": inserted, "duplicates": duplicates, "total": len(items)}

@app.post("/ingest/tick")
async def ingest_tick(payload: IngestItem, request: Request):
    start = time.time()
    REQ_COUNT.labels('/ingest/tick').inc()
    token = request.headers.get("x-api-key")
    if ALLOWED_TOKEN and token != ALLOWED_TOKEN:
        raise HTTPException(status_code=401, detail="invalid token")
    with engine.begin() as conn:
        conn.execute(
            text("""
            INSERT INTO ticks(symbol, ts_ms, timeframe, open, high, low, close, volume, kind, meta)
            VALUES (:symbol, :ts_ms, :timeframe, :open, :high, :low, :close, :volume, :kind, :meta)
            ON CONFLICT (symbol, ts_ms) DO NOTHING
            """),
            {
                'symbol': payload.symbol,
                'ts_ms': payload.ts,
                'timeframe': payload.timeframe,
                'open': payload.open,
                'high': payload.high,
                'low': payload.low,
                'close': payload.close,
                'volume': payload.volume,
                'kind': payload.kind,
                'meta': json.dumps(payload.meta or {}),
            }
        )
    DB_WRITE.inc()
    # Forward também para o endpoint de tick, se configurado
    if FWD_TICK:
        headers = {"Content-Type": "application/json"}
        if FWD_TOKEN:
            headers["x-api-key"] = FWD_TOKEN
        try:
            forward_payload = payload.model_dump()
            r = httpx.post(FWD_TICK, json=forward_payload, headers=headers, timeout=3.0)
            FWD_COUNT.labels('/ingest/tick', str(r.status_code)).inc()
            try:
                if 200 <= r.status_code < 400:
                    FWD_ITEMS.labels('/ingest/tick').inc()
            except Exception:
                pass
            # audit tick
            try:
                with engine.begin() as conn:
                    conn.execute(text("""
                      INSERT INTO forward_audit(symbol, ts_ms, endpoint, status, last_status_code)
                      VALUES (:symbol, :ts_ms, '/ingest/tick', :status, :code)
                      ON CONFLICT (symbol, ts_ms, endpoint) DO UPDATE SET status=:status, last_status_code=:code
                    """), {'symbol': payload.symbol, 'ts_ms': payload.ts, 'status': 'sent' if 200 <= r.status_code < 400 else 'error', 'code': r.status_code})
            except Exception:
                pass
            body = None
            try:
                body = r.json()
            except Exception:
                body = {"_raw": (r.text[:200] if r.text else "")}
            log.info("FORWARD /ingest/tick -> %s | status=%s | resp=%s | key=%s",
                     FWD_TICK, r.status_code, body, {"symbol": payload.symbol, "ts_ms": payload.ts})
            if FWD_CONFIRM:
                try:
                    cstart = time.time()
                    cr = httpx.post(FWD_CONFIRM, json={"keys": [{"symbol": payload.symbol, "ts_ms": payload.ts}]}, headers=headers, timeout=5.0)
                    try:
                        CONFIRM_COUNT.labels('/ingest/tick', str(cr.status_code)).inc()
                    except Exception:
                        pass
                    clog = None
                    try:
                        clog = cr.json()
                    except Exception:
                        clog = {"_raw": (cr.text[:200] if cr.text else "")}
                    log.info("CONFIRM /ingest/tick -> %s | status=%s | resp=%s", FWD_CONFIRM, cr.status_code, clog)
                    try:
                        CONFIRM_LAT.labels('/ingest/tick').observe(time.time()-cstart)
                        if cr.status_code >= 200 and cr.status_code < 400:
                            with engine.begin() as conn:
                                conn.execute(text("""
                                  UPDATE forward_audit
                                  SET status='confirmed', confirm_at=now(), last_status_code=:code
                                  WHERE symbol=:symbol AND ts_ms=:ts_ms AND endpoint='/ingest/tick'
                                """), {'symbol': payload.symbol, 'ts_ms': payload.ts, 'code': cr.status_code})
                    except Exception:
                        pass
                except Exception as e:
                    log.warning("CONFIRM failed: %s", str(e))
        except Exception:
            FWD_COUNT.labels('/ingest/tick', 'error').inc()
    REQ_LAT.labels('/ingest/tick').observe(time.time()-start)
    return {"inserted": 1}
