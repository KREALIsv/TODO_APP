# PRD — Comentarios y actividad en el detalle

**Producto:** WODO (todos_app)  
**Versión:** 0.1  
**Fecha:** 17 Ago 2026  
**Estado:** Draft — evaluación + propuesta de UX; listo para validar decisiones y pasar a implementación vía `TRD-comentarios.md`  
**Plataforma:** Flutter (iOS / Android / Web)  
**Relación:** Extiende el editor (`NoteEditorScreen`), el historial BuJo (`TaskDayHistorySection` / `DayEntry`) y los adjuntos (`PRD-adjuntos-imagen.md`). **No** copia el feed colaborativo de Trello.

---

## 1. Resumen

Añadir en el detalle de una **tarea** un **diario cronológico**: comentarios del usuario (texto y, opcionalmente, imágenes) mezclados con el **historial de días** que ya existe.

Un botón **Ocultar detalles / Mostrar detalles** filtra el ruido de auditoría (filas de `DayEntry`) y deja solo los comentarios.

Esto **no** es un hilo de equipo. WODO es local-first y de un usuario. El patrón de Trello sirve como referencia de *feed + toggle*, no como producto a clonar.

---

## 2. Evaluación de la idea

### 2.1 Qué resuelve (vale la pena)

Hoy una tarea tiene:

| Superficie | Rol |
|---|---|
| `title` + `body` | Definición del trabajo (se reescribe) |
| Adjuntos | Evidencia / portada del ítem |
| Checklist | Subpasos |
| `TaskDayHistorySection` | Qué días se planificó, completó, migró |

Falta un sitio para **anotar lo que pasó en el tiempo** sin ensuciar la descripción:

- «Hoy el cliente mandó el NIT por WhatsApp» + captura  
- «Probé el fix en staging, sigue fallando el validador»  
- Una foto del ticket / de la pantalla, atada a *ese momento*, no a la portada de la card

Eso encaja con el uso BuJo / ADHD de WODO: el diario del día dice *en qué día estuvo la tarea*; el comentario dice *qué ocurrió*.

### 2.2 Qué **no** debemos copiar de Trello

La referencia (card con sidebar «Comentarios y Actividad», avatares, «ha movido esta tarjeta de TO DO a DOING», rich text, «Seguir») asume:

1. **Varias personas** en un tablero con columnas.  
2. Un **changelog genérico** de cada movimiento de campo.  
3. Un **layout de dos columnas** (~60 % detalle / ~40 % feed) a pantalla completa.

WODO no tiene esas tres cosas:

| Trello | WODO hoy |
|---|---|
| Multi-usuario | Un usuario (+ sync opcional de *tu* cuenta) |
| Columnas Kanban | Listas + compromiso de día (`todayAt` / `dueAt`) |
| Activity = «movió de X a Y» | Activity = `DayEntry` (planificado / completado / migrado / agendado) |
| Editor a pantalla completa + sidebar | Móvil: editor full-screen. Desktop ≥1200: editor en panel derecho de **340 dp** |
| Rich text + paperclip + «Seguir» | Texto plano; adjuntos ya viven en otra sección; no hay watchers |

`PRD-adjuntos-imagen.md` §3 ya marcó «comentarios, avatares, watchers» como **no-objetivo** porque no aplican a WODO local. Esta propuesta **no contradice** eso: no añade colaboración. Añade un **journal personal** sobre el ítem.

`PRD-day-review.md` §3 deja fuera, a propósito, un «event log genérico de cada edit de texto». **Ocultar detalles no debe inventar ese log.** Solo oculta lo que ya tenemos: el historial de días.

### 2.3 Riesgos

| Riesgo | Mitigación |
|---|---|
| El `body` y los comentarios se solapan | Copy y UX: descripción = «qué es»; comentario = «qué pasó / nota de avance». Sin migrar el body a comentarios. |
| Imágenes de comentario vs Adjuntos | Scope distinto: Adjuntos = del ítem (pueden ser portada). Comentario = del momento. No aparecen en la fila de portada. |
| Panel desktop de 340 dp no cabe un split Trello | v1: **misma columna** que el móvil (feed al final del editor). Split 60/40 = P1 solo si el editor deja de vivir en 340 dp. |
| Composer independiente vs «Guardar» del editor | Comentarios se persisten **al enviar**, no al Guardar del editor. En nota/tarea nueva, el composer espera a que el ítem exista (o dispara un autosave mínimo). |
| Sync | Hoy sync cubre `note` / `tag` / `dayEntry`. **Los blobs de imagen no van en sync.** Comentarios de texto sí pueden entrar como entidad nueva; las fotos de comentario siguen el mismo techo que Adjuntos (backup local, no nube) hasta un slice de blobs. |
| Inflar el editor | Sección colapsable en espíritu (toggle de detalles). Sin toolbar rich. Sin «Seguir». |

