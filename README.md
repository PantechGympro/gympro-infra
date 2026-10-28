# GymPro Infra

Orquestación y despliegue de GymPro: `docker-compose*.yml` y la configuración de nginx
que actúa como capa de ingreso público (dominio/TLS), separados del código de
aplicación. No contiene lógica de negocio — solo cómo se conectan y exponen los
servicios.

> **Arquitectura multi-repo:** este repo es parte de GymPro, bajo la organización
> [PantechGympro](https://github.com/PantechGympro): [`gympro-api`](https://github.com/PantechGympro/gympro-api),
> [`gympro-web`](https://github.com/PantechGympro/gympro-web),
> [`gympro-mobile`](https://github.com/PantechGympro/gympro-mobile) y este
> (`gympro-infra`). `gympro-mobile` no participa aquí: no se despliega en el VPS.

---

## Estructura

```
.
├── docker-compose.yml           # Stack base de desarrollo
├── docker-compose.override.yml  # Overrides automáticos de desarrollo (hot reload, etc.)
├── docker-compose.prod.yml      # Overrides de producción
├── docker-compose.server.yml    # El que realmente corre en el VPS
├── deploy/nginx/
│   ├── gympro.lat.conf          # Ingreso público del frontend (dominio real)
│   └── api.gympro.lat.conf      # Ingreso público de la API (dominio real)
├── backups/.gitkeep             # Carpeta montada como volumen; contenido NO versionado
└── uploads/.gitkeep             # Carpeta montada como volumen; contenido NO versionado
```

El nginx que sirve el build estático de React y proxea `/api` internamente **no** vive
aquí — está dentro de [`gympro-web`](https://github.com/PantechGympro/gympro-web)
(`web/nginx.conf`), porque es parte de cómo se construye y corre esa imagen. Lo que vive
en este repo es la capa de ingreso público frente a todo el stack.

---

## Cómo se usa

Este repo se clona como hermano de `gympro-api` y `gympro-web`:

```
proyectos/
├── gympro-api/
├── gympro-web/
└── gympro-infra/   ← este repo; aquí se corre docker compose
```

Los `docker-compose*.yml` referencian el código de los otros dos repos con
`context: ../gympro-api` y `context: ../gympro-web` (ver cada archivo). Desde dentro de
`gympro-infra/`:

```bash
# Desarrollo
docker compose up --build -d

# Producción (VPS) — el que de verdad se usa ahí
docker compose -f docker-compose.server.yml up --build -d
```

### Variables de entorno

Las variables reales de cada servicio (`SECRET_KEY`, credenciales de base de datos,
API keys de pagos, etc.) viven en el `.env` de cada componente (`gympro-api/.env`,
`gympro-web/.env.local`), **no en este repo**. Aquí no hay secretos — solo la topología
de los servicios.

### Punto crítico: no cambiar el `name:` del proyecto de Compose

Los volúmenes nombrados de Docker (`pg_data`, `mongo_data`, etc.) están atados al
**nombre del proyecto de Compose** (`name:` dentro de `docker-compose.server.yml`), no a
la ruta donde vive el archivo. Si se clona este repo en una ubicación nueva del VPS
(por ejemplo, al mover la ruta de despliegue en el VPS), mantener el mismo `name:` reconecta
automáticamente a los mismos volúmenes con los mismos datos — no hace falta migrar nada.
Cambiar ese valor por accidente crea volúmenes nuevos y vacíos.

---

---

## Flujo de trabajo

| Rama | Para qué |
|---|---|
| `dev-miguel`, `dev-francisco`, `dev-maximiliano`, `dev-carlos` | Trabajo diario; una por integrante |
| `main` | Rama integrada. **Protegida**: no admite push directo |
| `qa` | Verificación antes de preparar la entrega |
| `staging` | Preproducción |
| `prod` | Lo que corre en el servidor. **Protegida** |

1. Trabaja en tu rama `dev-<nombre>`; nunca directamente sobre `main`.
2. Abre un pull request hacia `main` y completa la plantilla
   (`.github/PULL_REQUEST_TEMPLATE.md`).
3. La integración continua (`.github/workflows/ci.yml`) debe pasar en verde y el PR
   necesita la aprobación de otro integrante.
4. Al fusionar, el workflow `sync-dev-branches.yml` baja `main` a las cuatro ramas
   `dev-*` automáticamente. Si hay conflicto se detiene y lo reporta; se resuelve a
   mano:

   ```bash
   git checkout dev-<nombre>
   git merge main       # resolver los conflictos
   git push
   ```

5. La promoción entre ambientes sigue `main → qa → staging → prod`.

### Convención de commits

Conventional Commits, con alcance opcional entre paréntesis:

| Prefijo | Para qué |
|---|---|
| `feat:` | Funcionalidad nueva |
| `fix:` | Corrección de un bug |
| `chore:` | Mantenimiento, configuración, dependencias |
| `docs:` | Solo documentación |
| `refactor:` | Cambio de estructura sin cambiar comportamiento |
| `perf:` | Mejora de rendimiento |

Ejemplos: `feat(api): cobro recurrente con Mercado Pago`, `fix(mobile): sesión no se renueva`.

**Nunca se commitean secretos ni archivos `.env`.** El repositorio versiona únicamente
`.env.example`; los valores reales se mantienen fuera de git.

La documentación del proyecto se lleva en **Jira** (proyecto `SCRUM`): los entregables y
las decisiones técnicas se adjuntan o se enlazan desde la incidencia que les corresponde.

## Carpetas `backups/` y `uploads/`

Son estado de runtime, montado como volumen por los compose — nunca se versiona su
contenido, solo el `.gitkeep` que mantiene la carpeta en git. Los respaldos reales
(`pg_dump`, `mongodump`) se generan y guardan aparte (ver documentación de respaldos del
equipo).
