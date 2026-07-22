#!/usr/bin/env bash
# Inyecta (de forma idempotente) el bloque de wodo en el Caddyfile compartido
# del VPS y recarga Caddy sin downtime. No toca el resto de la config.
#
# Variables (con defaults para este VPS):
#   CADDYFILE        Ruta del Caddyfile en el host (default: /opt/syvar/ops/Caddyfile)
#   CADDY_CONTAINER  Nombre del contenedor Caddy   (default: syvar-uat-caddy)
#   LANDING_DOMAIN   Dominio landing               (default: wodo.app)
#   APP_DOMAIN       Dominio app                   (default: app.wodo.app)
#   API_DOMAIN       Dominio api                   (default: api.wodo.app)
set -euo pipefail

CADDYFILE="${CADDYFILE:-/opt/syvar/ops/Caddyfile}"
CADDY_CONTAINER="${CADDY_CONTAINER:-syvar-uat-caddy}"
LANDING_DOMAIN="${LANDING_DOMAIN:-wodo.app}"
APP_DOMAIN="${APP_DOMAIN:-app.wodo.app}"
API_DOMAIN="${API_DOMAIN:-api.wodo.app}"

BEGIN="# --- wodo (managed by deploy/scripts/setup-wodo-https.sh) ---"
END="# --- end wodo ---"

if [ ! -f "$CADDYFILE" ]; then
  echo "ERROR: no existe $CADDYFILE" >&2
  exit 1
fi

# Backup con timestamp antes de tocar nada.
cp -a "$CADDYFILE" "${CADDYFILE}.bak.$(date +%Y%m%d%H%M%S)"

# Quita cualquier bloque wodo previo (entre markers) para poder reaplicar.
tmp="$(mktemp)"
awk -v b="$BEGIN" -v e="$END" '
  $0==b {skip=1; next}
  $0==e {skip=0; next}
  skip!=1 {print}
' "$CADDYFILE" > "$tmp"

# Añade el bloque actualizado al final.
cat >> "$tmp" <<EOF

$BEGIN
$LANDING_DOMAIN {
	encode gzip zstd
	reverse_proxy wodo-landing:80
}

www.$LANDING_DOMAIN {
	redir https://$LANDING_DOMAIN{uri} permanent
}

$APP_DOMAIN {
	encode gzip zstd
	reverse_proxy wodo-web:80
}

$API_DOMAIN {
	encode gzip zstd
	reverse_proxy wodo-api:3000
}
$END
EOF

# IMPORTANTE: escribir IN-PLACE (no `mv`). El Caddyfile se monta como archivo
# único (bind mount) en el contenedor; un `mv` crea un inodo nuevo y el
# contenedor seguiría leyendo el inodo viejo (los cambios no se verían hasta
# reiniciar Caddy). `cat >` conserva el inodo y el reload los toma al instante.
cat "$tmp" > "$CADDYFILE"
rm -f "$tmp"

# Valida y recarga (el archivo se monta en el contenedor por bind mount).
docker exec "$CADDY_CONTAINER" caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec "$CADDY_CONTAINER" caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

echo "OK: bloque wodo aplicado y Caddy recargado ($LANDING_DOMAIN, www.$LANDING_DOMAIN, $APP_DOMAIN, $API_DOMAIN)."
