# Scripts de Automação e Saúde do Repositório

Scripts PowerShell para compilar, verificar e manter a saúde do repositório EA-MT5.

## 📜 Scripts Disponíveis

### compile-ea.ps1
Compila o EA via MetaEditor automaticamente.

**Uso:**
```powershell
.\compile-ea.ps1
.\compile-ea.ps1 -MetaEditorPath "C:\Program Files\MetaTrader 5\metaeditor64.exe" -FailOnError -ShowLog
```

**Flags:**
- `-EAPath`: Caminho do .mq5 (default: EA/DataCollectorPRO.mq5)
- `-MetaEditorPath`: Caminho do metaeditor64.exe (auto-detecta se omitido)
- `-FailOnError`: Retorna exit code ≠ 0 em falhas
- `-ShowLog`: Imprime log de compilação

---

### verify-ea-data.ps1
Verificação completa: EA local + API + dados recentes.

**Uso:**
```powershell
.\verify-ea-data.ps1
.\verify-ea-data.ps1 -RunCompileCheck -ExpectedPdcVer 1.65 -ExpectedApiBase http://192.168.15.20:18001 -TestTick -FailOnMismatch
```

**Flags:**
- `-RunCompileCheck`: Compila o EA antes de verificar
- `-ExpectedPdcVer`: Versão esperada (PDC_VER)
- `-MaxBinaryAgeMinutes`: Idade máxima do .ex5 (default: 1440 = 24h)
- `-ExpectedApiBase`: Base da API esperada
- `-TestTick`: Envia tick de teste para /ingest/tick
- `-MetaEditorPath`: Caminho do MetaEditor
- `-ShowCompileLog`: Imprime log de compilação
- `-FailOnMismatch`: Exit code ≠ 0 em divergências

**O que verifica:**
1. EA/DataCollectorPRO.mq5 existe e PDC_VER
2. Binário .ex5 atualizado e idade
3. API_URL, API_Tick_URL, API_Key (mascarado)
4. Health check do servidor
5. Envio de candle de teste
6. Dados recentes (últimos 10 símbolos)
7. Opcional: teste de tick

---

### repo-health.ps1
Checa saúde do repositório: EOL, trailing spaces, BOM, linhas longas, refs antigas.

**Uso:**
```powershell
.\repo-health.ps1
.\repo-health.ps1 -Fix
```

**Flags:**
- `-Fix`: Corrige automaticamente problemas (EOL, BOM)
- `-MaxEALineLen`: Comprimento máximo de linha em .mq5 (default: 180)

**Checagens:**
- EOL normalization (CRLF para Windows)
- Trailing spaces e TABs indesejados
- BOM em scripts PowerShell (remove com -Fix)
- Linhas muito longas em .mq5
- Referências obsoletas (Data/ → EA/)
- .gitattributes presente

---

### release-bump.ps1
Automação completa de release: bump versão + compile + verify + commit + tag.

**Uso:**
```powershell
.\release-bump.ps1 -CreateTag
.\release-bump.ps1 -CreateTag -MetaEditorPath "C:\Program Files\MetaTrader 5\metaeditor64.exe"
.\release-bump.ps1 -SkipCommit -CreateTag
```

**Flags:**
- `-CreateTag`: Cria tag git após bump
- `-SkipCommit`: Não faz commit automático
- `-MetaEditorPath`: Caminho do MetaEditor

**Fluxo:**
1. Incrementa PDC_VER (+0.01)
2. Compila o EA
3. Roda verify + repo-health
4. Commit automático (se não usar -SkipCommit)
5. Cria tag v{versão} (se usar -CreateTag)

---

### setup-precommit.ps1
Configura hook pre-commit para rodar compile + verify + health antes de cada commit.

**Uso:**
```powershell
.\setup-precommit.ps1 -ExpectedPdcVer 1.65
.\setup-precommit.ps1 -ExpectedPdcVer 1.65 -MetaEditorPath "C:\Program Files\MetaTrader 5\metaeditor64.exe" -Overwrite
```

**Flags:**
- `-ExpectedPdcVer`: Versão esperada para verificação
- `-MetaEditorPath`: Caminho do MetaEditor
- `-Overwrite`: Substitui hook existente

**O que o hook faz:**
1. compile-ea.ps1 -FailOnError
2. verify-ea-data.ps1 -RunCompileCheck -FailOnMismatch
3. repo-health.ps1

---

### rollback-version.ps1 🔄
Reverte PDC_VER para versão anterior ou específica.

**Uso:**
```powershell
# Rollback interativo (escolhe do histórico)
.\rollback-version.ps1

# Rollback para versão específica
.\rollback-version.ps1 -TargetVersion "1.64"

# Rollback forçado (ignora mudanças não commitadas)
.\rollback-version.ps1 -TargetVersion "1.63" -Force
```

