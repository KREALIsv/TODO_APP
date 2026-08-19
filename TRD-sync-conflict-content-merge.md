# TRD — Conflictos de sync por contenido (no por sesión)

**Producto:** Todos App (wodo)  
**Referencia:** incidente “401 → cerrar sesión → conflictos masivos”; PR #26 / fix `7bc28ca`  
**Fecha:** 19 Ago 2026  
**Estado:** Implementado (v1 cliente)  
**Analogía UX:** OneNote / editores colaborativos — el conflicto es por **nota concreta con cambios incompatibles**, nunca por “toda la libreta”.

---

## 1. Objetivo

Tras expirar el refresh token (o cualquier 401/410) y volver a iniciar sesión, la app debe:

1. **Reconectar y sincronizar** sin generar una lluvia de “Conflictos de sincronización”.
2. Tratar cada entidad por **`id` estable** (misma tarea = mismo `id`).
3. Crear UI de conflicto **solo** cuando hay divergencia real de **contenido** entre local y remoto.
4. Auto-fusionar el resto (p. ej. remoto completó la tarea del 6 ago; local aún la tenía abierta sin editar texto → aceptar remoto, sin copia).

---

## 2. Problema actual

### 2.1 Qué ve la usuaria

1. Error 401 / “Sesión cerrada”.
2. Cierra sesión o la app invalida tokens.
3. Vuelve a entrar → sección **Conflictos de sincronización** con muchas (a veces casi todas) las notas/tareas duplicadas como copias.

### 2.2 Por qué ocurre (diagnóstico técnico)

Hoy `shouldCreateSyncConflict` (`lib/features/sync/domain/sync_conflict.dart`) hace, en esencia:

| Condición | Efecto |
|---|---|
| `local` o `syncedSnapshot` null | No conflicto |
| Misma entidad ya aplicada en este pull | No conflicto (fix replay) |
| `local.toMap() == syncedSnapshot` (JSON completo) | No conflicto |
| Si no: `remote.updatedAt > local.updatedAt` | **Sí conflicto** |

Fallos de diseño:

1. **Base incorrecta en el pull.** `_applyRemoteNote` recibe como “synced” el snapshot de `beforePull = _snapshot()` (= estado local al inicio del sync), no el **último snapshot persistido** tras un sync exitoso (`sync_state.snapshot`). Eso no es un merge a 3 vías real (base / local / remote).
2. **Igualdad de mapa completo.** Incluye `updatedAt`, `completedAt`, metadatos y orden de listas. Un cambio solo de estado (completar) o un retoque de timestamp cuenta como “local distinto” cuando se usa la base correcta.
3. **Regla por reloj, no por contenido.** Si remoto es “más nuevo” y local ≠ base → copia de conflicto, aunque local y remoto solo difieran en `completed` / fechas, o el texto sea idéntico.
4. **Re-auth no debe resetear progreso.** Ya se corrigió no borrar cursor/snapshot al re-login de la misma cuenta (`7bc28ca`). Ese fix evita el peor caso de *replay* de historial; **no** soluciona conflictos espurios por comparación débil de contenido.
5. **Modelo mental erróneo.** Misma `entityId` = misma nota. Completar en otro dispositivo no es “otra nota”: es un avance de la misma.

Resultado: la UI de conflicto se comporta como un dump de la libreta, no como OneNote (solo páginas con choque real).

---

## 3. Alcance

### Incluido

- Merge a **3 vías** en cliente al aplicar mutaciones `note` en pull.
- Huella de **contenido semántico** (campos que sí importan al usuario).
- Auto-resolución por reglas (fast-forward, LWW de campos no conflictivos).
- Conflicto UI solo si hay **solapamiento incompatible** en campos de contenido.
- Garantías de **re-auth / 401** (misma cuenta): no reset de cursor/snapshot; sync limpio.
- Tests unitarios de la matriz de merge + regresión “reconnect no masifica conflictos”.
- Copy UX: conflicto = “esta nota cambió en dos sitios”, nunca implicar pérdida global.

### Fuera de alcance (esta entrega)

- CRDT / OT en servidor.
- Conflictos de `tag` / `dayEntry` con UI dedicada (seguir LWW / upsert actual salvo que reutilicen la misma huella).
- Comentarios de actividad (feature en curso): reservar slot en la huella cuando existan (`comments[]` u homólogo).
- Cambiar el log append-only del backend (`syncMutation`).
- Redesign completo de la pantalla de conflictos (solo ajustar cuándo aparece y el preview de **diff de campos**).

---

## 4. Modelo: merge a 3 vías por `id`

Para cada `entityId` de tipo `note` en pull:

```
base   = último snapshot persistido de esa nota (post-sync exitoso), o null
local  = NoteItem actual en Hive con ese id
remote = NoteItem del payload de la mutación
```

