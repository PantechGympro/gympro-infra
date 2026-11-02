# La red real que Compose crea es "<compose_project_name>_gympro" (el nombre
# lógico "gympro" del bloque `networks:` en docker-compose*.yml, prefijado por
# Compose con el nombre del proyecto). No se inventa una red nueva: se declara
# exactamente esa, para que Terraform sea la fuente de verdad de su topología
# sin duplicar lo que Compose ya gestiona.
resource "docker_network" "gympro" {
  count = var.manage ? 1 : 0

  name   = "${var.compose_project_name}_gympro"
  driver = "bridge"

  labels {
    label = "managed-by"
    value = "terraform"
  }
}
