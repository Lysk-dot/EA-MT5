<#
move-repo-to-mql5.ps1
Descrição:
  Copia (ou move) todo o conteúdo do repositório atual para o caminho do MetaTrader Experts.
  Faz backup automático do destino se já existir, usa robocopy para preservar atributos e subpastas,
  e tenta criar um link simbólico (ou junction) se -Move for usado.

Uso:
  - Abra o PowerShell no diretório raiz do repositório local (ou informe -Source).
  - Execute:
      .\move-repo-to-mql5.ps1
    Exemplos:
      .\move-repo-to-mql5.ps1                       # copia para o destino padrão, exclui .git
      .\move-repo-to-mql5.ps1 -IncludeGit           # copia incluindo a pasta .git
      .\move-repo-to-mql5.ps1 -Move                 # copia, apaga origem e tenta criar symlink
      .\move-repo-to-mql5.ps1 -Destination "C:\Outro\Caminho" -Move

Parâmetros:
  -Destination (string)  : Caminho final (padrão abaixo)
  -Source (string)       : Diretório de origem (padrão = diretório atual)
  -Move (switch)         : Se presente, remove a origem após cópia e tenta criar link
  -IncludeGit (switch)   : Se presente, inclui a pasta .git na cópia
#>
# (c) 2025 Felipe Petracco Carmo <kuramopr@gmail.com>. Proprietary. Todos os direitos reservados.

param(
    [string]$Destination = "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\D36DE9E413048DE15F2CEE9B72F26E48\MQL5\Experts\mt5-trading-db",
    [string]$Source = (Get-Location).ProviderPath,
    [switch]$Move,
    [switch]$IncludeGit
)

Set-StrictMode -Version Latest

function Write-Info($msg)  { Write-Host $msg -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host $msg -ForegroundColor Green }
function Write-Err($msg)   { Write-Host $msg -ForegroundColor Red }