Identidad: **siempre** `local.id == remote.id == entityId`. Las copias de conflicto siguen siendo entidades *locales* nuevas con `syncConflictOfNoteId = entityId`; **nunca** se pushean (ya vigente).

### 4.1 Clasificación de campos

| Clase | Campos | Rol en merge |
|---|---|---|
| **Identidad** | `id`, `type`, `createdAt` | No generan conflicto; `id` es la clave. |
| **Contenido (conflictuable)** | `title`, `body`, `checklistTitle`, `checklistItems` (texto + orden + ids de ítems), futuro `comments` | Si base→local y base→remote cambian el mismo campo a valores distintos → **conflicto**. |
| **Estado fusionable** | `completed`, `completedAt`, `pinned`, `dueAt`, `dueHasTime`, `todayAt`, `archivedAt`, `reminderMinutesBefore`, `tags`, `coverAttachmentId` | Preferir merge por campo: si solo un lado cambió desde `base`, tomar ese lado; si ambos cambiaron a valores distintos → o bien LWW por `updatedAt` **sin** copia UI, o conflicto suave (ver §4.3). |
| **Ignorados para igualdad** | `updatedAt`, `syncConflictOfNoteId` | Nunca disparan conflicto por sí solos. |

Definir:

```dart
Map<String, dynamic> noteContentFingerprint(NoteItem n);
Map<String, dynamic> noteMergeableStateFingerprint(NoteItem n);
bool contentEqual(NoteItem a, NoteItem b);
```

`mapsEqualForSync(local.toMap(), …)` **deja de usarse** para decidir conflictos.

### 4.2 Resultados del merge (enum)

| Resultado | Acción |
|---|---|
| `applyRemote` | `saveFromSync(remote)` — fast-forward o remoto gana sin UI. |
| `keepLocal` | No sobrescribir local; el push posterior sube local (si aún no está en servidor). |
| `merged` | Construir `NoteItem` campo a campo; `updatedAt = max(local, remote)`; `saveFromSync(merged)`; marcar dirty para push si hace falta. |
| `conflict` | Guardar copia local (`buildSyncConflictCopy`) **solo del snapshot local de contenido**, aplicar `remote` (o `merged` no conflictivo) como canónica; mostrar en UI. |

### 4.3 Algoritmo (norma)

```
si local == null:
  → applyRemote

si remote es conflict-copy (payload legacy):
  → ignore (shouldIgnoreRemoteNoteMutation)

si entityUpdatedDuringPull:
  → applyRemote   // replay historial en un solo pull

base = storedSnapshot[note][id]  // NO beforePull

localContentChanged  = contentFingerprint(local)  != contentFingerprint(base)
remoteContentChanged = contentFingerprint(remote) != contentFingerprint(base)
// si base == null: tratar como “ambos cambiaron” solo si contentFingerprint(local) != contentFingerprint(remote)

si !localContentChanged && !remoteContentChanged:
  → applyRemote (alinear metadatos/estado con remoto o merged estado)

si !localContentChanged && remoteContentChanged:
  → applyRemote   // fast-forward; ej. completada en otro device

si localContentChanged && !remoteContentChanged:
  → keepLocal     // push ya envió o enviará local

si localContentChanged && remoteContentChanged:
  si contentFingerprint(local) == contentFingerprint(remote):
    → merged estado (LWW/unión de estado fusionable); sin UI
  si no:
    → conflict    // OneNote: solo esta nota
```

**Ejemplo usuaria (6 ago):**  
misma `id`; local y base con mismo título/cuerpo; remoto `completed: true`.  
→ `localContentChanged = false`, `remoteContentChanged` puede ser false en contenido y true en estado → **applyRemote / merged**, **cero** conflicto.

### 4.4 Replay de historial (cursor desde 0)

Mantener `updatedDuringPull`: la primera aplicación materializa el estado; mutaciones siguientes del mismo `id` en el mismo pull hacen `applyRemote` sin nuevas copias.  
Complemento: si `base == null` (primer sync de la cuenta en el device) y local ya tiene datos, usar **solo** comparación `contentFingerprint(local) vs contentFingerprint(remote)` — si iguales, merge estado; si distintos, **un** conflicto por id (no uno por mutación histórica).

### 4.5 Re-auth / 401 (garantías)

| Evento | Comportamiento obligatorio |
|---|---|
| 401/410 + refresh fallido | Limpiar tokens; **no** borrar `cursor` ni `snapshot`; **no** tocar Hive de notas. |
| Logout manual misma cuenta | Igual: preservar cursor/snapshot. |
| Login misma cuenta | No `_resetSyncProgress()`; disparar `syncNow()`. |
| Login otra cuenta | Account-switch gate existente (upload / download / pausar). |
| Sync tras re-login | Push diffs vs snapshot; pull con merge §4.3. |