### 2.4 Veredicto

**Sí, como diario de la tarea (v1), no como chat de tarjeta.**

El botón «Ocultar detalles» tiene sentido **si** «detalles» = historial de días. Si se interpreta como changelog tipo Jira/Trello, es trabajo extra que el producto ya rechazó.

Comentarios **con o sin imagen** sí: reutilizar el pipeline de `AttachmentsRepository` (picker, compresión, visor), con `commentId` para no mezclarlos con la portada.

---

## 3. Problema

1. La descripción se usa a la vez como spec y como bitácora → queda un párrafo eterno o se pierde el contexto.  
2. El historial de días es útil para replay, pero ruidoso cuando solo quieres leer notas de avance.  
3. Una captura de «así se veía el bug el martes» no debería convertirse en portada de la card.  
4. En desktop, cualquier feed tipo Trello choca con el panel contextual de 340 dp.

---

## 4. Objetivos

### Producto
- Dejar un comentario de texto en ≤ 2 toques desde el editor de una tarea existente.  
- Adjuntar 0–N imágenes a *ese* comentario (mismo flujo galería/cámara que Adjuntos).  
- Ver un feed cronológico: comentarios + eventos de día.  
- **Ocultar detalles** deja solo comentarios; **Mostrar detalles** vuelve a mezclar.  
- Preferencia del toggle persistida (Settings / Hive), no por tarea.

### UX
- Lenguaje visual de WODO: superficie clara, acento verde `#2DA44E`, radios 12, sin avatares de equipo.  
- Composer compacto (texto + clip + Enviar). Sin rich text. Sin checkbox «Seguir».  
- Móvil: sección al **final** del editor, teclado no tapa el composer (padding / sticky al foco).  
- Desktop v1: **igual**, dentro del panel de 340 dp. No abrir una cuarta columna.

### No-objetivos (v1)
- Comentarios en **notas** (solo tareas). Las notas ya son el apunte; el journal aporta poco.  
- @menciones, reacciones, hilos anidados, «Seguir».  
- Changelog de título / tags / fechas / checklist.  
- Rich text, markdown renderizado, GIFs, vídeo, PDF.  
- Layout Trello 60/40 en el shell de tres columnas.  
- Sync de blobs de imagen (igual que Adjuntos hoy).  
- Contador 💬 en la card de Home (P1).  
- Edición colaborativa en tiempo real.

---

## 5. Usuarios y jobs

Persona: la misma del PRD principal — captura personal, a menudo en el móvil, a veces en web/desktop.

| Job | Resultado |
|---|---|
| Dejar rastro de un avance | Comentario visible en el detalle, con hora relativa |
| Pegar una captura al momento | Imagen bajo el texto, tap → visor ya existente |
| Revisar solo lo que yo escribí | Ocultar detalles; el historial de días desaparece |
| Entender el ciclo de la tarea | Mostrar detalles; comentarios + «Completada el 16 ago», «Migrada a…» |

---

## 6. Propuesta de UI

### 6.1 Principio

**Una sección, dos tipos de fila, un filtro.** No una pestaña «Actividad» aparte en v1.

Autor: siempre el dueño local. Sin círculo con inicial de otra persona. Identidad visual: icono de comentario / punto de timeline en primary, no un fake «Bea 3.14».

### 6.2 Móvil (compact < 600)

El editor sigue siendo un `ListView` (título → cuerpo → ¿Cuándo? → tags → checklist → adjuntos → switch tipo). **Debajo**, sustituye el bloque actual «Historial de días» por:

```
Comentarios                          [Ocultar detalles]
┌─────────────────────────────────────┐
│ Escribe un comentario…          📎  │
└─────────────────────────────────────┘
                         [Enviar]  (activo si hay texto o imagen)

  ┌─ Comentario ──────────────────────┐
  │ Ayer el validador rechazó el NIT. │
  │ [miniatura]                       │
  │ hace 2 h · Editar · Eliminar      │
  └───────────────────────────────────┘

  · Completada · 16 ago 2026          ← fila auditoría (DayEntry)
  · Planificada · 15 ago 2026
```

Con **Ocultar detalles**:

```
Comentarios                          [Mostrar detalles]

  ┌─ Comentario ──────────────────────┐
  │ Ayer el validador rechazó el NIT. │
  │ hace 2 h                          │
  └───────────────────────────────────┘

  (sin filas de historial)
```

