# PRD + TRD — Day review, backlog y migración consciente

**Producto:** Todos App  
**Versión:** 0.1  
**Fecha:** 20 Jul 2026  
**Estado:** Draft — listo para implementar  
**Plataforma:** Flutter (iOS / Android / Web)  
**Relación:** Extiende `PRD-control-tareas.md` y `PRD-perfil-actividad.md`. No reemplaza Archivadas; añade Diario del día + Backlog + log de outcomes.

---

## 1. Resumen

Pasar de “fecha del header = reloj” a un **control de día bidireccional**: planear el futuro y revisar el pasado (replay histórico), con un **log por día** (`DayEntry`) que permita ver completadas, pendientes en gris, migradas (`>`) y agendadas (`<`), inspirado en Bullet Journal pero adaptado a la UI verde de la app.

Tres pools claros:

| Pool | Pregunta | Evoluciona desde |
|---|---|---|
| **Día (Hoy / fecha seleccionada)** | ¿Qué hago / qué pasó este día? | Grupo Hoy + nuevo modo Diario |
| **Backlog** | ¿Qué está en cola sin día? | “Sin fecha” → pool explícito |
| **Archivadas** | ¿Qué saqué casi para borrar? | Soft-delete (sin fusionar con Backlog) |

**Migración consciente:** default **manual** (long-press / swipe). En Ajustes, opción **Revisión diaria (estilo BuJo)** una vez al día, con **Posponer** (vuelve al próximo open) y **Omitir hoy**. Diseñado para atención dispersa: poca fricción, sin culpa, sin badge rojo.

**Recurrencia:** fuera de este slice (después); se prevé tag/icono ↻ encima del mismo `DayEntry`.

---

## 2. Problema

1. La fecha del header no filtra ni navega; no se puede “ver el 19”.
2. Heatmap / racha muestran conteos, no la lista de lo ocurrido ese día.
3. Archivadas ≠ historial; “Sin fecha” no se siente como cola deliberada.
4. Sin log de outcomes, al migrar/reprogramar se pierde el replay (“qué tenía pendiente ese día”).
5. Un prompt BuJo agresivo castiga a cerebros con atención dispersa; sin ninguna revisión, el backlog mental crece.

---

## 3. Objetivos

### Producto
- Un selector de fecha para **planear y revisar** (mismo control).
- Replay del día: completadas + pendientes contrastadas + `>` / `<`.
- Backlog = cola viva; Archivadas = pre-eliminado.
- Racha visible = **solo días con ≥1 tarea completada** (`completedAt`).
- Migración consciente usable con ADHD: off por defecto; on = 1×/día, posponible.

### UX
- Tap en fecha del header (o celda heatmap) → modo Diario / día seleccionado.
- En replay, fijadas siempre arriba (referencia).
- Acciones Migrar / Agendar / Cola / Descartar en ≤ 2 toques (manual siempre).
- Copy sin culpa; snooze de primera clase.

### No-objetivos (este slice)
- Recurrencia / hábitos ↻ (fase posterior).
- Notificaciones push del ritual BuJo (solo sheet al open/foreground).
- Calendario permanente a pantalla completa.
- Auto-migración silenciosa a medianoche.
- Event log genérico de cada edit de texto (solo outcomes de día).
- Fusionar Archivadas con Backlog.

---

## 4. Decisiones cerradas

| # | Tema | Decisión |
|---|---|---|
| D1 | Selector de fecha | Bidireccional: pasado = replay; hoy/futuro = ejecución/plan |
| D2 | Contenido día pasado | Replay completo: planned ese día + outcomes (opción C) |
| D3 | Fijadas en replay | Siempre arriba como referencia |
| D4 | Racha | Solo completar tareas (`completedAt`) |
| D5 | Recurrentes | Después; mismo `DayEntry` + icono ↻ |
| D6 | Archivadas vs historial | Flujos distintos; Archivadas = pre-borrar |
| D7 | Backlog | Evolucionar “Sin fecha” a pool explícito; **no** fusionar con Archivadas |
| D8 | Migración | Default **manual (B)**; Settings → BuJo 1×/día + Posponer + Omitir hoy |
| D9 | Auto-migra midnight | **No**; quedan `open` grises en el diario |
| D10 | Índice bujo | Semántica en la card (iconos del design system), no página “Clave” como centro |

