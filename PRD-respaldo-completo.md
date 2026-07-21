# PRD — Respaldo completo: metadata, etiquetas y diario

**Producto:** WODO (todos_app)  
**Versión:** 1.0  
**Fecha:** 21 Jul 2026  
**Estado:** Draft — listo para TRD  
**Plataforma:** Flutter (iOS / Android / Web)  
**Relación:** Extiende `PRD-ajustes.md` §6.5–6.6 (exportar/importar). Complementa `PRD-control-tareas.md` (fechas de tarea), `TRD-tags.md` (catálogo de etiquetas) y `PRD-day-review.md` (log `DayEntry`).

---

## 1. Resumen

El respaldo actual (backup **v1**) exporta solo el array `notes` serializado con `NoteItem.toMap()`. Eso **no es suficiente** para reproducir la experiencia visual y funcional del usuario tras importar: se pierden colores de etiquetas, el catálogo de tags, el diario por día (`DayEntry`) y, en la práctica, parte de la metadata de tareas que la UI deriva de varias fuentes.

Este PRD define un **backup v2** que exporta e importa de forma atómica todo el estado de contenido local necesario para un roundtrip fiel (mismas notas/tareas, mismas fechas, mismos colores de pills, mismo historial de días).

**Fuera de alcance v1 de este PRD:** preferencias de Ajustes (tema, fondo de lista), sincronización en la nube, merge inteligente entre dos backups, cifrado del archivo.

---

## 2. Problema

### 2.1 Síntomas reportados

Tras exportar e importar en otro dispositivo (o tras reinstalar):

| Lo que el usuario ve | Lo que esperaba |
|---|---|
| Etiqueta `SYVEX` sin color personalizado (vuelve al color por defecto) | Mismo pill morado / opacidad que antes |
| Tareas que estaban en **Hoy** aparecen sin contexto de día o con metadata distinta | Misma agrupación Hoy / Próximas / Backlog |
| Chips de fecha (`Vence hoy`, icono ☀, `hace X min`) inconsistentes | Misma metadata visible en cards |
| Replay de días pasados incompleto o vacío | Historial de migraciones / completados por día |

### 2.2 Causa raíz (análisis técnico)

El backup v1 (`data_backup.dart`, `version: 1`) solo persiste:

```json
{
  "version": 1,
  "exportedAt": "…",
  "notes": [ /* NoteItem.toMap() */ ]
}
```

Pero el estado visible de la app vive en **cuatro cajas Hive** independientes:

| Box Hive | Repositorio | ¿Incluido en v1? | Impacto al omitirlo |
|---|---|---|---|
| `notes` | `NotesRepository` | **Sí** | — |
| `tags` | `TagsRepository` | **No** | Colores/opacidades/catálogo de etiquetas se regeneran con defaults |
| `day_entries` | `DayEntriesRepository` | **No** | Replay histórico, outcomes `>` `<`, progreso por día incompletos |
| `settings` | `SettingsRepository` | **No** (intencional en PRD-ajustes) | Tema/fondo no se restauran — aceptable |

Además, aunque `NoteItem.toMap()` **sí incluye** campos de fecha (`dueAt`, `dueHasTime`, `todayAt`, `completedAt`, `archivedAt`, `reminderMinutesBefore`) y `tags` (nombres), al importar:

1. Solo se llama `NotesRepository.replaceAllFromMaps()` — no se tocan `tags` ni `day_entries`.
2. `TagsRepository.ensureTags()` vuelve a ejecutarse con los nombres de las notas y **asigna colores por defecto** (`TagColors.defaultIdForTag`), pisando la personalización previa.
3. Los recordatorios locales (`TaskRemindersService`) no se reprograman tras import.
4. Archivos v1 antiguos sin keys de fecha siguen siendo válidos (retrocompat), pero el usuario puede confundir exportaciones parciales con pérdida de datos.

### 2.3 Jobs to be done

| Job | Resultado esperado |
|---|---|
| Cambiar de teléfono sin perder el trabajo | Importar backup → misma lista, mismos colores, mismas fechas |
| Recuperar tras borrado accidental | Restaurar archivo → estado idéntico al momento de exportar |
| Confiar en el respaldo | Roundtrip export → import en QA reproduce 100 % de la metadata de contenido |

---

