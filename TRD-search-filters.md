# TRD — Búsqueda y filtros (Home)

**Producto:** Todos App  
**Referencia PRD:** §6.5 (P0)  
**Fecha:** 16 Jul 2026  
**Estado:** Implementado

---

## 1. Objetivo

Permitir encontrar notas/tareas existentes desde Home mediante **búsqueda por texto** y **filtros por tipo/estado**, sin salir de la pantalla principal.

---

## 2. Alcance

### Incluido
- Icono de búsqueda en el header que expande un campo de texto
- Búsqueda en vivo (case-insensitive) sobre `title` y `body`
- Chips horizontales: **Todas · Fijadas · Notas · Tareas**
- Combinación búsqueda + filtro activo
- Lista adaptativa: secciones Fijadas/Recientes solo en modo default; lista plana en búsqueda o filtro activo
- Empty states específicos por contexto
- Tests unitarios de la lógica de query

### Fuera de alcance
- Filtro por tag o rango de fechas (P1)
- Búsqueda fonética / fuzzy
- Historial de búsquedas
- Instrumentación analytics (`search_used`) — fase posterior

---

## 3. Modelo y lógica

### `NotesFilter` (enum)

| Valor | Criterio |
|---|---|
| `all` | Sin filtro de tipo/estado |
| `pinned` | `item.pinned == true` |
| `notes` | `item.type == NoteType.note` |
| `tasks` | `item.type == NoteType.task` |

### `NotesQuery.apply`

Entrada: `List<NoteItem> items`, `NotesFilter filter`, `String searchQuery`  
Salida: lista filtrada, mantiene orden `updatedAt desc` (heredado de `getAll()`).

Pasos:
1. Aplicar filtro de chip (si `filter != all`)
2. Si `searchQuery.trim()` no está vacío → filtrar donde título o cuerpo contenga el texto (lowercase)

### Layout de lista

`useSectionedLayout` = `filter == all && searchQuery.trim().isEmpty`

- **Seccionado:** Fijadas arriba + Recientes abajo (comportamiento actual)
- **Plano:** una sola lista con encabezado contextual (“Resultados”, “Tareas”, etc.)

---

## 4. UI

### Header
```
[Avatar] [Fecha]                    [🔍] [⚙]
```
- Tap 🔍 → expande barra de búsqueda debajo del header
- Barra: `TextField` hint “Buscar notas…” + botón limpiar/cerrar
- Al cerrar búsqueda: limpia query y colapsa

### Debajo de captura rápida
```
[ Todas ] [ Fijadas ] [ Notas ] [ Tareas ]   ← horizontal scroll
```
- Chip seleccionado: fondo `AppColors.primary00`, borde `AppColors.primary`
- Un solo filtro activo a la vez

### Empty states

| Condición | Copy |
|---|---|
| Sin notas en app | `Tu primera nota está a un tap` |
| Búsqueda sin match | `No se encontraron notas` |
| Filtro Fijadas vacío | `No hay notas fijadas` |
| Filtro Notas vacío | `No hay notas` |
| Filtro Tareas vacío | `No hay tareas` |

---

## 5. Archivos

| Archivo | Rol |
|---|---|
| `lib/features/notes/domain/notes_filter.dart` | Enum + labels |
| `lib/features/notes/domain/notes_query.dart` | Lógica pura de filtrado |
| `lib/features/notes/presentation/widgets/filter_chips_bar.dart` | UI chips |
| `lib/features/home/presentation/home_screen.dart` | Integración search + layout |
| `test/features/notes/notes_query_test.dart` | Tests de lógica |

---

## 6. Criterios de aceptación

- [x] Icono búsqueda expande/colapsa campo
- [x] Resultados actualizan en vivo al escribir
- [x] Cada chip filtra la lista correctamente
- [x] Búsqueda + chip se combinan (AND)
- [x] Tap en resultado abre editor existente
- [x] Modo default conserva secciones Fijadas/Recientes
- [x] Tests pasan (`flutter test`)

---

## 7. Dependencias

- `NotesRepository.getAll()` — sin cambios en persistencia
- `NoteItem.title`, `NoteItem.body`, `NoteItem.type`, `NoteItem.pinned`
