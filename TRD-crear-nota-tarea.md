# TRD — Flujo de creación: nota (sheet) vs tarea (editor)

**Producto:** Todos App  
**Referencia PRD:** `PRD.md` §6.6 (FAB creativo), §6.8 (editor); `PRD-control-tareas.md` §6.4–6.5 (editor de tarea / ¿Cuándo?)  
**Fecha:** 18 Jul 2026  
**Estado:** Implementado (v1)

---

## 1. Objetivo

Actualizar el flujo del FAB `+` para que **crear una nota** y **crear una tarea** dejen de aterrizar en la misma pantalla indistinguible.

Regla de diseño: **la superficie coincide con la complejidad**.

| Intento | Superficie | Motivo |
|---|---|---|
| Nueva nota | Bottom sheet (modal) ligero | Captura libre, pocos campos |
| Nueva tarea | Pantalla completa (`NoteEditorScreen`) | Necesita espacio para tags + «¿Cuándo?» |
| Editar existente (nota o tarea) | Pantalla completa (sin cambio) | Edición siempre puede crecer |

La captura rápida del Home (`QuickCaptureField`) **no se toca**: sigue siendo el atajo de un toque para notas de una línea.

---

## 2. Problema actual

Hoy el flujo es:

```
FAB +  →  bottom sheet (Nota | Tarea)  →  NoteEditorScreen (casi idéntico)
```

Efectos:

1. La elección Nota/Tarea **se siente vacía**: el destino visual es el mismo.
2. Para notas, hay **doble fricción** frente a quick capture (menú + pantalla completa).
3. El menú intermedio añade un tap que el contexto del chip a menudo ya resuelve.

---

## 3. Alcance

### Incluido (este slice)

- FAB **contextual** según chip de filtro activo
- Long-press en FAB para el tipo alternativo
- Bottom sheet de **nueva nota** (crear)
- Editor full screen solo para **nueva tarea** (y para editar cualquier item, como hoy)
- Menú Nota/Tarea del FAB: **retirado** en v1 de este TRD (ver §4)
- Criterios de aceptación y orden de implementación

### Fuera de alcance

- Foto / Audio en el FAB (P1 del PRD principal)
- Autoguardado / borradores en el sheet de nota
- Rediseñar el editor de edición (solo se reutiliza)
- Cambiar quick capture a tareas
- Convertir nota↔tarea desde el sheet de creación (solo desde editor full)

---

## 4. Decisiones

| # | Tema | Decisión | Motivo |
|---|---|---|---|
| 1 | ¿Misma pantalla para crear nota y tarea? | **No** | Peso de UI distinto; evita elección sin efecto |
| 2 | ¿Menú Nota/Tarea al tap del `+`? | **No** en v1 | Con 2 tipos, el contexto del chip basta; menos taps |
| 3 | ¿Cómo elijo el tipo? | **FAB contextual** + **long-press** al otro | Cumple espíritu del PRD (§6.6 long-press → Nota) sin speed-dial aún |
| 4 | ¿Sheet también para editar notas? | **No** | Editar siempre full screen; sheet solo *crear* nota |
| 5 | ¿Toggle «Es una tarea» en el sheet? | **Sí** (solo tipo; sin «¿Cuándo?») | Escape hatch al capturar; fecha se añade al abrir el editor |
| 6 | ¿Toggle en editor de tarea nueva? | **Sí, se mantiene** | Escape hatch: convertir a nota al crear/editar |
| 7 | Chip Archivadas + `+` | Crear **nota** (sheet), igual que Todas/Notas | Archivo no implica intención de tarea |
| 8 | Con búsqueda abierta + `+` | Igual que el chip activo; no cambia el destino | Búsqueda no redefine el tipo |

---

## 5. Flujo objetivo

### 5.1 Mapa FAB → destino

