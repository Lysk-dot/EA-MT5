# Scripts Utilitários (`scripts/util/`)

Scripts auxiliares para instalação, testes, integração e manutenção do ambiente EA-MT5. Foram movidos da raiz para manter o repositório mais limpo.

## Lista e Função de Cada Script

- **centralize-logs.ps1**
  - Centraliza logs da API, Relay e MT5 em `logs/central.log` (com rotação automática ~20MB).
  - Uso: manual ou via agendador para facilitar troubleshooting.

- **install-python.ps1**
  - Instala Python 3.12 no Windows, já configurando PATH e pip.
  - Uso: inicialização do ambiente em máquinas novas.

- **send-test-to-main.ps1**
  - Envia um teste manual de candle para a API principal.
  - Uso: validação rápida de ingestão de dados.

- **setup-edge-relay.ps1**
  - Prepara e inicia o Edge Relay local (FastAPI), criando venv, instalando dependências e configurando variáveis.
  - Uso: configuração e troubleshooting do relay.

- **setup-windows-services.ps1**
  - Cria, inicia, para ou remove Scheduled Tasks do Windows para rodar API e Edge Relay como "serviços".
  - Uso: automação de inicialização dos serviços no boot.

- **verify-connectivity.ps1**
  - Testa conectividade com servidor Linux, API e banco de dados (ping, TCP, API health, psql).
  - Uso: diagnóstico de rede e ambiente.

## Como Executar

```powershell
# Exemplo de execução de utilitário
powershell -ExecutionPolicy Bypass -File scripts\util\verify-connectivity.ps1
```

> Consulte este arquivo sempre que precisar de utilitários para setup, diagnóstico ou integração.
