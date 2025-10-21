#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script para executar queries SQL contra o banco PostgreSQL MT5 Trading
Uso: python query-db.py
"""

import psycopg2
from tabulate import tabulate

# Configuracao do banco
DB_CONFIG = {
    'host': '192.168.15.20',
    'port': 5432,
    'dbname': 'mt5_trading',
    'user': 'trader',
    'password': 'trader123',
    'connect_timeout': 10
}

# Queries disponiveis
QUERIES = {
    '1': {
        'name': 'Ultimos 20 Registros',
        'sql': 'SELECT ts, symbol, timeframe, open, high, low, close, volume FROM market_data ORDER BY ts DESC LIMIT 20;'
    },
    '2': {
        'name': 'Resumo por Simbolo (24h)',
        'sql': "SELECT symbol, COUNT(*) as total, MAX(ts) as ultimo FROM market_data WHERE ts > NOW() - INTERVAL '24 hours' GROUP BY symbol ORDER BY total DESC;"
    },
    '3': {
        'name': 'Latencia de Dados',
        'sql': "SELECT symbol, MAX(ts) as ultimo_dado, EXTRACT(EPOCH FROM (NOW() - MAX(ts)))/60 as minutos_atras FROM market_data GROUP BY symbol ORDER BY minutos_atras ASC;"
    },
    '4': {
        'name': 'Estrutura da Tabela',
        'sql': "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'market_data' ORDER BY ordinal_position;"
    },
    '5': {
        'name': 'Timeline Completa',
        'sql': 'SELECT symbol, MIN(ts) as data_inicio, MAX(ts) as data_fim, COUNT(*) as total_registros FROM market_data GROUP BY symbol ORDER BY data_fim DESC;'
    }
}

def run_query(query_id='1'):
    try:
        # Conectar ao banco
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        # Pegar query
        if query_id not in QUERIES:
            print(f'Query {query_id} nao encontrada')
            return
        
        query_info = QUERIES[query_id]
        print(f'\n>>> Executando: {query_info["name"]}')
        print('=' * 60)
        
        # Executar
        cur.execute(query_info['sql'])
        rows = cur.fetchall()
        colnames = [desc[0] for desc in cur.description]
        
        if len(rows) == 0:
            print('Nenhum resultado encontrado.')
        else:
            print(f'\nResultados encontrados: {len(rows)}\n')
            print(tabulate(rows, headers=colnames, tablefmt='grid', showindex=False))
            print(f'\nTotal de linhas: {len(rows)}')
        
        cur.close()
        conn.close()
        print('\n' + '=' * 60)
        
    except Exception as e:
        print(f'Erro: {e}')

if __name__ == '__main__':
    import sys
    
    print('\n' + '=' * 60)
    print('  MT5 Trading Database - Query Tool')
    print('=' * 60)
    
    # Menu
    print('\nQueries disponiveis:')
    for key in sorted(QUERIES.keys()):
        print(f'  {key} - {QUERIES[key]["name"]}')
    
    # Pegar input
    if len(sys.argv) > 1:
        query_id = sys.argv[1]
    else:
        query_id = input('\nEscolha uma query (1-5): ').strip() or '1'
    
    run_query(query_id)
