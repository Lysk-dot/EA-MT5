#Requires -Version 5.1
<#
.SYNOPSIS
    Incrementa a versão do DataCollector em 0.01, atualiza o código e faz commit/tag.

.DESCRIPTION
    Este script:
    1. Detecta a versão atual do último arquivo DataCollector*.mq5
    2. Incrementa em 0.01 (ex: 1.65 -> 1.66)
    3. Cria novo arquivo com a versão incrementada
    4. Atualiza #property version e strings internas
    5. Faz git add, commit e tag automático
    6. (Opcional) Push para GitHub

.PARAMETER Message
    Mensagem descritiva do commit (obrigatória)

.PARAMETER Type
    Tipo de mudança: fix (0.01), feat (0.10), major (1.00)
    Default: fix

.PARAMETER NoPush
    <#

.EXAMPLE
    .\bump-version.ps1 -Message "corrige parse HTTP de múltiplos status"
    
    # (c) 2025 Felipe Petracco Carmo <kuramopr@gmail.com>. Proprietary. Todos os direitos reservados.
.EXAMPLE
    .\bump-version.ps1 -Message "adiciona suporte a chunking" -Type feat

.EXAMPLE
    .\bump-version.ps1 -Message "hotfix fallback UTF-8" -NoPush
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Message,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('fix','feat','major')]
    [string]$Type = 'fix',
    
    [Parameter(Mandatory=$false)]
    [switch]$NoPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Configurações
$DataFolder = Join-Path $PSScriptRoot "Data"
$Pattern = "DataCollector*.mq5"

Write-Host "=== Bump Version Script v1.0 ===" -ForegroundColor Cyan

# 1) Encontra o último arquivo
$LatestFile = Get-ChildItem -Path $DataFolder -Filter $Pattern -File | 
    Where-Object { $_.Name -notmatch 'Obsoleto' } |
    Sort-Object Name -Descending | 
    Select-Object -First 1

if (-not $LatestFile) {
    Write-Error "Nenhum arquivo $Pattern encontrado em $DataFolder"
}

Write-Host "Arquivo atual: $($LatestFile.Name)" -ForegroundColor Green

# 2) Extrai versão atual do nome (ex: DataCollector1.65.mq5 -> 1.65)
if ($LatestFile.BaseName -match 'DataCollector(\d+\.\d+)') {
    $CurrentVersion = $Matches[1]
} else {
    Write-Error "Não foi possível extrair versão do nome: $($LatestFile.Name)"
}

Write-Host "Versão atual: $CurrentVersion" -ForegroundColor Yellow

# 3) Calcula nova versão
$Parts = $CurrentVersion -split '\.'
$Major = [int]$Parts[0]
$Minor = [int]$Parts[1]

switch ($Type) {
    'fix'   { $Minor += 1 }
    'feat'  { $Minor += 10; if ($Minor -ge 100) { $Major += 1; $Minor = 0 } }
    'major' { $Major += 1; $Minor = 0 }
}

$NewVersion = "$Major.$Minor"
$NewVersionProperty = "$Major.$Minor" + "0"  # MQL5 usa formato X.YZ0

Write-Host "Nova versão: $NewVersion (property: $NewVersionProperty)" -ForegroundColor Cyan

# 4) Cria novo arquivo
$NewFileName = "DataCollector$NewVersion.mq5"
$NewFilePath = Join-Path $DataFolder $NewFileName

if (Test-Path $NewFilePath) {
    Write-Error "Arquivo $NewFileName já existe! Cancele ou remova antes."
}

# 5) Lê conteúdo e substitui versões
$Content = Get-Content $LatestFile.FullName -Raw -Encoding UTF8

# Substituições:
# - Linha de comentário do cabeçalho
$Content = $Content -replace '(ProfessionalDataCollector\.mq5 \(v)[\d\.]+', "`$1$NewVersion"

# - #property version (formato X.YZ0)
$Content = $Content -replace '#property version\s+"[\d\.]+"', "#property version   `"$NewVersionProperty`""

# - String "ver" no meta JSON
$Content = $Content -replace '(\\"ver\\":\\"PDC\\",\\"ver\\":\\")[\d\.]+', "`${1}$NewVersion"
$Content = $Content -replace '(\\"ea\\":\\"PDC\\",\\"ver\\":\\")[\d\.]+', "`${1}$NewVersion"

# 6) Grava novo arquivo
Set-Content -Path $NewFilePath -Value $Content -Encoding UTF8 -NoNewline
Write-Host "Criado: $NewFileName" -ForegroundColor Green

# 7) Git add, commit, tag
try {
    Push-Location $PSScriptRoot
    
    git add $NewFilePath
    $CommitMsg = "[$Type] v$NewVersion : $Message"
    git commit -m $CommitMsg
    
    $TagName = "v$NewVersion"
    git tag -a $TagName -m $CommitMsg
    
    Write-Host "Commit e tag criados: $TagName" -ForegroundColor Green
    
    # 8) Push (se não desabilitado)
    if (-not $NoPush) {
        Write-Host "Fazendo push para origin..." -ForegroundColor Yellow
        git push origin main
        git push origin $TagName
        Write-Host "Push concluído!" -ForegroundColor Green
    } else {
        Write-Host "Push desabilitado. Para enviar ao GitHub:" -ForegroundColor Yellow
        Write-Host "  git push origin main --tags" -ForegroundColor White
    }
    
} catch {
    Write-Error "Erro no Git: $_"
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== Versionamento concluído! ===" -ForegroundColor Cyan
Write-Host "Versão: $NewVersion | Arquivo: $NewFileName | Tag: v$NewVersion" -ForegroundColor White
