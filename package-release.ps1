<#
.SYNOPSIS
    Cria pacote de release versionado do EA-MT5

.DESCRIPTION
    Gera artefato .zip com EA compilado, documentação, licenças e instruções de instalação.
    Inclui versioning automático baseado em git tags ou manual.

.PARAMETER Version
    Versão do release (ex: 1.65). Se não fornecido, extrai do EA ou git tag.

.PARAMETER OutputDir
    Diretório de saída para o pacote (padrão: ./release)

.PARAMETER IncludeLicenses
    Incluir licenças geradas na pasta licenses/

.PARAMETER Minimal
    Cria pacote mínimo (apenas EA e README curto)

.EXAMPLE
    .\package-release.ps1 -Version 1.65

.EXAMPLE
    .\package-release.ps1 -Minimal
#>

[CmdletBinding()]
param(
    [string]$Version = "",
    [string]$OutputDir = "release",
    [switch]$IncludeLicenses,
    [switch]$Minimal
)

$ErrorActionPreference = "Stop"

# ============================================
# Configuração
# ============================================

$EA_NAME = "DataCollectorPRO"
$EA_FILE = "EA\$EA_NAME.mq5"
$EA_COMPILED = "EA\$EA_NAME.ex5"

# ============================================
# Funções
# ============================================

function Write-Step {
    param([string]$Message)
    Write-Host "`n🔹 $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Get-EAVersion {
    <#
    .SYNOPSIS
        Extrai versão do arquivo .mq5
    #>
    if (!(Test-Path $EA_FILE)) {
        throw "Arquivo EA não encontrado: $EA_FILE"
    }
    
    $content = Get-Content $EA_FILE -Raw
    
    # Tentar extrair de #define PDC_VER
    if ($content -match '#define\s+PDC_VER\s+"([^"]+)"') {
        return $matches[1]
    }
    
    # Tentar extrair de #property version
    if ($content -match '#property\s+version\s+"([^"]+)"') {
        return $matches[1]
    }
    
    throw "Não foi possível extrair versão do EA"
}

function Get-GitInfo {
    <#
    .SYNOPSIS
        Obtém informações do git
    #>
    $gitInfo = @{}
    
    try {
        $gitInfo['commit'] = git rev-parse HEAD 2>$null
        $gitInfo['branch'] = git rev-parse --abbrev-ref HEAD 2>$null
        $gitInfo['tag'] = git describe --tags --exact-match 2>$null
        $gitInfo['commit_short'] = git rev-parse --short HEAD 2>$null
    } catch {
        Write-Warning-Custom "Git não disponível ou não é um repositório git"
    }
    
    return $gitInfo
}

