# Scripts de Automação

Scripts PowerShell para automação de tarefas do projeto EA-MT5.

## 📜 Scripts Disponíveis

### bump-ea-version.ps1
Incrementa automaticamente a versão do EA no código MQL5.

**Uso:**
```powershell
.\docs\scripts\bump-ea-version.ps1
```

**O que faz:**
- Busca `#define EA_VERSION` no código
- Incrementa o último dígito (+0.01)
- Atualiza o arquivo automaticamente
- Exemplo: `1.63` → `1.64`

### generate-docs.ps1
Gera documentação automática do projeto.

**Uso:**
```powershell
.\docs\scripts\generate-docs.ps1
```

**O que faz:**
- Escaneia todos os arquivos .mq5
- Extrai comentários de documentação
- Gera README.md atualizado
- Lista inputs e funcionalidades

## 🔄 Automação com Git Hooks

Para rodar automaticamente a cada commit, adicione ao `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Auto-bump version
powershell.exe -File "docs/scripts/bump-ea-version.ps1"

# Regenerate docs
powershell.exe -File "docs/scripts/generate-docs.ps1"

# Stage changes
git add EA/*.mq5 README.md
```

## 📝 Notas

- Scripts requerem PowerShell 5.1+
- Executar da raiz do projeto
- Fazem backup antes de modificar arquivos

# Organização dos Scripts PowerShell

Todos os scripts `.ps1` que estavam na raiz do repositório foram organizados na pasta `scripts/`.

## Lista de scripts migrados

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

## Como usar

Execute os scripts diretamente da pasta `scripts/` ou ajuste seus comandos para apontar para o novo local:

```powershell
# Exemplo de execução
powershell -ExecutionPolicy Bypass -File scripts\compile-ea.ps1
```

> Os scripts originais na raiz agora apenas redirecionam para a versão organizada.

## Recomendações
- Atualize qualquer documentação ou automação que referencie scripts na raiz para usar o novo caminho.
- Consulte este README para saber a função de cada script.