- Header: icono `chat_bubble_outline` + título `Comentarios`.  
- El botón del toggle es un `TextButton` / chip outlined (mismo peso que «Ver más» del historial actual), no un CTA verde.  
- Composer: campo filled radio 12 + icono clip a la derecha. Al foco, aparece **Enviar** (primary).  
- Preview de imagen(es) entre el campo y Enviar, thumbs 64×64 como Adjuntos.  
- Filas de auditoría: densas, `bodySmall`, color secondary; tap → mismo `onDayTap` que hoy (ir al día).  
- Filas de comentario: card blanca / `AppSurface`, texto `bodyMedium`, meta relativa (`relative_time.dart`).  
- Empty: «Todavía no hay comentarios. El historial de días aparece aquí cuando planifiques o completes la tarea.» Si hide-details y no hay comentarios: «No hay comentarios. Muestra los detalles para ver el historial.»

Composer **sticky** solo mientras el campo tiene foco (evita comerse media pantalla en reposo).

### 6.3 Desktop (panel 340 dp — v1)

El editor embebido (`embedded: true`) **no cambia de sitio**. El feed va al final del mismo scroll.

Adaptaciones al ancho estrecho:

- Título `Comentarios` y el botón de toggle **en dos líneas** si no caben (no icon-only opaco).  
- Composer a ancho completo; clip + Enviar en la misma fila bajo el campo.  
- Miniaturas a 56 dp.  
- Sin segunda columna. El shell (perfil 300 + lista + contexto 340) se mantiene.

### 6.4 Desktop amplio — P1, no v1

Solo si en el futuro el editor deja el panel de 340 dp (p. ej. overlay ≥ 720 dp o el contexto se ensancha al abrir una tarea):

```
┌────────────── editor ≥ 720 ──────────────┐
│ Título / cuerpo / fechas / tags / …     │  Comentarios  [Ocultar…]
│ Adjuntos                                │  [composer]
│                                         │  feed sticky
└─────────────────────────────────────────┘
```

Hasta entonces, **no** forzar un split que recorte el formulario a ~200 dp.

### 6.5 Composer con imagen

```
┌─────────────────────────────────────┐
│ El validador sigue fallando…        │
│                                     │
│ ┌────┐                              │
│ │img │  ✕                           │
│ └────┘                              │
└─────────────────────────────────────┘
📎 Añadir imagen              [Enviar]
```

Action sheet igual que Adjuntos: `Tomar foto` / `Elegir de la galería` / Cancelar. En web, solo archivo.

Límite propuesto: **4 imágenes por comentario**, **12 comentarios con imagen por tarea** (además del tope de 12 adjuntos de ítem). Compresión idéntica (max edge 1920, JPEG ~85).

Enviar con **solo imagen** (sin texto) está permitido.

### 6.6 Acciones del comentario

- **Editar** texto (inline o sheet); las imágenes se pueden quitar / añadir en el mismo editor.  
- **Eliminar** → confirmación ligera o undo 4 s (misma pauta que adjuntos).  
- Tap imagen → `AttachmentViewerScreen` existente.

### 6.7 Card de lista

v1: **sin** chip 💬. Evita ruido junto a 📎 y fechas.  
P1: `💬 N` en meta si `commentCount > 0`.

---

## 7. Requisitos funcionales

### 7.1 Crear comentario (P0)
- Visible solo en tareas **ya persistidas**.  
- Enviar habilitado si `trim(text).isNotEmpty` **o** hay ≥1 imagen pendiente.  
- Persistencia inmediata (Hive), independiente de Guardar del editor.  
- No cambia `NoteItem.body`.  
- `updatedAt` de la tarea: **no** se toca en v1 (un comentario no debe subir la card a Recientes). Decisión revisable — ver §11.

### 7.2 Imágenes (P0)
- 0–N por comentario, tope §6.5.  
- No setean `coverAttachmentId`.  
- No cuentan en el `📎 N` de Adjuntos del ítem.  
- Borrar comentario borra sus blobs.  
- Borrar / duplicar tarea: cascade igual que adjuntos de ítem.

### 7.3 Feed (P0)
- Orden: `createdAt` desc (más reciente arriba, debajo del composer).  
- Tipos: `comment` | `dayEntry`.  
- Hide-details: filtra `dayEntry`.  
- Historial vacío + sin comentarios: empty copy actual del historial, más mención a comentarios.

### 7.4 Toggle (P0)
- Default: **mostrar detalles** (el historial no es secreto).  
- Persistido en `SettingsRepository` (`hideCommentAuditDetails: bool`).  
- Copy: `Ocultar detalles` / `Mostrar detalles`. Semantics: «Ocultar historial de días».

