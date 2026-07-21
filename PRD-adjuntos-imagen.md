# PRD — Adjuntos de imagen y portada en tareas

**Producto:** WODO (todos_app)  
**Versión:** 1.0  
**Fecha:** 21 Jul 2026  
**Estado:** Draft — listo para TRD / prototipo UI  
**Plataforma:** Flutter (iOS / Android / Web)  
**Relación:** Cumple el ítem «Foto adjunta» de `PRD.md` §11 (v1.1). Se integra con `PRD-respaldo-completo.md` (backup debe incluir adjuntos) y con el editor / cards actuales.

---

## 1. Resumen

Permitir **adjuntar una o varias imágenes** a una tarea (y, opcionalmente, a una nota) para que el usuario tenga contexto visual al resolverla (capturas, tickets, bocetos, fotos del problema).

En el detalle:

1. Una **fila de miniaturas** con las fotos adjuntas.  
2. **Ver más** abre una grilla de cuadrados.  
3. Tap en una foto → **visor a pantalla completa**.  
4. Cualquier imagen puede marcarse como **portada**; esa portada aparece en la **card de la lista**, encima del título, al estilo de la referencia (Trello/Jira) pero adaptada a la UI clara y verde de WODO.

---

## 2. Problema

Hoy las tareas son solo texto + tags + fechas. Muchos trabajos reales necesitan una imagen de apoyo:

- «Arreglar este bug» → captura de pantalla  
- «Comprar esto» → foto del producto  
- «Montar el mueble» → foto de la etiqueta / instrucciones  

Sin adjuntos, el usuario sale de la app a Fotos/WhatsApp y pierde el hilo. Sin **portada**, la lista no distingue visualmente qué tarea es cuál.

---

## 3. Objetivos

### Producto
- Adjuntar **1–N** imágenes por item (límite razonable; ver §6).  
- Marcar **una** como portada (o ninguna).  
- Verlas en detalle (fila → grilla → full screen).  
- Ver la portada en la card de Home / Tareas.

### UX
- Flujo de añadir imagen en **≤ 2 toques** desde el editor.  
- UI limpia: sin cards decorativas de más; una sola sección «Adjuntos».  
- Portada opcional: no obligar a elegir una.  
- Adaptada a WODO: fondo claro, cards blancas, acento verde, pills de tags como hoy.

### No-objetivos (v1 de este PRD)
- Comentarios, avatares de assignee, watchers (elementos de la referencia que no aplican a WODO local).  
- Video / PDF / audio (audio ya está en roadmap del PRD principal como slice aparte).  
- Edición/crop avanzada de imagen.  
- Sync en la nube de adjuntos (todo local).  
- Compresión agresiva configurable por el usuario.

---

## 4. Propuesta de UI (ejemplo limpio)

### 4.1 Principio visual

La referencia (card oscura + portada arriba + meta abajo) se traduce así en WODO:

| Referencia | WODO |
|---|---|
| Card oscura | Card blanca / superficie clara (mismo `NoteCard` actual) |
| Portada edge-to-edge arriba | Banda de imagen **redondeada arriba**, altura fija ~120–140 dp |
| Pills de color | Reutilizar `TagPill` existentes (no inventar otra fila) |
| Iconos de comments / paperclip | Solo un chip meta `📎 N` si hay adjuntos; sin comentarios |
| Avatar | No aplica (app single-user local) |

### 4.2 Card en lista (con portada)

```
┌─────────────────────────────────────┐
│ ░░░░░░░░░░░░░ PORTADA ░░░░░░░░░░░░░ │  ← Image, clip top corners
│ ░░░░░░░░░░░ (cover photo) ░░░░░░░░░ │     height ~128, BoxFit.cover
├─────────────────────────────────────┤
│ ☐  Fix: cambiar estado de contratos │
│     [SYVEX]                         │
│     ☑ Tarea · ☀ Vence hoy · 📎 3    │
└─────────────────────────────────────┘
```

**Sin portada:** la card se ve exactamente como hoy (checkbox + título + tags + meta). No se reserva espacio vacío.

**Completada:** portada con overlay suave + opacidad reducida (mismo tratamiento que el texto tachado).

