# PRD — Control de tareas: fechas, "Hoy" y acciones rápidas

**Producto:** Todos App
**Versión:** 1.0
**Fecha:** 16 Jul 2026
**Estado:** Draft
**Plataforma:** Flutter (iOS / Android / Web)
**Relación:** Extiende `PRD.md` (Home orientada a Notas). **Enmienda la Decisión #1** (§15) y **resuelve la Decisión #4** (archivar).

---

## 1. Resumen

Añadir una **capa de ejecución** sobre el inbox de notas actual: fechas límite opcionales, un compromiso explícito de "hacer hoy" (switch), agrupación **Hoy** con progreso `X/Y done` dentro de la vista de tareas, y acciones rápidas por swipe (completar / archivar) que además limpian la card.

La Home **no cambia de concepto**: sigue siendo inbox de notas con captura rápida. El control de tareas vive dentro del chip **Tareas**, que pasa de "lista plana de todas las tasks" a una vista agrupada y accionable.

---

## 2. Problema

Hoy el chip **Tareas** muestra todas las tareas sin importar fecha ni urgencia:

1. No hay forma de distinguir "esto vence hoy" de "esto es algún día".
2. No hay forma de comprometerse con un subconjunto del día (patrón My Day / Today).
3. No hay sensación de progreso diario (`X/Y done` no existe; solo streak global).
4. Las acciones de card (pin y borrar siempre visibles) generan ruido y el borrado es la acción destructiva más accesible.
5. No existe archivar: la única salida de una tarea vieja es borrarla.

Con >20 tareas acumuladas, la vista Tareas deja de servir para decidir qué hacer ahora.

---

## 3. Objetivos

### Objetivos de producto
- Que el usuario pueda responder "¿qué tengo que hacer hoy?" en un vistazo.
- Fechas límite como recordatorio pasivo, **nunca** como requisito para crear una tarea.
- Progreso diario visible (`X/Y done`) sin agrandar la gamificación.
- Higiene de lista: archivar en vez de borrar como acción rápida.

### Objetivos de UX
- Marcar/desmarcar "hoy" en ≤ 2 toques desde la lista o el editor.
- Completar con swipe sin abrir la tarea.
- Card más limpia: contenido + fecha; acciones por gesto o en editor.
- Ninguna acción destructiva sin undo.

### No-objetivos (v1 de este PRD)
- Notificaciones / reminders push (v2 del PRD principal)
- Recurrencia de tareas
- Reordenamiento manual con drag handle (6 puntitos) — **v1.1 de este PRD**
- Fecha de inicio (`startAt`) — solo si producto lo pide tras usar due
- Estados más allá de done/undone
- Prioridad como campo (se sigue usando el tag `Urgente`)
- Papelera con retención/expiración automática

---

## 4. Usuarios y casos de uso

### Jobs to be done

| Job | Resultado esperado |
|---|---|
| Comprometerme con lo de hoy | Switch "Hoy" → tarea aparece en grupo Hoy |
| No olvidar un deadline | Fecha límite visible en card; vencidas resaltadas arriba |
| Saber cómo voy | Badge `X/Y done` del día |
| Despachar rápido | Swipe derecha completa sin abrir |
| Limpiar sin miedo | Swipe izquierda archiva (recuperable), no borra |
| Capturar sin fricción | Crear tarea sigue sin pedir fecha |

---

## 5. Propuesta de solución

### Concepto
**Tareas = vista de ejecución agrupada.** Home queda igual; al activar el chip **Tareas**:

```
[ Todas ] [ Fijadas ] [ Notas ] [ Tareas* ]

Hoy                                   2/5 done
  ┌─────────────────────────────────────────┐
  │ ☐ Deploy hotfix        [Urgente] ⚠ Vencida │
  │ ☐ Review PR            [Trabajo] 🕐 10:00 │
  │ ☑ ~Drink water~        [Personal]         │
  └─────────────────────────────────────────┘
Próximas
  │ ☐ Update docs          [Docs] 23 Jul      │
Sin fecha
  │ ☐ Ordenar closet       [Casa]             │
```

