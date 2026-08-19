# PRD — Orden manual en Hoy (cola de ejecución)

**Producto:** Todos App (wodo)  
**Versión:** 0.1  
**Fecha:** 19 Ago 2026  
**Estado:** Draft — decisiones 1–9 y A cerradas; Fijadas entre ellas + congelar snapshot (19 Ago 2026)  
**Plataforma:** Flutter (iOS / Android / Web)  
**Relación:** Cierra el v1.1 aparcado en `PRD-control-tareas.md` §6.11. Enmienda el orden de `PRD.md` §6.4 (Recientes / `updatedAt`) para las **tareas del día**. Extiende `DayEntry` de `PRD-day-review.md`.

---

## 1. Resumen

**Hoy** deja de ser una lista que se reordena sola cada vez que se guarda algo. Pasa a ser una **cola de ejecución**: las tareas del día se pueden **arrastrar** para dejarlas en el orden en que se quieren cumplir.

**Fijadas** es atención (lo que quieres ver arriba). En este mismo cambio se pueden **ordenar entre ellas**. No se mezclan con Hoy / Del día: no arrastras una fijada hacia Del día ni al revés (eso sigue siendo fijar / desfijar).

`updatedAt` **sigue existiendo** (último guardado de título / cuerpo / tags / fechas). Deja de ser la llave de orden de esas listas una vez el usuario mueve una card. Un comentario sigue sin tocar `updatedAt` ni mover la card.

Esta propuesta **no cambia quién entra** a Hoy, Del día o Fijadas. Cambia **en qué orden se ven** y cómo se persiste.

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
- Que **mover una** deje las demás **donde estaban**. Un orden inicial automático es suficiente; el usuario no pide que el sistema reacomode el resto.
- Que **Fijadas** se puedan ordenar **entre ellas** (atención), con la misma regla: un drag no reordena solas las otras.
- Que ese orden de Hoy sea el de **cumplimiento**, no el de último guardado.
- Que `updatedAt` siga midiendo “último cambio de contenido”, no “posición en la cola”.

### UX
- Reordenar en ≤ 1 gesto desde la lista (handle), sin abrir el editor.
- Tap / long-press / swipe **siguen igual**.
- Completar no obliga a reordenar: las hechas se van al final y dejan de arrastrarse.
- Una tarea nueva o recién sumada a Hoy **no se cuela arriba** por recencia.

### No-objetivos (este cambio)
- Arrastrar **entre** Fijadas y Del día / Hoy (eso es fijar o “hacer hoy”, no sort).
- Drag en **Próximas**, **Backlog / Sin fecha**, replay de días pasados, o checklist/adjuntos.
- Cambiar quién entra a Hoy / Del día (`TaskDayQuery` / `NotesQuery.ofDayFrom`).
- Que un comentario empiece a tocar `updatedAt` (sigue prohibido).
- Prioridad como campo, ni “ordenar por tag Urgente”.
- Reorden entre grupos (arrastrar de Hoy a Próximas). Eso es reprogramar, no sort.

---

## 5. Propuesta de solución

### Concepto

Dos listas, dos jobs, **mismo gesto**, **misma regla de congelar**:

**Hoy = cola del día** (cómo quiero cumplir hoy). Orden en `DayEntry`.  
**Fijadas = atención** (qué quiero ver arriba, independiente del día). Orden en la nota.

```
Chip Todas, día = hoy
┌─────────────────────────────┐
│ Fijadas                     │
│  ⋮⋮  Proyecto X             │  ← handle; solo entre fijadas
│  ⋮⋮  Receta de la semana    │
├─────────────────────────────┤
│ Del día                     │
│  ⋮⋮  Llamar a Ana           │  ← misma cola que Hoy
│  ⋮⋮  Comprar filtro         │
│  ——  ~~Mail de las 9~~      │
│  Nota de la reunión         │  ← notas: recencia, sin handle
└─────────────────────────────┘
```

Mover “Comprar filtro” no reordena “Llamar a Ana” ni las fijadas. Solo cambia el hueco de esa card.

### Dónde se puede arrastrar

