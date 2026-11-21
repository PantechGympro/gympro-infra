#!/usr/bin/env bash
# Pruebas de los scripts de despliegue (post-deploy-check, rollback, snapshot, notify)
# con `docker` y `curl` simulados. No necesita Docker ni red. Uso: bash deploy/tests/run.sh
set -uo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"; SCRIPTS="$AQUI/../scripts"
FALLAS=0; N=0
ok()   { N=$((N+1)); echo "  ✓ $1"; }
mal()  { N=$((N+1)); FALLAS=$((FALLAS+1)); echo "  ✗ $1"; }
espera() { # descripcion comando...
  local d="$1"; shift; if "$@"; then ok "$d"; else mal "$d"; fi
}

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/root/gympro-infra" "$T/root/gympro-api"

# docker falso: SIM=sano|enfermo|sin_ready ; registra cada llamada en $SIM_LOG
cat > "$T/bin/docker" <<'DOCKER'
#!/usr/bin/env bash
echo "docker $*" >> "$SIM_LOG"
case "$*" in
  *"ps -q api"*) echo cid123 ;;
  inspect*) [ "$SIM" = enfermo ] && echo unhealthy || echo healthy ;;
  *"exec -T api curl"*"/api/health/ready"*)
      case "$SIM" in sano) printf '{"status":"ready"}\n200' ;; sin_ready) printf 'Not Found\n404' ;; *) printf '{"status":"degraded"}\n503' ;; esac ;;
  *"exec -T api curl"*) [ "$SIM" = enfermo ] && exit 22 || echo '{"status":"ok"}' ;;
  *"exec -T web wget"*) [ "$SIM" = enfermo ] && exit 1 || exit 0 ;;
  *) exit 0 ;;
esac
DOCKER
# curl falso: guarda el cuerpo enviado al webhook
cat > "$T/bin/curl" <<'CURL'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do case "$1" in -d) printf '%s' "$2" > "$SIM_BODY"; shift 2 ;; *) shift ;; esac; done
[ "${CURL_FALLA:-0}" = 1 ] && exit 22 || exit 0
CURL
chmod +x "$T/bin/docker" "$T/bin/curl"
export ROLLBACK_VERIFY_TIMEOUT=5
# Los scripts escriben tablas en $GITHUB_STEP_SUMMARY; en las pruebas se redirige a un archivo
# temporal para que los escenarios simulados (incluidas las fallas) no aparezcan en el resumen del job.
export GITHUB_STEP_SUMMARY="$T/step-summary.md"
export PATH="$T/bin:$PATH" SIM_LOG="$T/log" SIM_BODY="$T/body" GYMPRO_ROOT="$T/root" PUBLIC_URLS=""

echo "post-deploy-check"
SIM=sano    bash "$SCRIPTS/post-deploy-check.sh" staging 5 >/dev/null 2>&1; espera "ambiente sano → exit 0" test $? -eq 0
SIM=enfermo bash "$SCRIPTS/post-deploy-check.sh" staging 5 >/dev/null 2>&1; espera "ambiente enfermo → exit 1" test $? -eq 1
SIM=sin_ready bash "$SCRIPTS/post-deploy-check.sh" prod 5 >/dev/null 2>&1;  espera "API anterior sin /ready (404) no falla" test $? -eq 0
SIM=degradado bash "$SCRIPTS/post-deploy-check.sh" prod 5 >/dev/null 2>&1; espera "dependencia caída (/ready 503) → exit 1" test $? -eq 1
SIM=sano bash "$SCRIPTS/post-deploy-check.sh" qa 5 >/dev/null 2>&1;          espera "ambiente desconocido → error de uso" test $? -eq 64
: > "$SIM_LOG"; SIM=sano bash "$SCRIPTS/post-deploy-check.sh" prod 5 >/dev/null 2>&1
espera "prod usa docker-compose.server.yml" grep -q -- "-f docker-compose.server.yml" "$SIM_LOG"
: > "$SIM_LOG"; SIM=sano bash "$SCRIPTS/post-deploy-check.sh" staging 5 >/dev/null 2>&1
espera "staging usa -p gympro-staging y el override" grep -q -- "-p gympro-staging -f docker-compose.yml -f docker-compose.override.yml" "$SIM_LOG"
SIM=sano PUBLIC_URLS="https://publica.test" PUBLIC_STRICT=1 bash "$SCRIPTS/post-deploy-check.sh" prod 5 >/dev/null 2>&1
espera "URL pública que responde no falla" test $? -eq 0
CURL_FALLA=1 SIM=sano PUBLIC_URLS="https://publica.test" PUBLIC_STRICT=1 bash "$SCRIPTS/post-deploy-check.sh" prod 5 >/dev/null 2>&1
espera "URL pública caída con PUBLIC_STRICT=1 (prod) → exit 1" test $? -eq 1
CURL_FALLA=1 SIM=sano PUBLIC_URLS="https://publica.test" PUBLIC_STRICT=0 bash "$SCRIPTS/post-deploy-check.sh" staging 5 >/dev/null 2>&1
espera "URL pública caída con PUBLIC_STRICT=0 (staging) solo avisa" test $? -eq 0

