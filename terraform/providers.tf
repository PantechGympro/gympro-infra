# providers.tf — Docker remoto por SSH + Cloudflare (DNS, opcional).
#
# Por qué Docker-sobre-SSH y no un provider de nube (AWS/DigitalOcean/Hetzner):
# el VPS de GymPro es un servidor propio ya contratado (Contabo Cloud VPS 10,
# ver ../docker-compose.prod.yml) sin API de aprovisionamiento de máquinas
# virtuales. Terraform no puede "crear" ese VPS — ya existe y se administra
# por SSH — pero sí puede declarar como código su configuración: red Docker,
# volúmenes, firewall y bootstrap del host. El provider oficial de Docker
# soporta conectarse a un daemon remoto por SSH de forma nativa; lo que no
# tiene recurso nativo (firewall UFW, paquetes del sistema) se declara con
# null_resource + remote-exec sobre la misma conexión SSH.
#
# Autenticación SSH: la máquina donde corres `terraform apply` debe poder
# hacer `ssh ${var.vps_ssh_user}@${var.vps_host}` sin pedir contraseña (llave
# en el ssh-agent, o un Host configurado en ~/.ssh/config con IdentityFile).
# Terraform nunca recibe la llave privada como variable — así nunca queda en
# el state ni en un .tfvars versionado.
provider "docker" {
  host = "ssh://${var.vps_ssh_user}@${var.vps_host}:${var.vps_ssh_port}"
}

# Solo se usa si manage_dns = true (ver variables.tf). Si gympro.lat no está en
# Cloudflare, sustituye este provider por el de tu registrador real y ajusta
# modules/dns, o deja manage_dns = false y gestiona el registro A a mano.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
