# TRD — Comentarios (diario) + ocultar historial de días

**Producto:** WODO (todos_app)  
**Referencia PRD:** `PRD-comentarios.md`  
**Fecha:** 17 Ago 2026  
**Estado:** Draft — no implementado  
**Plataforma:** Flutter (iOS / Android / Web)

---

## 1. Objetivo

Sustituir el bloque aislado `TaskDayHistorySection` del editor de tareas por un **feed unificado** (comentarios del usuario + `DayEntry`) con:

- composer de texto ± imágenes  
- toggle persistido **Ocultar detalles** (filtra `DayEntry`)  
- persistencia Hive inmediata al enviar  
- backup de comentarios e imágenes de comentario  

Sin changelog genérico de campos, sin rich text, sin split Trello en el panel de 340 dp.

---

## 2. Alcance

### Incluido (v1)

- Tipo `NoteComment` + box Hive `comments`  
- Extender `NoteAttachment` con `commentId` nullable (imágenes de comentario)  
- `CommentsRepository`  
- Widget `CommentsActivitySection` (composer + feed + toggle)  
- Integración en `NoteEditorScreen` (full y `embedded`)  
- Setting `hideCommentAuditDetails`  
- Cascade: borrar comentario → blobs; borrar nota → comentarios + blobs  
- Backup import/export  
- Tests unitarios de modelo, merge del feed, filtro, cascade, serialización backup

### Fuera de v1

- Comentarios en notas (`NoteType.note`)  
- Chip 💬 en `NoteCard`  
- Entidad sync `comment` + cambio de DTO backend (`note` \| `tag` \| `dayEntry`)  
- Layout de dos columnas  
- `updatedAt` de la nota al comentar  
- Watchers / menciones / reacciones

---

## 3. Decisiones de ingeniería

| # | Tema | Decisión | Motivo |
|---|---|---|---|
| 1 | ¿Lista de comentarios embebida en `NoteItem`? | **No** — box `comments` | El ítem ya es grande (checklist, tags); el feed se lista aparte; cascade más claro |
| 2 | ¿Reusar `DayEntry` para comentarios? | **No** | Semántica BuJo distinta; no forzar `via`/`outcome` |
| 3 | Imágenes | **Mismo** `attachments` + `commentId` | Un pipeline de bytes/compresión/visor; `forNote` ignora las que tienen `commentId` |
| 4 | Merge del feed | Función pura `buildCommentActivityFeed` | Testeable sin widgets |
| 5 | Toggle | `SettingsRepository` bool | Un default para toda la app, no por tarea |
| 6 | Composer vs Guardar editor | `CommentsRepository.add` al Enviar | Evita perder el comentario si se descarta el editor |
| 7 | Tarea nueva (`item == null`) | Composer `enabled: false` | El `noteId` UUID ya existe en el editor, pero el ítem no está en Hive; comentar antes de Guardar dejaría huérfanos si el usuario cancela y se limpian adjuntos de sesión |
| 8 | Orden | `createdAt` desc | Composer arriba = Trello; no chat invertido |
| 9 | Identidad visual | Sin avatar con inicial | App de un usuario; icono `chat_bubble_outline` / `history` |
| 10 | `TaskDayHistorySection` | Se **reutiliza la fila** (`_TaskDayHistoryTile` extraída o widget público) dentro del feed; el section widget actual queda como fallback empty o se depreca | No duplicar copy de outcomes |

---

## 4. Modelo

### 4.1 `NoteComment`

```dart
class NoteComment {
  final String id;           // UUID
  final String noteId;
  final String body;         // puede ser '' si solo hay imágenes
  final DateTime createdAt;
  final DateTime? editedAt;
}
```

Hive map: `id`, `noteId`, `body`, `createdAt`, `editedAt`.  
Retrocompat: ausencia de `editedAt` → `null`.

Validación al guardar:

- `body.trim().isEmpty` **y** cero imágenes → rechazo  
- `body.length > 4000` → rechazo / truncar con error de UI

