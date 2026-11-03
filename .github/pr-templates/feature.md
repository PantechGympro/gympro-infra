## Qué cambia

Descripción breve de la funcionalidad/recurso nuevo y por qué es necesario.

## Alcance

- ¿Qué servicio(s) del stack se ven afectados?
- ¿Requiere cambios coordinados en otro repo (web/api/mobile)?

## Cómo se probó

- [ ] Probado localmente con `docker compose up --build`
- [ ] Verificado que no rompe el stack de producción (`docker-compose.server.yml`)

## Checklist

- [ ] No se commitearon secretos ni archivos `.env`
- [ ] Si se cambió el `name:` del proyecto de Compose, se evaluó el impacto en los volúmenes existentes
- [ ] La CI pasa en verde
- [ ] Se actualizó el README si el cambio afecta cómo se levanta el stack

## Issues relacionados

Closes #
