#!/usr/bin/env bash
# Delete a WODO user from production Postgres (phase 0 — manual unblock).
#
# Usage (on the VPS as root or a user with docker access):
#   sudo bash scripts/delete-wodo-user.sh tu@correo.com
#
# Requires: wodo-postgres container on syvar_default (see deploy/AUTH_SYNC_ROLLOUT.md).

set -euo pipefail

EMAIL="${1:-}"
CONTAINER="${WODO_DB_CONTAINER:-wodo-postgres}"
DB_USER="${WODO_DB_USER:-wodo_user}"
DB_NAME="${WODO_DB_NAME:-wodo}"

if [[ -z "$EMAIL" ]]; then
  echo "Uso: $0 <correo@ejemplo.com>" >&2
  exit 1
fi

NORMALIZED="$(printf '%s' "$EMAIL" | tr '[:upper:]' '[:lower:]' | xargs)"
ESCAPED="${NORMALIZED//\'/\'\'}"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Error: contenedor Postgres '$CONTAINER' no está en ejecución." >&2
  echo "Contenedores:" >&2
  docker ps --format '  {{.Names}}' >&2
  exit 1
fi

echo "Buscando usuario: $NORMALIZED"

docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c \
  "SELECT id, email, created_at FROM users WHERE email = '$ESCAPED';"

read -r -p "¿Eliminar este usuario y todos sus datos en la nube? [escribe SI] " CONFIRM
if [[ "$CONFIRM" != "SI" ]]; then
  echo "Cancelado."
  exit 0
fi

docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c \
  "DELETE FROM users WHERE email = '$ESCAPED';"

echo "Listo. El correo puede volver a registrarse en la app."