## 3. Objetivos

### Producto
- Backup **v2** que capture todo el estado de contenido local (notas, tareas, tags, diario).
- Importación **atómica**: o restaura todo correctamente o falla sin dejar datos a medias.
- Retrocompatibilidad con backups **v1** (solo notas).

### UX
- El usuario no necesita saber qué es un `DayEntry` ni un `colorId`: solo ve que «todo volvió igual».
- Mensajes claros: `Datos importados · N notas, M etiquetas` (opcional v1.1).
- Confirmación previa a importar se mantiene (`PRD-ajustes.md` §6.6).

### No-objetivos (este slice)
- Exportar/importar tema, fondo de lista ni preferencias de heatmap.
- Merge de dos backups (sigue siendo **reemplazo total**).
- Backup automático programado.
- Cifrado con contraseña del archivo.

---

## 4. Propuesta de solución

### 4.1 Formato backup v2

Archivo único JSON, extensión `.json`, nombre `wodo_backup_<timestamp>.json`:

```json
{
  "version": 2,
  "exportedAt": "2026-07-21T15:48:00.000",
  "app": "wodo",
  "notes": [ /* NoteItem.toMap() × N */ ],
  "tags": {
    "names": ["SYVEX", "Trabajo", "Personal"],
    "colors": { "syvex": "violet", "trabajo": "blue" },
    "opacities": { "syvex": 1.0, "trabajo": 0.85 }
  },
  "dayEntries": [ /* DayEntry.toMap() × M */ ]
}
```

**Reglas:**
- `version` obligatorio; `2` para este PRD.
- `notes`: activas + archivadas (igual que v1).
- `tags`: snapshot completo de `TagsRepository` (nombres + mapas de color/opacidad). Keys de color en minúsculas (misma convención que Hive).
- `dayEntries`: snapshot de `DayEntriesRepository.getAll()`. Puede ser `[]` si el usuario nunca usó replay/migraciones.
- Campos ausentes en import → defaults seguros (ver §6.3).

### 4.2 Diagrama de flujo

```
Exportar (Ajustes)
    │
    ├─ NotesRepository.exportAllMaps()
    ├─ TagsRepository.exportSnapshot()      ← nuevo
    ├─ DayEntriesRepository.exportAllMaps() ← nuevo
    │
    └─ JSON v2 → compartir / guardar .json

Importar (Ajustes)
    │
    ├─ Validar JSON + versión
    ├─ Confirmación usuario (reemplazo total)
    │
    ├─ Transacción lógica:
    │     1. replaceAllFromMaps(notes)
    │     2. replaceSnapshot(tags)          ← nuevo
    │     3. replaceAllFromMaps(dayEntries) ← nuevo
    │     4. TaskRemindersService.syncAll() ← nuevo
    │
    └─ Snackbar éxito / error sin tocar datos si falla paso 1
```

### 4.3 Qué metadata queda cubierta

| Metadata en UI | Fuente de verdad | Incluida en v2 |
|---|---|---|
| Título, cuerpo, tipo nota/tarea | `NoteItem` | Sí |
| Fijada, completada | `NoteItem` | Sí |
| Etiquetas (nombres en card) | `NoteItem.tags` | Sí |
| Color y opacidad del pill | `TagsRepository` | **Sí (nuevo)** |
| Vence hoy / fecha límite | `NoteItem.dueAt`, `dueHasTime` | Sí (ya en nota) |
| Compromiso Hoy (☀) | `NoteItem.todayAt` | Sí (ya en nota) |
| Completada el… | `NoteItem.completedAt` | Sí |
| Archivada | `NoteItem.archivedAt` | Sí |
| Recordatorio | `NoteItem.reminderMinutesBefore` | Sí + reprogramar al import |
| Replay `>` `<` backlog | `DayEntry` | **Sí (nuevo)** |
| Streak / heatmap por día | Derivado de notas + entries | Indirecto (suficiente con v2) |
| Tema / fondo lista | `SettingsRepository` | No (fuera de alcance) |

---

## 5. Requisitos funcionales

### 5.1 Exportar (P0)

