# TRD — Comentarios (diario) + ocultar registros de sistema

**Producto:** WODO (todos_app)  
**Referencia PRD:** `PRD-comentarios.md` v0.2  
**Fecha:** 19 Ago 2026  
**Estado:** Draft — no implementado; decisiones de producto cerradas (layout A, `updatedAt` sí)  
**Plataforma:** Flutter (iOS / Android / Web)

---

## 1. Objetivo

Añadir en el editor de **nota y tarea** un feed unificado:

- comentarios de la persona (texto ± imágenes; persistencia al Enviar)  
- registros de **sistema**: `DayEntry` + `NoteAuditEvent` (ediciones al persistir)  
- toggle **Ocultar detalles** que oculta *todo* lo de sistema  
- portada explícita desde una foto de comentario  
- sync de `comment` + `noteAudit` (sin blobs)  
- backup local con bytes  

Sin rich text, sin colaboración. Comentar **sí** actualiza `NoteItem.updatedAt`. Layout desktop = camino A (panel 340 dp).

---

## 2. Alcance

### Incluido (v1)

- `NoteComment` + box Hive `comments`  
- `NoteAuditEvent` + box `note_audits`  
- `NoteAttachment.commentId`  
- `CommentsRepository`, `NoteAuditRepository`  
- `CommentsActivitySection` en notas **y** tareas (full + embedded)  
- Setting `hideCommentAuditDetails`  
- Portada desde imagen con `commentId` (menú / visor)  
- Sync: entidades `comment` y `noteAudit`; DTO Nest  
- Backup + wipe  
- Tests: serialización, feed/filtro, cascade, cover, sync de texto, backup

### Fuera de v1

- Chip 💬 en `NoteCard`  
- Sync de `attachment_blobs`  
- Split de dos columnas / ensanchar el editor (camino B, v2)  
- Dejar `updatedAt` quieto al comentar  
- Watchers / menciones / reacciones / avatares

---

## 3. Decisiones de ingeniería

| # | Tema | Decisión | Motivo |
|---|---|---|---|
| 1 | ¿Comentarios embebidos en `NoteItem`? | **No** — box `comments` | Ítem ya grande; cascade y sync por entidad |
| 2 | ¿Reusar `DayEntry` para comentarios o audits? | **No** | Semánticas distintas |
| 3 | Imágenes | Mismo `attachments` + `commentId` | Un pipeline |
| 4 | `forNote` | Sigue excluyendo `commentId != null` | La fila Adjuntos y 📎 no mezclan el diario |
| 5 | Portada | `coverAttachmentId` puede apuntar a un adjunto con `commentId` | `getById` / bytes no filtran por commentId |
| 6 | Auto-portada | Solo primera imagen **sin** `commentId` | Una captura de bug no debe robar la card |
| 7 | Merge del feed | `buildCommentActivityFeed` pura | Testeable |
| 8 | Toggle | Setting global bool | Un default para toda la app |
| 9 | Composer vs Guardar | `CommentsRepository.add` al Enviar | No se pierde si se descarta el editor |
| 10 | Ítem nuevo | Composer `enabled: false` | Evita huérfanos al cancelar |
| 11 | `updatedAt` | **Sí** al crear/editar/borrar comentario | Es un cambio; mueve Del día (notas) y heatmap de escritura. No toca completed/pin/archivo |
| 12 | Auditoría | Diff al persistir, un evento por campo | No por tecla |
| 13 | Comentario ≠ audit | CRUD de comentario no escribe `NoteAuditEvent` | Hide-details no los esconde |
| 14 | Sync blobs | **No** en v1 | Placeholder remoto |
| 15 | Identidad visual | Sin avatar | Diario personal |
| 16 | Layout 340 dp | **A** cerrado | No `Row` dentro de 340; B es v2 |

---

## 4. Modelo

### 4.1 `NoteComment`

```dart
class NoteComment {
  final String id;
  final String noteId;
  final String body;         // '' permitido si hay imágenes
  final DateTime createdAt;
  final DateTime? editedAt;
}
```

Validación: body vacío **y** 0 imágenes → rechazo; `body.length > 4000` → error de UI.

### 4.2 `NoteAuditEvent`

```dart
enum NoteAuditKind {
  created,
  titleChanged,
  bodyChanged,
  tagsChanged,
  dueChanged,
  todayChanged,
  reminderChanged,
  completed,
  reopened,
  archived,
  restored,
  typeChanged,
  checklistChanged,
  coverChanged,
}

class NoteAuditEvent {
  final String id;
  final String noteId;
  final NoteAuditKind kind;
  final DateTime createdAt;
  final String? summary; // copy ES ya resuelto, p. ej. "Título actualizado"
}
```

No persistir old/new values en v1 (privacidad + tamaño). El copy es suficiente.

`DayEntry` **no** se duplica como audit: el feed lo incluye como kind `dayEntry`.

### 4.3 `NoteAttachment`

```dart
final String? commentId; // null = fila Adjuntos
```

`forNote` filtra `commentId == null`.  
`forComment(commentId)`, `deleteForComment`.  
`getById` / `bytesFor` sin filtro (portada y visor).