| Superficie | ¿Drag? | Por qué |
|---|---|---|
| Chip **Tareas** → grupo **Hoy** (día = hoy) | **Sí** | Cola de ejecución |
| Chip **Todas** → **Del día** (día = hoy), solo las **tareas** de esa cola | **Sí, mismo orden** | Si no, Todas y Tareas se contradicen |
| Chip Todas → Del día, **notas** | **No** | Diario: `updatedAt` desc |
| **Fijadas** (sección en Todas, o chip Fijadas) | **Sí, entre ellas** | Atención. No cruzan a Del día |
| Próximas / Backlog | No | Ahí manda `dueAt` / recencia |
| Día futuro (plan) | **Después** | Mismo `DayEntry.sortOrder` |
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

Una tarea **fijada y de hoy** puede verse en **dos sitios**: Fijadas (chip Todas) y Hoy (chip Tareas). Son dos órdenes distintos y no se copian: atención vs cola del día. En Todas no aparece otra vez en Del día (sigue `pinned` fuera de esa banda).

### 6.2 Qué deja de ordenar `updatedAt`

| Lista | Orden actual | Orden propuesto |
|---|---|---|
| Hoy (pendientes) | Ranking §6.2 + desempate `updatedAt` | `DayEntry.sortOrder` asc |
| Hoy (completadas hoy) | Al final, desempate `updatedAt` | Al final, `sortOrder` relativo que tenían (o `completedAt` desc si nunca se ordenó) |
| Del día — tareas (hoy) | `updatedAt` desc (vía `getAll`) | El mismo `sortOrder` que Hoy |
| Del día — notas | `updatedAt` desc | **Sin cambio** |
| Fijadas (sección y chip) | `updatedAt` desc | `NoteItem.pinnedOrder` tras el primer drag entre fijadas |
| Chip Notas / búsqueda | `updatedAt` desc | **Sin cambio** |
| Próximas | `dueAt` asc | **Sin cambio** |
| Backlog | `updatedAt` desc | **Sin cambio** |

`updatedAt` **sigue** siendo:

- último guardado de título / cuerpo / tags / fechas (y hoy también pin/archivo/complete en el repo);
- membresía de **notas** en Del día;
- heatmap / sync / conflictos.

`updatedAt` **deja de ser** la razón por la que una tarea salta de sitio en Hoy, y deja de reordenar Fijadas una vez esa lista está congelada.

### 6.3 Persistencia: dos sitios, dos significados

| Lista | Campo | Por qué ahí |
|---|---|---|
| Cola de **Hoy** / tareas de Del día | `DayEntry.sortOrder` (`int`, default `0`) | La cola es de **este día**. Mañana es otra entry. |
| **Fijadas** | `NoteItem.pinnedOrder` (`int?`, default `null`) | La atención **no es de un día**. Vivir en el día no se entendería. |

No hay un `NoteItem.sortOrder` genérico. Ese nombre mezclaría Hoy con Fijadas.

**Hoy / DayEntry**

Si una tarea entra a Hoy y aún no hay `DayEntry`, el writer actual crea o actualiza la entry y, si el día ya está congelado, le pone `sortOrder` al final de pendientes.

Backup / sync: viaja en `DayEntry.toMap()`. Ausente = `0`. No es contenido conflictuable. Last-write-wins.

**Fijadas / nota**

`pinnedOrder` solo cuenta si `pinned == true`. Al desfijar se puede dejar el número (no estorba) o limpiarlo; al volver a fijar, si el bloque ya está congelado, entra **al final** (como “nueva en atención”).

Backup / sync: viaja en `NoteItem.toMap()`. Ausente = `null` (semilla por `updatedAt`). Tampoco es conflicto de contenido.

### 6.4 Semilla y “solo se mueve la que arrastro”

Un **orden inicial** automático es adecuado. El usuario no tiene que acomodar las 12 cards el primer día. Lo que no puede pasar: que al mover **una**, el sistema **reordene las otras** (ranking de vencidas, `updatedAt`, etc.).

**Cola Hoy (por día)**

Hasta el primer drag **en esa cola, ese día**:

1. Mostrar el orden automático actual (`TaskGroupsQuery._compareToday`: vencidas → hora → switch → hechas).
2. Ese snapshot **es** la semilla. No se escribe a disco solo por abrir Home.

En el **primer drag** de esa cola:

1. Congelar **exactamente** la secuencia que el usuario está viendo (`sortOrder` 0, 10, 20, …).
2. Aplicar **solo** el movimiento de esa card (el resto mantiene el orden relativo).
3. A partir de ahí el ranking automático **no vuelve a correr** para esa cola ese día.

**Fijadas (atención, no por día)**

