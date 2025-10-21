@echo off
cd /d "%~dp0infra\edge-relay"
set REMOTE_INGEST=http://192.168.15.20:18001/ingest
set REMOTE_TICK=http://192.168.15.20:18001/ingest/tick
set REMOTE_TOKEN=changeme
set QUEUE_DIR=%~dp0infra\edge-relay\queue

echo.
echo  Iniciando Edge Relay em http://127.0.0.1:18001 ...
echo.
echo  Para parar o relay: feche esta janela ou pressione CTRL+C
echo.

python -m uvicorn app.main:app --host 127.0.0.1 --port 18001 --workers 1
