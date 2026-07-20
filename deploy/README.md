# Deploy Dowo (dowo.com + app.dowo.com)

Infraestructura mínima para publicar:

- `https://dowo.com` → landing estática (`landing/`)
- `https://app.dowo.com` → Flutter web (`flutter build web`)
- `https://www.dowo.com` → redirección permanente a `dowo.com`
- HTTPS automático con Let's Encrypt (Caddy)

## 1. DNS en Namecheap (dowo.com)

Entra a **Domain List → dowo.com → Advanced DNS**.

### Elimina registros viejos

Borra cualquier registro de parking o redirect, por ejemplo:

- CNAME `www` → `parkingpage.namecheap.com`
- URL Redirect `@` → `http://www...`

(Si tu panel se parece al de `wodo.app`, el procedimiento es el mismo pero en el dominio **dowo.com**.)

### Agrega estos registros

Reemplaza `TU_IP_DEL_SERVIDOR` por la IP pública de tu servidor de prueba.

| Type | Host | Value | TTL |
|------|------|-------|-----|
| **A Record** | `@` | `TU_IP_DEL_SERVIDOR` | Automatic |
| **A Record** | `www` | `TU_IP_DEL_SERVIDOR` | Automatic |
| **A Record** | `app` | `TU_IP_DEL_SERVIDOR` | Automatic |

Notas:

- `@` es la raíz (`dowo.com`).
- `app` crea `app.dowo.com`.
- No uses el redirect de Namecheap para esto; Caddy en el servidor maneja HTTPS y `www → dowo.com`.
- La propagación DNS suele tardar entre unos minutos y 1 hora.

### Verificación rápida

Cuando propague:

```bash
dig +short dowo.com
dig +short app.dowo.com
dig +short www.dowo.com
```

Las tres deben devolver la IP del servidor.

## 2. Preparar el servidor (una sola vez)

Requisitos: Docker y Docker Compose ya instalados, puertos **80** y **443** abiertos.

```bash
# Usuario dedicado (recomendado)
sudo adduser deploy
sudo usermod -aG docker deploy

# Carpeta de deploy
sudo mkdir -p /opt/dowo
sudo chown deploy:deploy /opt/dowo
```

Como usuario `deploy`:

```bash
cd /opt/dowo
git clone https://github.com/KREALIsv/TODO_APP.git repo
cd repo/deploy
cp .env.example .env
# Edita .env con tu email para Let's Encrypt
nano .env

mkdir -p sites/landing sites/web
docker compose up -d
```

El archivo `.env` mínimo:

```env
ACME_EMAIL=tu-email@ejemplo.com
LANDING_DOMAIN=dowo.com
APP_DOMAIN=app.dowo.com
```

## 3. SSH para GitHub Actions

En tu máquina local:

```bash
ssh-keygen -t ed25519 -C "github-actions-dowo" -f ./dowo-deploy-key -N ""
```

En el servidor (`~/.ssh/authorized_keys` del usuario `deploy`):

```text
<contenido de dowo-deploy-key.pub>
```

En GitHub → repo **TODO_APP** → **Settings → Secrets and variables → Actions**:

| Secret | Valor |
|--------|-------|
| `DEPLOY_HOST` | IP o hostname del servidor |
| `DEPLOY_USER` | `deploy` |
| `DEPLOY_SSH_PRIVATE_KEY` | contenido de `dowo-deploy-key` (privada) |
| `DEPLOY_PATH` | `/opt/dowo/repo/deploy` |
| `DEPLOY_PORT` | `22` (opcional si usas otro puerto) |

Opcional: crea el environment **production** en GitHub (Settings → Environments) para proteger despliegues.

## 4. Flujo de ramas

| Rama | Uso |
|------|-----|
| `uat` | Integrar cambios antes de producción (PRs hacia `main`) |
| `main` | Producción/beta pública → dispara deploy automático |

Cada push a `main` ejecuta `.github/workflows/deploy.yml`:

1. `flutter build web --release`
2. Sincroniza `landing/` y `build/web/` al servidor
3. `docker compose up -d` (Caddy recarga certificados y sitios)

Deploy manual: **Actions → Deploy Dowo → Run workflow**.

## 5. Primer deploy

1. Configura DNS (paso 1).
2. Prepara servidor y secrets (pasos 2 y 3).
3. Haz merge a `main` o ejecuta el workflow manualmente.
4. Abre `https://dowo.com` y `https://app.dowo.com`.

## 6. Seguridad

- SSH solo con clave; desactiva login por contraseña si es posible.
- El workflow usa `rsync --delete` para mantener el servidor igual al repo.
- Caddy emite y renueva certificados TLS automáticamente.
- La app web guarda datos en el navegador (Hive); no hay backend ni base de datos en este deploy.
- No subas `.env` del servidor al repositorio.

## 7. Si ya tienes otros contenedores Docker

Este stack solo publica puertos 80/443 en el host. Si otro reverse proxy (Traefik, nginx, Dokploy) ya ocupa esos puertos:

- Opción A: integra `dowo.com` y `app.dowo.com` en ese proxy y sirve las carpetas `sites/landing` y `sites/web`.
- Opción B: deja Caddy en puertos internos y enruta desde tu proxy existente.

Si compartes la salida de `docker ps` y qué proxy usas, se puede adaptar el `docker-compose.yml`.
