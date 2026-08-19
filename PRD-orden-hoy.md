# PRD — Orden manual en Hoy (cola de ejecución)

**Producto:** Todos App (wodo)  
**Versión:** 0.1  
**Fecha:** 19 Ago 2026  
**Estado:** Draft — propuesta para revisar  
**Plataforma:** Flutter (iOS / Android / Web)  
**Relación:** Cierra el v1.1 aparcado en `PRD-control-tareas.md` §6.11. Enmienda el orden de `PRD.md` §6.4 (Recientes / `updatedAt`) para las **tareas del día**. Extiende `DayEntry` de `PRD-day-review.md`.

---

## 1. Resumen

**Hoy** deja de ser una lista que se reordena sola cada vez que se guarda algo. Pasa a ser una **cola de ejecución**: las tareas del día se pueden **arrastrar** para dejarlas en el orden en que se quieren cumplir.

`updatedAt` **sigue existiendo** (último guardado de título / cuerpo / tags / fechas). Deja de ser la llave de orden de esas tareas. Un comentario sigue sin tocar `updatedAt` ni mover la card.

Esta propuesta **no cambia quién entra** a Hoy ni a Del día. Solo cambia **en qué orden se ven** las tareas de hoy, y cómo se persiste ese orden.

---

## 2. Dónde estamos hoy (diagnóstico)

Tres ideas distintas se han ido superponiendo. Conviene separarlas.

| Concepto | Pregunta que responde | Qué es hoy en la app |
|---|---|---|
| **Recientes** (PRD Home viejo) | ¿Qué toqué último? | Título **ya no existe**. Era no-fijadas ordenadas por `updatedAt` desc. |
| **Del día** (chip Todas) | ¿Qué pertenece a este día de calendario? | Notas: creadas o guardadas ese día. Tareas: compromiso / due / captura / `DayEntry` / overdue si el día es hoy. |
| **Hoy** (chip Tareas) | ¿Qué voy a ejecutar hoy? | Grupo con badge `X/Y done`. Misma membresía que Del día para tareas de hoy, más vencidas y captura inbox. |

### 2.1 Recientes → Del día

En `PRD.md` §6.4, Recientes era la lista de no fijadas por **último guardado**. En Home actual, chip **Todas** muestra **Fijadas** + **Del día**. Una nota entra a Del día si se **creó o se guardó** ese día (`createdAt` / `updatedAt` en el día local).

Eso es membresía, no un título de sección. El orden visible de Del día **sigue heredando** `NotesRepository.getAll()` → `updatedAt` desc. Por eso editar título/cuerpo/tags/fechas **sube la card**. Completar / fijar / archivar también pisan `updatedAt` hoy en el repo.

### 2.2 Comentario ≠ guardado

Regla ya acordada y a **conservar**: un comentario es contexto. **No** toca `updatedAt`, `completed`, `pinned` ni `archivedAt`. No mete la nota en Del día. No mueve la card.

### 2.3 Orden automático de Hoy (el que se reemplaza)

Chip **Tareas** no usa Recientes. Agrupa y ordena en `TaskGroupsQuery` (`lib/features/notes/domain/task_groups.dart`):

1. Vencidas (due más antiguo primero)
2. Due hoy con hora (asc)
3. Due hoy sin hora
4. Solo switch `todayAt` (asc)
5. Completadas hoy **al final**

Dentro de varios de esos buckets el desempate **sigue siendo `updatedAt`**. Guardar una tarea pendiente la puede **saltar de sitio** sin que el usuario haya decidido un nuevo plan.

`PRD-control-tareas.md` ya aparcó el drag como v1.1 (`sortOrder`, handle de 6 puntitos). Esta propuesta lo abre con reglas concretas.

### 2.4 Gestos que ya ocupan la card

| Gesto | Hoy hace |
|---|---|
| Tap | Abre editor |
| Long-press | Menú contextual (Hacer hoy, Archivar, …) |
| Swipe derecha | Completar / desfijar según tipo |
| Swipe izquierda | Archivar |

