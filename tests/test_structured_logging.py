import os
import json
from pathlib import Path
from infra.observability.structured_logging import setup_structured_logging, LogContext, log_with_metrics

def test_basic_logging(tmp_path):
    log_file = tmp_path / "test_api.log"
    logger = setup_structured_logging(log_file=log_file, level="INFO", enable_console=False)
    with LogContext(symbol="EURUSD", timeframe="M1", mode="TIMER"):
        log_with_metrics(
            logger, "info", "Test log entry", duration_ms=123.4, items_count=10
        )
    # Verifica se o arquivo foi criado
    assert log_file.exists()
    # Verifica se o log está em formato JSON e contém os campos
    with open(log_file, "r", encoding="utf-8") as f:
        line = f.readline()
        data = json.loads(line)
        assert data["symbol"] == "EURUSD"
        assert data["timeframe"] == "M1"
        assert data["mode"] == "TIMER"
        assert data["duration_ms"] == 123.4
        assert data["items_count"] == 10
        assert "timestamp" in data
        assert "message" in data
        assert "source" in data

def test_logcontext_reset(tmp_path):
    log_file = tmp_path / "test_api2.log"
    logger = setup_structured_logging(log_file=log_file, level="INFO", enable_console=False)
    with LogContext(symbol="GBPUSD", timeframe="H1"):
        log_with_metrics(logger, "info", "Symbol GBPUSD", items_count=5)
    # Fora do contexto, não deve ter symbol/timeframe
    log_with_metrics(logger, "info", "No context", items_count=1)
    with open(log_file, "r", encoding="utf-8") as f:
        lines = f.readlines()
        data1 = json.loads(lines[0])
        data2 = json.loads(lines[1])
        assert data1["symbol"] == "GBPUSD"
        assert data1["timeframe"] == "H1"
        assert "symbol" not in data2 or data2["symbol"] == ""
        assert "timeframe" not in data2 or data2["timeframe"] == ""
