# TRD — Control de tareas (fechas, Hoy, swipe, archivar)

**Producto:** Todos App  
**Referencia PRD:** `PRD-control-tareas.md`  
**Fecha:** 17 Jul 2026  
**Estado:** Implementado (v1)

---

## 1. Objetivo

Implementar el slice v1 de control de tareas: campos de fecha/compromiso/archivo en Hive, agrupación Hoy, badge X/Y, editor, card limpia, swipe y vista Archivadas.

---

## 2. Serialización Hive (`NoteItem`)

| Key | Tipo en map | Default si ausente |
|---|---|---|
| `dueAt` | ISO-8601 `String?` | `null` |
| `dueHasTime` | `bool` | `false` |
| `todayAt` | ISO-8601 `String?` | `null` |
| `completedAt` | ISO-8601 `String?` | `null` |
| `archivedAt` | ISO-8601 `String?` | `null` |

`copyWith` usa sentinel `_unset` para permitir clear a `null` en fechas opcionales.

---

## 3. Swipe

**Decisión:** `flutter_slidable` ^3.1.0 — reveal sin dismiss, undo sin sacar la card del árbol.

| Dirección | Task | Note |
|---|---|---|
| Start→End (derecha) | Completar / reabrir | Fijar / desfijar |
| End→Start (izquierda) | Archivar | Archivar |

Ningún swipe borra: eliminar solo en editor, long-press o vista Archivadas.

---

## 4. Casos de prueba clave (Hoy / grupos)

| # | Setup | Esperado |
|---|---|---|
| 1 | Vencida incompleta | En Hoy, primera |
| 2 | Due hoy con hora vs sin hora | Con hora antes |
| 3 | `todayAt` = ayer | No en Hoy |
| 4 | Completada hoy | En Hoy al final; cuenta en X/Y |
| 5 | Vencida completada | Fuera de Hoy |
| 6 | Badge 0/0 | Oculto |
| 7 | Próximas vacías | Lista vacía (no UI) |
| 8 | Legacy map sin keys nuevas | Carga con nulls |

---

## 5. Archivos

| Archivo | Rol |
|---|---|
| `domain/date_only.dart` | Helper día local |
| `domain/task_dates.dart` | Helpers compromiso / overdue |
| `domain/task_groups.dart` | Agrupación + progreso |
| `domain/note_item.dart` | Campos nuevos |
| `data/notes_repository.dart` | archive/restore/today/completedAt |
| `widgets/task_when_field.dart` | Selector ¿Cuándo? + picker fecha/hora |
| `widgets/task_date_meta.dart` | Meta en card |
| `widgets/today_progress_badge.dart` | Pill X/Y |
| `widgets/grouped_tasks_sliver.dart` | Secciones Tareas |
| `widgets/swipeable_note_card.dart` | Slidable + long-press |
| `home_screen.dart` | Orquestación |
| `note_editor_screen.dart` | Contenido + ¿Cuándo? |
| `activity_stats.dart` | completedAt + excluir archivadas |

---

## 6. Orden de implementación

1. Modelo + repo + tests  
2. TaskGroups + NotesQuery  
3. Editor  
4. Home agrupada + Archivadas  
5. Card meta  
6. Swipe + long-press  
7. Activity  
8. QA `flutter test`