---

## 5. Modelo mental y flujos

```
Captura → Backlog ⇄ Día ←→ (migrar > / agendar <)
                ↓
           Completada / Cancelada
Cualquiera → Archivadas → Restaurar (→ Backlog) | Eliminar
```

### F1 — Ver el 19 (replay)
Header fecha → picker / prev-next → 19 Jul → modo Diario: fijadas ↑ + entries del 19 con contraste de outcomes.

### F2 — Planear miércoles
Selector → miércoles futuro → ver/agregar compromisos de ese día (vía `dueAt` o “hacer ese día”); Backlog aparte.

### F3 — Migrar manual
Long-press / swipe en pendiente de Hoy → **Hoy+1** (`>`) | **Otro día** (`<`) | **Cola** | **Descartar**.

### F4 — Ritual BuJo (opt-in)
Open app → sheet “Hay N de ayer…” (N≤5) → mismas 4 acciones + Posponer + Omitir hoy.

### F5 — Heatmap → día
Tap celda → navega al Diario de ese día (deja de ser solo SnackBar).

---

## 6. Índice bujo → UI

| Bujo | Outcome / rol | UI (estilo app) |
|---|---|---|
| □ | `open` | Checkbox vacío, texto normal |
| ☑ | `completed` | Checkbox + strikethrough |
| ~~ | `cancelled` | Texto gris + line-through suave |
| `>` | `migrated` | Chevron-right + meta `→ d MMM` |
| `<` | `scheduled` | Calendar/chevron + meta `← d MMM` |
| Cola | `backlogged` | Meta “→ Backlog” en gris |
| ★ | Importante | Tag `Urgente` / pin existente |
| 💡 | Nota | Tipo note; en diario si fijada o hubo actividad |
| ↻ | Recurrencia (luego) | Chip repeat |

Leyenda corta opcional en Ajustes / primer uso. El índice se lee en la lista.

---

## 7. ADHD / atención dispersa (refuerzo)

| Regla | Detalle |
|---|---|
| Default calmado | BuJo Off = cero prompts |
| 1 prompt / día | No se acumulan sheets al posponer |
| Tope N≤5 | Resto: “Ver todas” o quedan en diario |
| 4 acciones grandes | Hoy / Otro día / Cola / Descartar |
| Posponer = 1ª clase | Mismo peso visual que Omitir hoy |
| Bulk | “El resto → cola” al final del sheet |
| Sin interrupt mid-edit | Solo al open/foreground; nunca sobre el editor |
| Sin badge rojo | No badge en icono de app por pendientes de ayer |
| Racha intacta | Posponer / omitir / cola **no** rompen racha |
| Copy | “Hay N cosas de ayer. ¿Las movemos o a la cola?” — nunca “atrasadas / fallaste” |
| Vencidas | Ritual BuJo = lugar preferido para decidir; long-press siempre disponible |

---

## 8. Requisitos funcionales (PRD)

### 8.1 `DayEntry` (P0)

Registro append-friendly por `(noteId, day)`. Una tarea puede tener varias entries a lo largo del tiempo; **una entry activa por (noteId, day)** (última gana o upsert).

| Campo | Tipo | Semántica |
|---|---|---|
| `id` | `String` | UUID propio |
| `noteId` | `String` | FK lógica a `NoteItem.id` |
| `day` | `DateTime` (dateOnly) | Día del log |
| `via` | enum | `todaySwitch` \| `due` \| `migratedIn` \| `scheduledIn` \| `manual` |
| `outcome` | enum | `open` \| `completed` \| `migrated` \| `scheduled` \| `cancelled` \| `backlogged` |
| `targetDay` | `DateTime?` | Destino si migrated/scheduled |
| `outcomeAt` | `DateTime?` | Cuándo se cerró el outcome (null si `open`) |
| `createdAt` | `DateTime` | Alta de la entry |

**Cuándo se crea / actualiza una entry**

