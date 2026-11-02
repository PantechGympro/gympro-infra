# Reglas de firewall del host vía UFW: el equivalente real a "grupos de
# seguridad" en un VPS propio sin API de nube (Contabo no expone security
# groups administrables por Terraform, ver ../../providers.tf). Idempotente:
# `ufw allow` no duplica una regla ya existente, y el script completo solo se
# re-ejecuta si cambia su contenido (ver el trigger "script_hash" abajo) —
# por eso un `terraform plan` repetido sobre el mismo estado no reporta drift.
#
# Hallazgo real al escribir este módulo (ver ../../../docker-compose.server.yml,
# el que de verdad corre en el VPS, no docker-compose.prod.yml): postgres
# (5434), mongo (27036) y ollama (11435) publican su puerto en TODAS las
# interfaces, no solo en loopback. docker-compose.prod.yml sí los cierra
# (`ports: []`) pero esa variante no es la que usa el servidor real. Sin un
# firewall explícito a nivel de host, esos 3 puertos quedan alcanzables desde
# internet. Este módulo cierra esa brecha: solo 22/80/443 quedan abiertos;
# todo lo demás (5434, 27036, 8081, 11435, y el 5000 de la API que ya está en
# loopback) se deniega por la policy default de UFW, sin necesidad de reglas
# DENY explícitas por puerto.
locals {
  firewall_script = <<-EOT
    set -e
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    %{ for cidr in var.allowed_ssh_cidrs ~}
    sudo ufw allow from ${cidr} to any port 22 proto tcp comment 'gympro:ssh'
    %{ endfor ~}
    sudo ufw allow 80/tcp comment 'gympro:http'
    sudo ufw allow 443/tcp comment 'gympro:https'
    sudo ufw --force enable
    sudo ufw status verbose
  EOT
}

resource "null_resource" "ufw_rules" {
  triggers = {
    script_hash       = sha256(local.firewall_script)
    allowed_ssh_cidrs = join(",", var.allowed_ssh_cidrs)
  }

  connection {
    type = "ssh"
    host = var.vps_host
    user = var.vps_ssh_user
    port = var.vps_ssh_port
  }

  provisioner "remote-exec" {
    inline = [local.firewall_script]
  }
}
