import socket
import pytest

# Testa conexão com localhost na porta padrão do PostgreSQL
@pytest.mark.parametrize("host, port", [
    ("127.0.0.1", 5432),  # PostgreSQL
    ("127.0.0.1", 8000),  # API local (exemplo)
])
def test_tcp_connection(host, port):
    try:
        with socket.create_connection((host, port), timeout=2):
            pass
    except Exception as e:
        pytest.fail(f"Falha ao conectar em {host}:{port} - {e}")

# Testa conexão HTTP com API local
import requests

def test_api_health():
    try:
        response = requests.get("http://127.0.0.1:8000/health")
        assert response.status_code == 200
    except Exception as e:
        pytest.fail(f"Falha ao conectar na API: {e}")