Los otros chips (Todas / Fijadas / Notas) **no cambian**.

---

## 6. Requisitos funcionales

### 6.1 Modelo de datos (P0)

Nuevos campos en `NoteItem`, todos opcionales y retrocompatibles (key ausente → `null`, mismo patrón que `tags`):

| Campo | Tipo | Semántica |
|---|---|---|
| `dueAt` | `DateTime?` | Fecha límite. `null` = sin fecha (inbox/algún día) |
| `dueHasTime` | `bool` (default `false`) | Si `true`, la hora de `dueAt` es significativa y se muestra (`10:00 AM`); si `false`, es tarea de "todo el día" |
| `todayAt` | `DateTime?` | Timestamp de cuando se activó el switch "Hoy". Cuenta como compromiso **solo si es del día actual** (auto-expira a medianoche sin migración ni job) |
| `completedAt` | `DateTime?` | Se setea al completar; se limpia al descompletar. `completed` (bool) se mantiene por compatibilidad y se sincroniza siempre |
| `archivedAt` | `DateTime?` | Soft-delete. `null` = activa. Archivada = oculta de todas las listas salvo "Archivadas" |
| `reminderMinutesBefore` | `int?` | Minutos antes de `dueAt` para notificación local. `null` = sin recordatorio; `0` = en el momento. Requiere `dueAt`. Ver §6.12 |

**Reglas:**
- Fechas de negocio (`dueAt`, `todayAt`) aplican **solo a `type == task`**. Al convertir tarea → nota se limpian; nota → tarea nace sin fechas.
- Crear tarea **nunca** exige fecha (quick capture y editor).
- `toggleCompleted` escribe/limpia `completedAt` además de `completed`.
- Datos existentes: todo `null` → todas las tareas actuales quedan "sin fecha", nada se rompe.

### 6.2 Definición de "Hoy" (P0)

Una tarea activa (no archivada) pertenece al grupo **Hoy** si cumple **cualquiera**:

1. `todayAt` es del día actual (switch encendido hoy), o
2. `dueAt` es del día actual, o
3. **Vencida:** `dueAt < inicio de hoy` y `!completed`

**Notas de la regla:**
- Días en timezone local del dispositivo (`dateOnly`), igual que el heatmap.
- Las completadas hoy **permanecen** en el grupo Hoy (strikethrough, al final) hasta el fin del día — alimentan el `X/Y`.
- Las vencidas completadas salen de Hoy (ya no son deuda).
- Una tarea sin fecha y sin switch **nunca** aparece en Hoy.

**Orden dentro de Hoy:**
1. Vencidas (más antigua primero)
2. Con hora de hoy (`dueHasTime`, ascendente)
3. Due hoy sin hora
4. Solo switch (por `todayAt` asc)
5. Completadas hoy (al final)

### 6.3 Vista Tareas agrupada (P0)

Con chip **Tareas** activo y sin búsqueda:

| Grupo | Contenido | Orden |
|---|---|---|
| **Hoy** + badge `X/Y done` | Según §6.2 | Según §6.2 |
| **Próximas** | `dueAt > hoy`, no completadas | `dueAt` asc |
| **Sin fecha** | `dueAt == null`, sin switch hoy, no completadas | `updatedAt` desc |
| **Completadas** (colapsado) | Completadas antes de hoy | `completedAt` desc |

- Grupos vacíos no se muestran (excepto Hoy: ver empty state §6.8).
- Con búsqueda o filtro adicional activo → lista plana (comportamiento actual).
- El grupo Completadas se muestra colapsado con contador (`Completadas (12)`); tap expande.

**Badge de progreso:**
- Formato: `X/Y done` donde `Y` = tareas del grupo Hoy, `X` = completadas de esas.
- Pill compacto (estilo `3/5 done` verde suave de la referencia), a la derecha del título del grupo.
- `0/0`: no se muestra badge.
- Al llegar a `Y/Y` con `Y ≥ 1`: estado visual de celebración sutil (color pleno; sin confetti).

### 6.4 Compromiso "Hoy" (P0)

