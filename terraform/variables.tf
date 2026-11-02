variable "environment" {
  description = "Entorno de despliegue: \"staging\" o \"production\". Determina qué tfvars de environments/ se pasa a `terraform plan/apply -var-file=...` y debe coincidir con el *workspace* de Terraform activo."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment debe ser \"staging\" o \"production\"."
  }
}

variable "vps_host" {
  description = "IP o hostname del VPS de este entorno."
  type        = string
}

variable "vps_ssh_user" {
  description = "Usuario SSH con permisos de docker (grupo `docker`) y sudo para las reglas de firewall y el bootstrap del host."
  type        = string
  default     = "deploy"
}

variable "vps_ssh_port" {
  description = "Puerto SSH del VPS."
  type        = number
  default     = 22
}

variable "compose_project_name" {
  description = <<-EOT
    Debe ser IDÉNTICO al `name:` del docker-compose*.yml que corre en este
    entorno (ver ../README.md: "Punto crítico: no cambiar el name: del
    proyecto de Compose"). En production ya es "gympro-server"
    (docker-compose.server.yml, el que de verdad corre en el VPS) — cambiarlo
    aquí sin cambiarlo allá (o viceversa) hace que Compose cree volúmenes
    nuevos y vacíos, perdiendo de vista los datos reales del gimnasio piloto.
  EOT
  type = string
}

variable "manage_existing_resources" {
  description = <<-EOT
    false (default): los módulos "network" y "storage" NO intentan crear la
    red ni los volúmenes de Docker — asumen que ya existen (caso real de
    "production", creados por `docker compose up` antes de que existiera este
    código Terraform). Pásalo a true solo DESPUÉS de adoptarlos con
    `terraform import` (ver terraform/README.md) para que Terraform los
    administre sin recrearlos ni perder datos.
    En "staging" (entorno nuevo, sin datos) debe ser true desde el principio.
  EOT
  type    = bool
  default = false
}

variable "deploy_path" {
  description = "Ruta absoluta en el VPS donde viven, como carpetas hermanas, gympro-api/, gympro-web/ y gympro-infra/ (ver ../README.md: estructura de carpetas esperada)."
  type        = string
  default     = "/opt/gympro"
}

variable "runtime_dirs" {
  description = "Subcarpetas de estado que docker-compose.server.yml monta como bind mount dentro de gympro-infra/ (backups/, uploads/) y que deben existir con los permisos correctos antes del primer `docker compose up`."
  type        = list(string)
  default     = ["backups", "uploads"]
}

variable "allowed_ssh_cidrs" {
  description = <<-EOT
    CIDRs permitidos para SSH (puerto 22) en el firewall del host. El default
    0.0.0.0/0 (cualquier IP) es intencionalmente permisivo para no bloquear a
    nadie del equipo al aplicar por primera vez: RESTRÍNGELO en
    environments/production.tfvars a las IPs/VPN reales del equipo en cuanto
    se confirmen — es la recomendación de seguridad real para el VPS del
    piloto, no solo un placeholder.
  EOT
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "domain_name" {
  description = "Dominio base de GymPro."
  type        = string
  default     = "gympro.lat"
}

variable "manage_dns" {
  description = <<-EOT
    true activa el módulo "dns", que crea los registros A de gympro.lat / www
    / api vía el provider de Cloudflare (requiere cloudflare_api_token +
    cloudflare_zone_id). Default false: hoy el DNS de gympro.lat se administra
    manualmente donde se compró el dominio — déjalo así hasta confirmar que la
    zona vive en Cloudflare, o cambia modules/dns por el provider de tu
    registrador real.
  EOT
  type    = bool
  default = false
}

variable "cloudflare_api_token" {
  description = "Token de API de Cloudflare (scope Zone:DNS Edit). Solo se usa si manage_dns = true. NUNCA lo pongas en un .tfvars versionado: pásalo con TF_VAR_cloudflare_api_token o como variable sensible en Terraform Cloud."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID de gympro.lat en Cloudflare. Solo se usa si manage_dns = true."
  type        = string
  default     = ""
}