### 4.3 Editor / detalle — sección Adjuntos

Ubicación: **después de cuerpo / ¿Cuándo? / tags**, antes del switch «Es una tarea». Solo visible (o al menos solo con portada) cuando el item es o puede ser tarea; en v1 también se permite en notas para no bloquear.

```
Adjuntos                                    + Añadir
┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐
│img1│ │img2│ │ ★  │ │img4│ │ +  │   ← fila horizontal scroll
│    │ │    │ │port│ │    │ │    │      ★ = badge «Portada» en la miniatura
└────┘ └────┘ └────┘ └────┘ └────┘
                    Ver más (5)
```

- Miniaturas **cuadradas** 64×64, radio 12 (mismo lenguaje que inputs).  
- Primera acción: botón `+` al final de la fila **o** fila «Añadir» en el header.  
- Badge pequeño en la esquina de la miniatura marcada como portada (icono ★ o label `Portada` en primary).  
- Si hay **> 4** miniaturas visibles: texto `Ver más (N)` debajo → abre la grilla.

### 4.4 «Ver más» — grilla

Bottom sheet o pantalla ligera a media altura:

```
Fotos · 5                              ✕
┌────┐ ┌────┐ ┌────┐
│ 1  │ │ 2  │ │ 3★ │
└────┘ └────┘ └────┘
┌────┐ ┌────┐
│ 4  │ │ 5  │
└────┘ └────┘
```

- Grid 3 columnas, squares, gap 8.  
- Long-press o menú `⋯` en cada celda: `Ver`, `Usar como portada`, `Eliminar`.  
- Tap corto → visor full screen.

### 4.5 Visor full screen

```
←  2 / 5                      ⋯
┌─────────────────────────────┐
│                             │
│         (imagen)            │  ← PageView horizontal
│                             │
└─────────────────────────────┘
        Usar como portada
```

- Swipe entre imágenes.  
- Acción primaria: `Usar como portada` / `Quitar portada`.  
- Menú: `Eliminar`, `Compartir` (share_plus, v1.1 opcional).

### 4.6 Añadir imagen — action sheet

```
Añadir imagen
─────────────
📷  Tomar foto
🖼  Elegir de la galería
─────────────
Cancelar
```

Misma pauta que `PRD-ajustes.md` para imagen de fondo (v1.1).

### 4.7 Empty state de adjuntos

Sin imágenes: solo el botón discreto `+ Añadir imagen` (no una card vacía grande).

---

## 5. Modelo de datos

### 5.1 Nuevo tipo `NoteAttachment`

| Campo | Tipo | Notas |
|---|---|---|
| `id` | `String` | UUID |
| `noteId` | `String` | FK lógica a `NoteItem.id` |
| `kind` | `image` (enum extensible) | Solo imagen en v1 |
| `fileName` | `String` | Nombre original o generado |
| `localPath` / `relativePath` | `String` | Ruta relativa bajo directorio de la app |
| `mimeType` | `String` | ej. `image/jpeg` |
| `byteSize` | `int` | Para límites y UI |
| `width` / `height` | `int?` | Opcional |
| `createdAt` | `DateTime` | |
| `sortOrder` | `int` | Orden en la fila |

### 5.2 Campos en `NoteItem`

| Campo | Tipo | Semántica |
|---|---|---|
| `coverAttachmentId` | `String?` | `null` = sin portada. Debe apuntar a un adjunto del mismo item. |
| `attachmentCount` | `int` (derivado o cache) | Para meta `📎 N` sin leer todos los blobs |

**Decisión:** los blobs **no** van dentro del JSON de Hive de la nota. Se guardan como archivos en disco (`path_provider` → `attachments/<noteId>/<attachmentId>.jpg`) y el metadata en box Hive `attachments` (o lista embebida de metadata ligera en la nota).

**Recomendación v1:** box `attachments` + `coverAttachmentId` en `NoteItem`.

### 5.3 Límites (v1)

| Límite | Valor propuesto |
|---|---|
| Máx. imágenes por item | **12** |
| Máx. tamaño por archivo | **8 MB** (antes de comprimir) |
| Formatos | JPEG, PNG, WebP, HEIC (si la plataforma lo decodifica) |
| Compresión al importar | Downscale a max edge **1920 px**, JPEG calidad ~85 |