**En el editor** (solo si `type == task`): selector exclusivo **¿Cuándo?** (ver §6.5). El chip **Hoy** setea `todayAt = now` y limpia `dueAt`. Si `todayAt` existe pero es de un día anterior, el chip no aparece seleccionado (auto-expiró).

Al guardar una tarea que queda en el grupo Hoy: snackbar `Sumada a Hoy · X/Y done` (crear) o `En Hoy · X/Y done` (editar). Completar sigue siendo gesto de lista (checkbox/swipe), no control del editor.

**Desde la card (acceso rápido):**
- Long-press en card de tarea → menú contextual: `Hacer hoy` / `Quitar de hoy`, `Archivar`, `Eliminar`.

### 6.5 Selector «¿Cuándo?» en editor (P0)

Sección tras título/contenido (solo tasks). Chips exclusivos (camino rápido):

| Chip | Persistencia |
|---|---|
| **Hoy** | `todayAt = now`, `dueAt = null`, `dueHasTime = false` |
| **Mañana** | `dueAt = dateOnly(mañana)`, `todayAt = null` |
| **Fecha** | `showDatePicker` → `dueAt`; `todayAt = null`. Label del chip **fijo** (`Fecha`) — nunca incrusta la fecha ni «hoy» |
| **Algún día** | `dueAt = null`, `todayAt = null` |

**Campo de valor** (siempre visible bajo los chips): mismo lenguaje visual que los `TextField` del editor (borde `neutral20`, radio 12, padding 16/12). Los chips siguen siendo atajos rápidos.

| Estado | Copy en el campo |
|---|---|
| Hoy | `Hoy` |
| Algún día | `Sin fecha` (placeholder muted) |
| Mañana / Fecha | `D mmm` o `D mmm, H:MM AM/PM` (mismo formato si es el día actual) |
| Vencida | badge `Plazo vencido` a la derecha del valor |

Chevron `▾` a la derecha. Tap en el campo (o en chip **Fecha**) → siempre el sheet de detalle (§6.12), donde se edita vencimiento, hora y recordatorio. Chips con `showCheckmark: false`.

- Hidratación al editar: compromiso hoy → Hoy; due mañana sin hora → Mañana; otro `dueAt` → Fecha; else → Algún día.
- Sin diálogo obligatorio de hora tras elegir día.
- Sin validaciones de rango: se permiten fechas pasadas (nace vencida, decisión consciente del usuario).
- Completar no vive en el editor; Archivar + Eliminar sí (AppBar, solo en edición).

### 6.6 Card de tarea (P0 — rediseño ligero)

**Se elimina** de la card: botón pin y botón eliminar siempre visibles.

**Se mantiene:** checkbox, título, preview, tags (máx. 3 + `+N`), indicador de tipo.

**Se añade — meta de fecha (reemplaza al tiempo relativo en tasks con fecha):**

| Estado | Render |
|---|---|
| Vencida | Tag pill rojo suave: `🕐 14 Jul` (fondo error al 12%, texto/icono error) |
| Vence hoy sin hora | `Vence hoy` en primary |
| Vence hoy con hora | `🕐 10:00 AM` en primary |
| Próxima | `23 Jul` en neutral |
| Sin fecha | tiempo relativo actual (`hace 2 h`) |
| En grupo Hoy por switch | punto/icono sutil de "hoy" (☀ o similar) |

- El pin sigue existiendo: indicador visual si `pinned` (icono pequeño en meta), acción desde editor o long-press.
- Notas (`type == note`) conservan su card actual sin cambios.

### 6.7 Swipe actions (P0)

Sobre cards en cualquier lista (usando `Dismissible`/`Slidable` con backgrounds de color):

| Gesto | Tarea | Nota |
|---|---|---|
| **Swipe derecha** | Completar / descompletar (toast `Tarea completada · Deshacer`) | Fijar / desfijar |
| **Swipe izquierda** | Archivar (toast `Tarea archivada · Deshacer`, 4 s) | Archivar (ídem) |

- Ningún swipe borra. **Eliminar** vive en: editor (botón), long-press (menú) y vista Archivadas.
- Umbral de swipe estándar de plataforma; fondo verde (completar) / neutral (archivar) con icono.
- Undo revierte el campo tocado (`completedAt`/`completed` o `archivedAt`).

