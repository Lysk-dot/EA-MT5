# 📚 Como Usar as Queries SQL com PostgreSQL no VS Code

## 🔌 Passo 1: Conectar ao Banco de Dados

### Opção A: Via PostgreSQL Explorer (Recomendado)
1. **Abra o PostgreSQL Explorer**:
   - Clique no ícone 🐘 (elefante) na barra lateral esquerda do VS Code
   - Ou pressione `Ctrl+Shift+P` e digite: `PostgreSQL: Focus on PostgreSQL View`

2. **Adicione uma nova conexão**:
   - Clique no ícone `+` (Add Connection) no topo do painel PostgreSQL
   - Ou clique com botão direito no espaço vazio → `Add Connection`

3. **Preencha os dados da conexão**:
   ```
   Host: 192.168.15.20
   Port: 5432
   Database: mt5_trading
   Username: trader
   Password: trader123
   Use SSL: No
   Connection Name: MT5 Trading DB
   ```

4. **Salve a conexão**:
   - Clique em `Save` ou pressione `Enter`
   - A conexão aparecerá no painel PostgreSQL Explorer

### Opção B: Via Command Palette
1. Pressione `Ctrl+Shift+P`
2. Digite: `PostgreSQL: Add Connection`
3. Preencha os mesmos dados acima

---

## 📂 Passo 2: Abrir e Executar Queries

### Método 1: Executar Query do Arquivo SQL
1. **Abra o arquivo SQL** que deseja executar:
   - `MT5-Trading-Analysis.sql` (principal, 10 queries)
   - `01-verificacao-basica.sql`
   - `02-analise-volume.sql`
   - `03-monitoramento-pipeline.sql`

2. **Conecte o arquivo ao banco**:
   - No topo do arquivo, você verá uma barra com `Select a connection`
   - Clique nela e selecione: `MT5 Trading DB`

3. **Execute a query**:
   - **Executar tudo**: Pressione `F5`
   - **Executar seleção**: Selecione o bloco SQL desejado → Pressione `F5`
   - **Executar linha atual**: Posicione o cursor → Pressione `F5`

### Método 2: Via Explorer de Tabelas
1. **Expanda a conexão** no PostgreSQL Explorer:
   ```
   MT5 Trading DB
   └── Databases
       └── mt5_trading
           └── Schemas
               └── public
                   └── Tables
                       ├── market_data
                       ├── market_data_raw
                       ├── trade_logs
                       ├── fills
                       ├── signals
                       └── ...
   ```

2. **Ações rápidas na tabela**:
   - Clique com **botão direito** em `market_data`
   - Opções disponíveis:
     - `Select Top 100` - Ver primeiras 100 linhas
     - `New Query` - Criar query customizada
     - `Refresh` - Atualizar estrutura da tabela

### Método 3: Nova Query do Zero
1. Clique com **botão direito** na conexão `MT5 Trading DB`
2. Selecione `New Query`
3. Um novo arquivo SQL será criado já conectado ao banco
4. Digite sua query e pressione `F5`

---

## ⌨️ Atalhos Úteis

| Ação | Atalho |
|------|--------|
| Executar Query | `F5` |
| Executar Query Selecionada | `Ctrl+Shift+E` (pode variar) |
| Formatar SQL | `Shift+Alt+F` |
| Comentar/Descomentar | `Ctrl+/` |
| Salvar Arquivo | `Ctrl+S` |
| Novo Query | `Ctrl+Alt+Q` (após conectar) |

---

## 📊 Passo 3: Visualizar Resultados

### Painel de Resultados
Após executar uma query (F5), os resultados aparecem em um painel na parte inferior:

1. **Abas de Resultados**:
   - Se você executou múltiplas queries, cada uma terá uma aba
   - Navegue entre elas clicando nas abas

2. **Ações nos Resultados**:
   - **Copiar**: Selecione linhas → `Ctrl+C`
   - **Exportar como CSV**: Clique com botão direito → `Save as CSV`
   - **Exportar como JSON**: Clique com botão direito → `Save as JSON`
   - **Copiar como Markdown**: Clique com botão direito → `Copy as Markdown`

3. **Ordenação e Filtros**:
   - Clique no cabeçalho da coluna para ordenar
   - Use a barra de pesquisa no topo para filtrar resultados

---

## 🎯 Exemplo Prático: Executando MT5-Trading-Analysis.sql

### Passo a Passo Completo:

1. **Abra o arquivo**:
   ```
   Ctrl+P → Digite: MT5-Trading-Analysis.sql → Enter
   ```

