#!/usr/bin/env bash
# lib.sh — funciones comunes de los scripts de despliegue (SCRUM-166).
# Uso: source "$(dirname "$0")/lib.sh"; cargar_entorno <staging|prod>
set -euo pipefail

# El runner self-hosted puede arrancar como servicio SIN la variable HOME (el `~` de bash sí
# funciona porque lee /etc/passwd). Con `set -u` usar $HOME directamente abortaba el script.
HOME_DIR="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}"
HOME_DIR="${HOME_DIR:-/root}"

log()  { printf '[deploy] %s\n' "$*"; }
warn() { printf '::warning::%s\n' "$*"; }

cargar_entorno() {
  DEPLOY_ENV="${1:?Falta el ambiente: staging | prod}"
  case "$DEPLOY_ENV" in
    staging)
      ROOT="${GYMPRO_ROOT:-$HOME_DIR/GymPro-Staging}"
      COMPOSE=(docker compose -p gympro-staging -f docker-compose.yml -f docker-compose.override.yml)
      PUBLIC_URLS="${PUBLIC_URLS-https://test.gympro.lat}"
      PUBLIC_STRICT="${PUBLIC_STRICT:-0}"   # en staging una URL pública caída solo avisa
      ;;
    prod)
      ROOT="${GYMPRO_ROOT:-$HOME_DIR/GymPro-Prod}"
      COMPOSE=(docker compose -f docker-compose.server.yml)
      PUBLIC_URLS="${PUBLIC_URLS-https://gympro.lat https://api.gympro.lat/api/health}"
      PUBLIC_STRICT="${PUBLIC_STRICT:-1}"   # en producción una URL pública caída = fallo
      ;;
    *) echo "Ambiente desconocido: $DEPLOY_ENV (usa staging | prod)" >&2; exit 64 ;;
  esac
  INFRA_DIR="$ROOT/gympro-infra"
  # shellcheck disable=SC2034  # lo usan snapshot-release.sh y rollback.sh
  SNAP_DIR="$ROOT/.rollback"
}

# docker compose del ambiente, desde el directorio de infra.
compose() { ( cd "$INFRA_DIR" && "${COMPOSE[@]}" "$@" ); }

# repo -> servicio de compose que hay que reconstruir
servicio_de() {
  case "$1" in
    gympro-api) echo api ;;
    gympro-web) echo web ;;
    gympro-infra) echo "" ;;
    *) echo "Repo desconocido: $1" >&2; return 64 ;;
  esac
}

# Reintenta "$@" cada 5 s hasta que pase o se agote $DEADLINE (epoch s).
reintentar() {
  while true; do
    if "$@" >/dev/null 2>&1; then return 0; fi
    [ "$(date +%s)" -ge "$DEADLINE" ] && return 1
    sleep 5
  done
}

resumen() { [ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%s\n' "$*" >> "$GITHUB_STEP_SUMMARY" || true; }
