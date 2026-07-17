# PRD — Pantalla Home orientada a Notas

**Producto:** Todos App  
**Versión:** 1.0  
**Fecha:** 16 Jul 2026  
**Estado:** Draft  
**Plataforma:** Flutter (iOS / Android / Web)

---

## 1. Resumen

Rediseñar la pantalla Home actual (enfocada en tareas del día + heatmap de actividad) para que el flujo principal sea **capturar, organizar y revisar notas** de forma rápida, sin perder la capacidad de marcar acciones concretas (tareas) cuando haga falta.

La Home deja de ser solo un checklist diario y pasa a ser un **inbox personal de pensamiento + ejecución ligera**.

---

## 2. Problema

La UI actual optimiza:

- Completar tareas del día
- Ver racha / actividad
- Reordenar items

Pero **no optimiza** el caso de uso más frecuente de una app de notas:

1. Abrir app → escribir algo en < 3 segundos
2. Encontrar esa nota después
3. Distinguir “idea / apunte” vs “acción pendiente”
4. Volver a notas importantes sin scroll infinito

Hoy el FAB “+” y la lista de tasks empujan al usuario a pensar en *tareas*, no en *captura libre*.

---

## 3. Objetivos

### Objetivos de producto
- Reducir fricción de captura (nota nueva en ≤ 3 toques / ≤ 5 segundos).
- Convertir la Home en un hub de notas con tareas como tipo secundario.
- Mantener motivación (streak/actividad) sin que robe espacio al contenido.

### Objetivos de UX
- Captura rápida siempre visible.
- Jerarquía clara: Fijadas → Recientes → Resto.
- Búsqueda y filtros usables en móvil.
- Edición inline / al tap, con autoguardado.

### No-objetivos (v1)
- Editor colaborativo en tiempo real
- Markdown avanzado / wiki linking
- Sync multi-dispositivo completo (salvo lo ya existente)
- IA de resumen / generación de notas

---

## 4. Usuarios y casos de uso

### Persona principal
Persona que usa el móvil para anotar ideas, recordatorios sueltos, meeting scraps y tareas cortas a lo largo del día.

### Jobs to be done
| Job | Resultado esperado |
|---|---|
| Capturar una idea al vuelo | Nota guardada sin decidir categoría primero |
| Convertir un apunte en acción | Nota puede volverse tarea o tener checklist |
| Encontrar algo de ayer | Búsqueda o filtro por fecha/etiqueta |
| Volver a lo importante | Notas fijadas arriba |
| Sentir progreso | Streak/actividad visible pero compacto |

---

## 5. Propuesta de solución

### Concepto de pantalla
**Home = Inbox de notas + acciones rápidas**

Estructura top → bottom:

1. **Header** — avatar, fecha, settings + acceso a búsqueda
2. **Captura rápida** — input sticky: “Escribe una nota…”
3. **Chips de filtro** — Todas / Fijadas / Notas / Tareas + etiquetas
4. **Sección Fijadas**
5. **Sección Recientes** (o lista unificada filtrada)
6. **FAB expandible** — Nota / Tarea / Foto / Audio
7. **Acceso a Perfil** — avatar/header abre actividad local y heatmap dedicado

---

## 6. Requisitos funcionales

### 6.1 Captura rápida (P0)
- Campo de entrada siempre visible bajo el header.
- Tap en el campo abre modo composición (título opcional + cuerpo).
- Enter / botón Guardar crea la nota y limpia el campo.
- Autoguardado cada N segundos o al blur (debounce).
- Si el usuario sale a mitad, se guarda como borrador.

**Criterios de aceptación**
- [ ] Crear nota con solo título o solo cuerpo
- [ ] Nota aparece en Recientes sin refresh manual
- [ ] Borrador se recupera al volver a Home

### 6.2 Modelo de contenido (P0)
Cada item puede ser:

| Tipo | Comportamiento |
|---|---|
| **Nota** | Texto libre, preview, sin checkbox obligatorio |
| **Tarea** | Checkbox, estado done/undone, opcional hora |
| **Híbrido** | Nota con checklist interna (fase 2) |

Campos mínimos:
- `id`, `type` (`note` | `task`)
- `title` (opcional)
- `body`
- `tags[]`
- `pinned` (bool)
- `createdAt`, `updatedAt`
- `completedAt` (solo tasks)
- `dueAt` / `scheduledAt` (opcional)

### 6.3 Lista de notas (P0)
- Cards compactas con:
  - Título (o primeras líneas del body)
  - Preview 1–2 líneas
  - Tags
  - Timestamp relativo (“hace 2 h”, “ayer”)
  - Indicador de fijada / tipo