try {
    Write-Info "Iniciando operação..."
    Write-Info "Origem: $Source"
    Write-Info "Destino: $Destination"
    Write-Info "Operação: $(if ($Move) { 'MOVER (copiar → remover origem)' } else { 'COPIAR' })"
    Write-Info "Incluir .git: $($IncludeGit.IsPresent)"

    if (-not (Test-Path -Path $Source -PathType Container)) {
        throw "Diretório de origem não existe: $Source"
    }

    # Se destino existir, renomeia para backup com timestamp
    if (Test-Path -Path $Destination) {
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $backup = "${Destination}_backup_$timestamp"
        Write-Info "Destino já existe. Renomeando destino atual para backup: $backup"
        try {
            # Garantir que o caminho pai do backup exista
            $backupParent = Split-Path -Parent $backup
            if (-not (Test-Path -Path $backupParent)) {
                New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
            }
            Move-Item -Path $Destination -Destination $backup -Force -ErrorAction Stop
            Write-Ok "Backup criado: $backup"
        } catch {
            throw "Falha ao renomear destino existente: $_"
        }
    }

    # Garante que o diretório pai do destino exista
    $destParent = Split-Path -Parent $Destination
    if (-not (Test-Path -Path $destParent)) {
        Write-Info "Criando diretório pai do destino: $destParent"
        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    }

    # Preparar exclusões (por padrão excluir .git)
    $excludeArgs = @()
    if (-not $IncludeGit) {
        # Excluir .git (pode ser apenas nome da pasta)
        $excludeArgs += "/XD"
        $excludeArgs += ".git"
    }

    # Monta e executa robocopy para copiar com mirror
    Write-Info "Executando robocopy para copiar/espelhar arquivos..."
    $robocopyArgs = @(
        $Source,
        $Destination,
        "/MIR",            # mirror: copia e purga
        "/COPY:DAT",       # copy data, attributes, timestamps
        "/R:2", "/W:3"     # retries
    ) + $excludeArgs

    # Executa robocopy (robocopy é um comando externo)
    & robocopy @robocopyArgs
    $rc = $LASTEXITCODE
    Write-Info "robocopy exit code: $rc"
    # Robocopy codes 0-7 geralmente indicam sucesso/alertas; >7 é falha
    if ($rc -gt 7) {
        throw "robocopy relatou falha (código $rc). Verifique mensagens do robocopy acima."
    }

    Write-Ok "Cópia/espelhamento concluído."

    # Se Move, tentar remover a origem (com cautela se o script está dentro da origem)
    if ($Move) {
        Write-Info "Modo MOVE: remover origem e tentar criar link do caminho antigo para o novo."

        # Checar se destino existe antes de apagar
        if (-not (Test-Path -Path $Destination -PathType Container)) {
            throw "Destino não encontrado após cópia; abortando remoção da origem."
        }

        $scriptPath = $MyInvocation.MyCommand.Path
        $scriptInsideSource = $false
        if ($scriptPath) {
            $scriptFull = (Resolve-Path -LiteralPath $scriptPath).ProviderPath
            $sourceFull = (Resolve-Path -LiteralPath $Source).ProviderPath
            if ($scriptFull.StartsWith($sourceFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                $scriptInsideSource = $true
            }
        }

        try {
            if ($scriptInsideSource) {
                Write-Info "O script está sendo executado dentro da origem. Irei remover todo o conteúdo da origem EXCETO o próprio script para evitar erro."
                Get-ChildItem -LiteralPath $Source -Force | Where-Object { $_.FullName -ne $scriptFull } |
                    ForEach-Object {
                        try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop } catch { Write-Warning "Falha ao remover '$_': $_" }
                    }
                Write-Ok "Conteúdo da origem removido (exceto o script)."
                Write-Info "Você pode remover manualmente o script após encerrar sua execução se desejar."
            } else {
                Write-Info "Removendo origem: $Source"
                Remove-Item -LiteralPath $Source -Recurse -Force -ErrorAction Stop
                Write-Ok "Origem removida."
            }
        } catch {
            Write-Warning "Falha ao remover origem automaticamente: $_. Você pode remover manualmente."
        }

        # Tentar criar link simbólico; se falhar, tentar junction
        try {
            Write-Info "Tentando criar link simbólico (pode exigir privilégios/Admin ou Developer Mode)..."
            New-Item -ItemType SymbolicLink -Path $Source -Target $Destination -Force -ErrorAction Stop | Out-Null
            Write-Ok "Symlink criado: $Source -> $Destination"
        } catch {
            Write-Warning "Não foi possível criar symlink: $_. Tentando criar junction (menos privilégios necessários)."
            try {
                New-Item -ItemType Junction -Path $Source -Target $Destination -Force -ErrorAction Stop | Out-Null
                Write-Ok "Junction criada: $Source -> $Destination"
            } catch {
                Write-Warning "Falha ao criar junction também: $_. Você pode criar manualmente com permissões elevadas:"
                Write-Host "  New-Item -ItemType SymbolicLink -Path `"$Source`" -Target `"$Destination`""
            }
        }
    }

    # Sumário final: contar arquivos
    $countDest = 0
    try { $countDest = (Get-ChildItem -LiteralPath $Destination -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count } catch {}
    $countSrc = 0
    try {
        if (Test-Path -LiteralPath $Source) {
            $countSrc = (Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        } else { $countSrc = 0 }
    } catch {}

    Write-Ok "Resumo:"
    Write-Ok "  Arquivos no destino: $countDest"
    Write-Ok "  Arquivos na origem (após operação): $countSrc"
    Write-Ok "  Caminho final: $Destination"

    Write-Ok "Operação concluída com sucesso."
    exit 0

} catch {
    Write-Err "ERRO: $_"
    exit 1
}
Move-Item -Path "c:\Users\lysk9\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\move-repo-to-mql5.ps1" -Destination "c:\Users\lysk9\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\scripts\move-repo-to-mql5.ps1"