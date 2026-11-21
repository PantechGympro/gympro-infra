#!/usr/bin/env bash
# rollback.sh <staging|prod> <gympro-api|gympro-web|gympro-infra>
# Restaura el código guardado por snapshot-release.sh, reconstruye el servicio y
# vuelve a verificar la salud. Sale 0 si el ambiente quedó sano.
#
# LÍMITE CONOCIDO: las migraciones de Alembic que ya corrieron NO se revierten.
# El código anterior debe poder funcionar con el esquema nuevo (patrón
# expandir/contraer: primero añadir columnas/tablas, borrar en un despliegue posterior).
set -uo pipefail
. "$(dirname "$0")/lib.sh"
cargar_entorno "${1:-}"
repo="${2:?Falta el repo}"
snap="$SNAP_DIR/$repo"; dest="$ROOT/$repo"
servicio="$(servicio_de "$repo")" || exit 64

if [ ! -d "$snap" ] || [ -z "$(ls -A "$snap" 2>/dev/null)" ]; then
  log "❌ No hay snapshot de $repo: no se puede revertir automáticamente."
  exit 2
fi

log "Restaurando $repo desde $snap (commit $(cat "$snap/BUILD_INFO" 2>/dev/null | cut -c1-12 || echo desconocido))"
rsync -ac --delete --exclude='.env' --exclude='.git' --exclude='uploads/' --exclude='backups/' "$snap/" "$dest/" || exit 1

if [ -n "$servicio" ]; then compose up -d --build "$servicio" || exit 1
else compose up -d --build || exit 1; fi

log "Verificando el ambiente tras el rollback…"
bash "$(dirname "$0")/post-deploy-check.sh" "$DEPLOY_ENV" "${ROLLBACK_VERIFY_TIMEOUT:-240}"
