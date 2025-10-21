import os, json, sqlite3, time
import argparse
import requests

# Simple exporter: read from local SQLite (ea.db) and push to main API in batches
# Default filter: last N minutes or by limit

def get_args():
    p = argparse.ArgumentParser()
    # default DB at infra/api/data/ea.db
    p.add_argument('--db', default=os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data', 'ea.db')))
    p.add_argument('--api', default='http://192.168.15.20:18001')
    p.add_argument('--token', default='mt5_trading_secure_key_2025_prod')
    p.add_argument('--limit', type=int, default=200, help='Max rows to fetch (ignored when --all)')
    p.add_argument('--since-minutes', type=int, default=None)
    p.add_argument('--batch', type=int, default=200)
    p.add_argument('--all', action='store_true', help='Export all rows using pagination (by ts_ms asc)')
    p.add_argument('--page-size', type=int, default=1000, help='Rows per page when using --all')
    p.add_argument('--dry-run', action='store_true')
    p.add_argument('--endpoint', default=None, help='Override endpoint path, e.g., /ingest or /ingest/tick. If omitted, auto-detects based on items.')
    p.add_argument('--wrap-items', action='store_true', default=True, help='When targeting /ingest, wrap payload as {"items": [...]} (recommended for remote API)')
    p.add_argument('--aggregate-to', default='auto', choices=['auto','none','M1'], help='If sending tick rows to /ingest, aggregate to candles (default auto=M1).')
    p.add_argument('--fallback-aggregate-on-404', action='store_true', default=True, help='If /ingest/tick 404, fallback to aggregated candles on /ingest')
    return p.parse_args()


def fetch_rows(db_path, limit, since_minutes=None):
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    if since_minutes:
        c.execute("SELECT symbol, ts_ms, timeframe, open, high, low, close, volume, kind, meta FROM ticks WHERE ts_ms > strftime('%s','now','-%d minutes')*1000 ORDER BY ts_ms DESC LIMIT ?" % since_minutes, (limit,))
    else:
        c.execute("SELECT symbol, ts_ms, timeframe, open, high, low, close, volume, kind, meta FROM ticks ORDER BY ts_ms DESC LIMIT ?", (limit,))
    rows = c.fetchall()
    conn.close()
    items = []
    for r in rows:
        items.append({
            'symbol': r[0],
            'ts': int(r[1]),
            'timeframe': r[2],
            'open': r[3], 'high': r[4], 'low': r[5], 'close': r[6], 'volume': r[7],
            'kind': r[8],
            'meta': json.loads(r[9]) if r[9] else {}
        })
    return items

def fetch_rows_paged(db_path, start_ts_ms: int, page_size: int):
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute("SELECT symbol, ts_ms, timeframe, open, high, low, close, volume, kind, meta FROM ticks WHERE ts_ms > ? ORDER BY ts_ms ASC LIMIT ?", (start_ts_ms, page_size))
    rows = c.fetchall()
    conn.close()
    items = []
    for r in rows:
        items.append({
            'symbol': r[0],
            'ts': int(r[1]),
            'timeframe': r[2],
            'open': r[3], 'high': r[4], 'low': r[5], 'close': r[6], 'volume': r[7],
            'kind': r[8],
            'meta': json.loads(r[9]) if r[9] else {}
        })
    last_ts = items[-1]['ts'] if items else start_ts_ms
    return items, last_ts


def resolve_endpoint(items, override: str = None):
    if override:
        ep = override if override.startswith('/') else '/' + override
        return ep
    # Auto-detect: if all items look like ticks (timeframe == 'tick' or kind == 'tick'), use /ingest/tick, else /ingest
    is_tick = True
    for it in items:
        tf = str(it.get('timeframe', '')).lower()
        kd = str(it.get('kind', '')).lower()
        if not (tf == 'tick' or kd == 'tick'):
            is_tick = False
            break
    return '/ingest/tick' if is_tick else '/ingest'


def post_batch(api_base, token, items, endpoint_override: str = None, wrap_items: bool = True):
    ep = resolve_endpoint(items, endpoint_override)
    url = api_base.rstrip('/') + ep
    headers = {'Content-Type': 'application/json', 'x-api-key': token, 'User-Agent': 'LocalExporter/1.0'}
    payload = {'items': items} if (ep == '/ingest' and wrap_items) else items
    r = requests.post(url, json=payload, headers=headers, timeout=10)
    try:
        data = r.json()
    except Exception:
        data = {'_raw': r.text[:200]}
    return r.status_code, data


def is_all_ticks(items):
    for it in items:
        tf = str(it.get('timeframe', '')).lower()
        kd = str(it.get('kind', '')).lower()
        if not (tf == 'tick' or kd == 'tick'):
            return False
    return True


def choose_price(it: dict) -> float | None:
    # Prefer last, then bid, then open
    meta = it.get('meta') or {}
    for key in ('last', 'bid', 'open'):
        v = meta.get(key)
        if v is None:
            v = it.get(key)
        if isinstance(v, (int, float)):
            return float(v)
    # fallback to close/high/low if present
    for key in ('close', 'high', 'low'):
        v = it.get(key)
        if isinstance(v, (int, float)):
            return float(v)
    return None


def floor_minute(ts_ms: int) -> int:
    return (int(ts_ms) // 60000) * 60000


def aggregate_ticks_to_candles(items: list[dict], timeframe: str = 'M1') -> list[dict]:
    buckets = {}
    order = {}
    for it in sorted(items, key=lambda x: int(x.get('ts', 0))):
        ts_ms = int(it.get('ts'))
        sym = it.get('symbol')
        bucket_ts = floor_minute(ts_ms)
        key = (sym, bucket_ts)
        price = choose_price(it)
        if price is None:
            # skip items without usable price
            continue
        if key not in buckets:
            buckets[key] = {
                'symbol': sym,
                'ts': bucket_ts,
                'timeframe': timeframe,
                'open': price,
                'high': price,
                'low': price,
                'close': price,
                'volume': 0.0,
                'kind': 'candle',
                'meta': {'src': 'agg-tick', 'count': 1}
            }
            order[key] = 1
        else:
            b = buckets[key]
            b['high'] = max(b['high'], price)
            b['low'] = min(b['low'], price)
            b['close'] = price
            b['meta']['count'] = b['meta'].get('count', 0) + 1
            order[key] += 1
        # accumulate volume if present
        vol = it.get('volume')
        if vol is None:
            vol = (it.get('meta') or {}).get('volume')
        if isinstance(vol, (int, float)):
            buckets[key]['volume'] = buckets[key].get('volume', 0.0) + float(vol)
    # return in time order
    return [buckets[k] for k in sorted(buckets.keys(), key=lambda x: x[1])]


def main():
    args = get_args()
    db_path = args.db
    if args.all:
        print(f"Exporting ALL rows paginated from {db_path} -> {args.api}")
        sent = 0
        cursor_ts = -1
        while True:
            items, cursor_ts = fetch_rows_paged(db_path, cursor_ts, args.page_size)
            if not items:
                break
            for i in range(0, len(items), args.batch):
                orig_batch = items[i:i+args.batch]
                batch = orig_batch
                if args.dry_run:
                    print(json.dumps(batch[:2], indent=2) + ('\n...' if len(batch)>2 else ''))
                else:
                    st, body = post_batch(args.api, args.token, batch, args.endpoint, args.wrap_items)
                    print(f"POST {resolve_endpoint(batch, args.endpoint)} batch={len(batch)} -> status={st} body={body}")
                    if st == 404 and args.fallback_aggregate_on_404 and is_all_ticks(batch):
                        # try aggregate to M1 and send to /ingest
                        agg_tf = 'M1' if args.aggregate_to in ('auto','M1') else None
                        if agg_tf:
                            candles = aggregate_ticks_to_candles(batch, timeframe=agg_tf)
                            st2, body2 = post_batch(args.api, args.token, candles, '/ingest', True)
                            print(f"FALLBACK POST /ingest agg={agg_tf} items={len(candles)} -> status={st2} body={body2}")
                            st, body = st2, body2
                    if 200 <= st < 400:
                        sent += len(batch)
                    else:
                        print("Stopping on error status")
                        print(f"Last cursor ts_ms={cursor_ts}")
                        print(f"Progress sent={sent}")
                        return
                time.sleep(0.2)
        print(f"Done. sent={sent}")
    else:
        items = fetch_rows(db_path, args.limit, args.since_minutes)
        print(f"Fetched {len(items)} rows from {db_path}")
        if args.dry_run:
            print(json.dumps(items[:2], indent=2) + ('\n...' if len(items)>2 else ''))
            return
        sent = 0
        for i in range(0, len(items), args.batch):
            orig_batch = items[i:i+args.batch]
            batch = orig_batch
            st, body = post_batch(args.api, args.token, batch, args.endpoint, args.wrap_items)
            print(f"POST {resolve_endpoint(batch, args.endpoint)} batch={len(batch)} -> status={st} body={body}")
            if st == 404 and args.fallback_aggregate_on_404 and is_all_ticks(batch):
                agg_tf = 'M1' if args.aggregate_to in ('auto','M1') else None
                if agg_tf:
                    candles = aggregate_ticks_to_candles(batch, timeframe=agg_tf)
                    st2, body2 = post_batch(args.api, args.token, candles, '/ingest', True)
                    print(f"FALLBACK POST /ingest agg={agg_tf} items={len(candles)} -> status={st2} body={body2}")
                    st, body = st2, body2
            if 200 <= st < 400:
                sent += len(batch)
            else:
                print("Stopping on error status")
                break
            time.sleep(0.2)
        print(f"Done. sent={sent}")

if __name__ == '__main__':
    main()
