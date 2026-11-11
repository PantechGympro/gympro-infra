## Qué se corrige

Descripción del problema de infraestructura y su causa raíz.

## Cómo reproducirlo (antes del fix)

1.
2.

## Cómo se probó

- [ ] Se reprodujo el problema localmente antes de aplicar el fix
- [ ] Se verificó que el fix resuelve el problema con `docker compose up --build`
- [ ] Se verificó que no rompe el stack de producción (`docker-compose.server.yml`)

## Riesgo de regresión

¿Este cambio puede afectar otros servicios o volúmenes existentes?

## Checklist

- [ ] No se commitearon secretos ni archivos `.env`
- [ ] Si se cambió el `name:` del proyecto de Compose, se evaluó el impacto en los volúmenes existentes
- [ ] La CI pasa en verde

## Issues relacionados

Closes #