function Create-InstallReadme {
    param(
        [string]$Version,
        [string]$OutputPath,
        [bool]$IsMinimal
    )
    
    $date = Get-Date -Format "yyyy-MM-dd"
    
    if ($IsMinimal) {
        $content = @"
# EA-MT5 DataCollectorPRO v$Version

## 🚀 Instalação Rápida

### 1. Copiar EA para MT5
1. Abra MetaTrader 5
2. File > Open Data Folder
3. Navegue até \MQL5\Experts
4. Copie o arquivo DataCollectorPRO.mq5
5. Compile no MetaEditor (F7)

### 2. Configurar API
Inputs principais:
- \`API_URL\`: http://192.168.15.20:18001/ingest
- \`API_Tick_URL\`: http://192.168.15.20:18001/ingest/tick
- \`API_Key\`: (sua chave)

### 3. Habilitar WebRequest
Tools > Options > Expert Advisors > Allow WebRequest for:
- http://192.168.15.20:18001

### 4. Ativar EA
Arraste o EA para um gráfico e configure os parâmetros.

## 📚 Documentação Completa
https://github.com/Lysk-dot/EA-MT5

---
Build: $date | Version: $Version
"@
    } else {
        $content = @"
# EA-MT5 DataCollectorPRO v$Version - Guia Completo

## 📦 Conteúdo do Pacote

- \`EA/DataCollectorPRO.mq5\` - Código fonte do Expert Advisor
- \`EA/DataCollectorPRO.ex5\` - EA compilado (se disponível)
- \`docs/\` - Documentação completa
  - \`README-COMPLETO.md\` - Documentação principal
  - \`openapi.yaml\` - Contrato da API REST
  - \`SECURITY-LICENSE-PEPPER.md\` - Guia de segurança
- \`licenses/\` - Licenças geradas (se aplicável)
- \`INSTALL.md\` - Este arquivo
- \`version.json\` - Informações de build

## 🚀 Instalação

### Pré-requisitos
- MetaTrader 5 (build 3950+)
- API REST rodando (local ou servidor)
- PostgreSQL/TimescaleDB configurado

### Passo 1: Instalar EA no MT5

1. **Abrir pasta de dados do MT5:**
   - No MT5: File > Open Data Folder
   - Ou manualmente: \`%APPDATA%\MetaQuotes\Terminal\[ID]\MQL5\`

2. **Copiar arquivos:**
   ```
   DataCollectorPRO.mq5  →  MQL5\Experts\
   DataCollectorPRO.ex5  →  MQL5\Experts\ (se existir)
   ```

3. **Compilar (se necessário):**
   - Abra o MetaEditor (F4 no MT5)
   - Abra DataCollectorPRO.mq5
   - Compile (F7)
   - Verifique erros na aba "Errors"

### Passo 2: Configurar WebRequest

**IMPORTANTE:** O EA precisa de permissão para fazer requisições HTTP.

1. Tools > Options > Expert Advisors
2. Marcar: "Allow WebRequest for listed URL"
3. Adicionar URLs:
   ```
   http://192.168.15.20:18001
   http://127.0.0.1:18001
   ```
4. OK para salvar

### Passo 3: Configurar Inputs do EA

Ao adicionar o EA no gráfico, configure:

#### Coleta de Dados
- \`Collection_Interval\`: 60 (segundos entre coletas)
- \`Collection_Timeframe\`: PERIOD_CURRENT (ou específico)
- \`Enable_API_Integration\`: true

#### API
- \`API_URL\`: http://192.168.15.20:18001/ingest
- \`API_Tick_URL\`: http://192.168.15.20:18001/ingest/tick
- \`API_Key\`: mt5_trading_secure_key_2025_prod (ou sua chave)
- \`API_Timeout\`: 6000 (ms)

#### Ticks (Tempo Real)
- \`Enable_Tick_Stream\`: true
- \`Tick_Send_Mode\`: TICK_BATCHED
- \`Tick_Batch_Max\`: 200
- \`Tick_Flush_IntervalMs\`: 1000

#### Licenciamento (Opcional)
- \`License_Enabled\`: false (desabilitar se não usar)
- \`License_Key\`: (vazio ou sua chave)

### Passo 4: Ativar EA

1. Arraste DataCollectorPRO para qualquer gráfico
2. Marque "Allow DLL imports" (se solicitado)
3. Marque "Allow WebRequest" (se solicitado)
4. OK para ativar

### Passo 5: Verificar Funcionamento

#### No MT5:
- Aba "Experts": deve mostrar logs de inicialização
- Verifique mensagens: \`[INIT] DataCollectorPRO v$Version started\`
- Logs de coleta: \`[INGEST] try=1 code=200\`

#### Na API:
```bash
# Verificar health
curl http://192.168.15.20:18001/health

# Ver últimos dados (se tiver query tool)
python tools/query-db.py 1
```

#### No PostgreSQL:
```sql
-- Verificar dados recentes
SELECT symbol, timeframe, ts, close 
FROM ticks 
ORDER BY ts DESC 
LIMIT 10;

-- Verificar ticks
SELECT symbol, bid, ask, ts 
FROM raw_ticks 
ORDER BY ts DESC 
LIMIT 10;
```

## 🔧 Troubleshooting

### EA não inicia
- Verifique versão do MT5 (mínimo build 3950)
- Recompile o EA no MetaEditor
- Verifique permissões de DLL e WebRequest

### Sem dados na API
- Verifique URL da API está correta e acessível
- Teste manualmente: \`curl http://IP:PORT/health\`
- Verifique API_Key está correto
- Veja logs do EA na aba Experts

### Erro 401 (Unauthorized)
- API_Key incorreto
- Verifique configuração da API

### Erro de WebRequest
- URLs não estão na whitelist
- Adicione URLs em Tools > Options > Expert Advisors

### Performance
- Reduza \`Collection_Interval\` se muitos símbolos
- Ajuste \`MaxItemsPerBatch\` se payloads grandes
- Use \`Tick_Send_Mode=TICK_BATCHED\` para ticks

## 📚 Documentação

### Links
- **GitHub**: https://github.com/Lysk-dot/EA-MT5
- **API Docs**: Ver \`docs/openapi.yaml\`
- **Documentação Completa**: Ver \`docs/README-COMPLETO.md\`

### Arquivos Importantes
- \`API_FLOW_SIMULATION.md\` - Fluxo de dados
- \`DATA-FLOW.md\` - Arquitetura do pipeline
- \`SECURITY-LICENSE-PEPPER.md\` - Segurança

## 🔄 Atualização

Para atualizar de versão anterior:

1. Remova o EA do gráfico
2. Substitua arquivos .mq5/.ex5
3. Recompile se necessário
4. Reative o EA no gráfico
5. Inputs são preservados

## 📝 Changelog

Versão $Version - $date
- Consulte CHANGELOG.md no repositório para detalhes

## 🆘 Suporte

Para problemas ou dúvidas:
- GitHub Issues: https://github.com/Lysk-dot/EA-MT5/issues
- Documentação: Ver pasta \`docs/\`

---

**Build Information**
- Version: $Version
- Build Date: $date
- Package: EA-MT5-v$Version.zip

© 2025 EA-MT5 Project. Uso interno.
"@
    }
    
    $content | Out-File -FilePath $OutputPath -Encoding UTF8
}

function Create-VersionJson {
    param(
        [string]$Version,
        [hashtable]$GitInfo,
        [string]$OutputPath
    )
    
    $versionData = @{
        version = $Version
        build_date = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        ea_name = $EA_NAME
    }
    
    if ($GitInfo.Count -gt 0) {
        $versionData['git'] = @{
            commit = $GitInfo['commit']
            commit_short = $GitInfo['commit_short']
            branch = $GitInfo['branch']
            tag = $GitInfo['tag']
        }
    }
    
    $versionData | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
}

# ============================================
# Main Script
# ============================================

Write-Host @"

╔════════════════════════════════════════╗
║   EA-MT5 Release Packager              ║
╚════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Determinar versão
if ([string]::IsNullOrEmpty($Version)) {
    Write-Step "Detectando versão automaticamente..."
    try {
        $Version = Get-EAVersion
        Write-Success "Versão detectada: $Version"
    } catch {
        Write-Error-Custom "Não foi possível detectar versão. Use -Version"
        exit 1
    }
}

# Obter info do git
$gitInfo = Get-GitInfo
if ($gitInfo['commit']) {
    Write-Success "Git: $($gitInfo['commit_short']) @ $($gitInfo['branch'])"
}

# Criar estrutura de release
$pkgName = "EA-MT5-v$Version"
$pkgDir = Join-Path $OutputDir $pkgName
$zipPath = Join-Path $OutputDir "$pkgName.zip"

Write-Step "Criando estrutura de release..."
Remove-Item -Path $pkgDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null

# Copiar EA
Write-Step "Copiando Expert Advisor..."
$eaDestDir = Join-Path $pkgDir "EA"
New-Item -ItemType Directory -Path $eaDestDir -Force | Out-Null

if (Test-Path $EA_FILE) {
    Copy-Item $EA_FILE -Destination $eaDestDir
    Write-Success "Código fonte copiado"
} else {
    Write-Error-Custom "Arquivo EA não encontrado: $EA_FILE"
    exit 1
}

if (Test-Path $EA_COMPILED) {
    Copy-Item $EA_COMPILED -Destination $eaDestDir
    Write-Success "EA compilado copiado"
} else {
    Write-Warning-Custom "EA compilado não encontrado (.ex5)"
}

# Documentação
if (!$Minimal) {
    Write-Step "Copiando documentação..."
    $docsDestDir = Join-Path $pkgDir "docs"
    New-Item -ItemType Directory -Path $docsDestDir -Force | Out-Null
    
    # Arquivos principais
    if (Test-Path "docs\README-COMPLETO.md") {
        Copy-Item "docs\README-COMPLETO.md" -Destination $pkgDir
    }
    
    if (Test-Path "docs\api\openapi.yaml") {
        Copy-Item "docs\api\openapi.yaml" -Destination $docsDestDir
    }
    
    if (Test-Path "docs\SECURITY-LICENSE-PEPPER.md") {
        Copy-Item "docs\SECURITY-LICENSE-PEPPER.md" -Destination $docsDestDir
    }
    
    Write-Success "Documentação copiada"
}

# Licenças
if ($IncludeLicenses -and (Test-Path "licenses")) {
    Write-Step "Copiando licenças..."
    $licDestDir = Join-Path $pkgDir "licenses"
    New-Item -ItemType Directory -Path $licDestDir -Force | Out-Null
    
    Get-ChildItem "licenses\*.txt" -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName -Destination $licDestDir
    }
    
    Write-Success "Licenças copiadas"
}

# Criar README de instalação
Write-Step "Gerando INSTALL.md..."
$installPath = Join-Path $pkgDir "INSTALL.md"
Create-InstallReadme -Version $Version -OutputPath $installPath -IsMinimal:$Minimal
Write-Success "INSTALL.md criado"

# Criar version.json
Write-Step "Gerando version.json..."
$versionPath = Join-Path $pkgDir "version.json"
Create-VersionJson -Version $Version -GitInfo $gitInfo -OutputPath $versionPath
Write-Success "version.json criado"

# Compactar
Write-Step "Compactando pacote..."
try {
    Compress-Archive -Path "$pkgDir\*" -DestinationPath $zipPath -Force
    Write-Success "Pacote criado: $zipPath"
} catch {
    Write-Error-Custom "Erro ao compactar: $_"
    exit 1
}

# Informações finais
$zipSize = (Get-Item $zipPath).Length / 1MB
Write-Host @"

╔════════════════════════════════════════╗
║   Release Package Created!             ║
╚════════════════════════════════════════╝

📦 Pacote:    $pkgName.zip
📏 Tamanho:   $([math]::Round($zipSize, 2)) MB
📂 Local:     $zipPath
📌 Versão:    $Version

"@ -ForegroundColor Green

# Checksums
if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
    Write-Step "Calculando checksums..."
    $sha256 = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
    $md5 = (Get-FileHash -Path $zipPath -Algorithm MD5).Hash
    
    Write-Host "SHA256: $sha256" -ForegroundColor Gray
    Write-Host "MD5:    $md5" -ForegroundColor Gray
    
    # Salvar checksums
    $checksumPath = Join-Path $OutputDir "$pkgName.checksums.txt"
    @"
# EA-MT5 v$Version Checksums
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

SHA256: $sha256
MD5:    $md5

File: $pkgName.zip
"@ | Out-File -FilePath $checksumPath -Encoding UTF8
    
    Write-Success "Checksums salvos em: $checksumPath"
}

Write-Host "`n✨ Pronto para distribuição!" -ForegroundColor Cyan
