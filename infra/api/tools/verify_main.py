import argparse
import requests
import sys
import time
import re
from typing import Dict, Tuple

METRIC_LINE = re.compile(r"^([a-zA-Z_:][a-zA-Z0-9_:]*)(\{([^}]*)\})?\s+([0-9eE+\-\.]+)")


def parse_labels(lbl: str) -> Dict[str, str]:
    out = {}
    if not lbl:
        return out
    # split on commas not within quotes
    parts = []
    cur = []
    in_q = False
    for ch in lbl:
        if ch == '"':
            in_q = not in_q
            cur.append(ch)
        elif ch == ',' and not in_q:
            parts.append(''.join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    if cur:
        parts.append(''.join(cur).strip())
    for p in parts:
        if '=' in p:
            k, v = p.split('=', 1)
            v = v.strip().strip('"')
            out[k.strip()] = v
    return out


def parse_prometheus(text: str) -> Dict[Tuple[str, Tuple[Tuple[str, str], ...]], float]:
    metrics = {}
    for line in text.splitlines():
        if not line or line.startswith('#'):
            continue
        m = METRIC_LINE.match(line)
        if not m:
            continue
        name = m.group(1)
        labels = parse_labels(m.group(3) or '')
        val = float(m.group(4))
        key = (name, tuple(sorted(labels.items())))
        metrics[key] = val
    return metrics


def get_metric(metrics, name: str, **labels) -> float | None:
    target = tuple(sorted(labels.items()))
    for (n, lbls), v in metrics.items():
        if n == name and lbls == target:
            return v
    return None


def run_verify(api: str, token: str | None, timeout: int = 5):
    base = api.rstrip('/')
    headers = {'User-Agent': 'Verifier/1.0'}
    if token:
        headers['x-api-key'] = token

    # Health
    try:
        rh = requests.get(base + '/health', headers=headers, timeout=timeout)
        h_json = None
        try:
            h_json = rh.json()
        except Exception:
            pass
        print(f"/health -> {rh.status_code} {h_json}")
    except Exception as e:
        print(f"/health error: {e}")

    # Metrics
    try:
        rm = requests.get(base + '/metrics', headers={'User-Agent': 'Verifier/1.0'}, timeout=timeout)
        if rm.status_code >= 200 and rm.status_code < 400:
            metrics = parse_prometheus(rm.text)
            writes = get_metric(metrics, 'db_writes_total')
            ing_total = get_metric(metrics, 'api_requests_total', endpoint='/ingest')
            tick_total = get_metric(metrics, 'api_requests_total', endpoint='/ingest/tick')
            fwd_sent = get_metric(metrics, 'forward_items_total', endpoint='/ingest')
            print('metrics:')
            print(f"  db_writes_total = {writes}")
            print(f"  api_requests_total{{endpoint='/ingest'}} = {ing_total}")
            print(f"  api_requests_total{{endpoint='/ingest/tick'}} = {tick_total}")
            print(f"  forward_items_total{{endpoint='/ingest'}} = {fwd_sent}")
        else:
            print(f"/metrics -> {rm.status_code}")
    except Exception as e:
        print(f"/metrics error: {e}")


def run_sql_verify(host, port, db, user, password, min_since=60):
    try:
        import psycopg2
    except ImportError:
        print("psycopg2 not installed. Run: pip install psycopg2-binary")
        return
    try:
        conn = psycopg2.connect(
            host=host, port=port, dbname=db, user=user, password=password, connect_timeout=5
        )
        cur = conn.cursor()
        print(f"\n[SQL] Tabelas disponíveis:")
        cur.execute("SELECT tablename FROM pg_tables WHERE schemaname='public';")
        tables = [r[0] for r in cur.fetchall()]
        for t in tables:
            print(f"  - {t}")
        likely = [n for n in tables if n.lower() in ('ticks','market_data','candles','ohlcv')]
        tried = False
        for table in likely:
            print(f"\n[SQL] Tentando consulta em '{table}':")
            try:
                cur.execute(f"""
                    SELECT symbol, COUNT(*) as n, MAX(ts) as ultimo_ts
                    FROM {table}
                    WHERE ts > now() - interval '{min_since} minutes'
                    GROUP BY symbol
                    ORDER BY n DESC, symbol
                    LIMIT 10;
                """)
                rows = cur.fetchall()
                for sym, n, ultimo in rows:
                    print(f"  {sym:10s}  {n:5d}  {str(ultimo)}")
                tried = True
            except Exception as e:
                print(f"  Erro na consulta: {e}")
        if not tried:
            print("Nenhuma tabela de ticks/candles encontrada. Use uma destas queries no painel SQL do VS Code:")
            for t in tables:
                print(f"SELECT * FROM {t} LIMIT 10;")
        # Print ready-to-use connection string for VS Code SQL panel
        print(f"\n[VS Code SQL] Connection string:")
        print(f"postgresql://{user}:{password}@{host}:{port}/{db}")
        cur.close()
        conn.close()
    except Exception as e:
        print(f"[SQL] Erro: {e}")

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--api', default='http://192.168.15.20:18001')
    p.add_argument('--token', default=None)
    p.add_argument('--timeout', type=int, default=5)
    # DB options
    p.add_argument('--db-host', default=None)
    p.add_argument('--db-port', type=int, default=5432)
    p.add_argument('--db-name', default=None)
    p.add_argument('--db-user', default=None)
    p.add_argument('--db-pass', default=None)
    p.add_argument('--db-minutes', type=int, default=60)
    args = p.parse_args()
    run_verify(args.api, args.token, args.timeout)
    if args.db_host and args.db_name and args.db_user and args.db_pass:
        run_sql_verify(args.db_host, args.db_port, args.db_name, args.db_user, args.db_pass, args.db_minutes)

if __name__ == '__main__':
    main()