Si el snapshot quedó “sucio” (app matada a mitad de sync), el merge por contenido sigue siendo seguro: peor caso = 1 conflicto por nota realmente divergente.

---

## 5. UI (estilo OneNote)

1. Banner / sección de conflictos **solo** si `pendingSyncConflictCount > 0` tras un sync que creó conflictos **nuevos por contenido**.
2. Cada card = **una** `entityId` canónica + preview de campos en conflicto (título / cuerpo / checklist; más adelante comentarios).
3. Acciones vigentes: quedarte con nube / con local / mantener ambas (promover copia).
4. No listar como conflicto notas cuyo único delta fue `completed`, fechas o tags auto-mergeables.
5. Mensaje vacío / post-reconnect: si 0 conflictos → silencioso (o snackbar opcional “Sincronizado”); nunca abrir pantalla de conflictos vacía.

Ajustes: mantener “Resolver conflictos…” y limpieza de copias huérfanas.

---

## 6. Archivos a tocar (implementación)

| Archivo | Cambio |
|---|---|
| `lib/features/sync/domain/sync_conflict.dart` | Fingerprints, enum de resultado, `resolveNoteMerge(...)`, deprecar regla `updatedAt`-only. |
| `lib/features/sync/data/sync_service.dart` | Pasar **stored snapshot** como `base`; aplicar resultado del merge; conservar `updatedDuringPull` + garantías re-auth. |
| `test/features/sync/sync_conflict_test.dart` | Matriz §4.3 + caso “completar remoto sin editar texto”. |
| `test/features/sync/sync_reconnect_merge_test.dart` (nuevo) | Simula: snapshot N, local = N, remote completada → 0 copias; local editó título y remote editó título distinto → 1 copia. |
| `TRD-sync-conflict-content-merge.md` | Este documento. |

Backend: sin cambio obligatorio (log de mutaciones ya es por `entityId`).

---

## 7. Casos de prueba clave

| # | Setup | Esperado |
|---|---|---|
| 1 | Re-login misma cuenta; local == snapshot; remote solo `completed` | 0 conflictos; nota completada |
| 2 | Offline: local edita `body`; remote no cambió | keepLocal / push; 0 conflictos |
| 3 | Local edita `title` “A→B”; remote `title` “A→C” | 1 conflicto en esa id |
| 4 | Local y remote cambian `title` al mismo “B” | 0 conflictos; merge estado |
| 5 | Pull con 5 mutaciones históricas misma id tras cursor reset | 1 apply final; 0 copias extra |
| 6 | 401 → logout → login; sin edits locales | 0 conflictos |
| 7 | Solo difiere `updatedAt` | 0 conflictos |
| 8 | Checklist: mismo texto, distinto `completed` en subítem | merge estado o LWW; sin conflicto de “contenido” si se clasifica completed de ítem como fusionable (**decisión:** texto del ítem = contenido; `completed` del ítem = estado) |
| 9 | Account switch otra email | No aplica este merge; gate existente |

---

## 8. Orden de implementación

1. Fingerprints + `resolveNoteMerge` + tests de matriz (sin wire).  
2. Cablear `_applyRemoteNote` con `base` = snapshot persistido.  
3. Auditoría re-auth: assert en tests/código de que logout/401 no borra cursor/snapshot.  
4. Ajuste UI preview de campos en conflicto (opcional misma PR).  
5. `flutter test` + prueba manual: forzar 401 (token inválido) → re-login → lista limpia.  
6. QA en web + móvil con dos dispositivos (completar en uno, texto en el otro).

---

## 9. Criterios de aceptación

- [x] Expiración de refresh + re-login **sin** ediciones locales concurrentes incompatibles → **0** copias de conflicto nuevas.
- [x] Misma `id`: completar / archivar / fechas en un dispositivo no duplica la nota en el otro.
- [x] Conflicto UI solo si hay divergencia de **contenido** (título, cuerpo, checklist textual, comentarios cuando existan).
- [x] Una nota en conflicto no implica marcar el resto de la libreta.
- [x] Tests de §7 en verde; sin regresiones del cleanup de conflict-copies en push.

---

## 10. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Falsos negativos (perder edit local) | Contenido conflictuable estricto; `keepLocal` cuando solo local cambió desde base. |
| Snapshot ausente tras wipe | Comparar local vs remote por fingerprint; un conflicto máx. por id. |
| Checklist ambigua | Separar texto de ítem vs `completed` (§7.8). |
| Builds antiguas con copias masivas | Mantener acción de limpieza en Ajustes. |

---

## 11. Decisión de producto (confirmada en este TRD)

> **No** se acepta que el fin de sesión cloud genere conflictos masivos.  
> La coordinación es por **`id`**.  
> Sin diferencia de contenido relevante → **no hay conflicto**.  
> La UI de resolución es excepcional y puntual (como OneNote), no un volcado de todas las notas.
