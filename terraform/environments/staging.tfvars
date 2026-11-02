# environments/staging.tfvars — entorno nuevo, sin datos reales.
# Terraform SÍ crea red y volúmenes desde cero aquí (manage_existing_resources = true).

environment               = "staging"
vps_host                  = "REEMPLAZA_CON_IP_DEL_VPS_STAGING"
vps_ssh_user              = "deploy"
compose_project_name      = "gympro-staging"
manage_existing_resources = true
deploy_path                = "/opt/gympro-staging"

# Restringe esto a las IPs/VPN reales del equipo en cuanto se confirmen.
allowed_ssh_cidrs = ["0.0.0.0/0"]

manage_dns = false