# Regresión: el runner del VPS arranca sin HOME y `set -u` abortaba lib.sh (HOME: unbound variable)
SIM=sano GYMPRO_ROOT="" env -u HOME -u GYMPRO_ROOT PATH="$PATH" SIM="sano" SIM_LOG="$SIM_LOG" SIM_BODY="$SIM_BODY" PUBLIC_URLS="" \
  bash "$SCRIPTS/post-deploy-check.sh" staging 5 >"$T/sinhome.out" 2>&1
espera "sin variable HOME no aborta por 'unbound variable'" bash -c '! grep -q "unbound variable" "$1"' _ "$T/sinhome.out"

echo "snapshot + rollback"
SIM=sano bash "$SCRIPTS/rollback.sh" staging gympro-api >/dev/null 2>&1; espera "rollback sin snapshot → exit 2" test $? -eq 2
echo v1 > "$T/root/gympro-api/app.txt"; echo abcdef1234567890 > "$T/root/gympro-api/BUILD_INFO"; echo secreto > "$T/root/gympro-api/.env"
SIM=sano bash "$SCRIPTS/snapshot-release.sh" staging gympro-api >/dev/null 2>&1
espera "snapshot guarda el código actual" test "$(cat "$T/root/.rollback/gympro-api/app.txt")" = v1
echo v2 > "$T/root/gympro-api/app.txt"; echo nuevo > "$T/root/gympro-api/extra.txt"; echo cambiado > "$T/root/gympro-api/.env"
: > "$SIM_LOG"; SIM=sano bash "$SCRIPTS/rollback.sh" staging gympro-api >/dev/null 2>&1; rc=$?
espera "rollback con ambiente sano → exit 0" test $rc -eq 0
espera "rollback restaura el contenido anterior (mismo tamaño que el nuevo)" test "$(cat "$T/root/gympro-api/app.txt")" = v1
espera "rollback elimina archivos nuevos" test ! -e "$T/root/gympro-api/extra.txt"
espera "rollback conserva el .env del servidor" test "$(cat "$T/root/gympro-api/.env")" = cambiado
espera "rollback reconstruye solo el servicio api" grep -q "up -d --build api" "$SIM_LOG"
SIM=enfermo bash "$SCRIPTS/rollback.sh" staging gympro-api >/dev/null 2>&1
espera "rollback que no deja el ambiente sano → exit ≠ 0" test $? -ne 0

echo "notify"
DEPLOY_ENV=prod DEPLOY_REPO=gympro-api DEPLOY_STATUS=exito bash "$SCRIPTS/notify.sh" >/dev/null 2>&1
espera "sin webhook no falla" test $? -eq 0
rm -f "$SIM_BODY"
DEPLOY_WEBHOOK_URL=https://hooks.test/x DEPLOY_ENV=prod DEPLOY_REPO=gympro-api DEPLOY_STATUS=revertido \
  GITHUB_SHA=0123456789abcdef GITHUB_ACTOR='ana "la" dev' GITHUB_REPOSITORY=org/gympro-api GITHUB_RUN_ID=77 \
  bash "$SCRIPTS/notify.sh" >/dev/null 2>&1
espera "con webhook envía JSON válido (comillas escapadas)" python3 -c "import json,sys; d=json.load(open('$SIM_BODY')); assert d['text']==d['content']"
espera "el mensaje indica reversión, ambiente, repo y commit corto" python3 -c "
import json; t=json.load(open('$SIM_BODY'))['text']
assert 'revirtió' in t and 'prod' in t and 'gympro-api' in t and '01234567' in t, t"
DEPLOY_WEBHOOK_URL=https://hooks.test/x CURL_FALLA=1 DEPLOY_STATUS=fallo bash "$SCRIPTS/notify.sh" >/dev/null 2>&1
espera "si el webhook falla, notify NO hace fallar el despliegue" test $? -eq 0
SUMM="$T/notify-summary.md"; : > "$SUMM"
GITHUB_STEP_SUMMARY="$SUMM" DEPLOY_ENV=staging DEPLOY_REPO=gympro-infra DEPLOY_STATUS=fallo bash "$SCRIPTS/notify.sh" >/dev/null 2>&1
espera "el resumen del job usa saltos de línea reales (sin \\n literal)" bash -c '! grep -qF "\\n" "$1" && [ "$(wc -l < "$1")" -ge 5 ]' _ "$SUMM"

echo; echo "$((N-FALLAS))/$N pruebas correctas"
[ "$FALLAS" -eq 0 ]