### 6.8 Archivar / Archivadas (P0)

**Resuelve Decisión #4 del PRD principal: soft-delete, sin papelera con expiración.**

- Archivar = `archivedAt = now`. La nota/tarea desaparece de todas las listas y de la búsqueda por defecto.
- **Acceso:** entrada `Archivadas` al final de la fila de chips (o en menú overflow del header — decidir en diseño visual; default: chip al final).
- En vista Archivadas cada card ofrece: `Restaurar` (limpia `archivedAt`) y `Eliminar definitivamente` (con confirmación).
- Archivadas **no** cuentan para Hoy, badge, streak ni heatmap.
- Eliminar desde cualquier punto conserva el undo toast actual.

### 6.9 Empty states (P0)

| Contexto | Copy |
|---|---|
| Grupo Hoy vacío, hay otras tareas | `Nada para hoy · desliza o abre una tarea para planear tu día` |
| Chip Tareas sin tareas activas | `No hay tareas` (actual) |
| Vista Archivadas vacía | `No hay elementos archivados` |
| Todo Hoy completado | Badge `Y/Y done` + grupo muestra las completadas tachadas |

### 6.10 Actividad / streak (P0 ajuste)

- Completar tarea cuenta actividad por `completedAt` (día real de completado) en lugar de `updatedAt`.
- Crear/editar sigue contando por `createdAt`/`updatedAt` (sin cambio).
- Archivar/restaurar **no** cuenta como actividad.

### 6.11 Reorden manual con drag (v1.1 — fuera de este slice)

- Handle de 6 puntitos visible solo en modo reorden (long-press en título del grupo o botón).
- Requiere campo `sortOrder` y reglas de interacción con el orden automático de §6.2 (el manual gana dentro del grupo).
- Se especificará en TRD propio cuando este PRD esté estable.

### 6.12 Detalle de fecha — Recordatorios y Periodicidad

**Punto de entrada (mix):**
- Los chips de §6.5 siguen siendo el camino rápido.
- El **resumen secundario** (o el chip Fecha ya seleccionado) abre un bottom sheet de detalle. No hay calendario permanente ni campos de fecha de inicio.

**Contenido del sheet:**
- Fecha de vencimiento (tap → `showDatePicker`)
- Hora opcional (tap → `showTimePicker`; acción para quitar hora)
- Recordatorio (dropdown de presets)
- Acciones: `Guardar` / `Quitar fecha`

**Periódico** (nuevo campo `recurrence`, opcional — v2):
- Presets: `Nunca` (default) / `Cada día` / `De lunes a viernes` / `Semanalmente` / `Mensualmente`.
- Sin presets de baja frecuencia ("el 1er lunes del mes").
- Al completar una ocurrencia con recurrencia activa, se genera la siguiente instancia en ese momento (patrón "hábito"), no se pre-generan todas las futuras.

**Crear recordatorio** (`reminderMinutesBefore`, opcional; requiere `dueAt`):
- Catálogo: `Ninguno` (default) / `En el momento del vencimiento` / `5 minutos antes` / `10 minutos antes` / `30 minutos antes` / `1 hora antes` / `1 día antes` / `2 días antes` / `1 semana antes`.
- Notificaciones **solo locales** (`flutter_local_notifications`) — Hive local, un dispositivo, sin backend ni sync.
- Reglas operativas:
  - Guardar/editar tarea con `dueAt` + recordatorio → programar notificación local con `id` derivado de `NoteItem.id`.
  - Completar, archivar, borrar o cambiar `dueAt`/recordatorio → cancelar y, si aplica, reprogramar.
  - Permiso de notificaciones la primera vez que el usuario activa un recordatorio (no al abrir la app).
  - Ventana silenciosa por defecto (ej. 22:00–7:00) para recordatorios "en el momento" que caigan de noche — evaluar en diseño visual.

---

## 7. Requisitos no funcionales