- Generar backup **v2** con las cuatro secciones del §4.1.
- Mantener nombre `wodo_backup_<timestamp>.json` y MIME `application/json`.
- Incluir notas archivadas.
- Si no hay `dayEntries`, exportar `"dayEntries": []`.
- Si no hay tags personalizados, exportar catálogo mínimo (defaults + tags usados en notas).
- Snackbar: `Datos exportados` (sin cambio de copy).

### 5.2 Importar (P0)

- Aceptar **v1** y **v2**:
  - **v1** (`version` ausente o `1`, solo `notes`): comportamiento actual + `ensureTags` con defaults (retrocompat).
  - **v2**: restauración completa según §4.2.
- Validar antes de escribir:
  - Cada nota: `id`, `type` obligatorios; roundtrip `NoteItem.fromMap`.
  - Cada `dayEntry`: `id`, `noteId`, `day`, `via`, `outcome`.
  - Colores: `colorId` debe existir en `TagColors.swatches` o caer a default.
- Confirmación explícita antes de aplicar (sin cambio).
- Si la validación falla: **no modificar** ningún box; mensaje `El archivo no es válido o está corrupto.`
- Tras éxito v2:
  - Reprogramar recordatorios (`syncAllReminders`).
  - UI refleja colores y agrupación sin reiniciar app.

### 5.3 Roundtrip (P0)

- Export v2 → import en dispositivo limpio → **assert** en tests:
  - Mismo conteo de notas/tareas/archivadas.
  - Igualdad de todos los campos de `NoteItem` (incl. fechas ISO).
  - Igualdad de `tags.colors` / `tags.opacities` para cada etiqueta usada.
  - Igualdad de `dayEntries` por `id`.
  - Cards muestran mismo `TagPill` color (widget/golden test opcional).

### 5.4 Borrar todos los datos (P0 — ajuste)

- `resetAll()` debe limpiar también `tags` (restaurar defaults) y `day_entries`, no solo `notes`.
- Documentar en TRD; hoy `NotesRepository.resetAll()` solo vacía notas.

### 5.5 Retrocompatibilidad (P0)

| Archivo | Comportamiento import |
|---|---|
| v1 solo `notes` | Importar notas; tags con defaults; `dayEntries` vacío |
| Lista JSON plana (legacy) | Igual que v1 |
| v2 completo | Restauración fiel |
| v2 con `dayEntries` omitido | Tratar como `[]` |
| v2 con `tags` omitido | Derivar nombres de notas + defaults (degradación graceful) |

---

## 6. Requisitos no funcionales

| Área | Requisito |
|---|---|
| Performance | 500 notas + 2000 day entries + 50 tags: export/import < 2 s en mid-range; spinner si > 300 ms |
| Atomicidad | Fallo en paso 2 o 3 no deja paso 1 aplicado sin rollback (transacción o restore previo) |
| Tamaño | JSON sin comprimir; estimar ~2–5 KB/nota; aceptable hasta ~5 MB en v1 |
| i18n | Copy de error/éxito en ES |
| Tests | Unit: parse v1/v2, roundtrip, tags colors, day entries; integración: import inválido no muta |
| Seguridad | Archivo en claro; usuario responsable de dónde lo guarda (sin cambio) |

---

## 7. Cambios técnicos previstos (orientación TRD)

| Archivo / módulo | Cambio |
|---|---|
| `data_backup.dart` | `encodeBackupV2`, `parseBackup`, import atómico, soporte v1 |
| `tags_repository.dart` | `exportSnapshot()` / `replaceSnapshot()` |
| `day_entries_repository.dart` | `exportAllMaps()` / `replaceAllFromMaps()` |
| `notes_repository.dart` | `resetAll()` ampliado o orquestador `DataRepository.resetAll()` |
| `settings_screen.dart` | Sin cambio de UI; posible loading en import |
| Tests | `settings_repository_test`, nuevo `data_backup_v2_test.dart` |

---

## 8. Alcance por fases

### v1 — Backup fiel (este PRD)

- [ ] Esquema JSON v2
- [ ] Export/import tags (colores + opacidades)
- [ ] Export/import `dayEntries`
- [ ] Import atómico con rollback
- [ ] Retrocompat v1
- [ ] `resetAll` limpia las tres cajas de contenido
- [ ] Re-sync recordatorios post-import
- [ ] Tests de roundtrip

### v1.1 — Pulido

