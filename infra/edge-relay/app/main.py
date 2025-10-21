import os, json, time, uuid, threading, queue as q, logging
from pathlib import Path
from fastapi import FastAPI, Request, HTTPException
import httpx
from dotenv import load_dotenv

# Load .env from parent directory
env_path = Path(__file__).parent.parent / '.env'
print(f"[DEBUG] Loading .env from: {env_path}")
print(f"[DEBUG] .env exists: {env_path.exists()}")
load_dotenv(env_path)

# Config
RELAY_HOST = os.getenv("RELAY_HOST", "127.0.0.1")
RELAY_PORT = int(os.getenv("RELAY_PORT", "18001"))
REMOTE_INGEST = os.getenv("REMOTE_INGEST", "http://192.168.15.20:18001/ingest")
REMOTE_TICK = os.getenv("REMOTE_TICK", "http://192.168.15.20:18001/ingest/tick")
REMOTE_TOKEN = os.getenv("REMOTE_TOKEN", "changeme")

print(f"[DEBUG] REMOTE_INGEST: {REMOTE_INGEST}")
print(f"[DEBUG] REMOTE_TICK: {REMOTE_TICK}")
print(f"[DEBUG] REMOTE_TOKEN: {REMOTE_TOKEN}")

QUEUE_DIR = Path(os.getenv("QUEUE_DIR", "./queue")).resolve()
QUEUE_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger("edge-relay")

app = FastAPI(title="EA Edge Relay", version="0.1")

# Simple file-based queue helpers

def _qfile(prefix: str) -> Path:
    return QUEUE_DIR / f"{prefix}-{int(time.time()*1000)}-{uuid.uuid4().hex}.json"

async def _forward_json(url: str, payload, headers: dict, timeout: float = 3.0):
    async with httpx.AsyncClient(timeout=timeout) as client:
        return await client.post(url, json=payload, headers=headers)

# Background replayer thread
stop_flag = threading.Event()

def replay_worker():
    while not stop_flag.is_set():
        try:
            files = sorted(QUEUE_DIR.glob('*.json'))
            for f in files:
                try:
                    with f.open('r', encoding='utf-8') as fh:
                        item = json.load(fh)
                    url = item.get('url')
                    payload = item.get('payload')
                    headers = item.get('headers', {})
                    # Try forward
                    r = httpx.post(url, json=payload, headers=headers, timeout=5.0)
                    if 200 <= r.status_code < 400:
                        f.unlink(missing_ok=True)
                        log.info("replayed ok: %s status=%s", f.name, r.status_code)
                    else:
                        log.warning("replay failed status=%s keep=%s", r.status_code, f.name)
                except Exception as e:
                    log.warning("replay error %s on %s", str(e), f.name)
            # sleep a bit when idle
            time.sleep(2)
        except Exception:
            time.sleep(2)

threading.Thread(target=replay_worker, daemon=True).start()

@app.get("/health")
async def health():
    return {"ok": True, "queue": len(list(QUEUE_DIR.glob('*.json')))}

# Ingest batch endpoint
@app.post("/ingest")
async def ingest(request: Request):
    headers = {"Content-Type": "application/json", "x-api-key": REMOTE_TOKEN}
    body = await request.json()
    # forward immediately, else queue
    try:
        r = await _forward_json(REMOTE_INGEST, body, headers, timeout=3.0)
        if 200 <= r.status_code < 400:
            return {"proxied": True, "status": r.status_code}
        else:
            raise HTTPException(status_code=502, detail=f"upstream status {r.status_code}")
    except Exception as e:
        # persist to queue
        file = _qfile('ingest')
        with file.open('w', encoding='utf-8') as fh:
            json.dump({"url": REMOTE_INGEST, "payload": body, "headers": headers}, fh)
        log.warning("queued /ingest size=%s file=%s reason=%s", (len(body) if isinstance(body, list) else 1), file.name, str(e))
        return {"queued": True}

# Tick endpoint
@app.post("/ingest/tick")
async def ingest_tick(request: Request):
    headers = {"Content-Type": "application/json", "x-api-key": REMOTE_TOKEN}
    body = await request.json()
    try:
        r = await _forward_json(REMOTE_TICK, body, headers, timeout=2.0)
        if 200 <= r.status_code < 400:
            return {"proxied": True, "status": r.status_code}
        else:
            raise HTTPException(status_code=502, detail=f"upstream status {r.status_code}")
    except Exception as e:
        file = _qfile('tick')
        with file.open('w', encoding='utf-8') as fh:
            json.dump({"url": REMOTE_TICK, "payload": body, "headers": headers}, fh)
        log.warning("queued /ingest/tick file=%s reason=%s", file.name, str(e))
        return {"queued": True}


# Run tip: uvicorn app.main:app --host 127.0.0.1 --port 18001 --workers 1

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=RELAY_HOST, port=RELAY_PORT, reload=False)
