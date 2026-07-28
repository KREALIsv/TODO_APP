# Consultas de usuarios en producción

Estos comandos deben ejecutarse en el VPS donde está funcionando el contenedor
`wodo-api`. Las consultas utilizan automáticamente el `DATABASE_URL` configurado
dentro del contenedor y no muestran las credenciales de PostgreSQL.

## Contar usuarios activos

Cuenta los usuarios que no han sido eliminados lógicamente.

```bash
docker exec wodo-api node -e 'const {Client}=require("pg"); const c=new Client({connectionString:process.env.DATABASE_URL}); (async()=>{await c.connect(); const r=await c.query("SELECT COUNT(*)::int AS usuarios_activos FROM users WHERE deleted_at IS NULL"); console.table(r.rows); await c.end()})().catch(e=>{console.error(e.message);process.exit(1)})'
```

Respuesta esperada (el número dependerá de los usuarios registrados):

```text
┌─────────┬──────────────────┐
│ (index) │ usuarios_activos │
├─────────┼──────────────────┤
│ 0       │ 15               │
└─────────┴──────────────────┘
```

## Listar usuarios activos

Muestra el identificador, correo, estado de verificación y fecha de creación de
cada usuario activo, comenzando por el registro más reciente.

```bash
docker exec wodo-api node -e 'const {Client}=require("pg"); const c=new Client({connectionString:process.env.DATABASE_URL}); (async()=>{await c.connect(); const r=await c.query("SELECT id,email,email_verified,created_at FROM users WHERE deleted_at IS NULL ORDER BY created_at DESC"); console.table(r.rows); await c.end()})().catch(e=>{console.error(e.message);process.exit(1)})'
```

Respuesta esperada (los datos mostrados son solamente un ejemplo):

```text
┌─────────┬──────────────────────────────────────┬────────────────────────────┬────────────────┬────────────────────────┐
│ (index) │ id                                   │ email                      │ email_verified │ created_at             │
├─────────┼──────────────────────────────────────┼────────────────────────────┼────────────────┼────────────────────────┤
│ 0       │ 550e8400-e29b-41d4-a716-446655440000 │ usuario@ejemplo.com        │ true           │ 2026-07-28T14:30:00Z   │
└─────────┴──────────────────────────────────────┴────────────────────────────┴────────────────┴────────────────────────┘
```