### 4.2 `NoteAttachment`

Campo nuevo opcional:

```dart
final String? commentId; // null = adjunto del ítem (portada / fila Adjuntos)
```

`AttachmentsRepository.forNote(noteId)` **filtra** `commentId == null` (comportamiento actual de Adjuntos y `📎 N`).

Nuevo: `forComment(commentId)`, `countForComment`, `deleteForComment`.

`maxPerNote = 12` sigue aplicando **solo** a adjuntos de ítem. Tope de comentario: constante `maxImagesPerComment = 4` en el repo de comentarios (cuenta `forComment`).

Al `addImage`, overload o parámetro opcional `commentId`. Si viene, no dispara auto-portada.

### 4.3 Setting

`SettingsRepository`: `hideCommentAuditDetails` default `false`.

### 4.4 Feed (dominio puro)

```dart
enum CommentFeedKind { comment, dayEntry }

class CommentFeedItem {
  final CommentFeedKind kind;
  final DateTime sortAt;
  final NoteComment? comment;
  final DayEntry? dayEntry;
}

List<CommentFeedItem> buildCommentActivityFeed({
  required List<NoteComment> comments,
  required List<DayEntry> dayEntries,
  required bool hideDetails,
})
```

- `sortAt`: comentario → `createdAt`; dayEntry → `outcomeAt ?? createdAt` (igual que `entriesForNote`).  
- `hideDetails == true` → omitir `dayEntry`.  
- Sort desc por `sortAt`; tie-breaker: comentarios antes que dayEntry si mismo instante.

---

## 5. Persistencia

| Box | Contenido |
|---|---|
| `comments` | `Map` de `NoteComment.toMap()` keyed by `id` |
| `attachments` | ya existe; maps con `commentId` |
| `attachment_blobs` | sin cambio |
| settings box | key bool nueva |

`CommentsRepository`:

- `init` / `initWithBoxes` (tests)  
- `forNote(noteId)` → lista desc  
- `add`, `updateBody`, `delete`  
- `deleteForNote`  
- `ValueListenable` o `ChangeNotifier` (`changes`) para el editor  
- `exportAllMaps` / `replaceAllFromMaps`

Init en `main.dart` junto a attachments / day entries.

Borrar nota (`NotesRepository.delete`): además de adjuntos de ítem, `comments.deleteForNote` (que borra blobs de comentario).

Descartar sesión de **nueva** tarea: hoy se borran adjuntos añadidos en sesión. Los comentarios no se pueden crear aún (composer off) → no hay leak.

Duplicar nota (si existe flujo): v1 **no** copia comentarios (bitácora del original). Documentar; P1 si producto lo pide.

---

## 6. UI

### 6.1 Archivos nuevos

| Archivo | Rol |
|---|---|
| `lib/features/notes/domain/note_comment.dart` | Modelo |
| `lib/features/notes/domain/comment_activity_feed.dart` | Merge + filtro |
| `lib/features/notes/data/comments_repository.dart` | Hive |
| `lib/features/notes/presentation/widgets/comments_activity_section.dart` | Sección |
| `lib/features/notes/presentation/widgets/comment_composer.dart` | Campo + clip + thumbs + Enviar |
| `lib/features/notes/presentation/widgets/comment_tile.dart` | Fila comentario |
| `test/features/notes/note_comment_test.dart` | Serialización |
| `test/features/notes/comment_activity_feed_test.dart` | Orden y hide-details |
| `test/features/notes/comments_repository_test.dart` | CRUD + cascade |
| `test/features/notes/comments_activity_section_test.dart` | Toggle copy, disabled, empty |

### 6.2 Archivos tocados

