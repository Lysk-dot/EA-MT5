# 🔐 Segurança - Externalização do Pepper de Licença

## Problema
O pepper da licença está hardcoded no código fonte do EA:
```mql5
string LIC_PEPPER = "PDC-LIC-2025-$k39"; // segredo leve embutido
```

## Solução

### Opção 1: Variável de Ambiente (Recomendado para scripts)
Para scripts PowerShell (`generate-license.ps1`):

```powershell
# Usar variável de ambiente
$LIC_PEPPER = $env:EA_LICENSE_PEPPER
if ([string]::IsNullOrEmpty($LIC_PEPPER)) {
    throw "❌ EA_LICENSE_PEPPER não definido. Configure: `$env:EA_LICENSE_PEPPER='seu-pepper'"
}
```

Configurar:
```powershell
# Windows - Persistente (System)
[System.Environment]::SetEnvironmentVariable('EA_LICENSE_PEPPER', 'PDC-LIC-2025-$k39', 'Machine')

# Windows - Sessão atual
$env:EA_LICENSE_PEPPER = 'PDC-LIC-2025-$k39'
```

### Opção 2: Arquivo de Configuração Criptografado
Criar arquivo `config/license.conf` (adicionar ao .gitignore):

```ini
[license]
pepper = PDC-LIC-2025-$k39
```

Script para ler:
```powershell
# scripts/get-license-pepper.ps1
$configPath = "$PSScriptRoot/../config/license.conf"
if (!(Test-Path $configPath)) {
    throw "❌ Arquivo de configuração não encontrado"
}

$config = Get-Content $configPath | ConvertFrom-StringData
$pepper = $config['pepper']
```

### Opção 3: GitHub Secrets (para CI/CD)
No GitHub Actions, usar secrets:

```yaml
- name: Generate License
  env:
    LICENSE_PEPPER: ${{ secrets.EA_LICENSE_PEPPER }}
  run: |
    .\generate-license.ps1 -Pepper $env:LICENSE_PEPPER
```

Configurar no GitHub:
1. Settings > Secrets and variables > Actions
2. New repository secret
3. Name: `EA_LICENSE_PEPPER`
4. Value: `PDC-LIC-2025-$k39`

### Opção 4: Azure Key Vault / AWS Secrets Manager (Produção)
Para ambientes enterprise:

```powershell
# Azure Key Vault
Install-Module -Name Az.KeyVault
$pepper = Get-AzKeyVaultSecret -VaultName "ea-mt5-vault" -Name "license-pepper" -AsPlainText

# AWS Secrets Manager
$pepper = (aws secretsmanager get-secret-value --secret-id ea-license-pepper --query SecretString --output text)
```

## Para o EA (MQL5)

**IMPORTANTE**: MQL5 não suporta variáveis de ambiente nativamente.

### Solução Recomendada:
1. **Remover pepper hardcoded do código fonte público**
2. **Usar input criptografado ou ofuscado**
3. **Gerar licenças offline** com pepper seguro

```mql5
// ANTES (inseguro - exposto no código)
string LIC_PEPPER = "PDC-LIC-2025-$k39";

// DEPOIS (pepper não está no código fonte)
// Opção A: Input (usuário final configura)
input string License_Pepper = ""; // deixar vazio no repositório

// Opção B: Hardcoded apenas em build privado
// O GitHub Actions NÃO compila com pepper real
// Build local/privado injeta o pepper durante compilação
```

### Build com Pepper Injetado

Script `compile-with-pepper.ps1`:
```powershell
param(
    [string]$Pepper = $env:EA_LICENSE_PEPPER
)

if ([string]::IsNullOrEmpty($Pepper)) {
    throw "❌ Pepper não fornecido"
}

# Criar versão temporária do .mq5 com pepper
$source = Get-Content "EA/DataCollectorPRO.mq5" -Raw
$withPepper = $source -replace 'string LIC_PEPPER = "";', "string LIC_PEPPER = `"$Pepper`";"

$tempFile = "EA/DataCollectorPRO_build.mq5"
$withPepper | Out-File $tempFile -Encoding UTF8

# Compilar
& "C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"$tempFile"

# Limpar
Remove-Item $tempFile
```

## Migração

### Passo 1: Atualizar .gitignore
```gitignore
# Secrets
config/license.conf
.env
secrets.ps1
*pepper*.txt
```

### Passo 2: Criar arquivo de configuração local
```powershell
# config/license.conf
[license]
pepper = PDC-LIC-2025-$k39
```

### Passo 3: Atualizar scripts
Modificar `generate-license.ps1`:

```powershell
# Carregar pepper de forma segura
if ($env:EA_LICENSE_PEPPER) {
    $LIC_PEPPER = $env:EA_LICENSE_PEPPER
} elseif (Test-Path "$PSScriptRoot/../config/license.conf") {
    $config = Get-Content "$PSScriptRoot/../config/license.conf" | ConvertFrom-StringData
    $LIC_PEPPER = $config['pepper']
} else {
    throw "❌ Pepper não configurado. Use: `$env:EA_LICENSE_PEPPER ou config/license.conf"
}
```

### Passo 4: Atualizar EA (opcional)
Se quiser remover completamente do código:

```mql5
// EA/DataCollectorPRO.mq5
input string License_Pepper = ""; // usuário configura ou build injeta

// Em OnInit()
if (License_Enabled && StringLen(License_Pepper) == 0) {
    Print("❌ License_Pepper não configurado");
    return INIT_FAILED;
}
```

### Passo 5: Documentar
Adicionar em README:

```markdown
## Configuração de Segurança

### Pepper de Licença
O pepper de licença NÃO está incluído no repositório.

**Configurar localmente:**
```powershell
# Opção 1: Variável de ambiente
$env:EA_LICENSE_PEPPER = 'seu-pepper-aqui'

# Opção 2: Arquivo config
echo "[license]`npepper = seu-pepper-aqui" > config/license.conf
```

**Para CI/CD:**
Configure o secret `EA_LICENSE_PEPPER` no GitHub Actions.
```

## Recomendação Final

Para máxima segurança:

1. ✅ **Scripts**: usar variável de ambiente `$env:EA_LICENSE_PEPPER`
2. ✅ **CI/CD**: GitHub Secrets
3. ✅ **EA**: build privado com pepper injetado (não no repo público)
4. ✅ **Produção**: Azure Key Vault ou AWS Secrets Manager
5. ✅ **Git**: adicionar `config/*.conf` ao .gitignore

## Riscos Atuais

⚠️ **CRÍTICO**: Pepper está exposto no código fonte público:
- `generate-license.ps1` linha 37
- `EA/DataCollectorPRO.mq5` linha 62

Qualquer pessoa pode:
- Ver o pepper no GitHub
- Gerar licenças válidas
- Distribuir sem autorização

## Próximos Passos

1. [ ] Criar `config/license.conf` (não versionado)
2. [ ] Atualizar `generate-license.ps1` para ler de env
3. [ ] Adicionar `config/*.conf` ao `.gitignore`
4. [ ] Configurar `EA_LICENSE_PEPPER` no GitHub Secrets
5. [ ] Remover pepper hardcoded do código em próximo commit
6. [ ] Documentar em README de segurança