- [ ] Snackbar detallado: `Importados: 42 notas, 8 etiquetas, 120 entradas de diario`
- [ ] Export opcional de settings (tema/fondo) como sección separada `preferences`
- [ ] Backup automático local antes de importar (rollback de un paso)

### v2 — Fuera

- Merge selectivo, sync en la nube, cifrado, export CSV.

---

## 9. Criterios de done

- [ ] Exportar desde app con tareas fechadas, etiquetas coloreadas y entradas de diario genera v2 válido
- [ ] Importar v2 en instalación vacía reproduce colores de pills idénticos (ej. SYVEX morado)
- [ ] Tareas conservan `dueAt`, `todayAt`, `completedAt`, `reminderMinutesBefore` tras roundtrip
- [ ] Vista **Tareas** agrupada (Hoy / Próximas / Backlog) coincide pre/post import para el mismo `now` mockeado en tests
- [ ] Replay de un día pasado muestra mismas filas `DayEntry` tras roundtrip
- [ ] Importar backup v1 antiguo sigue funcionando (solo notas)
- [ ] Import inválido no borra datos existentes
- [ ] `flutter test` verde con nuevos casos de roundtrip v2
- [ ] QA manual iOS: export → guardar en Archivos → import → verificar SYVEX + Hoy 1/5

---

## 10. Decisiones de producto

| # | Pregunta | Decisión |
|---|---|---|
| 1 | ¿Incluir ajustes (tema/fondo)? | **No** en v1 de este PRD; solo contenido |
| 2 | ¿Merge o reemplazo? | **Reemplazo total** (igual que PRD-ajustes) |
| 3 | ¿Versión del formato? | **v2** con campo `version`; v1 sigue soportado |
| 4 | ¿Exportar tags aunque solo estén en catálogo? | **Sí** — exportar snapshot completo de `TagsRepository` |
| 5 | ¿Qué pasa si `todayAt` es de otro día al importar? | **Se respeta el valor guardado**; la UI aplica reglas de expiración de `PRD-control-tareas.md` §6.1 (no reescribir en import) |
| 6 | ¿Nombre del archivo? | `wodo_backup_<timestamp>.json` (ya homologado) |

### Pendientes (no bloquean v1)

| # | Pregunta | Cuándo |
|---|---|---|
| A | ¿Incluir `settings` en v2.1 como sección opcional? | Tras v1 estable |
| B | ¿Comprimir `.json.gz` para backups grandes? | Si usuarios > 1000 notas |

---

## 11. Anexo — Ejemplo mínimo v2

```json
{
  "version": 2,
  "exportedAt": "2026-07-21T15:48:00.000",
  "app": "wodo",
  "notes": [
    {
      "id": "a1",
      "type": "task",
      "title": "Hacer onboarding SYVEX",
      "body": "",
      "pinned": false,
      "completed": false,
      "createdAt": "2026-07-21T13:45:00.000",
      "updatedAt": "2026-07-21T13:45:00.000",
      "tags": ["SYVEX"],
      "dueAt": null,
      "dueHasTime": false,
      "todayAt": "2026-07-21T13:45:00.000",
      "completedAt": null,
      "archivedAt": null,
      "reminderMinutesBefore": null
    }
  ],
  "tags": {
    "names": ["SYVEX", "Trabajo"],
    "colors": { "syvex": "violet", "trabajo": "blue" },
    "opacities": { "syvex": 1.0, "trabajo": 0.85 }
  },
  "dayEntries": [
    {
      "id": "e1",
      "noteId": "a1",
      "day": "2026-07-21",
      "via": "todaySwitch",
      "outcome": "open",
      "targetDay": null,
      "outcomeAt": null,
      "createdAt": "2026-07-21T13:45:00.000"
    }
  ]
}
```

---

## 12. Anexo — Copy sugerido (ES)

| Contexto | Texto |
|---|---|
| Exportar OK | `Datos exportados` |
| Importar OK (v2) | `Datos importados` |
| Importar inválido | `El archivo no es válido o está corrupto.` |
| Confirmación import | `Esto reemplazará tus notas y tareas actuales. ¿Continuar?` (sin cambio) |

---

**Owner:** Product / Engineering  
**Próximo paso:** `TRD-respaldo-completo.md` → implementar en orden: esquema v2 → export tags/dayEntries → import atómico → tests roundtrip → QA manual.
