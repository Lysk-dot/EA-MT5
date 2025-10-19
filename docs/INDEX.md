# EA-MT5 Documentation

Documentação completa do projeto EA-MT5 (Expert Advisor para MetaTrader 5 com pipeline de dados, API e monitoramento).

## 📁 Estrutura da Documentação

```
docs/
├── api/
│   └── STARTUP.md          # Como iniciar a API (com e sem Docker)
├── monitoring/
│   └── MONITORING.md       # Dashboards, alertas, métricas e troubleshooting
├── infra/
│   └── README.md           # Infraestrutura completa (Docker, services)
└── INDEX.md                # Este arquivo (índice geral)
```

## 🚀 Quick Start

1. **Instalar dependências**: Ver [infra/README.md](infra/README.md)
2. **Iniciar API**: Ver [api/STARTUP.md](api/STARTUP.md)
3. **Configurar monitoramento**: Ver [monitoring/MONITORING.md](monitoring/MONITORING.md)

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