| Evento | Efecto |
|---|---|
| Switch “Hoy” / compromiso al día D | Upsert entry `(note, D)` `outcome=open`, `via=todaySwitch` |
| `dueAt` cae en D (tarea activa) | Asegurar entry `(note, D)` `via=due` si aún no existe |
| Completar en D | Entry del día de compromiso (o D si no hay) → `completed`, `outcomeAt=now`; alinear `NoteItem.completedAt` |
| Migrar a D2 | Origen → `migrated` + `targetDay=D2`; destino upsert `open` `via=migratedIn` |
| Agendar a D2 | Origen → `scheduled` + `targetDay=D2`; set `dueAt`/compromiso; destino `via=scheduledIn` |
| Enviar a Backlog | Origen → `backlogged`; clear compromiso del día; `dueAt` opcional según UX (ver TRD) |
| Descartar | Origen → `cancelled` (no borra `NoteItem` salvo que luego archiven) |
| Archivar `NoteItem` | No borra entries (historial se conserva); item sale de pools vivos |

### 8.2 Modo Diario / día seleccionado (P0)

- Estado app: `selectedDay` (`dateOnly`). Default = hoy.
- Si `selectedDay == hoy` → Home de ejecución (chips actuales + Hoy/Backlog/…).
- Si `selectedDay < hoy` → **replay** (read-mostly): fijadas ↑ + lista de `DayEntry` del día con cards de outcome.
- Si `selectedDay > hoy` → vista de plan de ese día (tareas con due/compromiso a esa fecha + CTA desde Backlog).

### 8.3 Backlog (P0/P1)

- Pool de tareas activas sin compromiso de día (`dueAt == null` y sin `todayAt` del día vivo, y sin entry `open` en hoy).
- UI: sección/chip **Backlog** (rename conceptual de “Sin fecha”).
- Desde Backlog: “Hoy” / “Agendar” crea/actualiza `DayEntry`.

### 8.4 Archivadas (sin cambio de semántica)

- Sigue siendo soft-delete / pre-eliminado.
- Restaurar → Backlog (no auto-Hoy).
- No cuenta para racha ni aparece en pools vivos.

### 8.5 Racha (P0)

- `currentStreak` / `longestStreak` / días activos de racha: días con ≥1 `DayEntry.outcome == completed` **o** equivalencia: ≥1 task con `completedAt` ese día.
- Heatmap de “actividad/escritura” puede permanecer como métrica aparte en Perfil; la **racha mostrada como “racha”** usa solo completados.
- Archivar / restaurar / migrar / posponer **no** cuentan.

### 8.6 Revisión BuJo (P1, opt-in)

Settings keys (SharedPreferences o equivalente del proyecto):

| Key | Default |
|---|---|
| `bujoDailyReviewEnabled` | `false` |
| `bujoReviewSnoozedUntilOpen` | `false` |
| `bujoReviewLastCompletedDay` | `null` (dateOnly string) |
| `bujoReviewSkippedDay` | `null` |

Triggers al resume/open si: enabled && hay pendientes de ayer && `lastCompletedDay != hoy` && `skippedDay != hoy` && (si snoozed: mostrar; al posponer set snoozed flag para próximo open).

Sheet: lista ≤5 + acciones + Posponer + Omitir hoy + “Resto → cola”.

### 8.7 Acciones manuales (P0)

Disponibles siempre (BuJo on u off) en long-press / menú contextual / swipe secundario donde no choque con completar/archivar:

- Hacer hoy  
- Migrar a mañana (`>`)  
- Agendar (`<` + picker)  
- Enviar a Backlog  
- Descartar (cancel en diario; opcional archivar después)

---

# TRD — Implementación

## 9. Alcance técnico por fases

| Fase | Entrega | Prioridad |
|---|---|---|
| **0** | Modelo `DayEntry` + Hive box + repo + writers en complete/today/due | P0 |
| **1** | `selectedDay` + UI selector + modo Diario replay | P0 |
| **2** | Acciones Migrar / Agendar / Backlog / Descartar + meta `>` `<` en cards | P0 |
| **3** | Backlog pool explícito (rename Sin fecha + queries) | P1 |
| **4** | Racha solo completados + heatmap tap → día | P1 |
| **5** | Settings BuJo + sheet + snooze/omit | P1 |
| **6** | Recurrentes ↻ | Fuera (otro PRD) |

