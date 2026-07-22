# Deploy Wodo (wodo.app + app.wodo.app + api.wodo.app)

Publica en un **VPS compartido**:

- `https://wodo.app` → landing estática (`landing/`)
- `https://app.wodo.app` → Flutter web (`flutter build web --release --pwa-strategy=none`)
- `https://api.wodo.app` → API NestJS (auth + sync multi-dispositivo)
- `https://www.wodo.app` → redirección permanente a `wodo.app`

## Contexto del servidor (importante)

Este VPS (`144.91.71.215`) tiene **una sola IP pública** y ya corre otros
proyectos. Los puertos **80/443 los ocupa un Caddy compartido**
(`syvar-uat-caddy`, red Docker `syvar_default`, Caddyfile en
`/opt/syvar/ops/Caddyfile`). Ese Caddy actúa como **edge compartido** del
servidor: otros proyectos (p. ej. Sold Out `maps.*`) ya se enganchan ahí con
bloques gestionados por script.

Por eso wodo **no levanta su propio Caddy** ni publica 80/443. En su lugar:

1. Corre **tres** contenedores en `/opt/wodo`, conectados a la red del edge
   compartido (`syvar_default`), **sin** publicar puertos del host:
   - `wodo-landing` → sirve `sites/landing`
   - `wodo-web` → sirve `sites/web` (con fallback SPA para Flutter)
   - `wodo-api` → NestJS + Prisma (imagen `ghcr.io/krealisv/wodo-api:latest`)
2. Se registra en el edge con un **bloque gestionado entre markers**
   (`# --- wodo ... ---`) vía `scripts/setup-wodo-https.sh`, que hace backup,
   valida y recarga Caddy **sin tocar los bloques de otros proyectos**.

> Alternativa 100% independiente: pedir una **segunda IP pública** a Contabo y
> levantar un edge propio de wodo en esa IP. Requiere apuntar el DNS de wodo.app
> a la nueva IP. No hace falta si se usa el edge compartido.

## Estructura en el servidor (`/opt/wodo`)

```
/opt/wodo/
├── docker-compose.yml     # wodo-landing + wodo-web + wodo-api
├── .env.example           # DATABASE_URL, SECRET_AUTH_TOKEN_KEY, …
├── AUTH_SYNC_ROLLOUT.md   # checklist auth/sync → producción
├── nginx-spa.conf         # fallback SPA para la app Flutter
├── scripts/
│   └── setup-wodo-https.sh
└── sites/
    ├── landing/           # contenido de landing/ del repo
    └── web/               # salida de flutter build web
```

## Setup manual (una vez)

Requiere Docker + acceso al edge compartido en la misma red.

```bash
mkdir -p /opt/wodo/sites/landing /opt/wodo/sites/web
# subir docker-compose.yml, nginx-spa.conf y scripts/ a /opt/wodo
# subir landing/ -> /opt/wodo/sites/landing y build/web/ -> /opt/wodo/sites/web
cd /opt/wodo
docker compose up -d
bash scripts/setup-wodo-https.sh   # registra wodo en el edge y recarga Caddy
```

Variables opcionales del script (con defaults para este VPS):
`CADDYFILE`, `CADDY_CONTAINER`, `LANDING_DOMAIN`, `APP_DOMAIN`.

## Deploy automático (GitHub Actions)

`.github/workflows/deploy.yml` corre en cada push a `main` (o manual con
**Run workflow**):

1. `flutter build web --release --pwa-strategy=none` (con `WODO_API_URL=https://api.wodo.app/api/v1`)
2. Build/push imagen API + `rsync` de `deploy/`, `landing/` y `build/web/`
3. `docker compose pull && up -d` en `/opt/wodo`
4. `prisma migrate deploy` cuando cambia el backend
5. `setup-wodo-https.sh` (idempotente) para asegurar el enrutado en el edge

Secrets requeridos (**GitHub → Settings → Secrets → Actions**):

| Secret | Valor |
|--------|-------|
| `DEPLOY_HOST` | `144.91.71.215` |
| `DEPLOY_USER` | usuario SSH (recomendado un `deploy` con llave, no root) |
| `DEPLOY_SSH_PRIVATE_KEY` | clave privada del usuario de deploy |
| `DEPLOY_PATH` | `/opt/wodo` |
| `DEPLOY_PORT` | `22` |

Y crear el environment **`production`** (Settings → Environments).

## DNS (wodo.app)

| Type | Host | Value |
|------|------|-------|
| A | `@` | `144.91.71.215` |
| A | `www` | `144.91.71.215` |
| A | `app` | `144.91.71.215` |
| A | `api` | `144.91.71.215` |

## Notas

- Sin cuenta, la app sigue siendo **local-first** (Hive). Con cuenta, sincroniza
  notas, etiquetas y day log entre dispositivos vía `api.wodo.app`.
- Las **imágenes adjuntas** aún no se sincronizan (v1).
- Ver `deploy/AUTH_SYNC_ROLLOUT.md` para secrets, Postgres y verificación.
- El bloque de wodo en el edge es reversible: basta quitar el bloque entre
  markers y recargar Caddy.
- No se versionan secretos ni contenido servido (`.env`, `sites/`).
- El registro en el edge (`setup-wodo-https.sh`) es de **una sola vez**; los
  deploys rutinarios solo hacen rsync del contenido (nginx lo sirve directo del
  volumen). Por eso el workflow no reescribe el Caddyfile compartido en cada push.
- **Gotcha (bind mount de archivo único):** el Caddyfile compartido se monta como
  archivo individual. Editarlo con `mv` crea un inodo nuevo y el Caddy en
  ejecución sigue leyendo el inodo viejo (los cambios no se ven hasta reiniciar
  el contenedor). Por eso `setup-wodo-https.sh` escribe **in-place** (`cat >`).