| Archivo | Cambio |
|---|---|
| `note_attachment.dart` | `commentId` |
| `attachments_repository.dart` | filtro `forNote`; `forComment`; `addImage(..., commentId)` sin auto-cover |
| `note_editor_screen.dart` | Reemplazar `TaskDayHistorySection` por `CommentsActivitySection` cuando `isTask && _isEditing` |
| `task_day_history_section.dart` | Extraer tile pública `TaskDayHistoryTile` para reuso |
| `data_backup.dart` | clave `comments` en payload; wipe |
| `settings_repository.dart` | bool toggle |
| `main.dart` | `CommentsRepository.instance.init()` |

Nueva tarea (`!_isEditing`): mostrar la sección con composer disabled + hint, **sin** feed (no hay historial). Evita un hueco raro al crear.

### 6.3 `CommentsActivitySection`

Props: `noteId`, `enabled` (false si no persistida), `onDayTap` opcional.

Estructura:

1. Header: título + `TextButton` toggle (si hay ≥1 `DayEntry` **o** el setting está en hide, para poder volver). Si no hay ningún dayEntry, ocultar el botón.  
2. `CommentComposer` si `enabled`; si no, hint.  
3. `ListenableBuilder` de comments + dayEntries + settings → `buildCommentActivityFeed`.  
4. Empty states según PRD §12.

Móvil y desktop: **el mismo widget**. El panel de 340 dp ya scrollea; no hay `Row` de dos columnas.

Teclado: `scrollPadding` en el `TextField` del composer (pauta del título/cuerpo). No `Scaffold.bottomSheet` en v1 (el editor no es un scaffold con FAB). En compact, si el IME tapa, el `ListView` del editor ya hace scroll al foco.

### 6.4 Composer

- `TextField` filled, hint `Escribe un comentario…`, maxLines 4, 4000 chars.  
- `IconButton` clip → reusar `attachment_actions` / mismo sheet que `AttachmentsEditor`.  
- Thumbs locales (bytes en memoria o ids temporales): al Enviar, `add` comentario + `addImage(..., commentId)`.  
- `Enviar`: `FilledButton` o `TextButton` primary; disabled si vacío.  
- No checkbox Seguir.  
- No toolbar Tt/B/I.

Editar: tap Editar abre el mismo composer en modo edición (body + thumbs existentes) o un `showModalBottomSheet` en compact. Preferir **sheet** en compact para no pelear con el scroll del editor; en desktop embedded, inline.

### 6.5 Desktop 340 dp — reglas de layout

- Header: `Wrap` o `Column` si `maxWidth < 300`: título arriba, toggle debajo alineado a la derecha.  
- Composer: clip y Enviar en `Row` bajo el campo (`MainAxisAlignment.spaceBetween`).  
- No `AdaptiveBreakpoints.expanded` split.

P1 (fuera): si `MediaQuery.size.width >= 1200` **y** se ensancha el contexto, un `CommentsActivitySection.sideBySide`. No implementar ahora.

---

## 7. Backup

Payload actual: `notes`, `tags`, `dayEntries`, `attachments` (maps con `bytesBase64`).

Añadir `"comments": [ ...maps ]`.

Imágenes de comentario **ya viajan** dentro de `attachments` si se exportan todos los maps (incluidos los que tienen `commentId`). Verificar que `exportAllMaps` no filtre por `commentId`. Import: `fromMap` debe aceptar `commentId` ausente.

Versión de backup: si hay número de schema, incrementarlo; si no, import tolerante (falta `comments` → `[]`).

Wipe: `comments.resetAll()` además de notes/tags/day/attachments.

---

## 8. Sync (v1.1, contrato)

Hoy `SyncService._localSnapshot()` = `{ note, tag, dayEntry }`.  
Backend `entityType`: `'note' | 'tag' | 'dayEntry'`.

Para comentarios de texto:

1. Box en snapshot `comment`.  
2. Ampliar DTO Nest `IsIn`.  
3. Conflictos: last-write-wins por `id` (igual tags/dayEntry). Borrar remoto = DELETE.  
4. Blobs: **no**. Un dispositivo verá el comentario y thumbs rotos hasta sync de attachments — inaceptable. Por eso **sync de comments queda bloqueado** hasta blobs **o** se synca solo `body` y se ocultan imágenes missing (UI: placeholder «Imagen no sincronizada»). Preferir **bloquear el slice de sync** antes que thumbs rotos.

