# 🗂️ EA-MT5 Documentation Index

Documentação completa do projeto EA-MT5 (Expert Advisor para MetaTrader 5 com pipeline de dados, API e monitoramento).

## ⭐ DOCUMENTOS PRINCIPAIS (COMECE AQUI)

### 1. [README-COMPLETO.md](./README-COMPLETO.md) 🎯
**Guia completo do sistema** - Leia primeiro!
- Visão geral e arquitetura
- Todos os componentes explicados
- Configuração passo a passo
- Uso diário
- Troubleshooting completo

### 2. [DATA-FLOW.md](./DATA-FLOW.md) 📊
**Como os dados fluem pelo sistema**
- MT5 → SQLite Local → PostgreSQL Servidor
- Comandos de exportação
- Opções de automação

### 3. [queries/README-COMO-USAR.md](../infra/api/tools/queries/README-COMO-USAR.md) 🔍
**Guia de análise SQL**
- Conectar PostgreSQL no VS Code
- Queries prontas
- Exportar resultados

---

## 📁 Estrutura da Documentação

```
docs/
├── INDEX.md                    ← Você está aqui
├── README-COMPLETO.md          ← ⭐ COMECE AQUI
├── DATA-FLOW.md                ← Fluxo de dados
├── api/
│   ├── MT5-INTEGRATION.md      # Integração MT5 ↔ API
│   ├── STARTUP.md              # Como iniciar APIs
│   ├── TRACKING-SYSTEM.md      # Sistema de rastreamento
│   └── VERIFICATION-REPORT.md  # Relatórios de verificação
├── monitoring/
│   └── MONITORING.md           # Dashboards e alertas
├── infra/
│   ├── README.md               # Infraestrutura Docker
│   ├── BACKUP-REPLICATION.md   # Backup e replicação
│   ├── SECURITY-HARDENING.md   # Segurança
│   └── MARKET-ACTIVITY-ANALYSIS.md
├── scripts/
│   ├── AUTOMATION.md           # Scripts de automação
│   └── README.md
└── CHANGELOG-TRACKING.md       # Histórico de mudanças

infra/api/tools/
├── queries/
│   ├── README-COMO-USAR.md           ← Guia SQL
│   ├── MT5-Trading-Analysis.sql      ← 10 queries prontas
│   ├── 01-verificacao-basica.sql
│   ├── 02-analise-volume.sql
│   └── 03-monitoramento-pipeline.sql
├── export_to_main.py                 ← Exportador de dados
├── query-db.py                       ← Query tool Python
├── query.ps1                         ← Wrapper PowerShell
├── run-exporter.ps1                  ← Executar export
└── run-verify-sql.ps1                ← Verificar sistema
```

## 🚀 Quick Start

### Para Iniciantes:
1. Leia [README-COMPLETO.md](./README-COMPLETO.md)
2. Configure VS Code: [vscode-postgres-setup.md](../infra/api/tools/vscode-postgres-setup.md)
3. Execute primeira query: `python infra\api\tools\query-db.py 1`

### Para Uso Diário:
```powershell
# Exportar dados coletados
cd infra\api\tools
.\run-exporter.ps1

# Ver dados no servidor
python query-db.py 1

# Verificar saúde do sistema
.\run-verify-sql.ps1
```

## 📚 Documentos Principais

### [API Startup Guide](api/STARTUP.md)
- ✅ Como rodar sem Docker (Windows Server 2019)
- 🐳 Como rodar com Docker (após atualizar hardware)
- 🧪 Testes de endpoints
- 🔧 Troubleshooting

### [MT5 Integration Guide](api/MT5-INTEGRATION.md)
- 📡 Configuração do EA para conectar ao servidor Linux
- 💻 Código MQL5 completo e pronto para uso
- 🔐 Autenticação e endpoints
- 🧪 Testes de validação
- 🔍 Troubleshooting completo

### [Monitoring Guide](monitoring/MONITORING.md)
- 📊 Dashboards Grafana (API Overview, Pipeline Health, TimescaleDB)
- 🚨 Alertas configurados e severidades
- 📈 Métricas disponíveis (Prometheus)
- 🎯 SLOs recomendados
- 🔔 Configuração de notificações (email/Slack)

### [Infrastructure Guide](infra/README.md)
- 🐳 Docker Compose (API, DB, Grafana, Prometheus, pgAdmin)
- 🗄️ TimescaleDB setup
- 🔐 Configuração de segurança (.env)
- 🌐 Networking e portas

## 🛠️ Componentes do Sistema

### Expert Advisor (MQL5)
- **DataCollectorPRO.mq5**: EA principal com coleta de ticks/candles
- Auto-versionamento
- Licenciamento
- Dedupe local
- Forward para API

### API (FastAPI)
- Ingest de dados (single/batch)
- Forward para servidor remoto
- Confirmação de dados
- Métricas Prometheus
- Audit trail completo

### Monitoramento
- **Grafana**: Dashboards interativos
- **Prometheus**: Coleta de métricas
- **Alertas**: 11 regras configuradas
- **pgAdmin**: Interface web para PostgreSQL

### Database
- **TimescaleDB**: Time-series otimizado
- Hypertables para performance
- Índices otimizados
- Audit de forwards

## 🗂️ Scripts PowerShell Organizados

Todos os scripts `.ps1` que estavam na raiz do repositório foram migrados para a pasta `scripts/` para melhor organização.

**Lista de scripts migrados:**
- auto-commit.ps1
- bump-version.ps1
- compile-ea.ps1
- generate-license.ps1
- manage-observability.ps1
- monitor-mt5-journal.ps1
- move-repo-to-mql5.ps1
- notify-push-email.ps1
- query-observability.ps1
- quick-license.ps1
- release-bump.ps1
- repo-health.ps1
- rollback-version.ps1
- setup-autocommit.ps1
- setup-grafana-dashboards.ps1
- setup-precommit.ps1
- sync-mt5-webrequest.ps1
- verify-ea-data.ps1
- write-structured-log.ps1

**Como usar:**
Execute os scripts diretamente da pasta `scripts/`:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\compile-ea.ps1
```

> Os scripts originais na raiz agora apenas redirecionam para a versão organizada.

Consulte também `docs/scripts/README.md` para detalhes e recomendações.

## 🔗 Links Úteis

### Após subir containers:
- **API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **pgAdmin**: http://localhost:5050 (admin@admin.com/admin)

### Repositório:
- **GitHub**: https://github.com/Lysk-dot/EA-MT5

## 📝 Changelog

### v0.3 (18/10/2025)
- ✅ API completa com todos endpoints
- ✅ Monitoramento avançado (11 alertas)
- ✅ 3 dashboards Grafana
- ✅ Setup sem Docker para Windows Server 2019
- ✅ Documentação completa

### v0.2
- Infraestrutura Docker
- Pipeline de dados com audit
- Métricas Prometheus básicas

### v0.1
- EA DataCollectorPRO
- Auto-versionamento
- Licenciamento

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/amazing`)
3. Commit suas mudanças (`git commit -m 'feat: add amazing feature'`)
4. Push para a branch (`git push origin feature/amazing`)
5. Abra um Pull Request

## 📄 Licença

Proprietário: Lysk-dot
Repositório: EA-MT5