- Tap → abre editor
- Long-press o swipe:
  - Fijar / Desfijar
  - Archivar
  - Eliminar
  - Convertir a tarea (si es nota)

**Criterios de aceptación**
- [ ] Preview truncado no corta mid-palabra de forma fea
- [ ] Swipe actions tienen undo toast (3–5 s)
- [ ] Empty state claro cuando no hay notas

### 6.4 Fijadas y ordenamiento (P0)
- Sección “Fijadas” arriba si hay ≥1.
- Dentro de Fijadas y Recientes: orden por `updatedAt` desc (default).
- Reorden manual (drag) solo en Fijadas (P1).

### 6.5 Búsqueda y filtros (P0 / P1)
**P0**
- Búsqueda por texto en título/body
- Filtros: Todas · Notas · Tareas · Fijadas

**P1**
- Filtro por tag
- Filtro por rango de fechas
- Favoritos (si se añade star aparte de pin)

### 6.6 FAB creativo (P0)
Al pulsar `+`:
1. Nota (default)
2. Tarea
3. Foto (P1)
4. Audio (P1)

Si se mantiene press largo en `+`, abre directamente Nota.

### 6.7 Perfil / actividad local (P0)
- Home no renderiza el heatmap completo.
- Avatar/header abre una pantalla Perfil local con streak + heatmap dedicado.
- Contar actividad por: crear/editar nota, completar tarea.
- Ver `PRD-perfil-actividad.md`.

### 6.8 Editor de nota (P0)
- Pantalla full o bottom sheet expandido
- Título + body multilínea
- Tags editables
- Toggle pin
- Toggle “Convertir en tarea”
- Autoguardado visible (“Guardado” / “Guardando…”)

**Fuera de v1:** rich text completo, tablas, embeds.

### 6.9 Tags (P0 básico)
- Tags libres (Work, Personal, etc.)
- Colores soft por tag (palette fija)
- Crear tag al escribir uno nuevo

### 6.10 Gestos y productividad (P1)
- Swipe derecha: completar (si task) / fijar (si note)
- Swipe izquierda: archivar
- Drag handle para reordenar fijadas

---

## 7. Requisitos no funcionales

| Área | Requisito |
|---|---|
| Performance | Lista de 500 notas scrollea a 60fps en mid-range |
| Persistencia | Escritura local inmediata; sync async si aplica |
| Offline | Crear/editar/buscar offline |
| Accesibilidad | Contraste AA, labels en iconos, hit targets ≥ 44pt |
| i18n | Strings externalizados (ES/EN mínimo) |
| Crash safety | Autoguardado evita pérdida > 2 s de escritura |

---

## 8. UX / UI — cambios vs mock actual

| Actual | Nuevo |
|---|---|
| “Today’s Tasks” + progress 3/5 | “Fijadas” + “Recientes” (o “Inbox”) |
| Lista solo tasks con checkbox | Cards de nota; checkbox solo en tasks |
| Heatmap grande | Heatmap compacto / colapsable |
| FAB solo “add task” | FAB menú Nota/Tarea/(Foto/Audio) |
| Sin search en Home | Search icon + filtros chips |
| Tags solo categoria de task | Tags compartidos nota/tarea |

### Principios visuales
- Mantener paleta verde + neutros del mock.
- Priorizar contenido editable sobre gamificación.
- Cards solo donde hay interacción (lista); no cardificar el hero/header.
- Tipografía limpia sans; jerarquía título > preview > meta.

---

## 9. Flujos principales

### F1 — Captura rápida
Home → tap input → escribe → Guardar → nota en Recientes → toast “Nota guardada”

### F2 — Nota a tarea
Abrir nota → “Convertir en tarea” → aparece checkbox en lista → opcional hora

### F3 — Encontrar nota
Tap search → query → resultados en vivo → tap → editor

### F4 — Fijar importante
Swipe/long-press → Fijar → sube a sección Fijadas

### F5 — Completar tarea del día
Filtro Tareas → check → strikethrough → cuenta en streak

---

## 10. Métricas de éxito

| Métrica | Baseline (estimado) | Target v1 |
|---|---|---|
| Tiempo a primera nota (sesión) | n/a | < 5 s p50 |
| Notas creadas / DAU | n/a | ≥ 2 |
| % sesiones con al menos 1 captura | n/a | ≥ 60% |
| Uso de búsqueda semanal | n/a | ≥ 25% usuarios activos |
| Retención D7 | n/a | +10% vs versión tasks-only |

