Write-Host ""
Write-Host " Instalando Python 3.12 via download..." -ForegroundColor Cyan
Write-Host ""

$url = "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe"
$output = Join-Path $env:TEMP "python-installer.exe"

try {
    Write-Host " Baixando de $url ..." -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $client = New-Object System.Net.WebClient
    $client.DownloadFile($url, $output)
    
    Write-Host " Download concluído: $output" -ForegroundColor Green
    Write-Host ""
    
    Write-Host " Instalando Python (modo silencioso com PATH e pip)..." -ForegroundColor Yellow
    $installArgs = @(
        "/quiet",
        "InstallAllUsers=1",
        "PrependPath=1",
        "Include_pip=1",
        "Include_test=0"
    )
    
    Start-Process -FilePath $output -ArgumentList $installArgs -Wait -NoNewWindow
    
    Write-Host ""
    Write-Host " Python instalado com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host " IMPORTANTE: Feche e reabra este terminal para usar 'python' e 'pip'" -ForegroundColor Cyan
    Write-Host ""
    
    # Tentar testar Python
    Write-Host " Testando instalação (pode não funcionar neste terminal ainda)..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
    
    # Atualizar PATH da sessão atual
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    $pythonVersion = & python --version 2>&1
    if($LASTEXITCODE -eq 0) {
        Write-Host " OK: $pythonVersion" -ForegroundColor Green
    } else {
        Write-Host " Feche e reabra o terminal para usar Python" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host " Após reabrir o terminal, rode:" -ForegroundColor Cyan
    Write-Host "   python --version" -ForegroundColor White
    Write-Host "   pip --version" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host " ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}
Write-Host ""
Write-Host " Instalando Python 3.12 via download..." -ForegroundColor Cyan
Write-Host ""

$url = "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe"
$output = Join-Path $env:TEMP "python-installer.exe"

try {
    Write-Host " Baixando de $url ..." -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $client = New-Object System.Net.WebClient
    $client.DownloadFile($url, $output)
    
    Write-Host " Download concluído: $output" -ForegroundColor Green
    Write-Host ""
    
    Write-Host " Instalando Python (modo silencioso com PATH e pip)..." -ForegroundColor Yellow
    $installArgs = @(
        "/quiet",
        "InstallAllUsers=1",
        "PrependPath=1",
        "Include_pip=1",
        "Include_test=0"
    )
    
    Start-Process -FilePath $output -ArgumentList $installArgs -Wait -NoNewWindow
    
    Write-Host ""
    Write-Host " Python instalado com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host " IMPORTANTE: Feche e reabra este terminal para usar 'python' e 'pip'" -ForegroundColor Cyan
    Write-Host ""
    
    # Tentar testar Python
    Write-Host " Testando instalação (pode não funcionar neste terminal ainda)..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
    
    # Atualizar PATH da sessão atual
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    $pythonVersion = & python --version 2>&1
    if($LASTEXITCODE -eq 0) {
        Write-Host " OK: $pythonVersion" -ForegroundColor Green
    } else {
        Write-Host " Feche e reabra o terminal para usar Python" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host " Após reabrir o terminal, rode:" -ForegroundColor Cyan
    Write-Host "   python --version" -ForegroundColor White
    Write-Host "   pip --version" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host " ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}