2. **Conecte ao banco**:
   - No topo do editor, clique na barra que diz `Select a connection`
   - Escolha: `MT5 Trading DB`
   - ✅ Você verá "Connected to MT5 Trading DB" no status

3. **Execute uma query específica**:
   - Role até a seção desejada, por exemplo: `2️⃣ ÚLTIMOS 20 REGISTROS`
   - Selecione todo o bloco SQL (da linha `SELECT` até o `;`)
   - Pressione `F5`

4. **Veja os resultados**:
   - O painel de resultados abrirá automaticamente na parte inferior
   - Você verá as colunas: `ts`, `symbol`, `timeframe`, `open`, `high`, `low`, `close`, `volume`
   - Os dados estarão ordenados por timestamp (mais recentes primeiro)

5. **Exportar resultados** (opcional):
   - Clique com botão direito nos resultados
   - Escolha `Save as CSV` ou `Save as JSON`
   - Salve onde preferir

---

## 🔍 Queries Prontas para Usar

### 1. Ver Últimos Dados
```sql
SELECT * FROM market_data 
ORDER BY ts DESC 
LIMIT 20;
```

### 2. Contar Registros por Símbolo
```sql
SELECT symbol, COUNT(*) as total
FROM market_data
GROUP BY symbol
ORDER BY total DESC;
```

### 3. Dados Recentes (Últimas 24h)
```sql
SELECT symbol, COUNT(*) as candles_24h
FROM market_data
WHERE ts > NOW() - INTERVAL '24 hours'
GROUP BY symbol
ORDER BY candles_24h DESC;
```

### 4. Verificar Latência
```sql
SELECT 
    symbol,
    MAX(ts) as ultimo_dado,
    EXTRACT(EPOCH FROM (NOW() - MAX(ts)))/60 as minutos_atras
FROM market_data
GROUP BY symbol
ORDER BY minutos_atras ASC;
```

---

## 🛠️ Troubleshooting

### Problema: "No connection selected"
**Solução**: Clique na barra no topo do editor SQL e selecione `MT5 Trading DB`

### Problema: "Connection failed"
**Solução**: 
1. Verifique se o servidor PostgreSQL está rodando: `192.168.15.20:5432`
2. Teste a conexão com o verifier:
   ```powershell
   .\infra\api\tools\run-verify-sql.ps1
   ```

### Problema: "Syntax error near..."
**Solução**: 
1. Certifique-se de selecionar TODO o bloco SQL (incluindo o `;` final)
2. Não execute comentários (`--`) sem código SQL

### Problema: Query muito lenta
**Solução**:
1. Adicione `LIMIT` para reduzir resultados
2. Use `WHERE` para filtrar por timestamp recente
3. Exemplo otimizado:
   ```sql
   SELECT * FROM market_data 
   WHERE ts > NOW() - INTERVAL '1 hour'
   LIMIT 100;
   ```

---

## 🎓 Dicas Avançadas

### 1. Executar Múltiplas Queries em Sequência
Selecione várias seções e pressione `F5` - cada query gerará uma aba de resultados separada.

### 2. Salvar Queries Favoritas
Crie novos arquivos `.sql` para queries que você usa frequentemente:
```
queries/
  ├── favorites/
  │   ├── eurusd-last-100.sql
  │   ├── daily-summary.sql
  │   └── volume-analysis.sql
```

### 3. Usar Variáveis (PostgreSQL)
```sql
-- Definir variável
SET my_symbol = 'EURUSD';

-- Usar variável
SELECT * FROM market_data 
WHERE symbol = current_setting('my_symbol')
LIMIT 10;
```

### 4. Criar Views para Queries Frequentes
```sql
CREATE VIEW v_latest_data AS
SELECT * FROM market_data
WHERE ts > NOW() - INTERVAL '24 hours';

-- Agora use a view:
SELECT * FROM v_latest_data WHERE symbol = 'EURUSD';
```

---

## 📞 Recursos Adicionais

- **Connection String** (para referência):
  ```
  postgresql://trader:trader123@192.168.15.20:5432/mt5_trading
  ```

- **Script de Verificação**:
  ```powershell
  .\infra\api\tools\run-verify-sql.ps1
  ```

- **Documentação PostgreSQL**:
  - [Funções de Data/Hora](https://www.postgresql.org/docs/current/functions-datetime.html)
  - [Funções de Agregação](https://www.postgresql.org/docs/current/functions-aggregate.html)

---

🎉 **Pronto!** Agora você tem acesso completo ao banco de dados MT5 Trading direto do VS Code!