Orden de build recomendado: **0 → 1 → 2 → 4 → 3 → 5**.

---

## 10. Persistencia

### 10.1 Nueva box Hive: `day_entries`

- Key: `DayEntry.id`
- Índice secundario en memoria: `Map<String /* noteId|yyyy-mm-dd */, DayEntry>` o query O(n) aceptable (&lt; few thousand).
- Retrocompat: box vacía al inicio; **backfill lazy opcional** (fase 1.1): al abrir un día pasado D, si no hay entries, sintetizar desde `NoteItem` (`completedAt`/`dueAt`/`todayAt` históricos limitados). Documentar que pre-slice el replay puede ser incompleto.

### 10.2 Serialización `DayEntry`

```text
id, noteId, day (ISO dateOnly), via, outcome, targetDay?, outcomeAt?, createdAt
```

Enums como `String` name (mismo patrón que `NoteType`).

### 10.3 Settings

Reusar el store de ajustes existente (`PRD-ajustes.md` / prefs del proyecto). No meter flags BuJo dentro de Hive de notas.

### 10.4 `NoteItem`

Sin campos nuevos obligatorios en fase 0–2. Backlog se deriva. Recurrence (fase 6) añadirá `recurrence` opcional después.

---

## 11. Dominio — APIs propuestas

```text
lib/features/notes/domain/day_entry.dart
  enum DayVia { todaySwitch, due, migratedIn, scheduledIn, manual }
  enum DayOutcome { open, completed, migrated, scheduled, cancelled, backlogged }
  class DayEntry { ... toMap/fromMap/copyWith }

lib/features/notes/domain/day_log.dart
  List<DayEntry> entriesForDay(List<DayEntry> all, DateTime day)
  // resolve note + entry for UI rows

lib/features/notes/domain/day_migration.dart
  migrateTo(note, fromDay, toDay, now) -> patches
  scheduleTo(note, fromDay, toDay, now) -> patches
  sendToBacklog(note, fromDay, now) -> patches
  cancelOnDay(note, fromDay, now) -> patches

lib/features/notes/domain/activity_stats.dart
  // streakFromCompletions(completedDays | dayEntries)
  // separar engagement heatmap vs completion streak si aún no está limpio
```

### 11.1 `DayEntriesRepository`

| Método | Rol |
|---|---|
| `getAll()` / `watch()` | Lista / stream |
| `upsert(DayEntry)` | Alta/actualiza por (noteId, day) |
| `entriesForDay(DateTime day)` | Query |
| `openPendingForDay(DateTime day)` | `outcome == open` |
| `ensurePlanned(...)` | Idempotente al comprometer |

### 11.2 Integración `NotesRepository`

Al `toggleCompleted`, `setToday`, cambios de `dueAt`, migraciones: **transacción lógica** (actualizar NoteItem + DayEntry). Si falla uno, no dejar outcome huérfano (best-effort + tests).

---

## 12. Presentación — archivos

| Archivo | Cambio |
|---|---|
| `home_screen.dart` | Estado `selectedDay`; header tappable; branch live vs replay |
| `widgets/day_selector_header.dart` | **Nuevo** — fecha + chevrons / open picker |
| `widgets/day_replay_sliver.dart` | **Nuevo** — fijadas + entries del día |
| `widgets/day_outcome_meta.dart` | **Nuevo** — `>` `<` backlog cancel meta |
| `widgets/day_review_sheet.dart` | **Nuevo** — ritual BuJo |
| `note_card_context_sheet.dart` | Acciones migrar/agendar/cola/descartar |
| `swipeable_note_card.dart` | No chocar con complete/archive; menú o acción extra |
| `grouped_tasks_sliver.dart` | “Sin fecha” → label Backlog |
| `activity_heatmap.dart` / `profile_screen.dart` | `onCellTap` → navegar a día |
| `activity_stats.dart` | Racha por completions |
| `settings_screen.dart` | Toggle BuJo + copy ADHD |
| `archived_screen.dart` | Sin cambio semántico; copy “pre-eliminado” si aplica |

---

