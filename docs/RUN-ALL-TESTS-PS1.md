# Script de Execução de Testes: `run-all-tests.ps1`

Este script automatiza a execução dos testes do projeto EA-MT5.

## Localização

- Caminho: `run-all-tests.ps1`

## Funcionalidade

- Verifica se o pacote `pytest` está instalado.
- Instala o `pytest` automaticamente se necessário.
- Executa os testes dos módulos de logging e métricas.
- Exibe o resultado dos testes no terminal.

## Uso

Execute o script via PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File run-all-tests.ps1
```

## Saída Esperada

- Mensagem indicando sucesso ou falha dos testes.
- Detalhes dos testes executados e possíveis avisos.

## Observações

- O caminho do Python pode ser ajustado conforme o ambiente.
- Para adicionar novos testes, inclua o arquivo no comando pytest dentro do script.
