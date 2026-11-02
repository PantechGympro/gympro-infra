# Módulo opcional -- solo se instancia si manage_dns = true en el root module
# (ver ../../variables.tf). Asume que la zona de var.domain_name ya existe en
# Cloudflare. Si gympro.lat se administra en otro registrador, sustituye este
# módulo por el provider correspondiente, o deja manage_dns = false y
# gestiona el registro A manualmente (ver ../../../deploy/nginx/*.conf:
# gympro.lat, www.gympro.lat y api.gympro.lat deben apuntar los 3 a la IP del
# VPS).
resource "cloudflare_record" "root" {
  zone_id = var.zone_id
  name    = "@"
  content = var.vps_ip
  type    = "A"
  proxied = false
  ttl     = 300
}

resource "cloudflare_record" "www" {
  zone_id = var.zone_id
  name    = "www"
  content = var.vps_ip
  type    = "A"
  proxied = false
  ttl     = 300
}

resource "cloudflare_record" "api" {
  zone_id = var.zone_id
  name    = "api"
  content = var.vps_ip
  type    = "A"
  proxied = false
  ttl     = 300
}