### 7.5 Nueva tarea (P0)
- Composer deshabilitado con hint: `Guarda la tarea para comentar`.  
- Alternativa rechazada: crear la tarea en silencio al primer Enviar (demasiados side-effects con ¿Cuándo? / Hoy).

### 7.6 Backup (P0)
- Export/import incluye comentarios + bytes de imagen de comentario (mismo esquema base64 que adjuntos).  
- Wipe de datos borra box de comentarios.

### 7.7 Sync (P1 acoplado, no bloquea UI local)
- Entidad `comment` (metadata + texto + ids de imagen).  
- Blobs: fuera hasta exista sync de `attachments`.  
- Backend hoy solo admite `note` | `tag` | `dayEntry` — hay que ampliar el DTO.

### 7.8 Notas (P1)
- Misma sección si el uso lo pide; v1 no.

---

## 8. Requisitos no funcionales

| Área | Requisito |
|---|---|
| Performance | 100 comentarios + historial de una tarea scrollean sin jank; thumbs cacheadas |
| Teclado | En compact, el composer visible sobre el IME |
| Accesibilidad | Hit ≥ 44; labels «Añadir imagen al comentario», «Enviar comentario», «Ocultar historial de días» |
| i18n | Copy ES en §12; no hardcoded en widgets nuevos más allá de la pauta actual |
| Privacidad | Local; imágenes no salen del dispositivo salvo backup explícito / futuro sync de blobs |
| Offline | CRUD completo sin red |

---

## 9. Flujos

### F1 — Comentario de texto
Abrir tarea existente → scroll a Comentarios → escribir → Enviar → aparece arriba del feed. Guardar/Cerrar el editor no pide confirmar el comentario (ya está guardado).

### F2 — Comentario con imagen
Clip → galería/cámara → thumb en composer → (texto opcional) → Enviar → thumb en la card del comentario → tap abre visor.

### F3 — Ocultar auditoría
Con historial visible, tap **Ocultar detalles** → solo comentarios. El setting se mantiene al abrir otra tarea.

### F4 — Tarea nueva
Editor «Nueva tarea» → composer disabled → Guardar → reabrir o, si el editor permanece embebido en desktop, habilitar composer tras `onSaved`.

### F5 — Exportar
Ajustes → Exportar → el JSON/zip incluye `comments` + blobs.

---

## 10. Alcance por fases

### v1 (este PRD)
- Modelo `NoteComment` + imágenes scoped  
- Sección en `NoteEditorScreen` (móvil + embedded)  
- Toggle hide-details sobre `DayEntry`  
- Composer texto ± imagen  
- Editar / eliminar comentario  
- Backup  
- Tests de modelo, filtro del feed, cascade delete

### v1.1
- Chip 💬 en card  
- Comentarios en notas  
- Sticky composer más pulido en desktop  
- Sync entidad `comment` (sin blobs)

### v2
- Split 60/40 si el editor gana ancho  
- Sync de blobs  
- (Solo si hay multi-usuario de verdad) autor, menciones, «Seguir»

---

## 11. Decisiones de producto

| # | Pregunta | Decisión v1 |
|---|---|---|
| 1 | ¿Chat de equipo o diario personal? | **Diario personal** |
| 2 | ¿Notas y tareas? | **Solo tareas** |
| 3 | ¿Qué oculta «Ocultar detalles»? | **Solo `DayEntry`**, no un changelog nuevo |
| 4 | ¿Rich text? | **No** — texto plano |
| 5 | ¿Imágenes del comentario en Adjuntos / portada? | **No** |
| 6 | ¿Layout Trello en desktop? | **No** en v1 (panel 340 dp) |
| 7 | ¿«Seguir»? | **No** |
| 8 | ¿Persistencia vs Guardar del editor? | **Inmediata al Enviar** |
| 9 | ¿Comentar tarea no guardada? | **No** — hint para guardar primero |
| 10 | ¿Un comentario mueve Recientes (`updatedAt`)? | **No** |
| 11 | ¿Default del toggle? | **Mostrar detalles** |
| 12 | ¿Avatares? | **No** — icono de fila, no iniciales inventadas |

### Abiertas (no bloquean el diseño; sí el kickoff de código)

Ver también la lista al final de este documento. Las más cargadas:

| # | Pregunta | Inclinación |
|---|---|---|
| A | ¿El comentario cuenta como actividad del heatmap / racha? | **No** (la racha sigue siendo completar tareas) |
| B | ¿Editar un comentario deja huella «editado»? | **Sí**, timestamp `editedAt` discreto |
| C | ¿Límite de longitud del texto? | **4000** caracteres |
| D | ¿Orden del feed: nuevo arriba o abajo tipo chat? | **Nuevo arriba** (Trello; el composer está arriba) |

