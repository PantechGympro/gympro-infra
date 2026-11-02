# Bootstrap idempotente del host: el equivalente real de "instancia de
# cómputo como código" cuando la VM ya existe y no hay API de aprovisionamiento
# (ver ../../providers.tf) -- en vez de crear la máquina, se declara y aplica
# su configuración base de forma reproducible.
#
# Qué hace, en orden:
#   1. Confirma que Docker Engine + el plugin `docker compose` están
#      instalados (../../../docker-compose.yml los exige en su cabecera). Si
#      faltan, los instala con el script oficial get.docker.com (el mismo
#      método que recomienda la documentación de Docker para Debian/Ubuntu).
#   2. Crea var.deploy_path y, dentro de gympro-infra/, las carpetas
#      runtime_dirs (backups/, uploads/) con permisos 750 -- son las que
#      docker-compose.server.yml monta como bind mount para la API (ver
#      api.volumes ahí). Si no existen antes del primer `docker compose up`,
#      Docker las crea como root y la API (usuario no-root dentro del
#      contenedor) no puede escribir en ellas.
locals {
  bootstrap_script = <<-EOT
    set -e
    if ! command -v docker >/dev/null 2>&1; then
      curl -fsSL https://get.docker.com | sudo sh
      sudo usermod -aG docker "$(whoami)"
    fi
    docker compose version >/dev/null

    sudo mkdir -p "${var.deploy_path}"
    %{ for dir in var.runtime_dirs ~}
    sudo mkdir -p "${var.deploy_path}/gympro-infra/${dir}"
    sudo chmod 750 "${var.deploy_path}/gympro-infra/${dir}"
    %{ endfor ~}
    sudo chown -R "$(whoami):$(whoami)" "${var.deploy_path}"
  EOT
}

resource "null_resource" "bootstrap" {
  triggers = {
    script_hash = sha256(local.bootstrap_script)
  }

  connection {
    type = "ssh"
    host = var.vps_host
    user = var.vps_ssh_user
    port = var.vps_ssh_port
  }

  provisioner "remote-exec" {
    inline = [local.bootstrap_script]
  }
}