`addImage(..., {String? commentId})`: si `commentId != null`, no auto-cover.

`maxImagesPerComment = 4`. `maxPerNote = 12` solo cuenta adjuntos de ítem.

### 4.4 Setting

`hideCommentAuditDetails` default `false`.

### 4.5 Feed

```dart
enum CommentFeedKind { comment, dayEntry, audit }

List<CommentFeedItem> buildCommentActivityFeed({
  required List<NoteComment> comments,
  required List<DayEntry> dayEntries,
  required List<NoteAuditEvent> audits,
  required bool hideDetails,
})
```

- `sortAt`: comment → `createdAt`; dayEntry → `outcomeAt ?? createdAt`; audit → `createdAt`.  
- `hideDetails` → omitir `dayEntry` y `audit`.  
- Sort desc; empate: comment > audit > dayEntry.

---

## 5. Persistencia y escritura de auditoría

| Box | Contenido |
|---|---|
| `comments` | `NoteComment` |
| `note_audits` | `NoteAuditEvent` |
| `attachments` | maps con `commentId` opcional |
| `attachment_blobs` | sin cambio |
| settings | `hideCommentAuditDetails` |

`NotesRepository.add` / `update` / `archive` / `restore` / `toggleCompleted` / `saveTaskFromEditor` / `applyCoverAttachmentChange`:

1. Persistir el ítem como hoy (`updatedAt` **sí** se actualiza en esos flujos: son ediciones reales).  
2. Diff `previous` vs `next` → `NoteAuditRepository.addAll(events)`.

Helper puro `diffNoteAudits(NoteItem? previous, NoteItem next)` → lista de eventos. Tests unitarios por campo.

Comentar **no** pasa por ese diff (no es una edición de campos del ítem). Tras `comments.add` / `updateBody` / `delete`, el repo de comentarios llama a `notes.touchUpdatedAt(noteId)` (o `update` solo de `updatedAt`) para que Home / heatmap vean el cambio. Ese touch **no** genera `NoteAuditEvent`: el comentario ya es la fila de persona.

Borrar ítem: `comments.deleteForNote` + `audits.deleteForNote` + adjuntos (incluye commentId). Si la portada era de un comentario, ya se va el ítem.

Duplicar ítem (si existe): no copiar comments ni audits.

---

## 6. UI

### 6.1 Archivos nuevos

| Archivo | Rol |
|---|---|
| `domain/note_comment.dart` | Modelo |
| `domain/note_audit_event.dart` | Modelo + enum |
| `domain/comment_activity_feed.dart` | Merge + filtro |
| `domain/note_audit_diff.dart` | Diff previous/next |
| `data/comments_repository.dart` | Hive comments |
| `data/note_audit_repository.dart` | Hive audits |
| `widgets/comments_activity_section.dart` | Sección |
| `widgets/comment_composer.dart` | Campo + clip + Enviar |
| `widgets/comment_tile.dart` | Fila comentario + menú portada |
| `widgets/system_activity_tile.dart` | Fila audit / reexport day tile |

### 6.2 Archivos tocados

| Archivo | Cambio |
|---|---|
| `note_attachment.dart` | `commentId` |
| `attachments_repository.dart` | filtro `forNote`; `forComment`; `addImage` con commentId |
| `attachment_actions.dart` / visor | `Usar como portada` válido si el id existe, tenga o no commentId |
| `note_editor_screen.dart` | Sección si `_isEditing` (nota **o** tarea); historial de días deja de estar solo |
| `notes_repository.dart` | hooks de audit + cascade |
| `sync_service.dart` + snapshot | secciones `comment`, `noteAudit` |
| `backend` DTO `IsIn` + tipos | `comment`, `noteAudit` |
| `data_backup.dart` | `comments`, `noteAudits` |
| `settings_repository.dart` | bool |
| `main.dart` | init repos |

Composer disabled: hint según `NoteType`.

### 6.3 `CommentsActivitySection`

Props: `noteId`, `enabled`, `onDayTap`.

1. Header + toggle si hay ≥1 fila de sistema **o** el setting está en hide.  
2. Composer.  
3. Feed.  
4. Empty copy del PRD §12.

Móvil y desktop: **el mismo widget**. Sin split salvo decisión B.

### 6.4 Portada desde comentario

En `comment_tile` / visor: mismas acciones de portada que Adjuntos.  
`applyCoverAttachmentChange` persiste `coverAttachmentId` y toca `updatedAt` (cambio del ítem + audit `coverChanged`). Comentar también toca `updatedAt`, pero sin fila de audit.

Borrar comentario cuya imagen es portada → `coverAttachmentId = null` (sin auto-promote).

### 6.5 Desktop 340 dp (cerrado: A)

Wrap del header, composer a ancho. **No** ensanchar `DesktopContextPanel`. Camino B (overlay ≥ 720) queda en v2.

---

## 7. Backup

Añadir `"comments"` y `"noteAudits"`. Attachments ya exportan todos los maps (incluidos `commentId`) + `bytesBase64`. Import tolerante si faltan claves.

