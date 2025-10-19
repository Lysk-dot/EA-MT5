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
