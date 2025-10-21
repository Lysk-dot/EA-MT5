"""
Structured Logging for EA-MT5 API
Integrates with Loki/Grafana observability stack
"""
import logging
import json
import sys
from datetime import datetime
from typing import Any, Dict, Optional
from contextvars import ContextVar
from pathlib import Path

# Context variables for request tracing
request_id_ctx: ContextVar[str] = ContextVar('request_id', default='')
symbol_ctx: ContextVar[str] = ContextVar('symbol', default='')
timeframe_ctx: ContextVar[str] = ContextVar('timeframe', default='')
mode_ctx: ContextVar[str] = ContextVar('mode', default='')

class StructuredFormatter(logging.Formatter):
    """
    Formata logs em JSON estruturado para Loki
    """
    
    def format(self, record: logging.LogRecord) -> str:
        # Base fields
        log_data = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
        }
        
        # Context from contextvars
        if request_id := request_id_ctx.get():
            log_data['request_id'] = request_id
        if symbol := symbol_ctx.get():
            log_data['symbol'] = symbol
        if timeframe := timeframe_ctx.get():
            log_data['timeframe'] = timeframe
        if mode := mode_ctx.get():
            log_data['mode'] = mode
        
        # Extra fields from log record
        extra_fields = record.__dict__.get('extra_fields')
        if extra_fields:
            log_data.update(extra_fields)

        # Exception info
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)

        # Source location (serialize as string)
        log_data['source'] = f"{record.pathname}:{record.lineno} ({record.funcName})"

        # Performance metrics if available
        duration_ms = record.__dict__.get('duration_ms')
        if duration_ms is not None:
            log_data['duration_ms'] = duration_ms
        status_code = record.__dict__.get('status_code')
        if status_code is not None:
            log_data['status_code'] = status_code

        return json.dumps(log_data, ensure_ascii=False)

def setup_structured_logging(
    log_file: Optional[Path] = None,
    level: str = 'INFO',
    enable_console: bool = True
) -> logging.Logger:
    """
    Configura logging estruturado
    
    Args:
        log_file: Caminho para arquivo de log (opcional)
        level: Nível de log (DEBUG, INFO, WARNING, ERROR)
        enable_console: Se deve logar no console também
    
    Returns:
        Logger configurado
    """
    logger = logging.getLogger('ea_mt5')
    logger.setLevel(getattr(logging, level.upper()))
    logger.handlers.clear()
    
    formatter = StructuredFormatter()
    
    # File handler (JSON estruturado para Loki)
    if log_file:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    
    # Console handler (legível para humanos)
    if enable_console:
        console_handler = logging.StreamHandler(sys.stdout)
        console_formatter = logging.Formatter(
            '%(asctime)s [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_handler.setFormatter(console_formatter)
        logger.addHandler(console_handler)
    
    return logger

class LogContext:
    """
    Context manager para adicionar contexto temporário aos logs
    
    Usage:
        with LogContext(symbol='EURUSD', timeframe='M1'):
            logger.info("Processing data")
    """
    
    def __init__(self, **kwargs):
        self.context = kwargs
        self.tokens = {}
    
    def __enter__(self):
        # Set context variables
        if 'request_id' in self.context:
            self.tokens['request_id'] = request_id_ctx.set(self.context['request_id'])
        if 'symbol' in self.context:
            self.tokens['symbol'] = symbol_ctx.set(self.context['symbol'])
        if 'timeframe' in self.context:
            self.tokens['timeframe'] = timeframe_ctx.set(self.context['timeframe'])
        if 'mode' in self.context:
            self.tokens['mode'] = mode_ctx.set(self.context['mode'])
        return self
    
    def __exit__(self, *args):
        # Reset context variables
        for var_name, token in self.tokens.items():
            if var_name == 'request_id':
                request_id_ctx.reset(token)
            elif var_name == 'symbol':
                symbol_ctx.reset(token)
            elif var_name == 'timeframe':
                timeframe_ctx.reset(token)
            elif var_name == 'mode':
                mode_ctx.reset(token)

def log_with_metrics(
    logger: logging.Logger,
    level: str,
    message: str,
    **metrics
):
    """
    Log com métricas adicionais
    
    Args:
        logger: Logger instance
        level: Nível do log (info, warning, error)
        message: Mensagem
        **metrics: Métricas adicionais (duration_ms, status_code, etc)
    
    Example:
        log_with_metrics(
            logger, 'info', 
            'Request processed',
            duration_ms=45.2,
            status_code=200,
            items_count=150
        )
    """
    log_func = getattr(logger, level)
    
    # Create log record with extra fields
    extra = {'extra_fields': metrics}
    log_func(message, extra=extra)

# Exemplo de uso em FastAPI middleware
"""
from fastapi import Request
import time
import uuid

@app.middleware("http")
async def log_requests(request: Request, call_next):
    request_id = str(uuid.uuid4())
    start_time = time.time()
    
    # Extrair contexto da request
    symbol = request.query_params.get('symbol', '')
    
    with LogContext(request_id=request_id, symbol=symbol, mode='api'):
        logger.info(f"Request started: {request.method} {request.url.path}")
        
        try:
            response = await call_next(request)
            duration_ms = (time.time() - start_time) * 1000
            
            log_with_metrics(
                logger, 'info',
                f"Request completed: {request.method} {request.url.path}",
                duration_ms=duration_ms,
                status_code=response.status_code,
                method=request.method,
                path=request.url.path
            )
            
            return response
        except Exception as e:
            duration_ms = (time.time() - start_time) * 1000
            logger.error(
                f"Request failed: {str(e)}",
                extra={'extra_fields': {
                    'duration_ms': duration_ms,
                    'error': str(e),
                    'method': request.method,
                    'path': request.url.path
                }}
            )
            raise
"""

# Queries úteis para Loki/Grafana:
"""
# RPS por símbolo
rate({app="expert-advisor",symbol=~".+"} [1m])

# Latência P95
histogram_quantile(0.95, 
  sum(rate({app="expert-advisor"} | json | duration_ms != "" [5m])) by (le)
)

# Erros por minuto
sum(rate({level="ERROR"} [1m])) by (symbol, mode)

# Top símbolos por volume de logs
topk(10, 
  sum(rate({app="expert-advisor"} [5m])) by (symbol)
)

# Requests por modo de coleta
sum(rate({mode=~".+"} [1m])) by (mode)

# Timeframes mais ativos
sum(count_over_time({timeframe=~".+"} [5m])) by (timeframe)
"""
