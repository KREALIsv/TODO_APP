# Resend + WODO (correo transaccional)

WODO envía correos desde **`@krealistudio.com`** (marca Kreali) con enlaces a
**`https://app.wodo.app`**. La app y la API siguen en `wodo.app` / `api.wodo.app`.

## Dónde poner la API key (importante)

| Entorno | Archivo | ¿Se sube a Git? |
|---------|---------|-----------------|
| **Producción (VPS)** | `/opt/wodo/.env` | **No** |
| **Desarrollo local (API)** | `backend/.env` | **No** |

**No** pongas `RESEND_API_KEY` en:

- el `.env` de la raíz del repo (Flutter no la usa),
- GitHub Actions (el deploy no la necesita; la lee el contenedor `wodo-api` del VPS),
- el código fuente ni en commits.

### Producción — paso a paso

1. SSH al VPS: `ssh usuario@144.91.71.215`
2. Edita el env del stack: `nano /opt/wodo/.env`
3. Añade (o completa) estas líneas:

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

5. Reinicia solo la API:

```bash
cd /opt/wodo && docker compose up -d api
```

### Desarrollo local

```bash
cp backend/.env.example backend/.env
# Edita backend/.env y pega RESEND_API_KEY=...
cd deploy && docker compose -f compose.dev.yml up --build
```

`compose.dev.yml` ya carga `../backend/.env` en el contenedor `wodo-api-dev`.

## Resend (panel)

1. [resend.com](https://resend.com) → **Domains** → añade `krealistudio.com`
2. Copia los registros **SPF / DKIM** (y **DMARC** recomendado) en el DNS del dominio
3. **Verify DNS**
4. **API Keys** → crea una key → pégala en `/opt/wodo/.env` como `RESEND_API_KEY`

Remitente verificado típico: `WODO <noreply@krealistudio.com>` (debe coincidir con
`MAIL_FROM`).

## Límites anti-abuso (backend)

Por defecto el servidor aplica:

| Control | Variable | Default |
|---------|----------|---------|
| Máx. correos por usuario **y flujo** (ventana) | `MAIL_MAX_PER_USER_FLOW` | `2` |
| Ventana en horas | `MAIL_FLOW_WINDOW_HOURS` | `24` |
| Peticiones «olvidé contraseña» por IP | throttle NestJS en el endpoint | 5 / 15 min |

Flujos contabilizados por separado:

- `welcome` — bienvenida al registrarse
- `password_reset` — enlace para nueva contraseña

Si un usuario agota la cuota, la API responde **429** con un mensaje en español;
no se envía el correo (protege la cuota de Resend).

## Comprobar que funciona

```bash
curl -s https://api.wodo.app/api/health
```

Desde la app: **Iniciar sesión → ¿Olvidaste tu contraseña?** → introduce el correo.
Revisa bandeja de entrada y spam.

Enlace del correo: `https://app.wodo.app/?wodo_reset=TOKEN` (abre la pantalla de
nueva contraseña en la web).