**Fluxo:**
1. Verifica git status (bloqueia se houver mudanças não commitadas)
2. Lista últimas 10 tags/versões disponíveis
3. Detecta versão atual no EA
4. Solicita/confirma versão alvo
5. Atualiza `PDC_VER` e `#property version`
6. Compila EA (se compile-ea.ps1 disponível)
7. Cria commit de rollback

**Após rollback:**
```powershell
.\verify-ea-data.ps1 -ExpectedPdcVer "1.64"  # Verificar
# Testar no MT5
git push origin main  # Se ok
git reset --hard HEAD~1  # Se erro (reverter rollback)
```

**Cenários de uso:**
- 🐛 Bug crítico descoberto em produção
- ⏮️ Reversão rápida para versão estável
- 🧪 Teste comparativo entre versões

---

### setup-grafana-dashboards.ps1 📊
Gerencia dashboards Grafana para monitoramento avançado do EA.

**Uso:**
```powershell
# Exportar templates JSON
.\setup-grafana-dashboards.ps1 -Export

# Importar para Grafana (requer token)
$env:GRAFANA_TOKEN = "glsa_xxx..."
.\setup-grafana-dashboards.ps1 -Import

# Customizar URL do Grafana
.\setup-grafana-dashboards.ps1 -Import -GrafanaUrl "http://10.0.0.5:3000" -GrafanaToken "token"
```

**Dashboards incluídos:**

#### 1. EA Health (`dashboards/ea-health.json`)
Visão geral de saúde e performance do sistema:
- 📊 **Instâncias Ativas**: Contas únicas que enviaram dados nas últimas 24h
- 📈 **Taxa de Duplicatas**: Gauge indicando % de duplicatas (alerta mercado fechado)
- ⚡ **Requisições por Minuto**: Timeseries com total de requests vs inserts
- 🏷️ **Versões em Produção**: Tabela mostrando PDC versions ativas e última atividade
- 📊 **Top Símbolos**: Barchart com os 10 símbolos mais operados
- 🌐 **IPs de Origem**: Auditoria de source IPs por conta

#### 2. Market Activity Analysis - AI (`dashboards/market-activity.json`)
Análise inteligente de padrões de mercado:
- 🔥 **Heatmap Duplicatas**: Taxa de duplicatas por hora/dia da semana (identifica horários de mercado fechado)
- 🚨 **Detecção Mercado Fechado**: Gráfico com threshold de 80% duplicatas (flag binary: 0 = aberto, 1 = fechado)
- ⏱️ **Gaps de Dados**: Tabela com gaps >5 min sem dados (possíveis problemas)
- 🤖 **Dataset para ML**: Tabela com features agregadas (5min buckets) para treinar modelos de IA
  - Features: `time`, `total`, `duplicates`, `inserts`, `dup_rate`, `hour`, `dow`, `symbols`
  - Exportar CSV: Painel → ... → Inspect → Data → Download CSV
  - Use para: Random Forest, XGBoost, LSTM para prever horários de mercado fechado

#### 3. Performance by Account (`dashboards/performance.json`)
Monitoramento por conta individual:
- 📋 **Performance por Conta**: Tabela com métricas detalhadas (requests, inserts, dup_rate%, símbolos, first/last seen)
- 🔴 **Alertas Offline**: Contas que não enviam dados há >10 minutos (possível crash/desconexão)
- 🔍 **Auditoria IPs**: Contas com múltiplos IPs (possível duplicação de EAs ou VPS migration)

**Configurar token Grafana:**
1. Acesse: `http://192.168.15.20:3000/org/apikeys`
2. Clique "Add API key"
3. Name: `ea-dashboard-import`, Role: **Admin** ou **Editor**
4. Copie token gerado: `glsa_xxxxxxxxxx`
5. Configure: `$env:GRAFANA_TOKEN = "glsa_xxx"`

**Tecnologias usadas:**
- **TimescaleDB**: `time_bucket()` para agregação temporal eficiente
- **Regex SQL**: `regexp_match(user_agent, 'Account:(\d+)')` para extrair Account/Server/PDC_VER
- **Window Functions**: `LAG()` para detectar gaps entre registros
- **Filtros**: `COUNT(*) FILTER (WHERE was_duplicate)` para agregações condicionais

**Configurar alertas:**
1. Abrir dashboard → Painel desejado → Edit
2. Alert tab → Create alert rule
3. Exemplos:
   - **Conta offline**: `offline_duration > 10 minutes`
   - **Taxa duplicatas alta**: `dup_rate > 90%` (mercado provavelmente fechado)
   - **Múltiplos IPs**: `ip_count > 2` (possível duplicação)

**Machine Learning workflow:**
```powershell
# 1. Exportar dataset
.\setup-grafana-dashboards.ps1 -Export
# 2. Importar dashboards
.\setup-grafana-dashboards.ps1 -Import
# 3. Acessar "Market Activity Analysis" → "Dataset para ML"
# 4. Exportar CSV (Inspect → Data → Download)
# 5. Treinar modelo (Python exemplo):
```