Instrumentación mínima: `note_created`, `note_opened`, `note_pinned`, `task_completed`, `search_used`, `fab_action`.

---

## 11. Alcance por fases

### MVP (v1)
- Captura rápida
- CRUD notas + tareas
- Fijadas / Recientes
- Filtros básicos + búsqueda texto
- FAB Nota/Tarea
- Acceso a Perfil local con actividad
- Autoguardado
- Tags básicos
- Swipe archivar / eliminar con undo

### v1.1
- Foto adjunta
- Audio nota
- Reorden drag en Fijadas
- Filtro por tag/fecha
- Checklist dentro de nota

### v2
- Templates
- Carpetas / notebooks
- Widgets OS
- Reminders inteligentes
- Export Markdown / PDF

---

## 12. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Usuarios actuales solo quieren tasks | Toggle/filtro “Tareas” + onboarding 1 pantalla |
| Heatmap pierde engagement | Perfil local accesible desde avatar/header; Home puede mostrar microcopy de racha si hace falta |
| Lista se vuelve ruido | Fijadas + archivar + search fuertes |
| Autoguardado confunde | Indicador de estado claro + undo delete |

---

## 13. Dependencias

- Persistencia local (Hive / SQLite / Isar — según stack actual)
- Navegación bottom tabs existente
- Sistema de temas / colores verdes del diseño actual
- (Opcional) permisos cámara/micrófono en v1.1

---

## 14. Criterios de done (MVP)

- [x] Home muestra captura rápida + fijadas + recientes
- [x] Crear nota < 5 s en flujo feliz
- [x] Buscar y abrir nota existente
- [x] Convertir nota ↔ tarea
- [x] Completar tarea actualiza UI y actividad (UI ✓ · activity/streak ✓)
- [x] Activity sale del primer viewport de Home y se mueve a Perfil local (`PRD-perfil-actividad.md`)
- [x] Empty states y undo en delete (archive pendiente)
- [x] Pruebas unitarias del modelo Note/Task + repository
- [ ] QA manual iOS + Android en viewport pequeño

---

## 15. Decisiones de producto

### Cerradas (v1)

| # | Pregunta | Decisión | Evidencia |
|---|---|---|---|
| 1 | ¿“Tareas de hoy” como vista dedicada o filtro? | **Enmendada (16 Jul 2026):** filtro con grupos. El chip Tareas muestra grupo **Hoy** (+ badge `X/Y done`), Próximas y Sin fecha. Sigue sin haber pantalla dedicada. Ver `PRD-control-tareas.md`. | Chips de filtro + secciones Fijadas/Recientes |
| 2 | ¿Pin y Favorito son lo mismo? | **Sí, en v1.** Solo existe `pinned`; no hay star/favorito separado. | Modelo `NoteItem.pinned`, UI de pin |
| 3 | ¿El heatmap cuenta solo días con captura, o también solo lectura? | **Solo escritura.** Días con create/edit nota o completar tarea (`createdAt` / `updatedAt`). No cuenta opens/lecturas. Vive en Perfil local. Ver `PRD-perfil-actividad.md`. | `ActivityStats` + Perfil local |
| 5 | ¿Tabs Notas \| Tareas en bottom nav? | **No.** Todo vive en Home; sin bottom nav multi-tab por ahora. | Una sola `HomeScreen` como raíz |

### Pendientes (bloquean features futuras)

| # | Pregunta | Cuándo decidir |
|---|---|---|
| 4 | ¿Archivar es soft-delete con papelera, o ocultar sin recovery? | **Resuelta (16 Jul 2026):** soft-delete con `archivedAt` + vista Archivadas (restaurar / eliminar definitivo), sin expiración automática. Ver `PRD-control-tareas.md` §6.8 |

---

## 16. Anexo — Copy sugerido (ES)

- Placeholder captura: `Escribe una nota…`
- Sección: `Fijadas` / `Recientes`
- FAB sheet: `Nueva nota` / `Nueva tarea` / `Foto` / `Audio`
- Empty: `Tu primera nota está a un tap`
- Undo: `Nota archivada · Deshacer`
- Guardado: `Guardado` / `Guardando…`

---

**Owner:** Product / Design  
**Engineering:** Flutter app (`todos_app`)  
**Próximo paso:** Perfil local (`PRD-perfil-actividad.md`: mover heatmap + cards de actividad) → slice de control de tareas (`PRD-control-tareas.md`: fechas + Hoy + swipe/archivar) → autoguardado en editor → filtro por tag (P1)