Hasta el primer drag **entre fijadas**:

1. Semilla = orden actual (`updatedAt` desc), el que ya se ve.
2. Primer drag: congelar esa secuencia en `pinnedOrder` y mover **solo** esa card.

Abrir Home, guardar una nota, completar o comentar **no** congela ni reordena.

**Después de congelada cada lista**

| Evento | Hoy (pendientes) | Fijadas |
|---|---|---|
| Drag de una card | Solo esa cambia de sitio | Solo esa cambia de sitio |
| Nueva / “Hacer hoy” / volver a comprometer | Final de pendientes | — |
| Fijar una nueva | No entra a Fijadas por este evento si ya estaba fijada; si se fija ahora | **Final** del bloque |
| Guardar título/cuerpo/tags/fechas | No mueve | No mueve |
| Comentario | No mueve | No mueve |
| Completar | Baja al final de Hoy, sin handle | Si está fijada, **se queda** en Fijadas (atención ≠ done) |

**Reindex:** al soltar, reescribir los números de **esa** lista en pasos de 10. No tocar la otra lista.

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

- Handle de **6 puntitos** a la izquierda:
  - tareas **pendientes** de la cola de hoy (chip Tareas → Hoy, y las mismas en Del día hoy);
  - **todas** las cards de Fijadas (notas o tareas; la atención no se apaga al completar).
- Press / click en el handle + arrastrar. Feedback: elevación + hueco. El resto de cards de **esa** lista no cambia de orden relativo, salvo el hueco de la que se mueve.
- Completadas de Hoy, notas de Del día, Próximas, Backlog, replay: **sin** handle.
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
  + sortOrder: int        // 0 = legacy / semilla aún no congelada

NoteItem
  + pinnedOrder: int?     // null = semilla por updatedAt; solo aplica si pinned