## 13. Estado UI — `selectedDay`

```text
_HomeScreenState
  DateTime _selectedDay = dateOnly(now)  // además de _now clock
  // clock sigue refrescando _now; si selectedDay era "hoy" relativo, opcionalmente avanzar a medianoche+1 al resume
```

- Controles: tap fecha → `showDatePicker`; chevron izq/der cambia ±1 día.
- Chip filters en replay: simplificar (Todas / Fijadas visibles; Tareas = entries; Archivadas no mezcla).
- Volver a hoy: chip/botón “Hoy” si `selectedDay != today`.

---

## 14. Criterios de aceptación

### Fase 0–1
- [ ] Existe box `day_entries` y roundtrip de serialización
- [ ] Comprometer “Hoy” crea/actualiza entry `open`
- [ ] Completar marca entry `completed` y alimenta racha por completion
- [ ] Header fecha abre picker; elegir ayer muestra modo Diario
- [ ] Diario ayer: fijadas arriba; completadas vs open en contraste

### Fase 2
- [ ] Migrar a mañana: origen `migrated` con `→ fecha`; destino tiene entry `open`
- [ ] Agendar: origen `scheduled`; `dueAt` coherente
- [ ] Cola: origin `backlogged`; sale de Hoy
- [ ] Descartar: `cancelled` gris en replay; no borra nota

### Fase 4–5
- [ ] Racha no sube por crear/editar/archivar
- [ ] Heatmap tap abre ese día
- [ ] BuJo off: ningún sheet
- [ ] BuJo on: máx 1 sheet/día; Posponer reaparece next open; Omitir hoy calla hasta mañana
- [ ] Sheet ≤5 items; “Resto → cola” funciona
- [ ] Copy sin lenguaje de culpa

---

## 15. Tests unitarios (mínimo)

| Área | Casos |
|---|---|
| `DayEntry` serdes | enums, null `targetDay` |
| `day_migration` | migrate / schedule / backlog / cancel idempotencia |
| `entriesForDay` | filtra por dateOnly TZ local |
| Streak completions | solo `completedAt` / outcome completed; skip archive |
| BuJo gate | enabled/skip/snooze/lastCompleted matrix |
| Replay contrast | open vs completed vs migrated ordering |

---

## 16. Riesgos

| Riesgo | Mitigación |
|---|---|
| Replay vacío para datos legacy | Backfill lazy documentado; no bloquear ship |
| Doble fuente Hoy vs DayEntry | Writers únicos en repo; Hoy deriva de NoteItem **y** se espeja a entry |
| Swipe saturado | Migrar/agendar en long-press primero; swipe solo si hay slot |
| Usuarios overwhelm con BuJo | Default off; N≤5; bulk a cola |
| Confundir Archivadas y Backlog | Copy distinto; restaurar → Backlog |

---

## 17. Orden de implementación (checklist)

1. `DayEntry` + box + repository + tests serdes  
2. Hooks en `toggleCompleted` / set today / due changes  
3. `selectedDay` + `day_selector_header`  
4. `day_replay_sliver` + outcome meta  
5. Acciones migración en context sheet  
6. Streak por completions + heatmap navigation  
7. Rename UI Backlog + query  
8. Settings BuJo + `day_review_sheet`  
9. QA manual: ayer/hoy/mañana, posponer, omitir, ADHD copy  
10. `flutter test`

---

## 18. Pendientes de diseño visual (no bloquean modelo)

- Iconografía exacta `>` / `<` (Material/Cupertino vs custom monochrome).  
- Colocación chip Backlog vs “Sin fecha” literal.  
- Ilustración/empty state del Diario vacío.  
- Microcopy final ES del sheet BuJo.

---

## 19. Referencias

- `PRD-control-tareas.md` — Hoy, dueAt, archivadas, no-recurrence v1  
- `PRD-perfil-actividad.md` — heatmap / rachas  
- `TRD-control-tareas.md` — patrones Hive / swipe  
- Clave bujo (producto): tareas, hecha, migrada `>`, agendada `<`, importante, no completada  
- ADHD UX: snooze 1ª clase, “not today” ≠ fallo, 1 ritual/día, sin badge rojo
