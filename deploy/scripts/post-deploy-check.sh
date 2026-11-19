#!/usr/bin/env bash
# post-deploy-check.sh <staging|prod> [timeout_segundos=240]
# Verificación de salud posterior al despliegue. Sale 0 si todo está sano y 1 si no.
#   1. El contenedor api reporta "healthy" (HEALTHCHECK de Docker).
#   2. GET /api/health  (liveness)           -> 200
#   3. GET /api/health/ready (Postgres+Mongo+Redis) -> 200  (404 = API anterior sin readiness: se omite)
#   4. La cadena web -> nginx -> api responde (/api/health vía el contenedor web).
#   5. URLs públicas (PUBLIC_URLS): fallan el despliegue solo si PUBLIC_STRICT=1.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
cargar_entorno "${1:-}"
TIMEOUT="${2:-240}"
# shellcheck disable=SC2034  # lo lee reintentar() en lib.sh
DEADLINE=$(( $(date +%s) + TIMEOUT ))
FALLOS=0
FILAS=()

registrar() { # nombre estado detalle
  FILAS+=("| $1 | $2 | $3 |")
  log "$1: $2 $3"
}

api_cid() { compose ps -q api 2>/dev/null | head -n1; }
api_estado() {
  local cid; cid="$(api_cid)"; [ -z "$cid" ] && { echo "sin-contenedor"; return; }
  docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || echo desconocido
}
api_curl() { compose exec -T api curl -fsS --max-time 10 "http://localhost:5000$1"; }

# 1 ── contenedor healthy
api_healthy() { [ "$(api_estado)" = "healthy" ]; }
if reintentar api_healthy; then
  registrar "Contenedor api" "✅" "healthy"
else
  registrar "Contenedor api" "❌" "estado: $(api_estado)"; FALLOS=$((FALLOS+1))
fi

# 2 ── liveness
if reintentar api_curl /api/health; then
  registrar "GET /api/health" "✅" "$(api_curl /api/health 2>/dev/null | tr -d '\n' | cut -c1-120)"
else
  registrar "GET /api/health" "❌" "sin respuesta 200 dentro de ${TIMEOUT}s"; FALLOS=$((FALLOS+1))
fi

# 3 ── readiness (dependencias)
salida="$(compose exec -T api curl -s --max-time 15 -w '\n%{http_code}' http://localhost:5000/api/health/ready 2>/dev/null || true)"
codigo="$(printf '%s' "$salida" | tail -n1)"
case "$codigo" in
  200) registrar "GET /api/health/ready" "✅" "Postgres, Mongo y Redis responden" ;;
  404) registrar "GET /api/health/ready" "➖" "no existe en esta versión de la API (omitido)" ;;
  *)   registrar "GET /api/health/ready" "❌" "HTTP ${codigo:-sin respuesta}: $(printf '%s' "$salida" | head -n1 | cut -c1-200)"; FALLOS=$((FALLOS+1)) ;;
esac

# 4 ── cadena web -> nginx -> api
web_ok() { compose exec -T web wget -q -O /dev/null --timeout=10 http://127.0.0.1/api/health; }
if reintentar web_ok; then
  registrar "web → /api/health" "✅" "nginx del contenedor web alcanza la API"
else
  registrar "web → /api/health" "❌" "el contenedor web no alcanza la API"; FALLOS=$((FALLOS+1))
fi

# 5 ── URLs públicas
for url in $PUBLIC_URLS; do
  if curl -fsS -o /dev/null --max-time 15 --retry 4 --retry-delay 5 --retry-connrefused "$url" 2>/dev/null; then
    registrar "$url" "✅" "responde"
  elif [ "$PUBLIC_STRICT" = "1" ]; then
    registrar "$url" "❌" "no responde (PUBLIC_STRICT=1)"; FALLOS=$((FALLOS+1))
  else
    registrar "$url" "⚠️" "no responde (solo aviso en $DEPLOY_ENV)"
  fi
done

resumen "### Verificación post-despliegue — $DEPLOY_ENV"
resumen ""
resumen "| Comprobación | Resultado | Detalle |"
resumen "|---|---|---|"
for f in "${FILAS[@]}"; do resumen "$f"; done
resumen ""

if [ "$FALLOS" -gt 0 ]; then
  log "❌ $FALLOS comprobación(es) fallaron."
  compose logs --tail=60 api 2>/dev/null | sed 's/^/[api] /' || true
  exit 1
fi
log "✅ Despliegue sano."
