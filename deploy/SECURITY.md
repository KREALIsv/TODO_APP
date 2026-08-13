# SECURITY — modelo de amenazas (WODO sync / E2EE)

Documento breve alineado con `TRD-datos-protegidos-nube.md`. Complementa TLS + auth; no sustituye el E2EE opt-in.

## Activos

| Activo | Dónde |
|--------|--------|
| Notas / tareas / etiquetas | Hive local cifrado (LDEK); `sync_mutations.payload` en API; proyecciones `notes`/`tags` |
| Adjuntos locales | Hive `attachments` + `attachment_blobs` (cifrados at-rest) |
| Credenciales | `users.password_hash` (bcrypt); JWT access + refresh |
| DEK (clave de datos en la nube) | Solo en cliente (secure storage / memoria); wraps en servidor |
| LDEK (clave Hive local) | Solo en cliente. Sin candado: `wodo.local.ldek.v1`. Con candado: wrap PIN (`wodo.local.ldek.wrap.v1`); la LDEK cruda no se guarda en disco |
| Código de recuperación | Solo usuario; wrap `encrypted_dek_recovery` en servidor (no el código) |

## Amenazas y mitigaciones

| Amenaza | Mitigación |
|---------|------------|
| Servidor / ops lee contenido | E2EE opt-in: payloads AES-256-GCM; proyección plaintext desactivada |
| Mutaciones plaintext legacy tras activar E2EE | Purga al activar (+ cleanup idempotente): borra mutaciones no opacas; vacía espejos |
| Lectura de Hive en disco / backup del dispositivo | LDEK + `HiveAesCipher` (AES-256-CBC) en cajas de contenido; con candado, LDEK envuelta con PIN |
| PIN olvidado | Notas locales de ese dispositivo ilegibles; backup o nube (si hay cuenta) siguen siendo el camino |
| Robo de DB de sesiones | `sessions.refresh_token_hash` = SHA-256 del refresh JWT (no plaintext) |
| Dispositivo perdido / revocado | Lista de dispositivos + revoke (`vault_state=revoked`); re-vincular o recovery |
| Pairing interceptado | TTL 3 min; poll token secreto; DEK vía ECDH (servidor solo retransmite ciphertext) |
| Fuerza bruta recovery / mail | Rate limit Nest + cuota Resend por flujo |
| Soporte humano “recupera mis notas” | Imposible sin DEK/recovery (límite E2EE; mensaje de producto) |
| Logout borra datos locales | No: LDEK y Hive se conservan; solo se borra JWT + DEK de nube |

## Fuera de alcance (hoy)

- Adjuntos: sync de blobs encriptados = v2 (local ya va cifrado at-rest)
- Biometría como atajo del PIN (el wrap sigue siendo el PIN)
- Hash de grants efímeros de pairing (TTL corto; cleared on consume)
- Export JSON sigue en claro (el usuario elige compartir un backup)

## Checklist operativo

1. `SECRET_AUTH_TOKEN_KEY` ≥ 32 chars, distinto por entorno
2. HTTPS en edge (Caddy); `CORS_ALLOWED_ORIGINS` estricto
3. Migraciones: `pairing_sessions`, `encryption_e2ee`, `session_refresh_token_hash`
4. Tras deploy del hash de refresh: usuarios deben volver a iniciar sesión (sesiones previas invalidadas)
