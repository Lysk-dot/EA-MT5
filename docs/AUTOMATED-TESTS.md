# Testes Automatizados EA-MT5

Este documento descreve o processo de testes automatizados implementado no projeto EA-MT5.

## Scripts de Teste

- **tests/test_structured_logging.py**: Testa o módulo de logging estruturado, incluindo formatação JSON e contexto de logs.
- **tests/test_prometheus_metrics.py**: Testa o módulo de métricas Prometheus, incluindo registro e cálculo de métricas customizadas.

## Execução dos Testes

Utilize o script PowerShell `run-all-tests.ps1` para executar todos os testes automatizados:

```powershell
powershell -ExecutionPolicy Bypass -File run-all-tests.ps1
```

O script verifica se o `pytest` está instalado, executa os testes e exibe o resultado.

## Resultados Esperados

- Todos os testes devem passar sem erros.
- Avisos de depreciação podem aparecer, mas não impedem o sucesso dos testes.

## Localização dos Scripts

- Script de execução: `run-all-tests.ps1`
- Testes: `tests/test_structured_logging.py`, `tests/test_prometheus_metrics.py`

## Observações

- O ambiente Python 3.12 é utilizado.
- O caminho do executável Python pode ser ajustado no script conforme necessário.
- Para novos testes, adicione arquivos na pasta `tests/` e inclua no script conforme desejado.