El drag **no puede** robar el long-press ni el swipe. Por eso el handle es el gesto de reorden, no “mantener la card entera”.

---

## 3. Problema

La lista de hoy se comporta como un **feed de recencia** (o como un ranking de vencimiento) cuando el usuario la lee como una **cola**: “primero esto, después esto”.

1. Guardar título/cuerpo/tags/fechas reordena sin intención de plan.
2. El ranking automático (vencidas → hora → switch) impone una secuencia que no es “cómo quiero cumplirlas”.
3. Recientes desapareció, pero su llave (`updatedAt`) sigue gobernando Del día y parte de Hoy.
4. No hay forma de dejar el plan del día fijo y que un comentario —o un retoque de texto— no lo desarme.

---

## 4. Objetivos

### Producto
- Que las tareas de **Hoy** se puedan ordenar a mano: press/click + arrastrar.
- Que ese orden sea el de **cumplimiento**, no el de último guardado.
- Que `updatedAt` siga midiendo “último cambio de contenido”, no “posición en la cola”.

### UX
- Reordenar en ≤ 1 gesto desde la lista (handle), sin abrir el editor.
- Tap / long-press / swipe **siguen igual**.
- Completar no obliga a reordenar: las hechas se van al final y dejan de arrastrarse.
- Una tarea nueva o recién sumada a Hoy **no se cuela arriba** por recencia.

### No-objetivos (este slice)
- Drag en **Fijadas** (sigue siendo P1 del PRD Home; otro slice).
- Drag en **Próximas**, **Backlog / Sin fecha**, replay de días pasados, o checklist/adjuntos.
- Cambiar quién entra a Hoy / Del día (`TaskDayQuery` / `NotesQuery.ofDayFrom`).
- Que un comentario empiece a tocar `updatedAt` (sigue prohibido).
- Prioridad como campo, ni “ordenar por tag Urgente”.
- Reorden entre grupos (arrastrar de Hoy a Próximas). Eso es reprogramar, no sort.

---

## 5. Propuesta de solución

### Concepto

**Hoy = cola del día.**  
Membresía = reglas actuales.  
Orden = el que el usuario dejó, persistido **por día**.

```
Chip Tareas, día = hoy
┌─────────────────────────────┐
│ Hoy                    2/5  │
│  ⋮⋮  1. Llamar a Ana        │  ← handle + drag entre pendientes
│  ⋮⋮  2. Comprar filtro      │
│  ⋮⋮  3. Mandar presupuesto  │
│  ——  4. ~~Mail de las 9~~   │  ← hechas, abajo, sin handle
│  ——  5. ~~Sacar basura~~    │
└─────────────────────────────┘
```

`updatedAt` no aparece en este diagrama. Editar el presupuesto no lo mueve al 1.

### Dónde se puede arrastrar

| Superficie | ¿Drag? | Por qué |
|---|---|---|
| Chip **Tareas** → grupo **Hoy** (día = hoy) | **Sí (P0)** | Cola de ejecución |
| Chip **Todas** → **Del día** (día = hoy), solo las **tareas** de esa cola | **Sí (P0), mismo orden** | Si no, Todas y Tareas se contradicen |
| Chip Todas → Del día, **notas** | **No** | Siguen siendo diario: `updatedAt` desc |
| Fijadas | No | Otro job (referencia), otro slice |
| Próximas / Backlog | No | Ahí manda `dueAt` / recencia |
| Día futuro (plan) | **P1** | Mismo `DayEntry.sortOrder` cuando se implemente |
| Día pasado (replay) | No | Auditoría, no plan |

En Del día (Todas, hoy) la lista queda en **dos bandas implícitas**, sin título extra:

1. Tareas del día en el orden de Hoy (pendientes, luego hechas).
2. Notas del día por `updatedAt` desc.

Así Recientes no “vuelve”: las notas siguen siendo lo último escrito; las tareas dejan de mezclarse por recencia con esas notas.

