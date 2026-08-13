# Resend + WODO (correo transaccional unificado)

WODO envía correos desde **`@krealistudio.com`** (marca Kreali) con enlaces a
**`https://app.wodo.app`**. La app y la API siguen en `wodo.app` / `api.wodo.app`.

Flujos (misma API Resend, cuota por flujo):

| Flujo | Cuándo |
|-------|--------|
| `welcome` | Al crear cuenta |
| `password_reset` | «¿Olvidaste tu contraseña?» |
| `vault_recovery` | Opcional: «Enviar también a mi correo» al activar E2EE (el servidor **no** guarda el código) |

---

## Dónde poner la API key

| Entorno | Archivo | Variable |
|---------|---------|----------|
| **Producción (VPS)** | `/opt/wodo/.env` | `RESEND_API_KEY=re_...` |
| **Desarrollo local** | `backend/.env` | `RESEND_API_KEY=re_...` |

Plantillas de ejemplo (sin secretos reales):

- `deploy/.env.example` → copia conceptual del VPS
- `backend/.env.example` → copia a `backend/.env` en local

**No** pongas la key en:

- el `.env` de la raíz del repo (Flutter no la usa),
- GitHub Actions / secrets de CI (el contenedor `wodo-api` del VPS lee `/opt/wodo/.env`),
- el código fuente ni en commits.

### Producción — paso a paso

1. SSH: `ssh usuario@144.91.71.215`
2. Edita: `nano /opt/wodo/.env`
3. Asegura estas líneas:

```env
RESEND_API_KEY=re_tu_clave_de_resend
MAIL_FROM=WODO <noreply@krealistudio.com>
WODO_APP_URL=https://app.wodo.app
MAIL_MAX_PER_USER_FLOW=2
MAIL_FLOW_WINDOW_HOURS=24
```

4. Permisos (si hace falta):

```bash
sudo chown wododeploy:wododeploy /opt/wodo/.env
chmod 600 /opt/wodo/.env
```

5. Reinicia la API:

```bash
cd /opt/wodo && docker compose up -d api
```

### Desarrollo local

```bash
cp backend/.env.example backend/.env
# Edita backend/.env → RESEND_API_KEY=re_...
cd deploy && docker compose -f compose.dev.yml up --build
```

`compose.dev.yml` carga `../backend/.env` en `wodo-api-dev`.

---

## Resend (panel)

1. [resend.com](https://resend.com) → **Domains** → `krealistudio.com`
2. DNS: SPF / DKIM (+ DMARC recomendado) → **Verify**
3. **API Keys** → crea key → pégala solo en `/opt/wodo/.env` (prod) o `backend/.env` (dev)

Remitente: `WODO <noreply@krealistudio.com>` (= `MAIL_FROM`).

---

## Límites anti-abuso

| Control | Variable | Default |
|---------|----------|---------|
| Máx. correos por email **y flujo** | `MAIL_MAX_PER_USER_FLOW` | `2` / 24 h |
| Ventana | `MAIL_FLOW_WINDOW_HOURS` | `24` |
| Forgot-password / vault email por IP | throttle Nest | 5 / 15 min |

Si se agota la cuota → **429** en español; no se llama a Resend.

---

## Comprobar

```bash
curl -s https://api.wodo.app/api/health
```

- Bienvenida: crear cuenta → bandeja / spam  
- Reset: **¿Olvidaste tu contraseña?** → `https://app.wodo.app/?wodo_reset=TOKEN`  
- Vault: activar protección → **Enviar también a mi correo**