| Chip activo | Tap en `+` | Long-press en `+` |
|---|---|---|
| Todas | Sheet **Nueva nota** | Editor **Nueva tarea** |
| Fijadas | Sheet **Nueva nota** | Editor **Nueva tarea** |
| Notas | Sheet **Nueva nota** | Editor **Nueva tarea** |
| Tareas | Editor **Nueva tarea** | Sheet **Nueva nota** |
| Archivadas | Sheet **Nueva nota** | Editor **Nueva tarea** |

```
                    ┌─────────────────────┐
                    │   FAB + (tap)       │
                    └──────────┬──────────┘
                               │
              ┌────────────────┴────────────────┐
              │ chip == Tareas?                 │
              ▼                                 ▼
     NoteEditorScreen                  NoteComposeSheet
     initialType: task                 (nueva nota)
              │                                 │
              │ long-press                      │ long-press
              ▼                                 ▼
     NoteComposeSheet                  NoteEditorScreen
     (nueva nota)                      initialType: task
```

### 5.2 Abrir desde lista (sin cambio)

- Tap en card (nota o tarea) → `NoteEditorScreen` en modo edición, como hoy.
- Quick capture → crea nota inline, sin sheet ni editor.

### 5.3 Sheet «Nueva nota»

Contenido mínimo:

1. Handle / título dinámico «Nueva nota» / «Nueva tarea»
2. Campo título obligatorio — hint «Escribe un título»
3. Campo cuerpo opcional — hint «Añade detalles (opcional)»
4. Switch **Es una tarea** (solo cambia `type`; sin «¿Cuándo?»)
5. Acciones: **Cancelar** (cierra sin guardar) · **Guardar**
6. Tags: **fuera de v1** del sheet (se editan al abrir el item)

Comportamiento:

- Guardar sin título → warning (misma regla que el editor: «Escribe un título»); el cuerpo es opcional
- Guardar OK → `NotesRepository.add` con `type: note` o `task`, cierra sheet, snackbar «Nota guardada» / «Tarea guardada»
- Tarea desde sheet nace **sin fecha** (fecha en el editor full)
- Al cerrar con gesto/back sin guardar → descarta (sin borrador en este slice)
- `isScrollControlled: true` + padding de teclado para que el sheet no quede tapado

### 5.4 Editor «Nueva tarea»

- Reutilizar `NoteEditorScreen(initialType: NoteType.task)`.
- Muestra «¿Cuándo?», tags, switch «Es una tarea».
- Crear tarea **sigue sin exigir fecha** (PRD-control-tareas).

### 5.5 Long-press

- Tooltip / hint accesible: «Crear [el otro tipo]».
- Feedback: al soltar, abre el destino alternativo (sin menú intermedio).
- Si el long-press no es descubrible en QA, añadir tooltip una sola vez (onboarding) — **P1**, no bloquea v1.

---

## 6. Cambios técnicos previstos

### 6.1 Archivos

| Archivo | Cambio |
|---|---|
| `home_screen.dart` | Reemplazar `_showCreateMenu` por lógica contextual + long-press; abrir sheet o editor |
| `widgets/note_compose_sheet.dart` (**nuevo**) | UI + guardado de nueva nota |
| `note_editor_screen.dart` | Sin cambio obligatorio en v1; sigue siendo destino de tareas y de edición |
| `quick_capture_field.dart` | Sin cambio |

### 6.2 API sugerida en Home

```dart
bool get _fabCreatesTask => _activeFilter == NotesFilter.tasks;

void _onFabPressed() {
  if (_fabCreatesTask) {
    _openEditor(context, initialType: NoteType.task);
  } else {
    _openNoteComposeSheet(context);
  }
}

void _onFabLongPress() {
  if (_fabCreatesTask) {
    _openNoteComposeSheet(context);
  } else {
    _openEditor(context, initialType: NoteType.task);
  }
}
```

El sheet se presenta con `showModalBottomSheet` (o wrapper del design system si existe).

### 6.3 Widget `NoteComposeSheet`

Responsabilidades:

- Controllers locales de título/cuerpo
- Validación vacía
- `add` al repository
- Pop del sheet al guardar
- No conoce filtros ni navegación de edición

