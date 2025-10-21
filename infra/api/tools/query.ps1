# Script PowerShell para executar queries SQL facilmente
param([int]$Query = 1)

$pythonPath = "python"
$scriptPath = Join-Path $PSScriptRoot "query-db.py"

# Executar query
& $pythonPath $scriptPath $Query
