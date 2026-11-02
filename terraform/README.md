# Terraform — Infraestructura como código (HU-27)

Declara como código la infraestructura del VPS de GymPro: red Docker, volúmenes
persistentes, firewall del host y bootstrap base de la máquina. **No** declara
los contenedores de aplicación en sí (eso sigue siendo trabajo de
`docker-compose*.yml`, un nivel arriba) — Terraform y Compose conviven, cada
uno dueño de una capa distinta.

## Por qué este diseño (sin provider de nube)

El VPS real (Contabo Cloud VPS 10, ver `../docker-compose.prod.yml`) es un
servidor propio ya contratado, sin API pública de aprovisionamiento de
máquinas virtuales — no es AWS/DigitalOcean/Hetzner. Por eso no hay un recurso
Terraform que "cree la VM": la instancia de cómputo ya existe y se administra
por SSH, igual que hoy. Lo que **sí** se declara como código, con los
providers oficiales de Terraform, es:

| Requisito de HU-27                         | Cómo se implementa aquí |
|---------------------------------------------|--------------------------|
| Instancias de cómputo                       | `modules/host_bootstrap` — bootstrap idempotente del host vía SSH (Docker Engine, estructura de carpetas) en vez de crear la VM |
| Red virtual                                 | `modules/network` — `docker_network` sobre el daemon remoto |
| Reglas de firewall (grupos de seguridad)    | `modules/firewall` — reglas UFW idempotentes vía SSH (ver hallazgo de seguridad abajo) |
| Volúmenes de almacenamiento persistente     | `modules/storage` — `docker_volume` para `pg_data`/`mongo_data`/`ollama_models` |
| Configuración de DNS                        | `modules/dns` (opcional, Cloudflare) — desactivado por default, ver abajo |
| Backend remoto para tfstate con locking     | `cloud` block de HCP Terraform (ver `versions.tf`) |
| Separación de entornos (staging/producción) | *Workspaces* de Terraform + `environments/*.tfvars` |

## Hallazgo de seguridad que motivó el módulo de firewall

Revisando `../docker-compose.server.yml` (el que realmente corre en el VPS,
no `docker-compose.prod.yml`) para escribir este módulo: `postgres` (5434),
`mongo` (27036) y `ollama` (11435) publican su puerto en **todas** las
interfaces de red, no solo en loopback. `docker-compose.prod.yml` sí los
cierra (`ports: []`), pero esa variante no es la que usa el servidor real.
Sin un firewall de host, esos 3 puertos quedan alcanzables directo desde
internet, sin pasar por el nginx del host ni por TLS. `modules/firewall`
cierra esa brecha: solo 22/80/443 quedan abiertos; el resto se deniega por la
policy default de UFW. Esto no modifica los `docker-compose*.yml` — es una
capa de defensa adicional a nivel de host, independiente de cómo Docker
publique los puertos.

## Requisitos antes de usar esto

1. **Cuenta de [Terraform Cloud](https://app.terraform.io)** (gratis) con una
   organización creada — reemplaza `"pantechgympro"` en `versions.tf` por el
   slug real, y corre `terraform login` una vez en tu máquina.
2. **Acceso SSH sin contraseña** al VPS del entorno (`ssh-agent` con la llave
   cargada, o un `Host` en `~/.ssh/config` con `IdentityFile`). Terraform
   nunca recibe la llave privada como variable: así nunca queda en el state
   ni en un `.tfvars` versionado.
3. El usuario SSH (`vps_ssh_user`) debe estar en el grupo `docker` (o poder
   usar `sudo` para los comandos de bootstrap/firewall).
4. Terraform CLI >= 1.6 instalado localmente.

## Comandos manuales

```bash
cd terraform

terraform init

# Primera vez: crea los workspaces de Terraform Cloud (uno por entorno)
terraform workspace new staging
terraform workspace new production

# --- staging (entorno nuevo, sin datos: se crea todo desde cero) ---
terraform workspace select staging
terraform plan  -var-file=environments/staging.tfvars
terraform apply -var-file=environments/staging.tfvars

# --- production (VPS real del gimnasio piloto, YA tiene datos) ---
terraform workspace select production
terraform plan -var-file=environments/production.tfvars
# revisar el plan con cuidado -- ver sección "Adoptar production" abajo
# antes de aplicar nada con manage_existing_resources = true
```

### Adoptar `production` sin recrear ni perder datos

En producción, la red y los 3 volúmenes **ya existen** (los creó
`docker compose up` antes de que existiera este código). Mientras
`manage_existing_resources = false` (default en
`environments/production.tfvars`), Terraform solo gestiona firewall +
bootstrap del host — ninguno de los dos toca red/volúmenes/contenedores. Para
que Terraform también administre la red y los volúmenes reales (sin
recrearlos ni perder datos), antes de poner `manage_existing_resources = true`
hay que **adoptarlos** con `terraform import`:

```bash
terraform workspace select production

terraform import module.network.docker_network.gympro[0] gympro-server_gympro
terraform import 'module.storage.docker_volume.data["pg_data"]'       gympro-server_pg_data
terraform import 'module.storage.docker_volume.data["mongo_data"]'    gympro-server_mongo_data
terraform import 'module.storage.docker_volume.data["ollama_models"]' gympro-server_ollama_models

# Después del import, con manage_existing_resources = true en el tfvars:
terraform plan -var-file=environments/production.tfvars
# Debe mostrar 0 cambios (sin drift) -- si muestra algo distinto a los labels
# que agrega este módulo, NO aplicar sin entender primero por qué.
```

### DNS (desactivado por default)

`manage_dns = false` en ambos entornos: hoy el DNS de `gympro.lat` se
administra manualmente donde se compró el dominio. Si en algún momento la
zona se mueve a Cloudflare, activa `manage_dns = true` y define
`cloudflare_api_token` (variable de entorno `TF_VAR_cloudflare_api_token`,
nunca en un `.tfvars`) y `cloudflare_zone_id` en el `.tfvars` del entorno.

## Verificar "sin drift" (criterio de aceptación de HU-27)

```bash
terraform plan -var-file=environments/<entorno>.tfvars
```

Debe reportar `No changes.` en una segunda corrida sobre un entorno ya
aplicado. Los `null_resource` de firewall/bootstrap están diseñados para
esto: su `remote-exec` solo se re-ejecuta si cambia el contenido del script
(trigger `script_hash`), no en cada `apply`.