v1 local-only es coherente con adjuntos actuales (tampoco sync).

---

## 9. Tests clave

| # | Caso | Esperado |
|---|---|---|
| 1 | `fromMap` sin `editedAt` / `commentId` | Carga |
| 2 | Feed mixto orden desc | Comentario más nuevo primero |
| 3 | `hideDetails` | Cero items `dayEntry` |
| 4 | Empate de timestamp | Comentario gana |
| 5 | `forNote` attachments | No lista imágenes con `commentId` |
| 6 | Delete comment | Blobs de ese commentId desaparecen; adjuntos de ítem intactos |
| 7 | Delete note | Cero comments y cero attachments del noteId |
| 8 | Add imagen comentario | `coverAttachmentId` no cambia |
| 9 | Add comentario body vacío + 0 imgs | Error |
| 10 | Backup roundtrip | Comments + bytes |
| 11 | Widget: `enabled: false` | Hint, no Enviar |
| 12 | Widget: hide toggle copy | `Mostrar detalles` cuando setting true |
| 13 | Cover count 📎 | No incrementa por img de comentario |

---

## 10. Orden de implementación

1. Modelo `NoteComment` + `commentId` en attachment + tests de serialización.  
2. `CommentsRepository` + cascade desde `NotesRepository.delete` + tests.  
3. `buildCommentActivityFeed` + tests.  
4. Setting + `CommentsActivitySection` texto-only (sin imágenes) + extraer tile de historial.  
5. Composer imágenes (reusar picker/compresión).  
6. Backup.  
7. Ajustes de layout 340 dp (Wrap header) + tests de widget.  
8. (v1.1) sync — solo con plan de blobs.

No hace falta levantar backend para v1.

---

## 11. Criterios de done (v1)

- [ ] En una tarea guardada puedo enviar un comentario de solo texto y verlo al instante  
- [ ] Puedo enviar un comentario con 1–4 imágenes; tap abre el visor  
- [ ] Esas imágenes no aparecen en Adjuntos ni como portada ni en 📎 de la card  
- [ ] Ocultar detalles esconde el historial de días y deja comentarios; el setting sobrevive a reabrir  
- [ ] En «Nueva tarea» el composer explica que hay que guardar primero  
- [ ] Eliminar comentario / eliminar tarea no deja blobs huérfanos  
- [ ] Exportar e importar restaura comentarios e imágenes  
- [ ] Móvil y panel desktop usan el mismo widget; el shell de 3 columnas no gana una columna extra  
- [ ] `flutter test` incluye los casos de §9  
- [ ] `flutter analyze` no añade avisos en archivos nuevos (preexistentes en el repo se ignoran)

---

## 12. Impacto en el editor actual

Hoy el historial vive al final, tras el switch «Es una tarea»:

```498:517:lib/features/notes/presentation/note_editor_screen.dart
        if (isTask && _isEditing) ...[
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 8),
          TaskDayHistorySection(noteId: _noteId),
          // …
        ],
```

Se reemplaza por `CommentsActivitySection`. El divider se mantiene como corte «definición vs diario».

`AdaptiveBreakpoints.contextPanelWidth = 340` **no se cambia** en este slice.

---

## 13. Consultas técnicas (si producto cierra distinto)

Si §14 del PRD responde «sí a split desktop» → este TRD necesita un segundo slice de shell (ensanchar contexto o editor overlay), no un `Row` dentro de 340 dp.

Si §14 responde «sí a sync v1» → bloquear ship de comentarios con imagen **o** implementar blobs en sync en el mismo PR (alcance mucho mayor: `attachment_blobs` no está en snapshot).

---

## 14. Mocks

Ver `PRD-comentarios.md` §15 y `docs/comentarios/`. v1 implementa **15.1–15.3** (una columna). 15.4 es P1 de shell, no de este slice.
