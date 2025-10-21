@echo off
REM Inicializa API local SQLite e Edge Relay em janelas separadas
echo ======================================
echo INICIANDO SISTEMA COMPLETO
echo ======================================

set BASE_DIR=%~dp0

echo.
echo [1/2] Iniciando API SQLite local (porta 18002)...
start "API-SQLite-Local" cmd /k "cd /d %BASE_DIR%infra\api && set ALLOWED_TOKEN=changeme && python -m uvicorn app.main_lite:app --host 127.0.0.1 --port 18002"

timeout /t 5 /nobreak >nul

echo [2/2] Iniciando Edge Relay (porta 18001)...
start "Edge-Relay" cmd /k "cd /d %BASE_DIR%infra\edge-relay && python -m app.main"

timeout /t 5 /nobreak >nul

echo.
echo ======================================
echo SISTEMA INICIADO
echo ======================================
echo.
echo API Local:    http://127.0.0.1:18002/health
echo Edge Relay:   http://127.0.0.1:18001/health
echo.
echo Para verificar status:
echo   curl http://127.0.0.1:18002/stats
echo.
echo Pressione qualquer tecla para sair (janelas continuarao abertas)...
pause >nul
