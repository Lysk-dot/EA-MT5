param(
  [string]$GrafanaUrl = "http://192.168.15.20:3000",
  [string]$GrafanaToken = $env:GRAFANA_TOKEN,
  [string]$OutputDir = (Join-Path $PSScriptRoot 'dashboards'),
  [switch]$Import,
  [switch]$Export
)

# Gerenciador de dashboards Grafana: exporta JSON templates e importa via API

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

function Get-GrafanaHeaders {
  $headers = @{ 'Content-Type' = 'application/json' }
  if ($GrafanaToken) { $headers['Authorization'] = "Bearer $GrafanaToken" }
  return $headers
}

# ============= DASHBOARD TEMPLATES =============

$dashboardEAHealth = @{
  dashboard = @{
    title = "EA DataCollectorPRO - Health"
    tags = @("ea", "mt5", "health")
    timezone = "browser"
    panels = @(
      @{
        id = 1
        title = "Instâncias Ativas (últimas 24h)"
        type = "stat"
        gridPos = @{ x=0; y=0; w=8; h=4 }
        targets = @(@{
          rawSql = @"
SELECT 
  COUNT(DISTINCT regexp_match(user_agent, 'Account:(\d+)')[1]) as active_accounts
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
"@
          format = "table"
        })
        fieldConfig = @{
          defaults = @{
            color = @{ mode = "thresholds" }
            thresholds = @{
              mode = "absolute"
              steps = @(
                @{ value = $null; color = "red" }
                @{ value = 1; color = "yellow" }
                @{ value = 3; color = "green" }
              )
            }
          }
        }
      }
      @{
        id = 2
        title = "Taxa de Duplicatas (mercado fechado)"
        type = "gauge"
        gridPos = @{ x=8; y=0; w=8; h=4 }
        targets = @(@{
          rawSql = @"
SELECT 
  ROUND(COUNT(*) FILTER (WHERE was_duplicate) * 100.0 / COUNT(*), 2) as dup_rate
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '1 hour'
"@
        })
        fieldConfig = @{
          defaults = @{
            max = 100
            thresholds = @{
              mode = "absolute"
              steps = @(
                @{ value = $null; color = "green" }
                @{ value = 50; color = "yellow" }
                @{ value = 80; color = "red" }
              )
            }
          }
        }
      }
      @{
        id = 3
        title = "Requisições por Minuto"
        type = "graph"
        gridPos = @{ x=0; y=4; w=16; h=6 }
        targets = @(@{
          rawSql = @"
SELECT 
  time_bucket('1 minute', received_at) AS time,
  COUNT(*) as requests,
  COUNT(*) FILTER (WHERE NOT was_duplicate) as inserts
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '6 hours'
GROUP BY time
ORDER BY time
"@
        })
      }
      @{
        id = 4
        title = "Versões de EA em Produção"
        type = "table"
        gridPos = @{ x=16; y=0; w=8; h=10 }
        targets = @(@{
          rawSql = @"
SELECT 
  regexp_match(user_agent, 'PDC/([0-9.]+)')[1] AS version,
  COUNT(DISTINCT regexp_match(user_agent, 'Account:(\d+)')[1]) as accounts,
  MAX(received_at) as last_seen
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY version
ORDER BY last_seen DESC
"@
        })
      }
      @{
        id = 5
        title = "Top Símbolos (últimas 24h)"
        type = "barchart"
        gridPos = @{ x=0; y=10; w=12; h=6 }
        targets = @(@{
          rawSql = @"
SELECT 
  symbol,
  COUNT(*) FILTER (WHERE NOT was_duplicate) as inserts
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY symbol
ORDER BY inserts DESC
LIMIT 10
"@
        })
      }
      @{
        id = 6
        title = "IPs de Origem"
        type = "table"
        gridPos = @{ x=12; y=10; w=12; h=6 }
        targets = @(@{
          rawSql = @"
SELECT 
  source_ip,
  COUNT(DISTINCT regexp_match(user_agent, 'Account:(\d+)')[1]) as accounts,
  COUNT(*) as requests,
  MAX(received_at) as last_activity
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY source_ip
ORDER BY requests DESC
"@
        })
      }
    )
    schemaVersion = 36
    version = 1
  }
  overwrite = $true
}