---

## 6. Requisitos funcionales

### 6.1 Añadir (P0)
- Desde editor: action sheet galería / cámara.  
- Tras elegir: comprimir, guardar archivo, crear metadata, refrescar fila.  
- Si es la **primera** imagen del item → preguntar o auto-asignar como portada (**Decisión #3**: auto-portada en la primera).

### 6.2 Ver (P0)
- Fila de miniaturas en editor.  
- `Ver más` si N > umbral (4).  
- Visor full screen con swipe.

### 6.3 Portada (P0)
- Marcar / desmarcar desde miniatura (long-press) o desde el visor.  
- Solo **una** portada a la vez.  
- Card de lista muestra portada si `coverAttachmentId != null` y el archivo existe.  
- Si se elimina la imagen portada → `coverAttachmentId = null` (card vuelve al layout sin imagen).

### 6.4 Eliminar (P0)
- Confirmación ligera o undo snackbar (≥ 4 s).  
- Borra archivo + metadata.

### 6.5 Duplicar / archivar / borrar nota (P0)
- Duplicar: copiar archivos + metadata (+ portada).  
- Archivar: adjuntos se conservan.  
- Eliminar definitivo: borrar archivos del disco.

### 6.6 Backup (P0 — acoplado a `PRD-respaldo-completo`)
- Backup v2+ debe incluir:
  - Metadata de adjuntos  
  - `coverAttachmentId`  
  - Archivos (embebidos en base64 **o** zip sidecar — **Decisión #4** en TRD; preferencia: **zip** `wodo_backup_….zip` con `backup.json` + carpeta `files/`, o JSON v3 con attachments en base64 para web).  
- Sin esto, exportar «pierde» las fotos (mismo problema que los colores de tags antes del backup v2).

### 6.7 Web (P0 con degradación)
- Galería vía `file_picker` / input file.  
- Cámara: best-effort; si no hay, solo «Elegir archivo».  
- Almacenamiento: IndexedDB / OPFS vía path_provider web o bytes en Hive — decidir en TRD.

---

## 7. Requisitos no funcionales

| Área | Requisito |
|---|---|
| Performance | Lista de 50 cards con portada a 60 fps; miniaturas con cache (`Image.file` + resize) |
| Memoria | No cargar full-res en la lista; usar thumb generado al guardar |
| Privacidad | Todo local; sin subir a servidor |
| Permisos | Cámara / fotos solo al primer uso; copy claro si se niegan |
| Accesibilidad | Labels «Añadir imagen», «Portada», «Ver foto N de M»; hit targets ≥ 44 |
| i18n | Copy ES en §12 |

---

## 8. Flujos principales

### F1 — Adjuntar captura a una tarea
Abrir tarea → Adjuntos → `+` → Tomar foto → aparece en la fila → (auto) queda como portada → Guardar → en Home la card muestra la foto arriba.

### F2 — Elegir otra portada
Detalle → Ver más → long-press foto 3 → `Usar como portada` → badge ★ se mueve → lista refleja el cambio.

### F3 — Ver referencia a pantalla completa
Detalle → tap miniatura → swipe entre fotos → atrás.

### F4 — Quitar portada sin borrar fotos
Visor → `Quitar portada` → card vuelve al layout texto-only; fotos siguen en Adjuntos.

### F5 — Exportar / importar con fotos
Ajustes → Exportar → archivo incluye adjuntos → Importar en otro dispositivo → mismas portadas y galería.

---

## 9. Alcance por fases

### v1 (este PRD — MVP adjuntos)
- Modelo + storage local de imágenes  
- Fila de miniaturas + Ver más (grilla) + visor  
- Portada en card  
- Añadir desde galería / cámara  
- Eliminar / cambiar portada  
- Integración mínima con backup (bloqueante si no hay plan en el mismo slice o inmediatamente después)

### v1.1
- Compartir imagen suelta  
- Reordenar miniaturas (drag)  
- Thumbnails pre-generados en varios tamaños  
- Adjuntos también en sheet de creación rápida (opcional)

### v2
- Anotar / dibujar sobre captura  
- OCR / sugerencias (fuera)

---

## 10. Criterios de done

- [ ] Puedo adjuntar ≥ 2 imágenes a una tarea desde el editor  
- [ ] Veo la fila de miniaturas y `Ver más` abre grilla de cuadrados  
- [ ] Tap abre visor a pantalla completa con swipe  
- [ ] Puedo marcar una imagen como portada y se ve en la card de la lista (layout §4.2)  
- [ ] Sin portada, la card no cambia de layout  
- [ ] Eliminar la portada limpia `coverAttachmentId` y el archivo  
- [ ] Duplicar / borrar nota trata adjuntos correctamente  
- [ ] Permisos denegados muestran mensaje accionable  
- [ ] Tests: modelo attachment, cover exclusivity, delete cascade  
- [ ] QA iOS + Android + web (al menos galería en web)  
- [ ] Plan de backup documentado e implementado o explícitamente acoplado al PR de `PRD-respaldo-completo` v3

---

## 11. Decisiones de producto

| # | Pregunta | Decisión |
|---|---|---|
| 1 | ¿Solo tareas o también notas? | **Ambos** en v1 (misma sección Adjuntos); la portada en lista aplica a ambos tipos |
| 2 | ¿Portada obligatoria? | **No** — opcional |
| 3 | ¿Primera imagen = portada automática? | **Sí** — reduce fricción; el usuario puede quitarla o cambiarla |
| 4 | ¿Formato de backup con archivos? | **TRD decide** entre zip multi-file vs base64 en JSON v3; debe quedar resuelto antes de ship |
| 5 | ¿Altura de portada en card? | **128 dp** desktop/mobile compact; cover crop centrado |
| 6 | ¿Sheet de creación rápida incluye adjuntos? | **No** en v1 — solo editor full |
| 7 | ¿Mostrar contador 📎 en meta sin portada? | **Sí**, si `attachmentCount > 0` |

### Pendientes (no bloquean diseño)

| # | Pregunta | Cuándo |
|---|---|---|
| A | Librería exacta (`image_picker` vs `file_picker` + cámara nativa) | TRD |
| B | Generación de thumbs (package vs `instantiateImageCodec`) | TRD |
| C | Límite 12 / 8 MB ajustable tras QA | Post-v1 |

---

## 12. Anexo — Copy sugerido (ES)

| Contexto | Texto |
|---|---|
| Sección | `Adjuntos` |
| Añadir | `Añadir imagen` / `Tomar foto` / `Elegir de la galería` |
| Ver más | `Ver más (N)` |
| Portada | `Usar como portada` / `Quitar portada` / badge `Portada` |
| Eliminar | `¿Eliminar esta imagen?` · `Eliminar` |
| Límite | `Máximo 12 imágenes por nota` |
| Tamaño | `La imagen es demasiado grande` |
| Permiso | `Necesitamos acceso a tus fotos para adjuntarlas` |
| Meta card | `📎 3` |
| Empty | (sin copy; solo CTA `+ Añadir imagen`) |

---

## 13. Anexo — Wireframes ASCII (resumen)

**Lista con portada**

```
  ┌──────────────────────────┐
  │        [portada]         │
  │ ☐ Título de la tarea     │
  │   [tag]  📎 2 · Vence hoy│
  └──────────────────────────┘
```

**Detalle**

```
  Título
  Cuerpo…
  ¿Cuándo?  [Hoy]
  Tags      [SYVEX]
  Adjuntos  [+]
  [■][■★][■][■]   Ver más (6)
  ☐ Es una tarea
```

---

## 14. Dependencias

- `image_picker` (o equivalente) + permisos iOS/Android  
- `path_provider` (ya en el proyecto)  
- Compresión/decode de imágenes (Flutter codec o package)  
- Extensión de backup (`PRD-respaldo-completo.md`)  
- `NoteCard` / `NoteEditorScreen` / `SwipeableNoteCard`

---

**Owner:** Product / Design / Engineering  
**Próximo paso:** Validar este layout con un mock rápido (o prototipo Flutter vacío) → `TRD-adjuntos-imagen.md` (storage + backup + permisos) → implementar en orden: storage → editor fila → visor/grilla → portada en card → backup.