---

## 6. Requisitos funcionales

### 6.1 Membresía (sin cambio)

Siguen vigentes:

- `TaskDayQuery.belongsToHoy` — chip Tareas → Hoy.
- `NotesQuery.ofDayFrom` / `DayViewQuery.taskBelongsToDay` — Del día.
- Fijadas fuera de Del día (`pinned` arriba).
- Archivadas fuera de ambas.

Este PRD **no** reabre vencidas, switch, captura inbox ni completadas de hoy.

### 6.2 Qué deja de ordenar `updatedAt`

| Lista | Orden actual | Orden propuesto |
|---|---|---|
| Hoy (pendientes) | Ranking §6.2 + desempate `updatedAt` | `DayEntry.sortOrder` asc |
| Hoy (completadas hoy) | Al final, desempate `updatedAt` | Al final, `sortOrder` relativo que tenían (o `completedAt` desc si nunca se ordenó) |
| Del día — tareas (hoy) | `updatedAt` desc (vía `getAll`) | El mismo `sortOrder` que Hoy |
| Del día — notas | `updatedAt` desc | **Sin cambio** |
| Fijadas / chip Notas / búsqueda | `updatedAt` desc | **Sin cambio** |
| Próximas | `dueAt` asc | **Sin cambio** |
| Backlog | `updatedAt` desc | **Sin cambio** |

`updatedAt` **sigue** siendo:

- último guardado de título / cuerpo / tags / fechas (y hoy también pin/archivo/complete en el repo);
- membresía de **notas** en Del día;
- heatmap / sync / conflictos.

`updatedAt` **deja de ser** la razón por la que una tarea salta de sitio en Hoy.

### 6.3 Persistencia: orden por día, no global

**Campo nuevo:** `DayEntry.sortOrder` (`int`, default `0` si ausente).

| Por qué no `NoteItem.sortOrder` | Por qué `DayEntry` |
|---|---|
| Una tarea vive en muchos días (due, switch, migrar) | La cola es “cómo quiero cumplir **este** día” |
| Un número global choca entre Hoy de hoy y el plan del jueves | Ya hay una fila `(noteId, day)` |
| Medianoche / `todayAt` que expira no debería arrastrar el orden de ayer | Mañana es otra entry, otra cola |

Si una tarea entra a Hoy y **aún no hay** `DayEntry`, el writer actual de compromiso/due/captura crea o actualiza la entry (ya ocurre en el repo) y le asigna `sortOrder`.

**Backup / sync:** el campo viaja en `DayEntry.toMap()`. Ausente = `0` (legacy). No es contenido conflictuable (título/cuerpo/checklist): last-write-wins en el mapa de entries, igual que `outcome`. Detalle en el TRD.

### 6.4 Semilla (antes del primer drag)

Hasta que el usuario reordene **ese** día:

1. Mostrar el orden automático actual de `TaskGroupsQuery._compareToday` (vencidas → hora → switch → hechas).
2. En el **primer drag** de ese día, **congelar** esa secuencia en `sortOrder` (0, 10, 20, …) y aplicar el movimiento.
3. A partir de ahí, el manual **gana** dentro de las pendientes.

No se escribe `sortOrder` solo por abrir Home. Así un usuario que nunca arrastra no cambia datos.

**Nueva tarea o recién sumada a Hoy** (sin `sortOrder` propio, y el día ya tiene orden congelado):

- Se inserta **al final de las pendientes** (antes de las completadas).
- No al tope. Eso es el cambio respecto al feed por `updatedAt`.

**Huecos / reindex:** al soltar, reescribir `sortOrder` de las pendientes visibles en pasos de 10. Las completadas conservan el número que tenían (solo para desempate entre ellas).

### 6.5 Completar, reabrir, sacar del día

