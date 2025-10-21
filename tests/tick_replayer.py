#!/usr/bin/env python3
"""
Tick Replayer - Simula envio de dados do EA para API
Usa dados reais do arquivo JSONL para replay
"""
import json
import time
import requests
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional
import argparse
import sys

class TickReplayer:
    def __init__(self, api_url: str, api_key: str, speed_multiplier: float = 1.0):
        self.api_url = api_url.rstrip('/')
        self.api_key = api_key
        self.speed_multiplier = speed_multiplier
        self.stats = {
            'sent': 0,
            'success': 0,
            'duplicates': 0,
            'errors': 0,
            'items_sent': 0,
            'ticks_sent': 0
        }
        
    def load_jsonl_file(self, filepath: Path) -> List[Dict]:
        """Carrega arquivo JSONL de dados coletados"""
        records = []
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                    records.append(record)
                except json.JSONDecodeError as e:
                    print(f"⚠️  Erro ao parsear linha: {e}")
                    continue
        return records
    
    def replay_record(self, record: Dict) -> bool:
        """Envia um record para a API"""
        kind = record.get('kind', '')
        body = record.get('body', {})
        
        # Determinar endpoint
        if 'items:batch' in kind:
            endpoint = f"{self.api_url}/ingest"
            payload = body
            items_count = len(body.get('items', []))
        elif 'tick' in kind:
            endpoint = f"{self.api_url}/ingest/tick"
            # Normalizar para array de ticks
            if 'tick:1' in kind:
                payload = {'ticks': [body]}
            else:
                payload = body
            items_count = len(payload.get('ticks', []))
        else:
            print(f"⚠️  Tipo desconhecido: {kind}")
            return False
        
        # Enviar
        headers = {
            'Content-Type': 'application/json',
            'X-API-Key': self.api_key,
            'User-Agent': 'TickReplayer/1.0'
        }
        
        try:
            response = requests.post(endpoint, json=payload, headers=headers, timeout=10)
            
            self.stats['sent'] += 1
            
            if response.status_code == 200:
                self.stats['success'] += 1
                result = response.json()
                if 'items:batch' in kind:
                    self.stats['items_sent'] += items_count
                else:
                    self.stats['ticks_sent'] += items_count
                    
                # Contar duplicados
                if result.get('duplicates', 0) > 0:
                    self.stats['duplicates'] += result['duplicates']
                    
                print(f"✅ {kind}: {items_count} items | duplicates: {result.get('duplicates', 0)}")
                return True
                
            elif response.status_code == 409:
                # Conflict = duplicado = sucesso (idempotência)
                self.stats['success'] += 1
                self.stats['duplicates'] += items_count
                print(f"🔄 {kind}: {items_count} items | duplicado (409)")
                return True
                
            elif response.status_code == 207:
                # Multi-status - parcial
                self.stats['success'] += 1
                result = response.json()
                print(f"⚠️  {kind}: {items_count} items | multi-status: {result}")
                return True
                
            else:
                self.stats['errors'] += 1
                print(f"❌ {kind}: HTTP {response.status_code} | {response.text[:200]}")
                return False
                
        except requests.RequestException as e:
            self.stats['errors'] += 1
            print(f"❌ Erro de conexão: {e}")
            return False
    
    def replay_file(self, filepath: Path, delay_between: float = 0.1):
        """Replay de arquivo completo"""
        print(f"\n📂 Carregando arquivo: {filepath}")
        records = self.load_jsonl_file(filepath)
        print(f"📊 Total de records: {len(records)}")
        
        if not records:
            print("⚠️  Nenhum record para processar")
            return
        
        print(f"🚀 Iniciando replay com speed={self.speed_multiplier}x\n")
        
        start_time = time.time()
        
        for i, record in enumerate(records, 1):
            print(f"[{i}/{len(records)}] ", end='')
            self.replay_record(record)
            
            # Delay ajustado pelo speed multiplier
            if delay_between > 0 and i < len(records):
                time.sleep(delay_between / self.speed_multiplier)
        
        elapsed = time.time() - start_time
        
        # Estatísticas finais
        print(f"\n{'='*60}")
        print(f"📊 ESTATÍSTICAS DO REPLAY")
        print(f"{'='*60}")
        print(f"Total enviado:    {self.stats['sent']}")
        print(f"Sucesso:          {self.stats['success']} ({self.stats['success']/self.stats['sent']*100:.1f}%)")
        print(f"Erros:            {self.stats['errors']}")
        print(f"Items OHLCV:      {self.stats['items_sent']}")
        print(f"Ticks:            {self.stats['ticks_sent']}")
        print(f"Duplicados:       {self.stats['duplicates']}")
        print(f"Tempo decorrido:  {elapsed:.2f}s")
        print(f"Requests/s:       {self.stats['sent']/elapsed:.2f}")
        print(f"{'='*60}\n")

def find_latest_jsonl(directory: Path) -> Optional[Path]:
    """Encontra o arquivo JSONL mais recente"""
    jsonl_files = list(directory.glob("PDC_outbound_*.jsonl"))
    if not jsonl_files:
        return None
    return max(jsonl_files, key=lambda p: p.stat().st_mtime)

def main():
    parser = argparse.ArgumentParser(description='Tick Replayer - Replay de dados do EA')
    parser.add_argument('--api-url', default='http://192.168.15.20:18001',
                        help='URL base da API (default: http://192.168.15.20:18001)')
    parser.add_argument('--api-key', default='mt5_trading_secure_key_2025_prod',
                        help='API Key')
    parser.add_argument('--file', type=Path,
                        help='Arquivo JSONL para replay')
    parser.add_argument('--dir', type=Path,
                        help='Diretório para buscar arquivo mais recente')
    parser.add_argument('--speed', type=float, default=1.0,
                        help='Multiplicador de velocidade (default: 1.0)')
    parser.add_argument('--delay', type=float, default=0.1,
                        help='Delay entre requests em segundos (default: 0.1)')
    
    args = parser.parse_args()
    
    # Determinar arquivo
    if args.file:
        filepath = args.file
    elif args.dir:
        filepath = find_latest_jsonl(args.dir)
        if not filepath:
            print("❌ Nenhum arquivo JSONL encontrado no diretório")
            sys.exit(1)
    else:
        # Tentar diretório padrão do MT5
        default_dir = Path.home() / "AppData/Roaming/MetaQuotes/Terminal"
        print(f"🔍 Buscando em: {default_dir}")
        
        # Procurar em todas as instalações MT5
        jsonl_files = list(default_dir.glob("*/MQL5/Files/PDC_outbound_*.jsonl"))
        if not jsonl_files:
            print("❌ Nenhum arquivo JSONL encontrado. Use --file ou --dir")
            sys.exit(1)
        
        filepath = max(jsonl_files, key=lambda p: p.stat().st_mtime)
    
    if not filepath.exists():
        print(f"❌ Arquivo não encontrado: {filepath}")
        sys.exit(1)
    
    # Executar replay
    replayer = TickReplayer(args.api_url, args.api_key, args.speed)
    replayer.replay_file(filepath, args.delay)

if __name__ == '__main__':
    main()
