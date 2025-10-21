# API Lite - SQLite version for local development
import os
from pathlib import Path
from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import json, time, logging, sqlite3
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger("api-lite")

# Config
ALLOWED_TOKEN = os.getenv("ALLOWED_TOKEN", "changeme")
DB_PATH = Path(os.getenv("DB_PATH", "./data/ea.db")).resolve()
DB_PATH.parent.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="EA Ingest API Lite", version="0.1")

# Initialize SQLite
def init_db():
    conn = sqlite3.connect(str(DB_PATH))
    c = conn.cursor()
    
    # Ticks table
    c.execute("""
        CREATE TABLE IF NOT EXISTS ticks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT NOT NULL,
            ts_ms INTEGER NOT NULL,
            timeframe TEXT,
            open REAL,
            high REAL,
            low REAL,
            close REAL,
            volume REAL,
            kind TEXT,
            meta TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(symbol, ts_ms)
        )
    """)
    
    # Index for faster queries
    c.execute("CREATE INDEX IF NOT EXISTS idx_symbol_ts ON ticks(symbol, ts_ms)")
    
    conn.commit()
    conn.close()
    log.info(f"Database initialized: {DB_PATH}")

init_db()

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

@app.get("/health")
async def health():
    conn = sqlite3.connect(str(DB_PATH))
    c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM ticks")
    count = c.fetchone()[0]
    conn.close()
    return {"ok": True, "db": str(DB_PATH), "total_ticks": count}

@app.post("/ingest")
async def ingest(request: Request):
    # Auth
    token = request.headers.get("x-api-key")
    if ALLOWED_TOKEN and token != ALLOWED_TOKEN:
        raise HTTPException(status_code=401, detail="invalid token")
    
    body = await request.json()
    items = [body] if isinstance(body, dict) else body
    
    inserted = 0
    duplicates = 0
    
    conn = sqlite3.connect(str(DB_PATH))
    c = conn.cursor()
    
    for it in items:
        try:
            # Convert ts to int if string
            ts_val = it.get('ts')
            if isinstance(ts_val, str):
                # Try parse ISO8601 or int string
                try:
                    from dateutil import parser
                    dt = parser.isoparse(ts_val)
                    ts_val = int(dt.timestamp() * 1000)
                except:
                    ts_val = int(ts_val)
            
            c.execute("""
                INSERT OR IGNORE INTO ticks(symbol, ts_ms, timeframe, open, high, low, close, volume, kind, meta)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                it.get('symbol'),
                ts_val,
                it.get('timeframe'),
                it.get('open'),
                it.get('high'),
                it.get('low'),
                it.get('close'),
                it.get('volume'),
                it.get('kind'),
                json.dumps(it.get('meta', {}))
            ))
            
            if c.rowcount > 0:
                inserted += 1
            else:
                duplicates += 1
                
        except Exception as e:
            log.warning(f"Insert error: {e}")
    
    conn.commit()
    conn.close()
    
    log.info(f"Ingest: {inserted} inserted, {duplicates} duplicates")
    return {"inserted": inserted, "duplicates": duplicates, "total": len(items)}

@app.post("/ingest/tick")
async def ingest_tick(request: Request):
    # Auth
    token = request.headers.get("x-api-key")
    if ALLOWED_TOKEN and token != ALLOWED_TOKEN:
        raise HTTPException(status_code=401, detail="invalid token")
    
    body = await request.json()
    
    # Handle batch format {"ticks": [...]}
    if isinstance(body, dict) and "ticks" in body:
        items = body["ticks"]
    elif isinstance(body, list):
        items = body
    else:
        items = [body]
    
    log.info(f"Received {len(items)} tick(s) for ingestion")
    inserted = 0
    errors = 0
    conn = sqlite3.connect(str(DB_PATH))
    c = conn.cursor()
    
    for it in items:
        try:
            # Convert ts
            ts_val = it.get('ts')
            if isinstance(ts_val, str):
                try:
                    from dateutil import parser
                    dt = parser.isoparse(ts_val)
                    ts_val = int(dt.timestamp() * 1000)
                except:
                    ts_val = int(ts_val)
            
            c.execute("""
                INSERT OR IGNORE INTO ticks(symbol, ts_ms, timeframe, open, high, low, close, volume, kind, meta)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                it.get('symbol'),
                ts_val,
                'tick',
                it.get('bid') or it.get('last'),  # Use bid as open fallback
                it.get('ask'),
                it.get('bid'),
                it.get('last'),
                it.get('volume', 0),
                'tick',
                json.dumps(it)
            ))
            
            if c.rowcount > 0:
                inserted += 1
                
        except Exception as e:
            log.error(f"Tick insert error for item {it}: {e}", exc_info=True)
            errors += 1
    
    conn.commit()
    conn.close()
    
    log.info(f"Tick ingest complete: {inserted} inserted, {errors} errors")
    return {"inserted": inserted, "errors": errors, "total": len(items)}

@app.get("/stats")
async def stats():
    conn = sqlite3.connect(str(DB_PATH))
    c = conn.cursor()
    
    c.execute("SELECT COUNT(*) FROM ticks")
    total = c.fetchone()[0]
    
    c.execute("SELECT COUNT(DISTINCT symbol) FROM ticks")
    symbols = c.fetchone()[0]
    
    c.execute("SELECT symbol, COUNT(*) as cnt FROM ticks GROUP BY symbol ORDER BY cnt DESC LIMIT 10")
    top_symbols = [{"symbol": row[0], "count": row[1]} for row in c.fetchall()]
    
    conn.close()
    
    return {
        "total_ticks": total,
        "unique_symbols": symbols,
        "top_symbols": top_symbols
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=18002, log_level="info")
