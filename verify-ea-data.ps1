param(
    [string]$ExpectedPdcVer = $env:PDC_EXPECTED_VER,
    [int]$MaxBinaryAgeMinutes = 1440, # 24h
    [switch]$FailOnMismatch,
    [switch]$RunCompileCheck,
    [string]$MetaEditorPath,
    [string]$ExpectedApiBase = "http://192.168.15.20:18001",
    [switch]$TestTick,
    [switch]$ShowCompileLog
)

# Script para verificar dados recebidos do EA MT5
# Data: 2025-10-18

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verificação de Dados do EA MT5" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# [1/5] Validar EA local e versão
Write-Host "[1/5] Validando EA local e versão..." -ForegroundColor Yellow
try {
    $baseDir = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($baseDir)) { $baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $eaPath = Join-Path $baseDir 'EA\DataCollectorPRO.mq5'
    $eaBin  = Join-Path $baseDir 'EA\DataCollectorPRO.ex5'

    if (Test-Path $eaPath) {
    $src = Get-Content $eaPath -Raw -Encoding UTF8
        $pdcVer = $null
        $fileVer = $null
        if ($src -match '#define\s+PDC_VER\s+"([^"]+)"') { $pdcVer = $Matches[1] }
        if ($src -match '#property\s+version\s+"([^"]+)"') { $fileVer = $Matches[1] }

        $msg = "EA encontrado: $eaPath"
        if ($pdcVer) { $msg += " | PDC_VER=$pdcVer" }
        if ($fileVer) { $msg += " | property.version=$fileVer" }
        Write-Host "✅ $msg" -ForegroundColor Green

        $mqInfo = Get-Item $eaPath

        # Compile check opcional
        if ($RunCompileCheck) {
            try {
                $compileScript = Join-Path $baseDir 'compile-ea.ps1'
                if (-not (Test-Path $compileScript)) {
                    Write-Host "⚠️  compile-ea.ps1 não encontrado; pulando compile check" -ForegroundColor Yellow
                } else {
                    $psArgs = @('-ExecutionPolicy','Bypass','-File', $compileScript, '-EAPath', $eaPath)
                    if ($MetaEditorPath) { $psArgs += @('-MetaEditorPath', $MetaEditorPath) }
                    if ($ShowCompileLog) { $psArgs += '-ShowLog' }
                    $psArgs += '-FailOnError'
                    Write-Host "▶️  Rodando compile-ea.ps1..." -ForegroundColor DarkGray
                    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -PassThru -Wait -NoNewWindow
                    if ($p.ExitCode -ne 0) {
                        $msgc = "Falha na compilação (exit=$($p.ExitCode))"
                        if ($FailOnMismatch) { Write-Host "❌ $msgc" -ForegroundColor Red; exit 5 } else { Write-Host "⚠️  $msgc" -ForegroundColor Yellow }
                    } else {
                        Write-Host "✅ Compile check ok" -ForegroundColor Green
                    }
                }
            } catch {
                Write-Host "⚠️  Erro ao executar compile-ea.ps1: $($_.Exception.Message)" -ForegroundColor Yellow
                if ($FailOnMismatch) { exit 6 }
            }
        }
        if (Test-Path $eaBin) {
            $binInfo = Get-Item $eaBin
            Write-Host ("   Binário: {0} | Modificado: {1}" -f $eaBin, $binInfo.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Gray

            # Checar se binário está mais antigo que o fonte
            if ($binInfo.LastWriteTime -lt $mqInfo.LastWriteTime) {
                $msgOld = "Binário .ex5 está mais antigo que o .mq5 (recompile no MetaEditor)."
                if ($FailOnMismatch) { Write-Host "❌ $msgOld" -ForegroundColor Red; exit 2 } else { Write-Host "⚠️  $msgOld" -ForegroundColor Yellow }
            }

            # Checar idade do binário
            $ageMin = ([DateTime]::UtcNow - $binInfo.LastWriteTime.ToUniversalTime()).TotalMinutes
            if ($ageMin -gt $MaxBinaryAgeMinutes) {
                $msgAge = "Binário .ex5 tem ${([int]$ageMin)} min (> $MaxBinaryAgeMinutes). Considere recompilar."
                if ($FailOnMismatch) { Write-Host "❌ $msgAge" -ForegroundColor Red; exit 3 } else { Write-Host "⚠️  $msgAge" -ForegroundColor Yellow }
            }
        } else {
            Write-Host "   Binário .ex5 não encontrado (compile no MetaEditor para gerar)" -ForegroundColor DarkYellow
        }

        # Checar ExpectedPdcVer se fornecido
        if ($ExpectedPdcVer -and $pdcVer) {
            if ($pdcVer -ne $ExpectedPdcVer) {
                $msgVer = "PDC_VER atual '$pdcVer' difere do esperado '$ExpectedPdcVer'"
                if ($FailOnMismatch) { Write-Host "❌ $msgVer" -ForegroundColor Red; exit 4 } else { Write-Host "⚠️  $msgVer" -ForegroundColor Yellow }
            } else {
                Write-Host ("   Versão confere com esperado: {0}" -f $ExpectedPdcVer) -ForegroundColor DarkGreen
            }
        }

        # Checagens de configuração da API no código
        $apiUrl = $null; $apiTickUrl = $null; $apiKey = $null; $useBearer = $null; $bearer = $null
        if ($src -match 'input\s+string\s+API_URL\s*=\s*"([^"]+)"') { $apiUrl = $Matches[1] }
        if ($src -match 'input\s+string\s+API_Tick_URL\s*=\s*"([^"]+)"') { $apiTickUrl = $Matches[1] }
        if ($src -match 'input\s+string\s+API_Key\s*=\s*"([^"]*)"') { $apiKey = $Matches[1] }
        if ($src -match 'input\s+bool\s+API_Use_Bearer_Token\s*=\s*(true|false)') { $useBearer = $Matches[1] }
        if ($src -match 'input\s+string\s+API_Bearer_Token\s*=\s*"([^"]*)"') { $bearer = $Matches[1] }

        if ($apiUrl)      { Write-Host ("   API_URL:      {0}" -f $apiUrl) -ForegroundColor Gray }
        if ($apiTickUrl)  { Write-Host ("   API_Tick_URL: {0}" -f $apiTickUrl) -ForegroundColor Gray }
        if ($useBearer)   { Write-Host ("   API_Use_Bearer_Token: {0}" -f $useBearer) -ForegroundColor Gray }
    if ($null -ne $apiKey) {
            $masked = if ([string]::IsNullOrEmpty($apiKey)) { '(vazio)' } else { ($apiKey.Substring(0,2) + '***' + $apiKey.Substring([Math]::Max(0,$apiKey.Length-2))) }
            Write-Host ("   API_Key: {0}" -f $masked) -ForegroundColor Gray
        }
    if ($null -ne $bearer -and $useBearer -eq 'true') {
            $maskedB = if ([string]::IsNullOrEmpty($bearer)) { '(vazio)' } else { ($bearer.Substring(0,2) + '***' + $bearer.Substring([Math]::Max(0,$bearer.Length-2))) }
            Write-Host ("   API_Bearer_Token: {0}" -f $maskedB) -ForegroundColor Gray
        }

        # Validar base da API
        if ($ExpectedApiBase -and $apiUrl) {
            if ($apiUrl -notlike ("{0}*" -f $ExpectedApiBase)) {
                $msgApi = "API_URL diferente da base esperada: '$apiUrl' vs '$ExpectedApiBase'"
                if ($FailOnMismatch) { Write-Host "❌ $msgApi" -ForegroundColor Red; exit 7 } else { Write-Host "⚠️  $msgApi" -ForegroundColor Yellow }
            }
        }
        if ($ExpectedApiBase -and $apiTickUrl) {
            $expectedTick = ($ExpectedApiBase.TrimEnd('/')) + '/ingest/tick'
            if ($apiTickUrl -ne $expectedTick) {
                $msgTick = "API_Tick_URL diferente do esperado: '$apiTickUrl' vs '$expectedTick'"
                if ($FailOnMismatch) { Write-Host "❌ $msgTick" -ForegroundColor Red; exit 8 } else { Write-Host "⚠️  $msgTick" -ForegroundColor Yellow }
            }
        }

        # Aviso opcional: Geração de User-Agent automática
        if ($src -match 'input\s+bool\s+API_AutoGenerate_UserAgent\s*=\s*(true|false)\s*;') {
            $uaAuto = $Matches[1]
            if ($uaAuto -ne 'true') {
                Write-Host "ℹ️  API_AutoGenerate_UserAgent = $uaAuto (prod recomendado: true)" -ForegroundColor DarkYellow
            }
        }
    } else {
        Write-Host "⚠️  EA/DataCollectorPRO.mq5 não encontrado no repositório" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Falha ao validar EA: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 2. Health Check
Write-Host "[2/5] Health Check..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://192.168.15.20:18001/health" -TimeoutSec 5
    Write-Host "✅ Servidor ONLINE: $($health.status)" -ForegroundColor Green
} catch {
    Write-Host "❌ Servidor OFFLINE" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 3. Enviar candle de teste para marcar timestamp
Write-Host "[3/5] Enviando candle de teste..." -ForegroundColor Yellow
$testTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$testPayload = @{
    ts = $testTimestamp
    symbol = "TEST_VERIFICATION"
    timeframe = "M1"
    open = 1.0
    high = 1.0
    low = 1.0
    close = 1.0
    volume = 999
} | ConvertTo-Json

try {
    $testResult = Invoke-RestMethod -Uri "http://192.168.15.20:18001/ingest" `
        -Method POST `
        -Headers @{
            "Content-Type" = "application/json"
            "X-API-Key" = "mt5_trading_secure_key_2025_prod"
        } `
        -Body $testPayload `
        -TimeoutSec 5
    
    Write-Host "✅ Teste enviado: inserted=$($testResult.inserted)" -ForegroundColor Green
} catch {
    Write-Host "❌ Erro ao enviar teste: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# 4. Verificar dados recentes (tentativa com timeout curto)
Write-Host "[4/5] Buscando dados recentes..." -ForegroundColor Yellow
try {
    $metrics = Invoke-RestMethod -Uri "http://192.168.15.20:18001/metrics" -TimeoutSec 10
    
    if ($metrics.ok -and $metrics.data) {
        Write-Host ("Dados encontrados: " + $metrics.data.Count + " simbolos") -ForegroundColor Green
        Write-Host ""
        Write-Host "Ultimos dados por simbolo:" -ForegroundColor Cyan
        Write-Host "─────────────────────────────────────────────────────" -ForegroundColor Gray
        
        foreach ($item in $metrics.data | Sort-Object last_ts -Descending | Select-Object -First 10) {
            $timeDiff = (Get-Date) - [DateTime]::Parse($item.last_ts)
            $timeAgo = if ($timeDiff.TotalMinutes -lt 60) {
                "$([int]$timeDiff.TotalMinutes) min atras"
            } else {
                "$([int]$timeDiff.TotalHours) horas atras"
            }
            
            Write-Host ("  " + $item.symbol.PadRight(15) + " " + $item.timeframe.PadRight(5) + " | Ultimo: " + $timeAgo + " | Candles(10m): " + $item.rows_10m) -ForegroundColor White
        }
    } else {
        Write-Host "Nenhum dado encontrado" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Timeout ao buscar metricas (servidor pode estar processando)" -ForegroundColor Yellow
}

Write-Host ""
# 4b. (Opcional) Testar endpoint de TICK
if ($TestTick) {
    try {
        $tickUrl = if ($apiTickUrl) { $apiTickUrl } else { ($ExpectedApiBase.TrimEnd('/')) + '/ingest/tick' }
        Write-Host ("[4b] Testando tick em: {0}" -f $tickUrl) -ForegroundColor Yellow
        $tsTick = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        $tickPayload = @{ ticks = @(@{ ts=$tsTick; symbol='TEST_TICK'; bid=1.0; ask=1.1; last=1.05; volume=1 }) } | ConvertTo-Json
        $tickResult = Invoke-RestMethod -Uri $tickUrl -Method POST -Headers @{ 'Content-Type'='application/json'; 'X-API-Key'='mt5_trading_secure_key_2025_prod' } -Body $tickPayload -TimeoutSec 5
        Write-Host ("✅ Tick enviado: " + ($tickResult | ConvertTo-Json -Compress)) -ForegroundColor Green
    } catch {
        Write-Host ("⚠️  Erro ao enviar tick: " + $_.Exception.Message) -ForegroundColor Yellow
        if ($FailOnMismatch) { exit 9 }
    }
    Write-Host ""
}

# 5. Resumo
Write-Host "[5/5] Resumo" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host "Servidor: http://192.168.15.20:18001" -ForegroundColor White
Write-Host "Status: ONLINE e respondendo" -ForegroundColor Green
Write-Host ""
Write-Host "Para monitorar em tempo real, use:" -ForegroundColor Cyan
Write-Host "  while(\$true) { Clear-Host; .\verify-ea-data.ps1; Start-Sleep 10 }" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
