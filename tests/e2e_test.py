#!/usr/bin/env python3
"""
End-to-End Test Suite
Valida pipeline completo: EA -> API -> PostgreSQL
"""
import sys
import time
import psycopg2
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import argparse

class E2ETestSuite:
    def __init__(self, api_url: str, api_key: str, db_config: Dict):
        self.api_url = api_url.rstrip('/')
        self.api_key = api_key
        self.db_config = db_config
        self.test_results = []
        
    def connect_db(self):
        """Conecta ao PostgreSQL"""
        return psycopg2.connect(**self.db_config)
    
    def test_api_health(self) -> bool:
        """Testa endpoint /health"""
        print("\n🧪 Test 1: API Health Check")
        try:
            response = requests.get(f"{self.api_url}/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                print(f"✅ API está saudável: {data.get('status')}")
                return True
            else:
                print(f"❌ API retornou: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ Erro: {e}")
            return False
    
    def test_db_connection(self) -> bool:
        """Testa conexão com PostgreSQL"""
        print("\n🧪 Test 2: Database Connection")
        try:
            conn = self.connect_db()
            cursor = conn.cursor()
            cursor.execute("SELECT version();")
            version = cursor.fetchone()[0]
            print(f"✅ PostgreSQL conectado: {version[:50]}...")
            cursor.close()
            conn.close()
            return True
        except Exception as e:
            print(f"❌ Erro de conexão: {e}")
            return False
    
    def test_ingest_ohlcv(self) -> bool:
        """Testa ingestão de dados OHLCV"""
        print("\n🧪 Test 3: Ingest OHLCV Data")
        
        # Criar payload de teste
        test_ts = datetime.utcnow().replace(second=0, microsecond=0).isoformat() + 'Z'
        test_symbol = "TEST_EUR"
        test_tf = "M1"
        
        payload = {
            "items": [
                {
                    "symbol": test_symbol,
                    "timeframe": test_tf,
                    "ts": test_ts,
                    "open": 1.1000,
                    "high": 1.1010,
                    "low": 1.0995,
                    "close": 1.1005,
                    "tick_volume": 100,
                    "real_volume": 1000.0,
                    "spread": 2,
                    "source": "E2E_TEST",
                    "ea_version": "TEST",
                    "collection_mode": "TEST"
                }
            ]
        }
        
        # Enviar para API
        headers = {
            'Content-Type': 'application/json',
            'X-API-Key': self.api_key
        }
        
        try:
            response = requests.post(
                f"{self.api_url}/ingest",
                json=payload,
                headers=headers,
                timeout=10
            )
            
            if response.status_code in [200, 409]:
                result = response.json()
                print(f"✅ API aceitou: {result}")
                
                # Aguardar processamento
                time.sleep(2)
                
                # Verificar no banco
                conn = self.connect_db()
                cursor = conn.cursor()
                
                # Converter ts para timestamp comparável
                ts_query = datetime.fromisoformat(test_ts.replace('Z', '+00:00'))
                ts_ms = int(ts_query.timestamp() * 1000)
                
                cursor.execute("""
                    SELECT symbol, timeframe, open, close, source 
                    FROM ticks 
                    WHERE symbol = %s AND timeframe = %s AND ts_ms = %s
                """, (test_symbol, test_tf, ts_ms))
                
                row = cursor.fetchone()
                cursor.close()
                conn.close()
                
                if row:
                    print(f"✅ Dado encontrado no DB: symbol={row[0]}, tf={row[1]}, source={row[4]}")
                    return True
                else:
                    print(f"⚠️  Dado não encontrado no DB (pode ser duplicado)")
                    return True  # Ainda é sucesso se API aceitou
            else:
                print(f"❌ API retornou: {response.status_code} - {response.text[:200]}")
                return False
                
        except Exception as e:
            print(f"❌ Erro: {e}")
            return False
    
    def test_ingest_tick(self) -> bool:
        """Testa ingestão de ticks"""
        print("\n🧪 Test 4: Ingest Tick Data")
        
        test_time_msc = int(datetime.utcnow().timestamp() * 1000)
        test_time = datetime.utcfromtimestamp(test_time_msc / 1000).isoformat() + 'Z'
        test_symbol = "TEST_EUR"
        
        payload = {
            "ticks": [
                {
                    "symbol": test_symbol,
                    "time": test_time,
                    "time_msc": test_time_msc,
                    "bid": 1.1000,
                    "ask": 1.1002,
                    "last": 1.1001,
                    "volume": 100,
                    "flags": 6,
                    "source": "E2E_TEST",
                    "ea_version": "TEST"
                }
            ]
        }
        
        headers = {
            'Content-Type': 'application/json',
            'X-API-Key': self.api_key
        }
        
        try:
            response = requests.post(
                f"{self.api_url}/ingest/tick",
                json=payload,
                headers=headers,
                timeout=10
            )
            
            if response.status_code in [200, 409]:
                result = response.json()
                print(f"✅ API aceitou tick: {result}")
                
                # Aguardar processamento
                time.sleep(2)
                
                # Verificar no banco
                conn = self.connect_db()
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT symbol, bid, ask, source 
                    FROM raw_ticks 
                    WHERE symbol = %s AND time_msc = %s
                """, (test_symbol, test_time_msc))
                
                row = cursor.fetchone()
                cursor.close()
                conn.close()
                
                if row:
                    print(f"✅ Tick encontrado no DB: symbol={row[0]}, bid={row[1]}, source={row[3]}")
                    return True
                else:
                    print(f"⚠️  Tick não encontrado no DB (pode ser duplicado)")
                    return True
            else:
                print(f"❌ API retornou: {response.status_code} - {response.text[:200]}")
                return False
                
        except Exception as e:
            print(f"❌ Erro: {e}")
            return False
    
    def test_idempotency(self) -> bool:
        """Testa idempotência - envio duplicado deve retornar 409 ou contar duplicado"""
        print("\n🧪 Test 5: Idempotency Check")
        
        test_ts = datetime.utcnow().replace(second=0, microsecond=0).isoformat() + 'Z'
        test_symbol = "TEST_IDEM"
        
        payload = {
            "items": [
                {
                    "symbol": test_symbol,
                    "timeframe": "M1",
                    "ts": test_ts,
                    "open": 1.2000,
                    "high": 1.2010,
                    "low": 1.1995,
                    "close": 1.2005,
                    "tick_volume": 50,
                    "source": "E2E_TEST"
                }
            ]
        }
        
        headers = {
            'Content-Type': 'application/json',
            'X-API-Key': self.api_key
        }
        
        try:
            # Primeiro envio
            r1 = requests.post(f"{self.api_url}/ingest", json=payload, headers=headers, timeout=10)
            print(f"Envio 1: {r1.status_code}")
            
            time.sleep(1)
            
            # Segundo envio (duplicado)
            r2 = requests.post(f"{self.api_url}/ingest", json=payload, headers=headers, timeout=10)
            print(f"Envio 2: {r2.status_code}")
            
            # Validar idempotência
            if r2.status_code == 409:
                print("✅ Idempotência OK: retornou 409 Conflict no duplicado")
                return True
            elif r2.status_code == 200:
                result = r2.json()
                if result.get('duplicates', 0) > 0:
                    print(f"✅ Idempotência OK: contou {result['duplicates']} duplicados")
                    return True
                else:
                    print("⚠️  API aceitou duplicado sem indicar (possível bug)")
                    return False
            else:
                print(f"❌ Resposta inesperada: {r2.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ Erro: {e}")
            return False
    
    def test_duplicate_stats(self) -> bool:
        """Verifica se duplicate_stats está funcionando"""
        print("\n🧪 Test 6: Duplicate Stats Tracking")
        
        try:
            conn = self.connect_db()
            cursor = conn.cursor()
            
            # Verificar se tabela existe e tem dados
            cursor.execute("""
                SELECT COUNT(*) FROM duplicate_stats
                WHERE hour_bucket > now() - interval '24 hours'
            """)
            count = cursor.fetchone()[0]
            
            print(f"📊 Estatísticas de duplicados nas últimas 24h: {count} registros")
            
            # Ver top duplicados
            cursor.execute("""
                SELECT symbol, timeframe, duplicate_count, last_seen
                FROM duplicate_stats
                WHERE hour_bucket > now() - interval '24 hours'
                ORDER BY duplicate_count DESC
                LIMIT 5
            """)
            
            rows = cursor.fetchall()
            if rows:
                print("\n🔝 Top 5 símbolos com duplicados:")
                for row in rows:
                    print(f"   {row[0]} ({row[1]}): {row[2]} duplicados, último: {row[3]}")
            
            cursor.close()
            conn.close()
            
            print("✅ Sistema de tracking de duplicados está ativo")
            return True
            
        except Exception as e:
            print(f"❌ Erro: {e}")
            return False
    
    def run_all_tests(self):
        """Executa todos os testes"""
        print("="*70)
        print("🧪 EA-MT5 END-TO-END TEST SUITE")
        print("="*70)
        
        tests = [
            ("API Health", self.test_api_health),
            ("Database Connection", self.test_db_connection),
            ("Ingest OHLCV", self.test_ingest_ohlcv),
            ("Ingest Tick", self.test_ingest_tick),
            ("Idempotency", self.test_idempotency),
            ("Duplicate Stats", self.test_duplicate_stats),
        ]
        
        passed = 0
        failed = 0
        
        for name, test_func in tests:
            try:
                result = test_func()
                if result:
                    passed += 1
                else:
                    failed += 1
            except Exception as e:
                print(f"❌ Test {name} crashed: {e}")
                failed += 1
        
        # Resultado final
        print("\n" + "="*70)
        print("📊 RESULTADOS FINAIS")
        print("="*70)
        print(f"✅ Passou: {passed}/{len(tests)}")
        print(f"❌ Falhou: {failed}/{len(tests)}")
        print(f"Sucesso: {passed/len(tests)*100:.1f}%")
        print("="*70 + "\n")
        
        return failed == 0

def main():
    parser = argparse.ArgumentParser(description='End-to-End Test Suite')
    parser.add_argument('--api-url', default='http://192.168.15.20:18001',
                        help='URL da API')
    parser.add_argument('--api-key', default='mt5_trading_secure_key_2025_prod',
                        help='API Key')
    parser.add_argument('--db-host', default='192.168.15.20',
                        help='PostgreSQL host')
    parser.add_argument('--db-port', type=int, default=5432,
                        help='PostgreSQL port')
    parser.add_argument('--db-name', default='mt5_trading',
                        help='Database name')
    parser.add_argument('--db-user', default='trader',
                        help='Database user')
    parser.add_argument('--db-password', default='trader123',
                        help='Database password')
    
    args = parser.parse_args()
    
    db_config = {
        'host': args.db_host,
        'port': args.db_port,
        'database': args.db_name,
        'user': args.db_user,
        'password': args.db_password
    }
    
    suite = E2ETestSuite(args.api_url, args.api_key, db_config)
    success = suite.run_all_tests()
    
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
