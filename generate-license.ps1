param(
    [Parameter(Mandatory=$true)]
    [long]$AccountNumber,
    
    [Parameter(Mandatory=$false)]
    [int]$ExpirationDays = 365,
    
    [Parameter(Mandatory=$false)]
    [string]$ExpirationDate = ""
)

# Gerador de licença para DataCollectorPRO EA
# Usa FNV-1a 32-bit hash (mesmo algoritmo do EA)

function Get-FNV1a32Hash {
    param([string]$Text)
    
    [uint32]$hash = 2166136261
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    
    foreach ($byte in $bytes) {
        $hash = $hash -bxor $byte
        $hash = $hash * 16777619
    }
    
    return $hash
}

function Get-FNV1a32Hex {
    param([string]$Text)
    
    $hash = Get-FNV1a32Hash -Text $Text
    return "{0:X8}" -f $hash
}

# Pepper secret (mesmo do EA)
$LIC_PEPPER = "PDC-LIC-2025-`$k39"

# Calcular data de expiração
if ($ExpirationDate -ne "") {
    # Usar data específica (formato: YYYYMMDD)
    try {
        $expDate = [DateTime]::ParseExact($ExpirationDate, "yyyyMMdd", $null)
    } catch {
        Write-Host "❌ Formato de data inválido. Use: YYYYMMDD (ex: 20261018)" -ForegroundColor Red
        exit 1
    }
} else {
    # Usar dias a partir de hoje
    $expDate = (Get-Date).AddDays($ExpirationDays)
}

$expInt = [int]($expDate.ToString("yyyyMMdd"))

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Gerador de Licença - DataCollectorPRO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Conta MT5:      $AccountNumber" -ForegroundColor White
Write-Host "Expiração:      $($expDate.ToString('yyyy-MM-dd')) ($expInt)" -ForegroundColor White
Write-Host ""

# Gerar assinatura
$data = "{0}|{1}|{2}" -f $AccountNumber, $expInt, $LIC_PEPPER
$signature = Get-FNV1a32Hex -Text $data

# Montar chave de licença
$licenseKey = "PDC|{0}|{1}|{2}" -f $AccountNumber, $expInt, $signature

Write-Host "✅ Licença gerada:" -ForegroundColor Green
Write-Host ""
Write-Host $licenseKey -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Como usar:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Copie a chave acima" -ForegroundColor White
Write-Host ""
Write-Host "2. No MetaTrader 5:" -ForegroundColor White
Write-Host "   - Clique com botão direito no gráfico" -ForegroundColor Gray
Write-Host "   - Expert Advisors → DataCollectorPRO → Propriedades" -ForegroundColor Gray
Write-Host "   - Aba 'Inputs'" -ForegroundColor Gray
Write-Host "   - Localize: License_Key" -ForegroundColor Gray
Write-Host "   - Cole a chave de licença" -ForegroundColor Gray
Write-Host "   - Clique OK" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Ou edite diretamente no código:" -ForegroundColor White
Write-Host "   - Abra: EA/DataCollectorPRO.mq5" -ForegroundColor Gray
Write-Host "   - Localize: input string License_Key" -ForegroundColor Gray
Write-Host "   - Altere para: input string License_Key = `"$licenseKey`";" -ForegroundColor Gray
Write-Host "   - Recompile (F7)" -ForegroundColor Gray
Write-Host ""
Write-Host "Configurações opcionais:" -ForegroundColor Cyan
Write-Host "   - License_Enabled = true (padrão: ativa verificação)" -ForegroundColor Gray
Write-Host "   - License_Bind_Account = true (padrão: vincula à conta)" -ForegroundColor Gray
Write-Host ""

# Salvar em arquivo
$outputFile = Join-Path $PSScriptRoot "licenses\license_$AccountNumber.txt"
$outputDir = Split-Path $outputFile -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$content = @"
========================================
Licença DataCollectorPRO EA
========================================

Conta MT5:    $AccountNumber
Gerada em:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Expira em:    $($expDate.ToString('yyyy-MM-dd'))
Validade:     $ExpirationDays dias

========================================
CHAVE DE LICENÇA
========================================

$licenseKey

========================================
INSTRUÇÕES DE USO
========================================

1. Copie a chave acima

2. No MetaTrader 5:
   - Botão direito no gráfico → Expert Advisors → DataCollectorPRO → Propriedades
   - Aba 'Inputs'
   - License_Key: Cole a chave
   - License_Enabled: true
   - License_Bind_Account: true
   - Clique OK

3. Verificar nos logs:
   Deve aparecer: "=== INICIALIZANDO PDC v1.65 ==="
   Se aparecer erro de licença, verifique:
   - Chave copiada corretamente (sem espaços)
   - Número da conta correto
   - Data não expirada

========================================
RENOVAÇÃO
========================================

Para renovar, gere nova licença:
.\generate-license.ps1 -AccountNumber $AccountNumber -ExpirationDays 365

Para licença perpétua (50 anos):
.\generate-license.ps1 -AccountNumber $AccountNumber -ExpirationDays 18250

Para data específica:
.\generate-license.ps1 -AccountNumber $AccountNumber -ExpirationDate "20261231"

========================================
SUPORTE
========================================

Em caso de problemas:
1. Verifique logs do EA no MetaTrader 5
2. Confirme número da conta: AccountInfoInteger(ACCOUNT_LOGIN)
3. Verifique data do sistema

"@

$content | Out-File -FilePath $outputFile -Encoding UTF8
Write-Host "💾 Licença salva em: $outputFile" -ForegroundColor Green
Write-Host ""

# Exemplo de múltiplas contas
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Gerar para múltiplas contas:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host ".\generate-license.ps1 -AccountNumber 12345" -ForegroundColor Gray
Write-Host ".\generate-license.ps1 -AccountNumber 67890 -ExpirationDays 730" -ForegroundColor Gray
Write-Host ".\generate-license.ps1 -AccountNumber 11111 -ExpirationDate `"20261231`"" -ForegroundColor Gray
Write-Host ""
