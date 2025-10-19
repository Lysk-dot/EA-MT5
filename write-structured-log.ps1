param(
    [string]$LogFile,
    [string]$Level = "INFO",
    [string]$Message,
    [hashtable]$Context = @{}
)

# Script auxiliar para gerar logs estruturados compatíveis com Loki

function Write-StructuredLog {
    param(
        [string]$FilePath,
        [string]$Level,
        [string]$Message,
        [hashtable]$Context
    )
    
    $scriptName = if ($MyInvocation.ScriptName) { 
        Split-Path -Leaf $MyInvocation.ScriptName 
    } else { 
        "interactive" 
    }
    
    $log = [PSCustomObject]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        level = $Level.ToUpper()
        script = $scriptName
        message = $Message
        hostname = $env:COMPUTERNAME
        user = $env:USERNAME
    }
    
    # Adicionar contexto customizado
    foreach ($key in $Context.Keys) {
        $log | Add-Member -NotePropertyName $key -NotePropertyValue $Context[$key]
    }
    
    # Converter para JSON e salvar
    $jsonLog = $log | ConvertTo-Json -Compress
    $jsonLog | Out-File -Append -FilePath $FilePath -Encoding UTF8
    
    # Também imprimir no console (opcional)
    $color = switch ($Level.ToUpper()) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "INFO"  { "White" }
        "DEBUG" { "Gray" }
        default { "White" }
    }
    
    Write-Host ("[{0}] {1}: {2}" -f (Get-Date -Format "HH:mm:ss"), $Level.ToUpper(), $Message) -ForegroundColor $color
}

# Criar diretório de logs se não existir
$logsDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir | Out-Null
}

# Definir arquivo de log padrão
if (-not $LogFile) {
    $LogFile = Join-Path $logsDir 'automation.log'
}

# Escrever log
Write-StructuredLog -FilePath $LogFile -Level $Level -Message $Message -Context $Context

# Exemplo de uso:
# .\write-structured-log.ps1 -Level "INFO" -Message "Compilação iniciada" -Context @{ea="DataCollectorPRO"; version="1.65"}
# .\write-structured-log.ps1 -LogFile "logs/compile.log" -Level "ERROR" -Message "Falha na compilação" -Context @{exit_code=1; duration_ms=5234}
