@echo off
title Edge Relay Monitor
color 0A

:loop
cls
echo.
echo ========================================
echo   EDGE RELAY MONITOR
echo ========================================
echo.

curl -s http://127.0.0.1:18001/health 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERRO] Relay nao esta respondendo!
    echo Inicie o relay com: start-relay.bat
) else (
    echo.
    echo Relay ONLINE em http://127.0.0.1:18001
)

echo.
echo ----------------------------------------
echo Arquivos na fila pendente:
dir /B "infra\edge-relay\queue\*.json" 2>nul | find /C ".json"
echo ----------------------------------------
echo.
echo Pressione CTRL+C para sair
echo Atualizando em 5 segundos...
timeout /t 5 /nobreak >nul
goto loop
