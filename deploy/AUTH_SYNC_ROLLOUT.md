# Auth + sync rollout checklist

Use this when merging the `auth-sync` integration branch to `main`.

## DNS (one-time)

| Type | Host | Value |
|------|------|-------|
| A | `api` | `144.91.71.215` |

Existing records for `@`, `www`, and `app` stay unchanged.

## Server secrets (`/opt/wodo/.env`)

Copy from `deploy/.env.example` and fill in production values:

- `DATABASE_URL` — PostgreSQL reachable from the `wodo-api` container
- `SECRET_AUTH_TOKEN_KEY` — at least 32 random characters
- `CORS_ALLOWED_ORIGINS=https://app.wodo.app,https://wodo.app`

PostgreSQL is **not** in production `docker-compose.yml`; provision it separately
(managed DB or a Postgres container on the VPS with a private network).

## Edge (one-time)

Re-run on the VPS (needs access to the shared Caddyfile):

```bash
cd /opt/wodo && bash scripts/setup-wodo-https.sh
```

This adds `api.wodo.app` → `wodo-api:3000`.

## GitHub Actions

On push to `main`, the workflow:

1. Builds and pushes `ghcr.io/krealisv/wodo-api:latest` when `backend/**` changes
2. Builds Flutter web with `--dart-define=WODO_API_URL=https://api.wodo.app/api/v1`
3. Runs `docker compose pull && up -d` on the VPS
4. Runs `prisma migrate deploy` inside the API container

Ensure the VPS can pull from GHCR (public package or deploy token).

## Verify after deploy

```bash
curl -s https://api.wodo.app/api/health
```

Register/login from **Ajustes → Iniciar sesión** on web and Android, then check
**Sincronizar aquí** is **Activa** and **Sincronizar ahora** shows **Actualizado**.

Test multi-device: same account on web + phone; create a note on one, sync on the other.

## Local dev

```bash
cp backend/.env.example backend/.env
cd deploy && docker compose -f compose.dev.yml up --build
```

Run Flutter against the local API:

```bash
flutter run -d chrome \
  --dart-define=WODO_API_URL=http://localhost:3000/api/v1
```

## Not synced yet (v1)

- Image attachments (`coverAttachmentId`, blob storage)
- App settings (theme, background)
- Local reminders

Local data remains on-device; sync covers notes, tags, and day entries.
