param(
    [string]$Query,
    [ValidateSet('loki','jaeger','prometheus')]
    [string]$Target = 'loki',
    [int]$Limit = 100,
    [string]$Start = '-1h'
)

# Script para consultar dados via CLI

$baseUrl = switch ($Target) {
    'loki'       { 'http://localhost:3100' }
    'jaeger'     { 'http://localhost:16686' }
    'prometheus' { 'http://localhost:9090' }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Query Tool - $Target" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

switch ($Target) {
    'loki' {
        if (-not $Query) {
            Write-Host "Exemplos de queries Loki:" -ForegroundColor Yellow
            Write-Host '  {job="mt5"} |= "error"' -ForegroundColor Gray
            Write-Host '  {job="ea-datacollector", symbol="EURUSD"}' -ForegroundColor Gray
            Write-Host '  {job="automation", script="compile-ea.ps1"} |= "FAIL"' -ForegroundColor Gray
            Write-Host ""
            $Query = Read-Host "Query"
        }
        
        $url = "$baseUrl/loki/api/v1/query_range"
        $params = @{
            query = $Query
            limit = $Limit
            start = (Get-Date).AddHours(-1).ToUniversalTime().ToString('o')
            end   = (Get-Date).ToUniversalTime().ToString('o')
        }
        
        try {
            $response = Invoke-RestMethod -Uri $url -Method GET -Body $params -TimeoutSec 10
            
            if ($response.status -eq 'success' -and $response.data.result.Count -gt 0) {
                Write-Host ("Encontrados {0} resultados:" -f $response.data.result.Count) -ForegroundColor Green
                Write-Host ""
                
                foreach ($stream in $response.data.result) {
                    $labels = ($stream.stream | ConvertTo-Json -Compress)
                    Write-Host "Labels: $labels" -ForegroundColor Cyan
                    
                    foreach ($entry in $stream.values) {
                        $timestamp = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$entry[0]).LocalDateTime
                        $log = $entry[1]
                        Write-Host ("[{0}] {1}" -f $timestamp.ToString('yyyy-MM-dd HH:mm:ss'), $log) -ForegroundColor White
                    }
                    Write-Host ""
                }
            } else {
                Write-Host "Nenhum resultado encontrado" -ForegroundColor Yellow
            }
        } catch {
            Write-Host ("Erro: {0}" -f $_.Exception.Message) -ForegroundColor Red
        }
    }
    
    'jaeger' {
        Write-Host "Acessar Jaeger UI: http://localhost:16686" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Filtros disponíveis:" -ForegroundColor Yellow
        Write-Host "  - Service: ea-api" -ForegroundColor Gray
        Write-Host "  - Operation: POST /ingest" -ForegroundColor Gray
        Write-Host "  - Tags: symbol=EURUSD, account=12345" -ForegroundColor Gray
        Write-Host "  - Min Duration: 500ms" -ForegroundColor Gray
        Write-Host ""
        
        # Listar serviços disponíveis
        try {
            $services = Invoke-RestMethod -Uri "$baseUrl/api/services" -TimeoutSec 5
            Write-Host "Serviços disponíveis:" -ForegroundColor Cyan
            $services.data | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
        } catch {
            Write-Host "Erro ao buscar serviços" -ForegroundColor Red
        }
    }
    
    'prometheus' {
        if (-not $Query) {
            Write-Host "Exemplos de queries Prometheus:" -ForegroundColor Yellow
            Write-Host '  rate(api_requests_total[5m])' -ForegroundColor Gray
            Write-Host '  histogram_quantile(0.95, rate(api_request_latency_seconds_bucket[5m]))' -ForegroundColor Gray
            Write-Host '  sum(rate(api_errors_total[5m])) by (endpoint)' -ForegroundColor Gray
            Write-Host ""
            $Query = Read-Host "Query"
        }
        
        $url = "$baseUrl/api/v1/query"
        $params = @{ query = $Query }
        
        try {
            $response = Invoke-RestMethod -Uri $url -Method GET -Body $params -TimeoutSec 10
            
            if ($response.status -eq 'success' -and $response.data.result.Count -gt 0) {
                Write-Host ("Encontrados {0} resultados:" -f $response.data.result.Count) -ForegroundColor Green
                Write-Host ""
                
                foreach ($result in $response.data.result) {
                    $metric = ($result.metric | ConvertTo-Json -Compress)
                    $value = $result.value[1]
                    Write-Host ("Metric: {0} = {1}" -f $metric, $value) -ForegroundColor White
                }
            } else {
                Write-Host "Nenhum resultado encontrado" -ForegroundColor Yellow
            }
        } catch {
            Write-Host ("Erro: {0}" -f $_.Exception.Message) -ForegroundColor Red
        }
    }
}

Write-Host ""
