#!/usr/bin/env bash
# verificar-horario.sh — gate de horario para despliegues a staging y produccion.
#
# El gimnasio cierra ~23:00 entre semana, pero en fin de semana (sabado y domingo)
# cierra mucho antes (~18:00). Ventana permitida para desplegar:
#   lunes a viernes:   23:00 - 05:59 (hora CDMX)
#   sabado y domingo:  18:00 - 05:59 (hora CDMX)
# El tramo 00:00-05:59 vale cualquier dia: ya paso la medianoche, el gimnasio
# sigue cerrado sin importar si la noche anterior era entre semana o fin de semana.
#
# Uso: bash verificar-horario.sh   (sin argumentos; sale 0 si esta dentro de la
# ventana, 1 con ::error:: si no lo esta — para usar como step de un workflow).
set -euo pipefail

REGLA="lunes a viernes 23:00-05:59, sabado y domingo 18:00-05:59 (hora CDMX)"

hora=$(TZ="America/Mexico_City" date +%H)
dia=$(TZ="America/Mexico_City" date +%u)   # 1=lunes ... 6=sabado, 7=domingo
ahora=$(TZ="America/Mexico_City" date '+%Y-%m-%d %H:%M %Z, %A')

if [ "$dia" -ge 6 ]; then
  inicio=18
else
  inicio=23
fi

if [ "$hora" -ge "$inicio" ] || [ "$hora" -lt 6 ]; then
  echo "[deploy] Hora actual en CDMX: $ahora. Dentro de la ventana permitida ($REGLA), continuando."
else
  echo "::error::Son las $ahora en Ciudad de Mexico. El despliegue solo se aplica en horario de gimnasio cerrado ($REGLA). Vuelve a correr este job (Re-run jobs) o dispara el workflow de nuevo dentro de ese horario."
  exit 1
fi
