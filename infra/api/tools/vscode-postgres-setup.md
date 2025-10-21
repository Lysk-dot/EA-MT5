# Como usar o painel SQL do VS Code com PostgreSQL

## 1️⃣ Extensão Instalada
✅ **PostgreSQL Management Tool** (ckolkman.vscode-postgres) está instalada.

## 2️⃣ Configurar Conexão

### Método 1: Via Command Palette
1. Pressione `Ctrl+Shift+P`
2. Digite: `PostgreSQL: New Query`
3. Selecione `Create Connection Profile`
4. Preencha os dados:
   - **Host**: `192.168.15.20`
   - **Port**: `5432`
   - **Database**: `mt5_trading`
   - **Username**: `trader`
   - **Password**: `trader123`
   - **Profile Name**: `MT5 Trading DB`

### Método 2: Via PostgreSQL Explorer
1. Clique no ícone do **PostgreSQL Explorer** na barra lateral (ícone de elefante 🐘)
2. Clique em `+` para adicionar conexão
3. Preencha os mesmos dados acima

## 3️⃣ Explorar e Consultar

### Ver tabelas
1. Expanda a conexão `MT5 Trading DB`
2. Expanda `Databases` → `mt5_trading` → `Schemas` → `public` → `Tables`
3. Você verá:
   - `market_data` ← Dados de candles OHLCV
   - `market_data_raw` ← Dados brutos
   - `trade_logs`
   - `fills`
   - `signals`
   - `signals_queue`
   - `signals_ack`
   - `aggregator_state`

### Executar queries
1. Clique com botão direito na tabela `market_data`
2. Selecione `New Query` ou `Select Top 1000`
3. Ou crie um novo arquivo `.sql` e execute queries customizadas:

```sql
-- Ver últimos 100 registros de EURUSD
SELECT * FROM market_data 
WHERE symbol = 'EURUSD' 
ORDER BY ts DESC 
LIMIT 100;

-- Contar registros por símbolo
SELECT symbol, COUNT(*) as total, MAX(ts) as ultimo_tick
FROM market_data
GROUP BY symbol
ORDER BY total DESC;

-- Ver dados das últimas 24h
SELECT * FROM market_data
WHERE ts > NOW() - INTERVAL '24 hours'
ORDER BY ts DESC;

-- Análise de volume por hora
SELECT 
    DATE_TRUNC('hour', ts) as hora,
    symbol,
    SUM(volume) as volume_total,
    COUNT(*) as num_candles
FROM market_data
WHERE ts > NOW() - INTERVAL '7 days'
GROUP BY hora, symbol
ORDER BY hora DESC, volume_total DESC;
```

## 4️⃣ Atalhos Úteis

- **Execute Query**: `F5` ou `Ctrl+Enter`
- **Execute Current Statement**: `Ctrl+Shift+E`
- **Format SQL**: `Shift+Alt+F`
- **IntelliSense**: Autocomplete de tabelas e colunas

## 5️⃣ Exportar Resultados

Após executar uma query:
1. Clique com botão direito nos resultados
2. Escolha: `Save as CSV`, `Save as JSON`, ou `Copy`

## 6️⃣ Verificação Rápida

Execute este script para confirmar que tudo está funcionando:

```sql
-- Verificar estrutura da tabela market_data
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'market_data'
ORDER BY ordinal_position;

-- Verificar últimos dados recebidos
SELECT * FROM market_data 
ORDER BY ts DESC 
LIMIT 10;
```

## 📊 Connection String (para referência)
```
postgresql://trader:trader123@192.168.15.20:5432/mt5_trading
```

---

**Dica**: Salve suas queries favoritas em arquivos `.sql` na pasta `infra/api/tools/queries/` para reutilização!