| Área | Requisito |
|---|---|
| Retrocompatibilidad | Datos Hive existentes cargan sin migración; keys ausentes → `null`/default |
| Performance | Agrupación en memoria; lista de 500 items agrupa+renderiza sin jank (60fps mid-range) |
| Timezone | "Hoy" = día local del dispositivo; cambio de día refresca la vista al volver a foreground |
| Undo | Toda acción de swipe reversible en ≥ 4 s |
| Accesibilidad | Swipe actions con alternativa accesible (long-press menú); labels en switches y badges; hit targets ≥ 44pt |
| i18n | Strings nuevos externalizados ES (EN después) |
| Tests | Lógica pura de §6.2 (pertenencia a Hoy, orden, badge) con tests unitarios; serialización roundtrip de campos nuevos |

---

## 8. Flujos principales

### F1 — Planear el día
Home → chip Tareas → long-press en tarea → `Hacer hoy` → sube al grupo Hoy → badge pasa de `2/5` a `2/6`

### F2 — Deadline
Abrir tarea → chip `Fecha` → elegir día (+ hora opcional) → guardar → card muestra meta de fecha → el día 23 aparece en Hoy automáticamente

### F3 — Despachar
Vista Tareas → swipe derecha → tachada + `completedAt` → badge `3/6` → toast con Deshacer

### F4 — Vencida
Tarea con `dueAt` ayer sin completar → aparece **primera** en Hoy con `⚠ Vencida` → completar la saca de la deuda

### F5 — Limpiar
Swipe izquierda → archivada + toast Deshacer → recuperable en Archivadas → ahí `Restaurar` o `Eliminar definitivamente`

### F6 — Cambio de día
Tarea con switch de ayer no completada → hoy el switch aparece apagado y la tarea vuelve a Sin fecha/Próximas (no arrastra compromisos viejos; las vencidas por `dueAt` sí persisten en Hoy)

---

## 9. UX / UI — cambios vs estado actual

| Actual | Nuevo |
|---|---|
| Chip Tareas → lista plana por `updatedAt` | Grupos Hoy / Próximas / Sin fecha / Completadas |
| Sin noción de fecha en tareas | `dueAt` opcional + badge de estado en card |
| Sin progreso diario | Pill `X/Y done` en grupo Hoy |
| Pin + borrar visibles en cada card | Card limpia; swipe + long-press + editor |
| Borrar = única salida | Archivar (soft) como default; borrar detrás de confirmación |
| Completar solo vía checkbox | Checkbox + swipe derecha |

### Principios visuales
- Mantener paleta verde + neutros; rojo/naranja suave **solo** para vencidas.
- El grupo Hoy es jerárquicamente dominante en la vista Tareas (título mayor + badge).
- Badges de fecha compactos, mismo tamaño tipográfico que la meta actual.
- Sin nuevos heros ni cards decorativas; solo se re-estructura la lista.

---

## 10. Métricas de éxito

| Métrica | Target v1 |
|---|---|
| % tareas completadas vía swipe | ≥ 30% de completados |
| Tareas con `dueAt` asignada | ≥ 40% de tareas activas |
| Uso del switch Hoy | ≥ 3 activaciones/semana por usuario activo |
| Ratio archivar vs borrar | ≥ 2:1 |
| Días con Hoy completado (`Y/Y`) | medir baseline (nuevo) |

Instrumentación mínima: `task_due_set`, `task_today_toggled`, `task_completed_swipe`, `item_archived`, `item_restored`, `today_group_cleared`.

---

## 11. Alcance por fases

### v1 (este PRD — MVP del slice)
- Campos `dueAt` / `dueHasTime` / `todayAt` / `completedAt` / `archivedAt`
- Editor: selector «¿Cuándo?» (Hoy / Mañana / Fecha / Algún día)
- Vista Tareas agrupada + badge `X/Y done`
- Card: badge de fecha, limpieza de botones
- Swipe completar / archivar con undo
- Vista Archivadas (restaurar / eliminar definitivo)
- Long-press menú contextual
- Streak por `completedAt`
- Tests de lógica Hoy + serialización