| Acción | Efecto en la cola |
|---|---|
| Completar | Sale del set arrastrable. Queda **abajo** en Hoy / Del día. `sortOrder` no se borra. `X/Y` igual. |
| Reabrir el mismo día | Vuelve a pendientes **en su `sortOrder`**; si quedó “en medio” de las hechas, se reinserta entre pendientes por ese número. |
| Quitar de hoy / archivar / migrar | Sale de la cola. Su `sortOrder` en **ese** día queda histórico (replay). |
| Volver a comprometer el mismo día | Como “nueva en un día ya congelado”: final de pendientes. |
| Editar título/cuerpo/tags/fechas | Puede cambiar membresía (ya no es hoy). **No** cambia `sortOrder` ni la sube. |
| Comentario | Nada: ni `updatedAt`, ni membresía, ni orden. |

Arrastrar **solo** entre pendientes. No se puede soltar una hecha en medio de las pendientes, ni una pendiente debajo de las hechas (el drop target de hechas no existe).

### 6.6 Gesto

- Handle de **6 puntitos** a la izquierda de la card, **solo** en tareas pendientes de la cola de hoy (chip Tareas → Hoy, y las mismas cards en Del día hoy).
- Press / click en el handle + arrastrar. Feedback: elevación + hueco.
- Completadas, notas, Fijadas, Próximas, Backlog, replay: **sin** handle.
- Búsqueda o filtro extra: lista plana, **sin** drag (igual que hoy se pierde el agrupado).
- Web / desktop: el handle es el hit target; no hace falta “modo reorden”.
- El v1.1 viejo (“handle solo tras long-press en el título del grupo”) se **descarta**: oculta el job. El handle visible en la cola es el affordance.

Undo: no hace falta toast por cada drop (es reversible al instante). Si duele en QA, se añade `Orden restaurado · Deshacer` en P1.

### 6.7 Medianoche y otros días

- **Hoy → mañana:** las entries de ayer no ordenan la cola nueva. Cada día semilla de nuevo (§6.4) hasta el primer drag de **ese** día.
- **Replay** (día pasado): orden = `sortOrder` si existió; si no, orden de creación de la entry / reglas de auditoría actuales. Sin drag.
- **Plan de un día futuro (P1):** mismo campo, mismas reglas, cuando esa vista sea el sitio de planear.

### 6.8 Copy

Sin copy nuevo de sección. El handle es la explicación.

Empty de Hoy: sin cambio (`Nada para hoy · …`).

---

## 7. Modelo (delta)

```
DayEntry
  + sortOrder: int   // 0 = legacy / sin congelar
```

No se añade `sortOrder` a `NoteItem`.

Query nueva (nombre tentativo): `DayOrderQuery.sortTasks(items, entriesByNoteId)` usada por `TaskGroupsQuery.from` y por el render de Del día.

---

## 8. Criterios de aceptación

- [ ] En chip Tareas → Hoy, las pendientes muestran handle y se pueden reordenar por drag.
- [ ] Al soltar, el orden sobrevive a hot restart / relanzar la app.
- [ ] El mismo orden se ve en Todas → Del día (hoy) para esas tareas; las notas del día siguen por `updatedAt` desc **debajo** (o tras) esa banda.
- [ ] Guardar título/cuerpo/tags/fechas **no** mueve la card en Hoy.
- [ ] Un comentario **no** mueve la card ni cambia `updatedAt`.
- [ ] Completar manda la card al final y quita el handle; el badge `X/Y` sigue bien.
- [ ] Reabrir la devuelve a pendientes según su `sortOrder`.
- [ ] Una tarea nueva / “Hacer hoy” entra al **final** de pendientes si el día ya está congelado.
- [ ] El primer drag del día congela el orden automático previo (vencidas → hora → switch).
- [ ] Tap, long-press y swipe siguen funcionando en la misma card.
- [ ] Sin handle / sin drag en Fijadas, Próximas, Backlog, replay, búsqueda.
- [ ] Maps legacy de `DayEntry` sin `sortOrder` cargan como `0`.
- [ ] Tests unitarios: semilla, insert al final, completar/reabrir, Del día notas vs tareas.
- [ ] QA manual iOS + Android + web: drag vs scroll vs swipe.

