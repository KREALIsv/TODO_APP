# Deploy Wodo (wodo.app + app.wodo.app)

Publica en un **VPS compartido**:

- `https://wodo.app` → landing estática (`landing/`)
- `https://app.wodo.app` → Flutter web (`flutter build web`)
- `https://www.wodo.app` → redirección permanente a `wodo.app`

## Contexto del servidor (importante)

Este VPS (`144.91.71.215`) tiene **una sola IP pública** y ya corre otros
proyectos. Los puertos **80/443 los ocupa un Caddy compartido**
(`syvar-uat-caddy`, red Docker `syvar_default`, Caddyfile en
`/opt/syvar/ops/Caddyfile`). Ese Caddy actúa como **edge compartido** del
servidor: otros proyectos (p. ej. Sold Out `maps.*`) ya se enganchan ahí con
bloques gestionados por script.

Por eso wodo **no levanta su propio Caddy** ni publica 80/443. En su lugar:

1. Corre dos contenedores nginx aislados en `/opt/wodo`, conectados a la red del
   edge compartido (`syvar_default`), **sin** publicar puertos del host:
   - `wodo-landing` → sirve `sites/landing`
   - `wodo-web` → sirve `sites/web` (con fallback SPA para Flutter)
2. Se registra en el edge con un **bloque gestionado entre markers**
   (`# --- wodo ... ---`) vía `scripts/setup-wodo-https.sh`, que hace backup,
   valida y recarga Caddy **sin tocar los bloques de otros proyectos**.

> Alternativa 100% independiente: pedir una **segunda IP pública** a Contabo y
> levantar un edge propio de wodo en esa IP. Requiere apuntar el DNS de wodo.app
> a la nueva IP. No hace falta si se usa el edge compartido.

## Estructura en el servidor (`/opt/wodo`)

```
/opt/wodo/
├── docker-compose.yml     # wodo-landing + wodo-web en red externa syvar_default
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

1. `flutter build web --release`
2. `rsync` de `deploy/` (compose + nginx + scripts), `landing/` y `build/web/`
3. `docker compose up -d` en `/opt/wodo`
4. `setup-wodo-https.sh` (idempotente) para asegurar el enrutado en el edge

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

## Notas

- La app guarda datos en el navegador (Hive); no hay backend ni base de datos.
- El bloque de wodo en el edge es reversible: basta quitar el bloque entre
  markers y recargar Caddy.
- No se versionan secretos ni contenido servido (`.env`, `sites/`).
