# environments/production.tfvars — el VPS real del gimnasio piloto, con datos
# reales (Postgres/Mongo del piloto). NO poner manage_existing_resources en
# true sin haber corrido antes los `terraform import` del README: Terraform
# intentaría CREAR una red/volúmenes que ya existen y falla (o, peor, si en
# algún momento cambia la lógica, podría recrearlos vacíos).

environment               = "production"
vps_host                  = "REEMPLAZA_CON_IP_DEL_VPS_REAL_DEL_GIMNASIO"
vps_ssh_user              = "deploy" # o el usuario SSH ya configurado en el VPS
compose_project_name      = "gympro-server" # debe calzar EXACTO con el name: de docker-compose.server.yml
manage_existing_resources = false
deploy_path                = "/opt/gympro" # ajustar a la ruta real donde ya está clonado en el VPS

# Restringe esto a las IPs/VPN reales del equipo en cuanto se confirmen —
# es el VPS que corre el sistema real del gimnasio piloto.
allowed_ssh_cidrs = ["0.0.0.0/0"]

manage_dns = false