---

## 9. Fuera / riesgos

| Riesgo | Mitigación |
|---|---|
| Drag pelea con swipe y con scroll | Handle estrecho; `ReorderableListView` / sliver con `dragStartBehavior` solo en el handle |
| Todas vs Tareas con órdenes distintos | P0: **un** `sortOrder` por `(note, día)` |
| Usuario nunca arrastra y “pierde” el ranking de vencidas | El ranking sigue siendo la semilla hasta el primer drag |
| Vencida nueva a media tarde “debería” ir arriba | Tras congelar, **no** se reinserta arriba sola; el usuario la arrastra. (Si duele, P1: “anclar vencidas arriba” como opción.) |
| Sync: dos dispositivos reordenan | Last-write-wins en la entry; no es conflicto de contenido |

---

## 10. Decisiones

### Recomendadas (esta propuesta)

| # | Pregunta | Recomendación |
|---|---|---|
| 1 | ¿Dónde se guarda el orden? | **`DayEntry.sortOrder`**, no `NoteItem.sortOrder` |
| 2 | ¿Qué lista es la cola? | **Hoy** (chip Tareas) + las **tareas** de Del día hoy |
| 3 | ¿Las notas de Del día se arrastran? | **No.** Siguen por `updatedAt` (diario, no cola) |
| 4 | ¿`updatedAt` desaparece? | **No.** Deja de ordenar la cola de tareas de hoy |
| 5 | ¿Completadas se arrastran? | **No.** Siempre al final |
| 6 | ¿Gesto? | **Handle visible** en pendientes. Long-press sigue siendo menú |
| 7 | ¿Cuándo se persiste? | En el **primer drag** del día (congela semilla) y en cada drop |
| 8 | ¿Dónde entra lo nuevo? | **Final de pendientes** si el día ya está congelado |
| 9 | ¿Fijadas en este slice? | **No** |

### Abiertas (no bloquean el slice)

| # | Pregunta | Nota |
|---|---|---|
| A | Tras congelar, ¿una vencida nueva debe anclarse sola arriba? | Default **no**. Revisar en QA. |
| B | ¿Toast Deshacer al soltar? | Default **no**. |
| C | ¿Plan de día futuro en el mismo PR? | **P1**, mismo campo. |
| D | ¿Pisar `updatedAt` al completar/fijar/archivar? | Hoy el repo lo hace. Fuera de este slice; no debería usarse para ordenar Hoy. |

---

## 11. Enmiendas a PRDs previos

| Doc | Cambio |
|---|---|
| `PRD-control-tareas.md` §6.2 / §6.11 / decisión 8 | El orden automático de Hoy pasa a ser **semilla**. Drag deja de ser “v1.1 sin spec”. |
| `PRD.md` §6.4 | Recientes/`updatedAt` ya no describe la cola de tareas de hoy. Fijadas siguen por `updatedAt` hasta su propio slice. |
| `PRD-day-review.md` §8.1 | `DayEntry` gana `sortOrder`. |

---

## 12. Implementación (orden sugerido)

1. Campo `sortOrder` en `DayEntry` + roundtrip Hive/backup.  
2. `DayOrderQuery` + tests (semilla, insert, complete/reopen).  
3. `TaskGroupsQuery` usa esa query para Hoy.  
4. Del día (hoy): banda tareas por `sortOrder`, notas por `updatedAt`.  
5. UI: sliver reordenable + handle; swipe/long-press intactos.  
6. Repo: `reorderDayTasks(day, orderedNoteIds)` — no toca `NoteItem.updatedAt`.  
7. QA gestos.

**Próximo paso:** validar §10 con producto → `TRD-orden-hoy.md` (widgets, conflictos de gesto, sync) → implementar en ese orden.

---

**Owner:** Product / Design  
**Engineering:** Flutter app (`todos_app`)  
