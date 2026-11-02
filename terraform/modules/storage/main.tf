# Los 3 volúmenes nombrados reales que crea Compose (bloque `volumes:` al
# final de docker-compose.server.yml): pg_data, mongo_data y ollama_models.
# Docker los prefija con el nombre del proyecto de Compose — en production ya
# existen como "gympro-server_pg_data", etc., con los datos reales del
# gimnasio piloto.
#
# backups/ y uploads/ NO son volúmenes de Docker (son bind mounts a carpetas
# del host, ./backups y ./uploads en docker-compose.server.yml) — esas se
# gestionan en el módulo host_bootstrap, no aquí.
locals {
  volume_names = ["pg_data", "mongo_data", "ollama_models"]
}

resource "docker_volume" "data" {
  for_each = var.manage ? toset(local.volume_names) : []

  name = "${var.compose_project_name}_${each.value}"

  # Nunca destruir un volumen con datos reales (Postgres/Mongo del piloto o el
  # modelo de Ollama ya descargado) por un `terraform apply`/`destroy` que
  # recalcule mal este recurso.
  lifecycle {
    prevent_destroy = true
  }
}