### v1.1
- Drag reorder (6 puntitos) con `sortOrder`
- Filtro por rango de fechas en el listado (sobre `dueAt`) — conecta con P1 del PRD principal
- Vencidas: acción rápida `Mover a hoy` / `Reprogramar`
- Ordenar Sin fecha por antigüedad configurable

### v2 — Fechas avanzadas

Ver §6.12. Orden de construcción:

1. **Recordatorios locales** sobre `dueAt` (prioridad — impacto inmediato en "no olvidar deadline")
2. **Recurrencia**
3. Sugerencias de planificación (ayer incompleto → "¿mover a hoy?")

**Descartado para v2** (ver Decisión #10, §15): fecha de inicio (`startAt`) — se resuelve el mismo job con "Algún día" + recordatorio en la fecha deseada, sin campo nuevo que migrar.

---

## 12. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Grupo Hoy se llena de vencidas viejas y desmotiva | Vencidas arriba pero visualmente diferenciadas; v1.1 añade "Reprogramar" en bloque |
| Confusión Hoy vs due hoy | Selector exclusivo «¿Cuándo?»; en cards, iconos distintos (☀ vs 🕐/⚠) |
| Swipe accidental | Umbral estándar + undo 4 s en todas las acciones |
| Usuario no descubre long-press | Editor mantiene todas las acciones; onboarding tooltip 1 vez en primera tarea |
| `todayAt` bool-like mal implementado (no expira) | Regla explícita §6.1: cuenta solo si es del día actual; test unitario de expiración |
| Medianoche / cambio de día con app abierta | Re-evaluar grupos on-resume; aceptable no refrescar en vivo a las 00:00 |
| Doble fuente de verdad `completed`/`completedAt` | Sincronización única en `toggleCompleted`; test de invariante |

---

## 13. Dependencias

- `NoteItem` + `NotesRepository` (Hive) existentes — patrón de retrocompatibilidad de `tags`
- `NotesQuery` — se extiende con lógica de grupos (pura, testeable)
- `FilterChipsBar`, `NoteCard`, `TagPill` — se reutilizan/ajustan
- `showDatePicker` / `showTimePicker` de Material — sin paquetes nuevos obligatorios (evaluar `flutter_slidable` para swipe con reveal de opciones vs `Dismissible` nativo)
- **v2 (§6.12):** `flutter_local_notifications` para recordatorios locales (Android/iOS); revisar permisos de notificación (Android 13+ runtime permission, iOS `UNUserNotificationCenter`) y comportamiento en background/terminated app

---

## 14. Criterios de done (v1)

- [ ] Tarea puede crearse sin fecha, con fecha, y con fecha+hora; la fecha puede quitarse
- [ ] Chip Hoy del selector «¿Cuándo?» y long-press «Hacer hoy» funcionan, y el compromiso expira solo al día siguiente
- [ ] Grupo Hoy cumple exactamente §6.2 (incl. vencidas y completadas de hoy) con tests
- [ ] Badge `X/Y done` correcto en todos los estados (0/0 oculto, Y/Y celebración)
- [ ] Swipe derecha completa / izquierda archiva, ambos con undo funcional
- [ ] Card de tarea muestra el estado de fecha correcto en los 6 casos de §6.6
- [ ] Vista Archivadas permite restaurar y eliminar definitivo con confirmación
- [ ] Ninguna card muestra ya botones pin/borrar permanentes
- [ ] Datos previos al update cargan intactos (roundtrip test con map legacy)
- [ ] Streak cuenta completados por `completedAt`
- [ ] QA manual iOS + Android: swipe, pickers, cambio de día (cambiar fecha del dispositivo)

---

## 15. Decisiones de producto

### Cerradas (v1 de este PRD)

| # | Pregunta | Decisión |
|---|---|---|
| 1 | ¿Vista Hoy dedicada o dentro de Tareas? | **Dentro del chip Tareas** como grupo dominante. Home no cambia. (Enmienda Decisión #1 del PRD principal: de "solo filtro" a "filtro con grupos + progreso") |
| 2 | ¿Vencidas entran a Hoy? | **Sí**, arriba y diferenciadas, hasta completarse o reprogramarse |
| 3 | ¿Switch hoy como bool? | **No** — `todayAt: DateTime?` con expiración implícita diaria |
| 4 | ¿Archivar? | **Soft-delete** con `archivedAt`, vista Archivadas, sin expiración automática. (Resuelve Decisión #4 del PRD principal) |
| 5 | ¿Swipe borra? | **Nunca.** Borrar solo tras archivo o vía editor/long-press con confirmación |
| 6 | ¿Fechas en notas? | **No** — solo `type == task` en v1 |
| 7 | ¿`startAt` en v1? | **No** — diferido a v2 si hay demanda |
| 8 | ¿Drag reorder en v1? | **No** — v1.1 con `sortOrder` y TRD propio |
| 9 | ¿Hora obligatoria con fecha? | **No** — hora opcional vía `dueHasTime` |
| 10 | ¿`startAt` (fecha de inicio)? | **No.** Se resuelve el mismo job con "Algún día" + recordatorio en la fecha deseada; un campo menos que migrar y mantener |
| 11 | ¿Punto de entrada de fecha/hora/recordatorio? | **Mix**: chips rápidos (§6.5) + **resumen único** bajo chips que abre sheet de detalle (§6.12). Sin links sueltos ni calendario permanente |
| 12 | ¿Qué construir primero en v2, recordatorios o recurrencia? | **Recordatorios primero** (impacto inmediato en "no olvidar deadline"); recurrencia después |
| 13 | ¿Catálogo de presets de recordatorio? | **Completo**: Ninguno / en el momento / 5, 10, 30 min / 1 hora / 1, 2 días / 1 semana antes |
| 14 | ¿Alcance de notificaciones? | **Solo locales** (`flutter_local_notifications`), un dispositivo, sin backend/sync |
| 15 | ¿Copy especial si la fecha elegida es hoy? | **No.** Resumen siempre `D mmm` (igual que cualquier otro día). «Hoy» = solo el chip de compromiso `todayAt`. Chips con label fijo y sin checkmark |

### Pendientes (no bloquean v1)

| # | Pregunta | Cuándo decidir |
|---|---|---|
| A | Ubicación exacta de "Archivadas" (chip vs menú header) | Diseño visual de v1 |
| B | ¿Sugerir "mover a hoy" tareas incompletas de ayer? | v2 |
| C | Icono definitivo del estado "hoy por switch" | Diseño visual de v1 |

---

## 16. Anexo — Copy sugerido (ES)

| Contexto | Texto |
|---|---|
| Grupo | `Hoy` / `Próximas` / `Sin fecha` / `Completadas (N)` |
| Badge | `2/5 done` (evaluar `2/5 hechas` para ES puro) |
| Selector editor | `¿Cuándo?` · `Hoy` / `Mañana` / `Fecha` / `Algún día` |
| Long-press | `Hacer hoy` / `Quitar de hoy` / `Archivar` / `Eliminar` |
| Fecha editor | Chips `Hoy` / `Mañana` / `Fecha` / `Algún día` |
| Campo valor | `Hoy` / `Sin fecha` / `23 jul` / `23 jul, 9:00 AM` (+ badge `Plazo vencido`) — tap → sheet |
| Sheet fechas | `Vencimiento` / `Hora` / `Recordatorio` / `Guardar` / `Quitar fecha` |
| Toast compromiso | `Sumada a Hoy · X/Y done` / `En Hoy · X/Y done` |
| Card vencida | Tag pill `🕐 14 Jul` |
| Card hoy | `Vence hoy` / `10:00 AM` |
| Toast completar | `Tarea completada · Deshacer` |
| Toast archivar | `Tarea archivada · Deshacer` |
| Restaurar | `Restaurar` |
| Borrado definitivo | `¿Eliminar definitivamente? Esta acción no se puede deshacer.` |
| Empty Hoy | `Nada para hoy` |
| Empty Archivadas | `No hay elementos archivados` |

---

**Owner:** Product / Design
**Engineering:** Flutter app (`todos_app`)
**Próximo paso:** TRD del slice v1 (modelo + query de grupos) → implementación en orden: modelo → lógica Hoy → vista agrupada → editor → swipe → archivadas.
