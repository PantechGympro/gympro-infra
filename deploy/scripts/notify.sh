#!/usr/bin/env bash
# notify.sh — avisa al equipo el resultado de un despliegue (SCRUM-166).
# Variables: DEPLOY_ENV, DEPLOY_REPO, DEPLOY_STATUS (exito|revertido|fallo),
#            DEPLOY_WEBHOOK_URL (secreto; opcional), y las de GitHub Actions
#            (GITHUB_SHA, GITHUB_ACTOR, GITHUB_SERVER_URL, GITHUB_REPOSITORY, GITHUB_RUN_ID).
# Funciona con webhooks entrantes de Slack (campo "text") y Discord (campo "content").
# Sin DEPLOY_WEBHOOK_URL solo escribe el resumen del job: nunca hace fallar el despliegue.
set -uo pipefail

env_="${DEPLOY_ENV:-?}"; repo="${DEPLOY_REPO:-${GITHUB_REPOSITORY:-?}}"; estado="${DEPLOY_STATUS:-fallo}"
sha="$(printf '%s' "${GITHUB_SHA:-}" | cut -c1-8)"
run_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}"

case "$estado" in
  exito)     icono="✅"; titulo="Despliegue exitoso" ;;
  revertido) icono="⚠️"; titulo="Despliegue FALLÓ y se revirtió a la versión anterior" ;;
  *)         icono="🚨"; titulo="Despliegue FALLÓ (revisar a mano)" ;;
esac
texto="$icono $titulo — $repo → $env_ · commit $sha · por ${GITHUB_ACTOR:-?} · $run_url"

# Escapa comillas y barras para JSON sin depender de jq/python.
json_str() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
cuerpo="{\"text\":\"$(json_str "$texto")\",\"content\":\"$(json_str "$texto")\"}"

echo "$texto"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '### %s\n\n%s\n' "$icono $titulo" "- Repo: \`$repo\`  \n- Ambiente: \`$env_\`  \n- Commit: \`$sha\`  \n- Ejecución: $run_url" >> "$GITHUB_STEP_SUMMARY"

if [ -z "${DEPLOY_WEBHOOK_URL:-}" ]; then
  echo "DEPLOY_WEBHOOK_URL no configurado: solo se escribió el resumen del job."
  exit 0
fi
if curl -fsS -o /dev/null --max-time 15 --retry 3 -H 'Content-Type: application/json' -d "$cuerpo" "$DEPLOY_WEBHOOK_URL"; then
  echo "Notificación enviada."
else
  echo "::warning::No se pudo enviar la notificación (el despliegue no se ve afectado)."
fi
exit 0