```python
import pandas as pd
from sklearn.ensemble import RandomForestClassifier

df = pd.read_csv('market_dataset.csv')
df['market_closed'] = (df['dup_rate'] > 80).astype(int)

X = df[['hour', 'dow', 'symbols', 'total', 'duplicates']]
y = df['market_closed']

model = RandomForestClassifier()
model.fit(X, y)
# Predict se mercado estará fechado baseado em features
```

---

## 🎯 VS Code Tasks

Todas as operações podem ser executadas via Command Palette (`Ctrl+Shift+P` → `Tasks: Run Task`):

- **Compile EA**: Compila o EA com logs
- **Verify Full (strict)**: Verificação completa com todos os checks
- **Verify Quick (no compile)**: Verificação rápida sem compilar
- **Repo Health Check**: Checa saúde do repositório
- **Repo Health Fix**: Checa e corrige automaticamente
- **Release Bump (minor)**: Bump de versão + tag
- **Setup Pre-commit Hook**: Instala hook de pre-commit
- **Rollback Version (interactive)**: Reverte versão do EA
- **Setup Grafana Dashboards (export)**: Exporta templates JSON dos dashboards

**Atalhos:**
- `Ctrl+Shift+B`: Abre menu de builds (Compile EA)
- `Ctrl+Shift+T`: Abre menu de testes (Verify Full)

---

## 🔄 Fluxo de Trabalho Recomendado

### Desenvolvimento Diário
```powershell
# Antes de começar
.\verify-ea-data.ps1

# Durante desenvolvimento (opcional)
.\compile-ea.ps1 -FailOnError

# Antes de commit
.\repo-health.ps1
.\verify-ea-data.ps1 -RunCompileCheck -ExpectedPdcVer 1.65 -FailOnMismatch
```

### Release
```powershell
# Bump automático + tag
.\release-bump.ps1 -CreateTag

# Enviar para remote
git push origin main --tags
```

### Rollback de Emergência
```powershell
# Bug crítico em produção
.\rollback-version.ps1 -TargetVersion "1.64" -Force

# Testar rollback
.\verify-ea-data.ps1 -ExpectedPdcVer "1.64"

# Push se ok
git push origin main
```

### Configuração Inicial
```powershell
# 1. Instalar pre-commit hook (recomendado)
.\setup-precommit.ps1 -ExpectedPdcVer 1.65 -Overwrite

# 2. Configurar dashboards Grafana
.\setup-grafana-dashboards.ps1 -Export
$env:GRAFANA_TOKEN = "glsa_xxx"
.\setup-grafana-dashboards.ps1 -Import

# 3. Verificar tudo funciona
.\verify-ea-data.ps1 -RunCompileCheck -TestTick -FailOnMismatch
```

---

## 📝 Notas

- Scripts requerem **PowerShell 5.1+**
- Executar da raiz do projeto
- MetaEditor é auto-detectado se não especificado
- API Key é mascarada nos logs (segurança)
- Use `-FailOnError`/`-FailOnMismatch` para CI/CD strict
- Dashboards Grafana requerem **TimescaleDB** e schema compatível
- Token Grafana deve ter role **Admin** ou **Editor**

---

## 🔧 Troubleshooting

**MetaEditor não encontrado:**
```powershell
.\compile-ea.ps1 -MetaEditorPath "C:\Program Files\MetaTrader 5\metaeditor64.exe"
```

**Verificar versão esperada:**
```powershell
$env:PDC_EXPECTED_VER = '1.65'
.\verify-ea-data.ps1 -FailOnMismatch
```

**Hook não executa:**
- Certifique-se de rodar `.\setup-precommit.ps1 -Overwrite`
- Verifique se `.git/hooks/pre-commit` existe e tem permissão de execução

**Grafana: Unauthorized (401):**
- Token expirado ou role insuficiente
- Recriar token em `http://192.168.15.20:3000/org/apikeys` com role **Admin**

**Dashboard queries falham:**
- Verificar schema TimescaleDB: `ingest_log` table existe?
- User-Agent regex: certifique-se que EA envia formato correto
- Time bucket: `time_bucket()` requer extension TimescaleDB

**Rollback: PDC_VER não encontrado:**
- Certifique-se que EA tem `#define PDC_VER "x.xx"`
- Usar aspas duplas no define

---

## 🚀 Próximos Passos (Opcionais)

- **CI/CD**: GitHub Actions para build/deploy automático
- **Alertas**: Slack/Discord notifications via Grafana webhooks
- **Machine Learning**: Modelo preditivo para otimização de trading baseado em padrões de mercado
- **Dashboard Avançado**: Custom panels com D3.js para visualizações específicas
- **API Monitoring**: Prometheus exporter para métricas de API em tempo real
