# Desbloquear cuenta WODO en producción (fase 0)

Cuando un usuario olvidó la contraseña y aún **no** hay recuperación por correo,
puedes eliminar su fila en Postgres para que vuelva a **registrarse** con el mismo email.

## Requisitos

- SSH al VPS (`144.91.71.215`)
- Contenedor Postgres `wodo-postgres` en ejecución (red `syvar_default`)
- Credenciales en `/opt/wodo/.env` → `DATABASE_URL`

## Opción A — Script (recomendado)

En el VPS:

```bash
cd /opt/wodo
sudo bash scripts/delete-wodo-user.sh tu@correo.com
```

El script muestra el usuario, pide confirmación (`SI`) y ejecuta el `DELETE` (cascade borra notas/sync en la nube).

## Opción B — Comandos manuales

Copia y pega en la terminal del VPS (cambia el correo):

```bash
# 1. Entrar al contenedor Postgres
docker exec -it wodo-postgres psql -U wodo_user -d wodo

# 2. Dentro de psql — verificar usuario (minúsculas)
SELECT id, email, created_at FROM users WHERE email = 'tu@correo.com';

# 3. Borrar (cascade: sesiones, dispositivos, notas sync, etc.)
DELETE FROM users WHERE email = 'tu@correo.com';

# 4. Salir
\q
```

## Después del borrado

1. En la app: **Ajustes → Iniciar sesión** (o Perfil)
2. Pulsa **Usar otra cuenta** si el correo antiguo sigue prefilled
3. **Crear una cuenta nueva** con el mismo correo y una contraseña nueva
4. Guarda la contraseña (hasta que llegue recuperación por email en fase 2)

## Notas

- Esto **no** borra datos locales del dispositivo del usuario.
- Si el contenedor tiene otro nombre, lista contenedores: `docker ps --format '{{.Names}}' | grep wodo`
- Usuario/contraseña DB: revisa `DATABASE_URL` en `/opt/wodo/.env`
