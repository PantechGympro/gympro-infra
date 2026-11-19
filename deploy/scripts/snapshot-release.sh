#!/usr/bin/env bash
# snapshot-release.sh <staging|prod> <gympro-api|gympro-web|gympro-infra>
# Guarda el código que está corriendo ANTES de sincronizar el nuevo, para poder
# volver a él si la verificación post-despliegue falla (rollback.sh).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
cargar_entorno "${1:-}"
repo="${2:?Falta el repo}"
src="$ROOT/$repo"; dst="$SNAP_DIR/$repo"

if [ -d "$src" ] && [ -n "$(ls -A "$src" 2>/dev/null)" ]; then
  mkdir -p "$dst"
  rsync -ac --delete --exclude='.git' --exclude='node_modules' --exclude='uploads/' --exclude='backups/' "$src/" "$dst/"
  log "Snapshot de $repo guardado en $dst ($(cat "$dst/BUILD_INFO" 2>/dev/null | cut -c1-12 || echo sin-commit))"
else
  warn "No hay versión previa de $repo en $src: este despliegue no tendrá rollback."
fi