Wipe: reset comments + audits.

---

## 8. Sync (v1, sin blobs)

Hoy snapshot = `{ note, tag, dayEntry }`.  
Backend `entityType`: `'note' | 'tag' | 'dayEntry'`.

Añadir:

1. `comment` → `CommentsRepository` save/delete from sync.  
2. `noteAudit` → idem.  
3. Ampliar `SyncMutationDto`, `SyncResponseItem`, tests de snapshot.  
4. `SyncService`: escuchar `changes` de ambos repos; `_snapshot()` incluye las secciones.  
5. Conflictos: last-write-wins por `id` (entidades append-friendly). **No** pasar `comment` / `noteAudit` por el three-way merge de `note` (`TRD-sync-conflict-content-merge.md`).  
6. Pull de comentario con `attachmentIds` cuyos blobs no existen → UI placeholder.  
7. `coverAttachmentId` ya viaja en `note`; sin blob, la card usa el empty de portada actual.  
8. Alineación con `TRD-sync-conflict-content-merge.md` (ya en `main`): `contentEqual` **ignora** `updatedAt`. Comentar (solo timestamp en la nota) **no** crea copia de conflicto. Si el apply toma el remote porque el local solo cambió `updatedAt`, dejar `updatedAt = max(local, remote)` para no borrar el toque de Del día / heatmap. Test: comentar + pull de título remoto = 0 conflict copies; `updatedAt` queda el más nuevo.

**No** meter `bytesBase64` en el mutation de comment (payload grande, timeout). Eso es el slice de attachments.

Orden de apply: note primero, luego comment/audit (FK lógica). Si llega comment de un `noteId` aún no local, guardar igual (el editor no se abre).

---

## 9. Tests clave

| # | Caso | Esperado |
|---|---|---|
| 1 | `fromMap` sin `editedAt` / `commentId` / `summary` | Carga |
| 2 | Feed mixto desc | Comentario más nuevo primero |
| 3 | `hideDetails` | Cero dayEntry y cero audit |
| 4 | Empate de timestamp | Comment gana |
| 5 | `forNote` | No lista imgs con commentId |
| 6 | Cover apunta a commentId | Card / visor resuelven bytes |
| 7 | Delete comment portada | `coverAttachmentId` null; adjuntos de ítem intactos |
| 8 | Add img comentario | No auto-cover |
| 9 | Diff save título+tags | 2 audits; `updatedAt` del ítem sí cambia |
| 10 | Add comment | 0 audits; `updatedAt` del ítem **avanza** |
| 11 | Backup roundtrip | Comments + audits + bytes |
| 12 | Sync push/pull texto | Comment aparece en el otro snapshot |
| 13 | Sync sin blob | Placeholder, no crash |
| 14 | Widget nota nueva | Hint nota, no Enviar |
| 15 | 📎 count | No incrementa por img de comentario |

---

## 10. Orden de implementación

1. Modelos `NoteComment`, `NoteAuditEvent`, `commentId` + tests.  
2. Repos + `diffNoteAudits` + hooks en `NotesRepository` + cascade.  
3. `buildCommentActivityFeed` + tests de hide.  
4. UI sección texto-only en nota y tarea.  
5. Composer imágenes + portada explícita.  
6. Backup.  
7. Sync client + DTO backend + tests de snapshot.  
8. Placeholder de imagen remota.  
9. Layout 340 dp (Wrap header; sin split).

---

## 11. Criterios de done (v1)

- [ ] En una **nota o tarea** guardada envío un comentario de texto y se ve al instante  
- [ ] Puedo adjuntar 1–4 imágenes; `Usar como portada` pinta la card; no aparecen en Adjuntos ni en 📎  
- [ ] Ocultar detalles esconde días **y** «Título actualizado»; deja comentarios  
- [ ] Comentar actualiza `updatedAt` (nota puede entrar en Del día) y **no** escribe `NoteAuditEvent`  
- [ ] Guardar un cambio de título sí escribe audit y sí actualiza `updatedAt`  
- [ ] Ítem nuevo: composer disabled con hint correcto  
- [ ] Delete comment / delete nota no deja blobs; portada se limpia  
- [ ] Export/import restaura comments + audits + fotos locales  
- [ ] Segundo dispositivo (o test de snapshot) recibe el texto del comentario  
- [ ] Foto no sincronizada: placeholder, la app no crashea  
- [ ] `flutter test` cubre §9  

---

## 12. Impacto en el editor

Hoy el historial solo aparece en tareas:

```498:517:lib/features/notes/presentation/note_editor_screen.dart
        if (isTask && _isEditing) ...[
          // TaskDayHistorySection
        ],
```

Pasa a: `if (_isEditing) CommentsActivitySection(...)`.  
Las filas `DayEntry` siguen existiendo solo para tareas (el repo no tiene rows en notas).

`contextPanelWidth = 340` no se toca en el camino A.

---

## 13. Mocks

`PRD-comentarios.md` §15 y `docs/comentarios/`.  
15.1–15.3 = v1 (camino A). 15.4 = v2.
