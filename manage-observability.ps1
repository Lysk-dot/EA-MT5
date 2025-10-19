param(
    [ValidateSet('start','stop','restart','status','logs','clean')]
    [string]$Action = 'start',
    [string]$Service = 'all',
    [ValidateSet('observability','infra')]
    [string]$Stack = 'observability'
)

# Script para gerenciar stacks (observability e infra com API)

function Get-ComposeCmd {
    # Tenta usar 'docker compose' (v2)
    try {
        $dc = Get-Command docker -ErrorAction SilentlyContinue
        if ($null -ne $dc) {
            $null = & docker compose version 2>$null
            if ($LASTEXITCODE -eq 0) {
                return @{ exe = 'docker'; args = @('compose') }
            }
        }
    } catch {}

    # Tenta docker-compose.exe local (por ex. baixado em infra/)
    $localCompose = Join-Path (Join-Path $PSScriptRoot 'infra') 'docker-compose.exe'
    if (Test-Path $localCompose) {
        return @{ exe = $localCompose; args = @() }
    }

    # Tenta docker-compose no PATH (v1)
    try {
        $c = Get-Command docker-compose -ErrorAction SilentlyContinue
        if ($null -ne $c) {
            return @{ exe = 'docker-compose'; args = @() }
        }
    } catch {}

    throw "Docker Compose não encontrado. Instale o Docker Desktop (compose v2) ou coloque o docker-compose.exe em infra/."
}

function Ensure-DockerRunning {
    try {
        $null = & docker info 2>$null | Out-Null
        return $true
    } catch {
        Write-Host "⚠️  Docker daemon não está acessível. Tentando iniciar serviço..." -ForegroundColor Yellow
        try {
            Start-Service docker -ErrorAction Stop
            Start-Sleep -Seconds 2
            $null = & docker info 2>$null | Out-Null
            return $true
        } catch {
            Write-Host "❌ Não foi possível iniciar o Docker automaticamente." -ForegroundColor Red
            Write-Host "   Abra o Docker Desktop ou execute 'Start-Service docker' em PowerShell como Administrador." -ForegroundColor Yellow
            return $false
        }
    }
}

# Define diretório da stack e compose file
$stackDir = if ($Stack -eq 'infra') { Join-Path $PSScriptRoot 'infra' } else { Join-Path $PSScriptRoot 'infra\observability' }
Set-Location $stackDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Observability Stack Manager" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

switch ($Action) {
    'start' {
        Write-Host ("▶️  Iniciando stack: {0}" -f $Stack) -ForegroundColor Green

        if (-not (Ensure-DockerRunning)) { break }

        # Garante .env para stack 'infra'
        if ($Stack -eq 'infra') {
            $envFile = Join-Path $stackDir '.env'
            $envExample = Join-Path $stackDir '.env.example'
            if (-not (Test-Path $envFile) -and (Test-Path $envExample)) {
                Copy-Item $envExample $envFile -Force
                Write-Host "ℹ️  .env criado a partir de .env.example" -ForegroundColor DarkGray
            }
        }

        $compose = Get-ComposeCmd
        $exe = $compose.exe
        $baseArgs = @()
        $baseArgs += $compose.args
        $baseArgs += @('up','-d')

        if ($Service -ne 'all') { $baseArgs += @($Service) }

        & $exe @baseArgs
        
        Start-Sleep -Seconds 5
        
        Write-Host ""
        Write-Host "✅ Stack iniciada!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Acesse as interfaces:" -ForegroundColor Cyan
        if ($Stack -eq 'infra') {
            Write-Host "  � API:        http://localhost:18001 (GET /health)" -ForegroundColor White
            Write-Host "  📈 Prometheus: http://localhost:18011" -ForegroundColor White
            Write-Host "  �📊 Grafana:    http://localhost:18012 (admin/admin)" -ForegroundColor White
            Write-Host "  🗃️  PgAdmin:    http://localhost:18003" -ForegroundColor White
        } else {
            Write-Host "  📈 Prometheus: http://localhost:9090" -ForegroundColor White
            Write-Host "  � Grafana:    http://localhost:3000 (admin/admin)" -ForegroundColor White
            Write-Host "  �🔍 Jaeger:     http://localhost:16686" -ForegroundColor White
            Write-Host "  📝 Loki:       via Grafana → Explore → Loki" -ForegroundColor White
        }
    }
    
    'stop' {
        Write-Host ("⏹️  Parando stack: {0}" -f $Stack) -ForegroundColor Yellow
        $compose = Get-ComposeCmd
        $exe = $compose.exe
        $args = @(); $args += $compose.args; $args += @('stop')
        if ($Service -ne 'all') { $args += @($Service) }
        & $exe @args
        
        Write-Host "✅ Stack parada" -ForegroundColor Green
    }
    
    'restart' {
        Write-Host ("🔄 Reiniciando stack: {0}" -f $Stack) -ForegroundColor Yellow
        $compose = Get-ComposeCmd
        $exe = $compose.exe
        $args = @(); $args += $compose.args; $args += @('restart')
        if ($Service -ne 'all') { $args += @($Service) }
        & $exe @args
        
        Write-Host "✅ Stack reiniciada" -ForegroundColor Green
    }
    
    'status' {
        Write-Host "📊 Status dos serviços:" -ForegroundColor Cyan
        Write-Host ""
        $compose = Get-ComposeCmd
        & $compose.exe @($compose.args + 'ps')
        Write-Host ""
        
        # Verificar saúde dos endpoints
        Write-Host "🏥 Health checks:" -ForegroundColor Cyan
        
        if ($Stack -eq 'infra') {
            $checks = @(
                @{ Name="API"; Url="http://localhost:18001/health" }
                @{ Name="Prometheus"; Url="http://localhost:18011/-/healthy" }
                @{ Name="Grafana"; Url="http://localhost:18012/api/health" }
            )
        } else {
            $checks = @(
                @{ Name="Prometheus"; Url="http://localhost:9090/-/healthy" }
                @{ Name="Loki"; Url="http://localhost:3100/ready" }
                @{ Name="Grafana"; Url="http://localhost:3000/api/health" }
                @{ Name="Jaeger"; Url="http://localhost:16686/" }
            )
        }
        
        foreach ($check in $checks) {
            try {
                $null = Invoke-WebRequest -Uri $check.Url -TimeoutSec 3 -UseBasicParsing
                Write-Host ("  ✅ {0}: ONLINE" -f $check.Name) -ForegroundColor Green
            } catch {
                Write-Host ("  ❌ {0}: OFFLINE" -f $check.Name) -ForegroundColor Red
            }
        }
    }
    
    'logs' {
        Write-Host "📜 Logs dos serviços:" -ForegroundColor Cyan
        Write-Host ""
        $compose = Get-ComposeCmd
        $args = @(); $args += $compose.args; $args += @('logs','--tail=50','-f')
        if ($Service -ne 'all') { $args += @($Service) }
        & $compose.exe @args
    }
    
    'clean' {
        Write-Host "🧹 Limpando dados antigos..." -ForegroundColor Yellow
        Write-Host ""
        
        $confirm = Read-Host "ATENÇÃO: Isso irá apagar TODOS os dados coletados. Confirmar? (s/N)"
        
        if ($confirm -eq 's' -or $confirm -eq 'S') {
            $compose = Get-ComposeCmd
            & $compose.exe @($compose.args + 'down' + '-v')
            Write-Host "✅ Dados limpos" -ForegroundColor Green
        } else {
            Write-Host "Operação cancelada" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
