# main.tf — orquesta los 5 módulos sobre el mismo VPS (ver providers.tf para el
# por qué de Docker-sobre-SSH en vez de un provider de nube).

module "network" {
  source = "./modules/network"

  manage                = var.manage_existing_resources
  compose_project_name   = var.compose_project_name
}

module "storage" {
  source = "./modules/storage"

  manage                = var.manage_existing_resources
  compose_project_name   = var.compose_project_name
}

module "firewall" {
  source = "./modules/firewall"

  vps_host          = var.vps_host
  vps_ssh_user      = var.vps_ssh_user
  vps_ssh_port      = var.vps_ssh_port
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "host_bootstrap" {
  source = "./modules/host_bootstrap"

  vps_host     = var.vps_host
  vps_ssh_user = var.vps_ssh_user
  vps_ssh_port = var.vps_ssh_port
  deploy_path  = var.deploy_path
  runtime_dirs = var.runtime_dirs

  # El firewall debe quedar activo antes de tocar el resto del host: así, si
  # algo falla a medio bootstrap, el VPS ya está protegido.
  depends_on = [module.firewall]
}

module "dns" {
  count  = var.manage_dns ? 1 : 0
  source = "./modules/dns"

  domain_name = var.domain_name
  zone_id     = var.cloudflare_zone_id
  vps_ip      = var.vps_host
}