$dashboardMarketActivity = @{
  dashboard = @{
    title = "Market Activity Analysis (AI)"
    tags = @("market", "ai", "duplicates")
    timezone = "browser"
    panels = @(
      @{
        id = 1
        title = "Taxa de Duplicatas por Hora (Padrão de Mercado)"
        type = "heatmap"
        gridPos = @{ x=0; y=0; w=24; h=8 }
        targets = @(@{
          rawSql = @"
SELECT 
  time_bucket('1 hour', received_at) AS time,
  EXTRACT(DOW FROM received_at) as day_of_week,
  ROUND(COUNT(*) FILTER (WHERE was_duplicate) * 100.0 / COUNT(*), 2) as dup_rate
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '7 days'
GROUP BY time, day_of_week
ORDER BY time
"@
        })
      }
      @{
        id = 2
        title = "Detecção de Mercado Fechado (>80% duplicatas)"
        type = "graph"
        gridPos = @{ x=0; y=8; w=12; h=6 }
        targets = @(@{
          rawSql = @"
SELECT 
  time_bucket('15 minutes', received_at) AS time,
  ROUND(COUNT(*) FILTER (WHERE was_duplicate) * 100.0 / COUNT(*), 2) as dup_rate,
  CASE WHEN COUNT(*) FILTER (WHERE was_duplicate) * 100.0 / COUNT(*) > 80 THEN 1 ELSE 0 END as market_closed
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY time
ORDER BY time
"@
        })
      }
      @{
        id = 3
        title = "Gaps de Dados (> 5 min sem dados)"
        type = "table"
        gridPos = @{ x=12; y=8; w=12; h=6 }
        targets = @(@{
          rawSql = @"
WITH gaps AS (
  SELECT 
    received_at,
    LAG(received_at) OVER (ORDER BY received_at) as prev_time,
    EXTRACT(EPOCH FROM (received_at - LAG(received_at) OVER (ORDER BY received_at))) / 60 as gap_minutes
  FROM (SELECT DISTINCT time_bucket('1 minute', received_at) as received_at FROM ingest_log WHERE received_at > NOW() - INTERVAL '24 hours') t
)
SELECT received_at, gap_minutes
FROM gaps
WHERE gap_minutes > 5
ORDER BY gap_minutes DESC
LIMIT 20
"@
        })
      }
      @{
        id = 4
        title = "Dataset para ML (exportar via CSV)"
        type = "table"
        gridPos = @{ x=0; y=14; w=24; h=8 }
        targets = @(@{
          rawSql = @"
SELECT 
  time_bucket('5 minutes', received_at) AS time,
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE was_duplicate) as duplicates,
  COUNT(*) FILTER (WHERE NOT was_duplicate) as inserts,
  ROUND(COUNT(*) FILTER (WHERE was_duplicate) * 100.0 / COUNT(*), 2) as dup_rate,
  EXTRACT(HOUR FROM received_at) as hour,
  EXTRACT(DOW FROM received_at) as dow,
  COUNT(DISTINCT symbol) as symbols
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '7 days'
GROUP BY time
ORDER BY time
"@
        })
      }
    )
    schemaVersion = 36
    version = 1
  }
  overwrite = $true
}