```

Queries tentativas: `DayOrderQuery.sortTasks(...)` para Hoy / Del día; `PinnedOrderQuery.sort(...)` para Fijadas.

---

## 8. Criterios de aceptación

- [ ] En chip Tareas → Hoy, las pendientes muestran handle y se pueden reordenar por drag.
- [ ] Mover **una** pendiente no cambia el orden relativo de las otras (solo el hueco de esa card).
- [ ] Al soltar, el orden sobrevive a hot restart / relanzar la app.
- [ ] El mismo orden se ve en Todas → Del día (hoy) para esas tareas; las notas del día siguen por `updatedAt` desc **debajo** de esa banda.
- [ ] Fijadas (sección y chip) muestran handle y se reordenan **solo entre ellas**; no se pueden soltar en Del día.
- [ ] Mover **una** fijada no reordena las otras fijadas ni la cola de Hoy.
- [ ] Guardar título/cuerpo/tags/fechas **no** mueve la card en Hoy ni en Fijadas (si esa lista ya está congelada).
- [ ] Un comentario **no** mueve la card ni cambia `updatedAt`.
- [ ] Completar manda la card al final de Hoy y quita el handle ahí; si está fijada, **sigue** en Fijadas en su sitio.
- [ ] Reabrir la devuelve a pendientes de Hoy según su `sortOrder`.
- [ ] Una tarea nueva / “Hacer hoy” entra al **final** de pendientes si Hoy ya está congelado.
- [ ] Fijar una nueva entra al **final** de Fijadas si ese bloque ya está congelado.
- [ ] El primer drag de Hoy congela el snapshot visible (vencidas → hora → switch) y aplica solo ese movimiento.
- [ ] El primer drag de Fijadas congela el snapshot visible (`updatedAt` desc) y aplica solo ese movimiento.
- [ ] Tap, long-press y swipe siguen funcionando en la misma card.
- [ ] Sin handle / sin drag en Próximas, Backlog, replay, búsqueda, notas de Del día.
- [ ] Maps legacy de `DayEntry` sin `sortOrder` cargan como `0`; `NoteItem` sin `pinnedOrder` carga como `null`.
- [ ] Tests unitarios: semilla, un solo movimiento, insert al final, completar/reabrir, Fijadas vs Hoy, Del día notas vs tareas.
- [ ] QA manual iOS + Android + web: drag vs scroll vs swipe en ambas listas.

---

## 9. Fuera / riesgos

| Riesgo | Mitigación |
|---|---|
| Drag pelea con swipe y con scroll | Handle estrecho; `ReorderableListView` / sliver con `dragStartBehavior` solo en el handle |
| Todas vs Tareas con órdenes distintos | P0: **un** `sortOrder` por `(note, día)` |
| Usuario nunca arrastra y “pierde” el ranking de vencidas | El ranking sigue siendo la semilla hasta el primer drag |
| Vencida nueva a media tarde “debería” ir arriba | **Cerrado:** tras el primer drag del día, entra al **final de pendientes**. El usuario la arrastra si quiere. |
| Sync: dos dispositivos reordenan | Last-write-wins en la entry / `pinnedOrder`; no es conflicto de contenido |
| Tarea fijada + de hoy con dos órdenes | Correcto: Fijadas ≠ Hoy. No sincronizar `pinnedOrder` con `DayEntry.sortOrder`. |

---

## 10. Decisiones

### Cerradas (19 Ago 2026)

| # | Pregunta | Decisión |
|---|---|---|
| 1 | ¿Dónde se guarda el orden de Hoy? | **En el día:** `DayEntry.sortOrder`. No en la nota. |
| 2 | ¿Del día (Todas) usa la misma cola? | **Sí**, para las **tareas** de hoy. Las **notas** de Del día se quedan **debajo**, por recencia (`updatedAt`). |
| 3 | ¿Las notas de Del día se arrastran? | **No.** Diario, no cola. |
| A | Tras el primer drag, ¿una vencida nueva se ancla sola arriba? | **No.** Entra al **final de pendientes**. |
| 4 | ¿`updatedAt` desaparece? | **No.** Deja de reordenar Hoy / Fijadas una vez congeladas. |
| 5 | ¿Completadas se arrastran en Hoy? | **No.** Siempre al final de Hoy. En Fijadas, si sigue pinneada, **se queda**. |
| 6 | ¿Gesto? | **Handle visible**. Long-press sigue siendo menú. |
| 7 | ¿Cuándo se persiste? | Primer drag de **esa** lista (congela el snapshot visible) y cada drop. Mover una no reordena las otras. |
| 8 | ¿Dónde entra lo nuevo? | **Final** de esa lista si ya está congelada. |
| 9 | ¿También reordenamos **Fijadas**? | **Sí, entre ellas.** Atención, no cola del día. Orden en `NoteItem.pinnedOrder`. No se cruza con Hoy / Del día. |

### Abiertas (no bloquean este cambio)

| # | Pregunta | Nota |
|---|---|---|
| B | ¿Toast Deshacer al soltar? | Default **no**. |
| C | ¿Plan de día futuro en el mismo PR de implementación? | **Después**, mismo campo `DayEntry.sortOrder`. |
| D | ¿Pisar `updatedAt` al completar/fijar/archivar? | Hoy el repo lo hace. Fuera de este cambio; no debería usarse para ordenar Hoy. |

---

## 11. Enmiendas a PRDs previos

| Doc | Cambio |
|---|---|
| `PRD-control-tareas.md` §6.2 / §6.11 / decisión 8 | El orden automático de Hoy pasa a ser **semilla**. Drag deja de ser “v1.1 sin spec”. |
| `PRD.md` §6.4 | Recientes/`updatedAt` ya no describe la cola de tareas de hoy. Fijadas se ordenan entre ellas (`pinnedOrder`). |
| `PRD-day-review.md` §8.1 | `DayEntry` gana `sortOrder`. |

---

## 12. Implementación (orden sugerido)

1. `DayEntry.sortOrder` + `NoteItem.pinnedOrder` + roundtrip Hive/backup.  
2. `DayOrderQuery` + `PinnedOrderQuery` + tests (semilla, **un solo movimiento**, insert al final, complete/reopen).  
3. `TaskGroupsQuery` usa `DayOrderQuery` para Hoy.  
4. Del día (hoy): banda tareas por `sortOrder`, notas por `updatedAt`.  
5. Fijadas: `PinnedOrderQuery` en sección y chip.  
6. UI: dos slivers reordenables (Fijadas / Hoy); no se puede soltar de uno en el otro.  
7. Repo: `reorderDayTasks` y `reorderPinned` — no tocan `updatedAt`.  
8. QA gestos.

**Próximo paso:** `TRD-orden-hoy.md` (widgets, conflictos de gesto, sync) → implementar en el orden de esta sección.

---

**Owner:** Product / Design  
**Engineering:** Flutter app (`todos_app`)  
