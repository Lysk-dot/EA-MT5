terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Este módulo é um esqueleto para o servidor Linux (Prometheus + Grafana via Docker)
# Ajuste paths, volumes e secrets conforme sua infra.

resource "docker_image" "prometheus" {
  name = "prom/prometheus:v2.55.1"
}
resource "docker_image" "grafana" {
  name = "grafana/grafana:11.2.2"
}

resource "docker_container" "prometheus" {
  name  = "prometheus"
  image = docker_image.prometheus.latest
  ports {
    internal = 9090
    external = 9090
  }
  volumes {
    host_path      = abspath("./prometheus.yml")
    container_path = "/etc/prometheus/prometheus.yml"
    read_only      = true
  }
}

resource "docker_container" "grafana" {
  name  = "grafana"
  image = docker_image.grafana.latest
  ports {
    internal = 3000
    external = 3000
  }
  env = [
    "GF_SECURITY_ADMIN_USER=admin",
    "GF_SECURITY_ADMIN_PASSWORD=admin",
  ]
}