---

## 12. Copy (ES)

| Contexto | Texto |
|---|---|
| Título sección | `Comentarios` |
| Toggle on | `Ocultar detalles` |
| Toggle off | `Mostrar detalles` |
| Semantics toggle | `Ocultar historial de días` / `Mostrar historial de días` |
| Hint composer | `Escribe un comentario…` |
| Enviar | `Enviar` |
| Clip | `Añadir imagen` |
| Disabled nueva | `Guarda la tarea para comentar` |
| Empty mixto | `Todavía no hay comentarios. El historial de días aparecerá cuando planifiques o completes esta tarea.` |
| Empty solo comentarios | `No hay comentarios.` |
| Empty hide + sin comentarios | `No hay comentarios. Muestra los detalles para ver el historial.` |
| Editar / Eliminar | `Editar` / `Eliminar` |
| Confirm delete | `¿Eliminar este comentario?` |
| Editado | `editado` |
| Límite | `Máximo 4 imágenes por comentario` |

No usar «Actividad» en el título de v1: en WODO «actividad» ya es el heatmap del perfil. El toggle habla de **detalles** = historial de días.

---

## 13. Dependencias

- `NoteEditorScreen` / `TaskDayHistorySection` (se fusionan en un feed)  
- `AttachmentsRepository` + visor + action sheet  
- `DayEntriesRepository`  
- `SettingsRepository`  
- Backup (`data_backup.dart`)  
- Sync: solo metadata en v1.1; backend DTO  
- `relative_time.dart`, `AppColors`, `ThemeTokens`

---

## 14. Consultas para validar antes de implementar

Estas son las preguntas que cambian alcance. El TRD asume las inclinaciones de §11 si no hay respuesta.

1. **¿El comentario es un diario personal (recomendado) o estamos preparando colaboración / varios usuarios en la misma tarea?** Si es lo segundo, avatares, autor y sync de blobs suben a P0 y el veredicto de este PRD no aplica.  
2. **¿Confirmamos que «Ocultar detalles» oculta solo el historial de días**, y no un registro de «cambió el título / las tags / el vencimiento»?  
3. **¿Tareas solamente, o también notas en v1?**  
4. **¿Un comentario debe empujar la card a Recientes** (`updatedAt`)? El PRD dice que no, para no ensuciar el inbox.  
5. **¿Las fotos de un comentario pueden marcarse como portada** o deben quedar estrictamente fuera de Adjuntos?  
6. **Desktop: ¿aceptamos el feed al final del panel de 340 dp**, o preferís invertir antes en un editor más ancho (split)?  
7. **¿Hay que sincronizar comentarios entre dispositivos en v1**, sabiendo que las imágenes aún no viajan por sync?

---

## 15. Anexo — Propuestas visuales

Mocks de dirección (no píxel-perfect del Flutter actual). El chrome alrededor (heatmap, tabs, IDs tipo `TAREA-1234`) es atmósfera; **la sección Comentarios es lo que se propone**.

Archivos en `docs/comentarios/`.

### 15.1 Móvil — feed mixto (v1)

Composer arriba, comentario con imagen, debajo las filas de historial de días. El botón **Ocultar detalles** no es un CTA verde.

![Móvil: comentarios + historial](docs/comentarios/mobile_feed.webp)

### 15.2 Móvil — detalles ocultos + comentario con imagen (v1)

Toggle pasa a **Mostrar detalles**. El historial desaparece. Composer con thumb y **Enviar** activo.

![Móvil: solo comentarios](docs/comentarios/mobile_hide_details.webp)

### 15.3 Desktop v1 — mismo feed en el panel de 340 dp

El editor **no** gana una columna extra. Comentarios al final del scroll del panel derecho.

![Desktop: panel 340 dp](docs/comentarios/desktop_panel_340.webp)

### 15.4 Desktop P1 — split solo si el editor es más ancho

Layout de referencia tipo Trello **adaptado** (definición a la izquierda, diario a la derecha). **Fuera de v1.** Ignorar badge `DOING` / `TAREA-1234` del mock: WODO no tiene columnas Kanban.

![Desktop P1: editor ancho](docs/comentarios/desktop_split_p1.webp)

---

**Owner:** Product / Design / Engineering  
**Próximo paso:** Cerrar las consultas de §14 → implementar según `TRD-comentarios.md` (storage → feed + toggle → composer + imágenes → backup).
