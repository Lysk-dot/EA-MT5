<#
Centraliza logs de API, Relay e MT5 em um arquivo único rolling.
- Junta infra\logs\api.log e infra\logs\relay.log com Journal do MT5.
- Mantém um arquivo central em logs\central.log (rotaciona ~20MB).
Use com agendador (a cada 1-5 min) ou execute manualmente.
#>
# Script utilitário movido da raiz
. "$PSScriptRoot\..\..\centralize-logs.ps1"