### 6.4 Accesibilidad

- FAB: `tooltip` dinámico — «Nueva tarea» o «Nueva nota» según contexto
- Long-press: `semanticLabel` / hint «Mantén pulsado para crear [alternativa]»
- Hit target del FAB sin cambio

---

## 7. Criterios de aceptación

- [x] Con chip **Tareas**, tap en `+` abre editor «Nueva tarea» (full), sin menú Nota/Tarea
- [x] Con chip **Notas** (o Todas / Fijadas / Archivadas), tap en `+` abre sheet «Nueva nota»
- [x] Long-press en `+` abre el tipo contrario al del tap
- [x] Guardar nota desde sheet exige título; el cuerpo puede ir vacío
- [x] Sheet sin título + Guardar muestra warning y no cierra
- [x] Cancelar / dismiss descarta sin crear item
- [x] Nueva tarea puede guardarse sin fecha
- [x] Tap en una nota existente sigue abriendo editor full (no el sheet)
- [x] Quick capture sigue creando notas sin pasar por sheet ni editor
- [x] Ya no aparece el bottom sheet de elección «Nueva nota / Nueva tarea» al tap del FAB
- [x] Sheet permite marcar «Es una tarea» (sin «¿Cuándo?»)

---

## 8. Casos de prueba manuales

| # | Setup | Acción | Esperado |
|---|---|---|---|
| 1 | Chip Todas | Tap `+` | Sheet nueva nota |
| 2 | Chip Tareas | Tap `+` | Editor nueva tarea |
| 3 | Chip Notas | Long-press `+` | Editor nueva tarea |
| 4 | Chip Tareas | Long-press `+` | Sheet nueva nota |
| 5 | Sheet abierto | Guardar con título «hola» | Nota en lista; sheet cerrado |
| 6 | Sheet abierto | Guardar sin título | Warning; sheet sigue abierto |
| 7 | Lista | Tap card nota | Editor edición (full) |
| 8 | Home | Quick capture | Nota creada; no navega |

---

## 9. Orden de implementación

1. Extraer/crear `NoteComposeSheet` + guardar nota  
2. Cablear FAB contextual (tap) en `HomeScreen`  
3. Añadir long-press al FAB (tipo alternativo)  
4. Eliminar `_showCreateMenu` (menú Nota/Tarea)  
5. Tooltips / semantics del FAB  
6. QA manual según §8 + `flutter test` si hay tests de Home/navigation

---

## 10. Relación con el PRD

| PRD | Cómo lo cumple este TRD |
|---|---|
| §6.6 FAB Nota / Tarea | Ambos siguen existiendo; el **contexto** elige el default, long-press el secundario |
| §6.6 Long-press → Nota | En chip Tareas, long-press → nota; en el resto, tap → nota (long-press → tarea) |
| §6.8 «Pantalla full o bottom sheet» | Se usa **ambos**: sheet al crear nota, full al crear/editar tarea y al editar nota |
| Control de tareas: crear sin fecha | Intacta en `NoteEditorScreen` |

**Enmienda implícita al PRD §6.6:** el speed-dial / menú al tap deja de ser el patrón v1; se sustituye por FAB contextual + long-press. Foto/Audio, cuando lleguen (P1), pueden reintroducir un menú o speed-dial sin deshacer este modelo (tap = default contextual, menú solo si hay ≥3 destinos).

---

## 11. Riesgos

| Riesgo | Mitigación |
|---|---|
| Usuario en «Todas» no descubre cómo crear tarea | Long-press + tooltip; chip Tareas es el camino obvio |
| Sheet se siente pobre sin tags | Tags se añaden al abrir la nota después; v1.1 puede meter tags en sheet |
| Confusión sheet vs quick capture | Copy distinto: quick = «Escribe una nota…»; sheet = título + cuerpo para notas más largas |

---

**Próximo paso:** implementar en el orden §9, empezando por `NoteComposeSheet` y el cableado del FAB en `HomeScreen`.