$dashboardPerformance = @{
  dashboard = @{
    title = "EA Performance by Account"
    tags = @("performance", "accounts")
    timezone = "browser"
    panels = @(
      @{
        id = 1
        title = "Performance por Conta (últimas 24h)"
        type = "table"
        gridPos = @{ x=0; y=0; w=24; h=10 }
        targets = @(@{
          rawSql = @"
SELECT 
  regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
  regexp_match(user_agent, 'Server:([^;]+)')[1] AS server,
  COUNT(*) as total_requests,
  COUNT(*) FILTER (WHERE NOT was_duplicate) as inserts,
  ROUND(COUNT(*) FILTER (WHERE was_duplicate) * 100.0 / COUNT(*), 2) as dup_rate_pct,
  COUNT(DISTINCT symbol) as symbols,
  MIN(received_at) as first_seen,
  MAX(received_at) as last_seen
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY account, server
ORDER BY total_requests DESC
"@
        })
      }
      @{
        id = 2
        title = "Alertas: Contas Offline (>10 min sem dados)"
        type = "table"
        gridPos = @{ x=0; y=10; w=12; h=6 }
        targets = @(@{
          rawSql = @"
WITH last_activity AS (
  SELECT 
    regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
    MAX(received_at) as last_ping
  FROM ingest_log
  WHERE received_at > NOW() - INTERVAL '6 hours'
  GROUP BY account
)
SELECT account, last_ping, NOW() - last_ping as offline_duration
FROM last_activity
WHERE NOW() - last_ping > INTERVAL '10 minutes'
ORDER BY offline_duration DESC
"@
        })
      }
      @{
        id = 3
        title = "Auditoria: Múltiplos IPs por Conta"
        type = "table"
        gridPos = @{ x=12; y=10; w=12; h=6 }
        targets = @(@{
          rawSql = @"
SELECT 
  regexp_match(user_agent, 'Account:(\d+)')[1] AS account,
  ARRAY_AGG(DISTINCT source_ip) as ips,
  COUNT(DISTINCT source_ip) as ip_count
FROM ingest_log
WHERE received_at > NOW() - INTERVAL '7 days'
GROUP BY account
HAVING COUNT(DISTINCT source_ip) > 1
ORDER BY ip_count DESC
"@
        })
      }
    )
    schemaVersion = 36
    version = 1
  }
  overwrite = $true
}

# ============= EXPORT =============

if ($Export) {
  Write-Host "Exportando dashboards..." -ForegroundColor Yellow
  
  $dashboardEAHealth | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $OutputDir "ea-health.json") -Encoding UTF8
  Write-Host "✅ Exportado: ea-health.json" -ForegroundColor Green
  
  $dashboardMarketActivity | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $OutputDir "market-activity.json") -Encoding UTF8
  Write-Host "✅ Exportado: market-activity.json" -ForegroundColor Green
  
  $dashboardPerformance | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $OutputDir "performance.json") -Encoding UTF8
  Write-Host "✅ Exportado: performance.json" -ForegroundColor Green
  
  Write-Host ""
  Write-Host "Dashboards exportados para: $OutputDir" -ForegroundColor Cyan
}

# ============= IMPORT =============

if ($Import) {
  if (-not $GrafanaToken) {
    Write-Host "❌ GRAFANA_TOKEN não definido. Use: `$env:GRAFANA_TOKEN = 'seu-token'" -ForegroundColor Red
    Write-Host "Ou passe -GrafanaToken 'token'" -ForegroundColor Yellow
    exit 1
  }
  
  Write-Host "Importando dashboards para Grafana ($GrafanaUrl)..." -ForegroundColor Yellow
  $headers = Get-GrafanaHeaders
  
  $dashboards = @(
    @{ name = "EA Health"; data = $dashboardEAHealth }
    @{ name = "Market Activity"; data = $dashboardMarketActivity }
    @{ name = "Performance"; data = $dashboardPerformance }
  )
  
  foreach ($dash in $dashboards) {
    try {
      $url = "$GrafanaUrl/api/dashboards/db"
      $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body ($dash.data | ConvertTo-Json -Depth 20) -ContentType 'application/json'
      Write-Host ("✅ Importado: {0} (UID: {1})" -f $dash.name, $response.uid) -ForegroundColor Green
    } catch {
      Write-Host ("❌ Erro ao importar {0}: {1}" -f $dash.name, $_.Exception.Message) -ForegroundColor Red
    }
  }
  
  Write-Host ""
  Write-Host "Acesse: $GrafanaUrl/dashboards" -ForegroundColor Cyan
}

if (-not $Export -and -not $Import) {
  Write-Host "Uso:" -ForegroundColor Cyan
  Write-Host "  Exportar templates:  .\setup-grafana-dashboards.ps1 -Export" -ForegroundColor Gray
  Write-Host "  Importar no Grafana: .\setup-grafana-dashboards.ps1 -Import -GrafanaToken 'seu-token'" -ForegroundColor Gray
  Write-Host ""
  Write-Host "Criar token em Grafana:" -ForegroundColor Yellow
  Write-Host "  1. Acesse: $GrafanaUrl/org/apikeys" -ForegroundColor Gray
  Write-Host "  2. Clique em 'Add API key'" -ForegroundColor Gray
  Write-Host "  3. Role: Admin ou Editor" -ForegroundColor Gray
  Write-Host "  4. Copie o token gerado" -ForegroundColor Gray
}
