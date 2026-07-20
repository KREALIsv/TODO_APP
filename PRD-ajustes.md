# PRD — Ajustes (menú de configuración)

**Producto:** Todos App
**Versión:** 1.0
**Fecha:** 19 Jul 2026
**Estado:** Draft
**Plataforma:** Flutter (iOS / Android / Web)
**Relación:** Da contenido al ícono ⚙ (`Ajustes`) de `HomeScreen`, hoy sin acción (`onPressed: () {}`). Resuelve la **Decisión pendiente #A** de `PRD-control-tareas.md` §15 (ubicación de "Archivadas").

---

## 1. Resumen

El ícono de ajustes en el header de Home existe visualmente pero no hace nada. Este PRD define el contenido de **Ajustes**: una pantalla agrupada (el "menú") a la que se accede al tocar el ícono, y las pantallas/acciones específicas que cuelgan de cada fila — apariencia (tema y **fondo de la lista**), acceso a Archivadas, respaldo de datos (exportar/importar/borrar) y "Acerca de".

No se agregan cuentas, sincronización en la nube ni ajustes por usuario: la app es local (Hive), así que Ajustes es **configuración del dispositivo/instalación actual**.

---

## 2. Problema

1. El ícono ⚙ es un affordance roto: comunica "hay más configuración" pero no entrega nada → confunde/frustra.
2. No hay forma de cambiar apariencia (solo existe `AppTheme.light()`); usuarios con preferencia de modo oscuro no tienen opción.
3. `PRD-control-tareas.md` especifica una vista **Archivadas** (§6.8) pero deja pendiente **dónde vive** (Decisión #A) — hoy no existe ninguna entrada en la UI para llegar a ella.
4. No hay forma de respaldar, exportar o borrar los datos locales; si el usuario desinstala o pierde el dispositivo, pierde todo sin aviso previo.
5. No hay "Acerca de" — sin versión visible, sin canal para feedback.

---

## 3. Objetivos

### Objetivos de producto
- Convertir el ícono ⚙ en una pantalla de Ajustes útil y coherente con el resto de la app (misma paleta, mismo patrón visual de `ProfileScreen`).
- Dar salida a la vista Archivadas ya especificada, cerrando la decisión pendiente.
- Dar control básico de apariencia (claro/oscuro/sistema, y fondo de la lista).
- Dar una red de seguridad sobre los datos locales (exportar / importar / borrar todo).

### Objetivos de UX
- Ajustes se siente como una sección más de la app, no un menú aparte: mismas cards blancas con borde, misma tipografía que `ProfileScreen`.
- Cada fila deja claro su estado actual (ej. "Oscuro", "3 archivadas") sin necesidad de entrar.
- Ninguna acción destructiva (borrar todo) ocurre sin confirmación explícita y sin posibilidad de deshacer accidental.

### No-objetivos (v1)
- Cuentas de usuario, login, sync multi-dispositivo.
- Notificaciones/recordatorios reales (la app no los tiene aún — ver §11 v1.1/v2 de `PRD-control-tareas.md`); en v1 de Ajustes **no** se incluye un toggle que no hace nada.
- Idioma seleccionable (la app ya es 100% ES; EN queda para cuando exista i18n real).
- Ajustes por nota/tarea individual (ya viven en el editor).
- Gestión avanzada de etiquetas (renombrar/fusionar global) — se propone como v1.1 (§11).
- Fondo con **imagen personalizada** (foto de galería/cámara) — v1 ofrece colores/degradados curados y 2 fondos ilustrados de marca; la imagen propia con selector de galería/cámara y ajuste de colocación queda para v1.1 (§11) por los permisos y el riesgo de contraste (§12).
- Color libre (picker RGB) — no se ofrece en ninguna fase; siempre paleta curada, para mantener consistencia visual.

---

## 4. Usuarios y casos de uso

### Jobs to be done

| Job | Resultado esperado |
|---|---|
| "Quiero modo oscuro" | Cambiar tema en ≤ 2 toques, se aplica al instante |
| "¿Dónde quedó lo que archivé?" | Entrada clara "Archivadas" con contador |
| "No quiero perder mis notas si cambio de teléfono" | Exportar un respaldo en un toque |
| "Metí mucha data de prueba, quiero empezar de cero" | Borrar todo, con confirmación fuerte |
| "¿Qué versión tengo? ¿Cómo reporto un bug?" | Ver versión y enviar feedback desde Acerca de |

---

## 5. Propuesta de solución

### Concepto
El ícono ⚙ abre **`AjustesScreen`**: una pantalla completa (push, no bottom sheet), con el mismo lenguaje visual que `ProfileScreen` (`ListView` de secciones, cada una una card blanca con filas `icono · título · valor actual · chevron`). Cada fila **es** una entrada a "su respectiva pantalla" (bottom sheet de selección, pantalla dedicada, o diálogo de confirmación, según el caso).

```
←  Ajustes

APARIENCIA
┌─────────────────────────────────────┐
│ 🎨  Tema                    Sistema › │
│ 🖼  Fondo de la lista          ⬤  › │
└─────────────────────────────────────┘

ORGANIZACIÓN
┌─────────────────────────────────────┐
│ 🗄  Archivadas                   3 › │
└─────────────────────────────────────┘

DATOS
┌─────────────────────────────────────┐
│ ⬆  Exportar datos                 › │
│ ⬇  Importar datos                 › │
│ 🗑  Borrar todos los datos         › │
└─────────────────────────────────────┘

ACERCA DE
┌─────────────────────────────────────┐
│ ℹ  Acerca de esta app              › │
│ 💬 Enviar comentarios              › │
│    Versión                    1.0.0  │
└─────────────────────────────────────┘
```

### Entrada
`HomeScreen` reemplaza `onPressed: () {}` del `IconButton` de ajustes (línea del `SliverAppBar`, junto al de búsqueda) por navegación a `AjustesScreen`, mismo patrón `MaterialPageRoute` que usa `_openProfile`.

---

## 6. Requisitos funcionales

### 6.1 Pantalla `AjustesScreen` (P0)

- AppBar con título `Ajustes`, mismo estilo que `ProfileScreen` (`AppColors.white`, `surfaceTintColor: Colors.transparent`).
- Secciones con label pequeño mayúsculas (`APARIENCIA`, `ORGANIZACIÓN`, `DATOS`, `ACERCA DE`) sobre cada card, igual convención que `TaskSectionHeader` pero en variante de ajustes.
- Cada fila reutiliza el patrón de `_ContentRow` (icono + título + trailing + chevron) ya existente en `ProfileScreen`.

### 6.2 Apariencia → Tema (P0)

- Fila "Tema" muestra el valor actual (`Claro` / `Oscuro` / `Sistema`) como trailing.
- Tap abre un **bottom sheet** con 3 opciones exclusivas (radio list): `Sistema` (default) · `Claro` · `Oscuro`.
- Selección se aplica **inmediatamente** (sin botón "Guardar") y persiste localmente (nueva box Hive `settings`, o key simple; ver §13).
- `TodosApp` pasa de `MaterialApp(theme: AppTheme.light())` fijo a escuchar la preferencia (`themeMode` + `theme`/`darkTheme`).
- Si `AppTheme.dark()` no existe todavía, ver riesgo §12 — no bloquea lanzar solo `Claro`/`Sistema` en un primer corte si el tema oscuro no está listo a tiempo.

**Criterios de aceptación**
- [ ] Cambiar a Oscuro re-pinta toda la app sin reiniciar
- [ ] Preferencia persiste tras cerrar y reabrir la app
- [ ] `Sistema` sigue el modo del OS y reacciona a cambios en caliente

### 6.3 Apariencia → Fondo de la lista (P0 colores/ilustrados · P1 imagen propia)

Fila "Fondo de la lista" (justo debajo de "Tema") muestra un swatch circular pequeño con una miniatura del fondo actual como trailing. Tap abre **`FondoPickerScreen`** (pantalla completa o bottom sheet alto, con scroll), dividida en 3 grupos — igual idea que un picker de "Colores" de referencia: grilla de tarjetas grandes con degradado + icono, más una fila de sólidos rápidos abajo.

#### A) Colores (P0)

- Grilla de **2 columnas** con tarjetas de fondo (proporción ~16:10), cada una:
  - Un degradado suave de 2 tonos (diagonal), coherente con la paleta de marca (`AppColors`) pero con más variedad que un solo color plano.
  - Un pequeño emoji/ícono en la esquina inferior izquierda como identidad de la opción (ej. 🌊 `Océano`, ❄️ `Glaciar`, 🌸 `Sakura`, 🌍 `Selva`, 🍑 `Durazno`, 🌈 `Aurora`).
  - Borde de selección (ring de 2px en `AppColors.primary`) en la opción activa.
- Debajo de la grilla, una fila horizontal de **swatches sólidos** (colores planos, sin degradado) para quien quiera algo más simple/rápido.
- Primera opción siempre es `Predeterminado` (el `AppColors.neutral00` actual, sin degradado ni ilustración) — default de fábrica.
- Catálogo inicial sugerido: 8–10 degradados + 5 sólidos (ver anexo §16 para nombres).

#### B) Fondos ilustrados de marca (P0)

- Sección aparte, con 2 tarjetas grandes (mismo tamaño que las de Colores) usando la mascota rana de la app:
  - **`Rosa`** — la rana sobre el rosa de marca (`#F2327D`, el mismo que ya usa `landing/assets/app_icon.png` y `adaptive_icon_background` en `pubspec.yaml`). Asset ya existe, solo se debe copiar/optimizar a `assets/images/backgrounds/`.
  - **`Verde`** — la rana sobre un fondo verde simple (mismo estilo ilustrado, tono derivado de `AppColors.primary`/`secondary`). Asset **nuevo**, a generar en el mismo estilo que `Rosa` (ver riesgo §12: hoy solo existe el arte en rosa).
- Estas dos opciones son ilustraciones fijas (no editables ni recolorables) — son "identidad de marca", no parte de la paleta abstracta de colores.

#### C) Imagen personalizada (P1 — v1.1)

- Tarjeta `+ Elegir imagen…` al final de la grilla de Colores.
- Tap abre una **ventana emergente (action sheet)** con dos acciones:
  - `Elegir de galería`
  - `Tomar foto`
- Tras seleccionar/capturar la imagen, se muestra un paso de **colocación** antes de confirmar:
  - Modo de encuadre, exclusivo: `Cubrir` (recorta y llena toda la pantalla, default) · `Ajustar` (se ve completa, puede dejar franjas) · `Mosaico` (repite en patrón, pensado para texturas pequeñas).
  - En `Cubrir`/`Ajustar`: gesto simple de pan + pinch-zoom sobre una vista previa para reposicionar/encuadrar antes de aplicar.
  - Botones `Aplicar` (confirma y guarda) / `Cancelar` (descarta, el fondo actual no cambia).
- La imagen elegida se **copia** al almacenamiento local de la app (no solo se referencia), para que no se rompa si el usuario borra la foto original de su galería.
- Requiere permisos de cámara y galería/fotos; si el usuario los niega, mensaje explicativo con acceso directo a Ajustes del sistema.

En todos los casos (A/B/C): se aplica **de inmediato** detrás de las listas de Home y, por consistencia visual, también en Archivadas y Perfil; persiste en la misma preferencia local que el Tema (box `settings`, ver §13). Si el Tema activo es `Oscuro`, las opciones de Colores (grupo A) usan su variante de menor luminosidad (no el mismo hex que en claro); los fondos ilustrados (grupo B) y la imagen propia (grupo C) se mantienen iguales en ambos temas. Las **cards nunca cambian**: mantienen su fondo opaco (blanco en claro / superficie oscura en oscuro); el fondo elegido solo es visible en márgenes, gaps entre cards, header y estados vacíos.

**Criterios de aceptación**
- [ ] Elegir un degradado, sólido o fondo ilustrado se aplica de inmediato detrás de la lista de Home
- [ ] El fondo elegido persiste tras cerrar y reabrir la app
- [ ] Cambiar de Tema Claro↔Oscuro no deja los fondos de Colores con contraste roto (usa la variante correspondiente); `Rosa`/`Verde` e imagen propia no cambian con el tema
- [ ] El contraste texto/card se mantiene igual sin importar el fondo elegido (las cards siguen opacas)
- [ ] (v1.1) Elegir imagen desde la ventana emergente ofrece galería y cámara, y permite ajustar colocación (Cubrir/Ajustar/Mosaico) antes de aplicar
- [ ] (v1.1) Cancelar en el paso de colocación no modifica el fondo previamente activo

### 6.4 Organización → Archivadas (P0)

**Resuelve la Decisión pendiente #A de `PRD-control-tareas.md`: la entrada a Archivadas vive en Ajustes, no como chip en Home.**

- Fila "Archivadas" muestra el conteo actual (`NotesRepository.getArchived().length`); si es `0`, trailing puede omitirse o mostrar `0`.
- Tap abre `ArchivedScreen` (nueva), que implementa exactamente lo ya especificado en `PRD-control-tareas.md` §6.8:
  - Lista de items con `archivedAt != null` (vía `getArchived()`, ya existente).
  - Cada card ofrece `Restaurar` (limpia `archivedAt`, usa `restore()` ya existente) y `Eliminar definitivamente` (con diálogo de confirmación, usa `delete()` ya existente).
  - Empty state: `No hay elementos archivados`.
- No reintroduce el chip "Archivadas" en `FilterChipsBar` (se descarta esa alternativa a favor de Ajustes).

### 6.5 Datos → Exportar (P0)

- Genera un archivo JSON con todas las notas/tareas (activas + archivadas), serializadas con el `toMap()` existente de `NoteItem`.
- Ofrece el archivo vía hoja de compartir del sistema (guardar en archivos, enviar por mail, etc.).
- No incluye la preferencia de tema ni datos de ajustes, solo contenido (notas/tareas).
- Feedback: snackbar `Datos exportados` o mensaje de error si falla.

### 6.6 Datos → Importar (P0)

- Selector de archivo JSON (mismo formato que exporta §6.5).
- Valida estructura antes de aplicar (rechaza archivo corrupto/formato inesperado con mensaje claro, sin tocar los datos actuales).
- Confirmación explícita: importar **reemplaza** todos los datos actuales (`Esto reemplazará tus notas y tareas actuales. ¿Continuar?`), no hace merge en v1 (evita conflictos de `id` duplicados).
- Tras confirmar: reemplaza el contenido del box `notes` por el del archivo.

### 6.7 Datos → Borrar todos los datos (P0)

- Acción destructiva, doble confirmación:
  1. Diálogo explicando el alcance: `Se eliminarán todas tus notas y tareas, incluidas las archivadas. Esta acción no se puede deshacer.`
  2. Confirmación final (botón rojo `Borrar todo` vs `Cancelar`).
- Requiere exponer un método público de reset en `NotesRepository` (hoy `clear()` existe pero está marcado `@visibleForTesting`; se necesita una versión productiva, ver §13).
- Tras borrar: snackbar `Todos los datos fueron eliminados` y Home vuelve al empty state inicial.
- **Sin undo** (a diferencia de swipe archivar/eliminar individual) — la doble confirmación es la mitigación.

### 6.8 Acerca de (P0)

- **Acerca de esta app**: pantalla simple (o card expandida) con nombre de la app, breve descripción, y créditos.
- **Enviar comentarios**: abre `mailto:` o hoja de compartir con un mensaje pre-armado (incluye versión de la app para contexto de soporte).
- **Versión**: fila informativa (no navegable) mostrando `versionName+buildNumber` (ej. `1.0.0 (1)`), leída de `pubspec.yaml`/`Config` o del paquete de info de la plataforma.

### 6.9 Gestionar etiquetas (v1.1 — fuera de este slice)

- Pantalla para ver todas las tags (`getAllTags()`), renombrar (`renameTag`, ya existe en repo) o eliminar globalmente (`removeTag`, ya existe en repo) — hoy sin UI.
- Se deja fuera de v1 de Ajustes para no mezclar con el TRD de tags (`TRD-tags.md`, que marca esto explícitamente como "fuera de alcance" en su slice).
- Candidata natural para sección **Organización** en la siguiente iteración.

---

## 7. Requisitos no funcionales

| Área | Requisito |
|---|---|
| Retrocompatibilidad | Ausencia de preferencias guardadas → defaults (`Sistema`); no rompe instalaciones existentes |
| Performance | Cambio de tema instantáneo (< 1 frame perceptible); export/import de 500 items sin bloquear UI (mostrar loading si > ~300ms) |
| Seguridad de datos | Importar valida antes de reemplazar; borrar todo requiere doble confirmación explícita |
| Accesibilidad | Labels en filas e iconos; hit targets ≥ 44pt; diálogos destructivos con foco correcto para lectores de pantalla |
| i18n | Strings en ES, mismo patrón que el resto de la app |
| Offline | Todo Ajustes funciona 100% local, sin red |

---

## 8. Flujos principales

### F1 — Cambiar a modo oscuro
Home → ⚙ → Ajustes → Tema → `Oscuro` → toda la app cambia al instante → preferencia persiste

### F2 — Revisar y restaurar una tarea archivada
Home → ⚙ → Archivadas (`3`) → tap en item → `Restaurar` → vuelve a aparecer en Home

### F2.1 — Personalizar el fondo con un color/degradado
Home → ⚙ → Ajustes → Fondo de la lista → pestaña Colores → elegir 🌸 `Sakura` → el fondo detrás de las cards cambia al instante → preferencia persiste

### F2.2 — Elegir un fondo ilustrado de marca
Ajustes → Fondo de la lista → sección Fondos ilustrados → elegir `Verde` → la ranita aparece de fondo tras las cards

### F2.3 — Poner una foto propia de fondo (v1.1)
Ajustes → Fondo de la lista → `+ Elegir imagen…` → ventana emergente → `Elegir de galería` (o `Tomar foto`) → seleccionar/capturar → elegir `Cubrir` y reencuadrar con el dedo → `Aplicar` → fondo actualizado

### F3 — Respaldar antes de cambiar de teléfono
Ajustes → Datos → Exportar datos → compartir archivo `.json` → guardar en Drive/Files

### F4 — Recuperar un respaldo
Ajustes → Datos → Importar datos → elegir archivo → confirmar reemplazo → notas/tareas restauradas

### F5 — Empezar de cero
Ajustes → Datos → Borrar todos los datos → confirmar dos veces → Home vacía

### F6 — Reportar un bug
Ajustes → Acerca de → Enviar comentarios → se abre correo con versión pre-cargada

---

## 9. UX / UI — cambios vs estado actual

| Actual | Nuevo |
|---|---|
| Ícono ⚙ sin acción (`onPressed: () {}`) | Abre `AjustesScreen` |
| Solo `AppTheme.light()` | `Sistema` / `Claro` / `Oscuro` seleccionable |
| Fondo de la lista fijo (`AppColors.neutral00`) | Picker de fondos: colores/degradados, 2 fondos ilustrados de marca (Rosa/Verde) y, en v1.1, foto propia con colocación ajustable |
| Sin entrada a Archivadas en ningún lugar | Fila "Archivadas" en Ajustes con contador |
| Sin respaldo ni borrado masivo | Exportar / Importar / Borrar todo en sección Datos |
| Sin versión visible ni canal de feedback | Sección Acerca de |

### Principios visuales
- Reutilizar el patrón de `ProfileScreen` (cards blancas, borde `neutral20`, radius 12, `_ContentRow`) para que Ajustes no se sienta como una pantalla ajena.
- Rojo/error solo para la fila y el diálogo de "Borrar todos los datos".
- Sin nuevos iconos decorativos fuera de `Icons.*` ya usados en el resto de la app (consistencia con Material outlined icons).

---

## 10. Métricas de éxito

| Métrica | Target v1 |
|---|---|
| % usuarios que abren Ajustes al menos 1 vez | ≥ 50% (validar que el ícono ahora "funciona") |
| Adopción de tema oscuro | Medir baseline (nuevo) |
| % usuarios que cambian el fondo predeterminado | Medir baseline (nuevo) |
| Respaldos exportados / usuario activo mensual | ≥ 1 (señal de confianza en la app) |
| Tasa de confirmación vs cancelación en "Borrar todo" | Monitorear — tasa alta de cancelación tras iniciar puede indicar copy confuso |
| Uso de Archivadas vía Ajustes | ≥ mismo nivel que uso actual de archivar (si no crece, revisar descubribilidad) |

Instrumentación mínima: `settings_opened`, `theme_changed`, `background_changed`, `archived_viewed`, `data_exported`, `data_imported`, `data_wiped`, `feedback_sent`.

---

## 11. Alcance por fases

### v1 (este PRD — MVP del slice)
- `AjustesScreen` con las 4 secciones (Apariencia, Organización, Datos, Acerca de)
- Tema Claro/Oscuro/Sistema persistente
- Fondo de la lista: grupo Colores (degradados + sólidos, con `Predeterminado`) + grupo Fondos ilustrados de marca (`Rosa`, `Verde`), persistente
- `ArchivedScreen` (restaurar / eliminar definitivo) — cierra Decisión #A de `PRD-control-tareas.md`
- Exportar / Importar datos (JSON)
- Borrar todos los datos (doble confirmación)
- Acerca de + Enviar comentarios + Versión

### v1.1
- Fondo con imagen personalizada: ventana emergente `Elegir de galería` / `Tomar foto` + paso de colocación (`Cubrir` / `Ajustar` / `Mosaico` + reposicionar)
- Gestionar etiquetas (renombrar/fusionar/eliminar global) — §6.9
- Importar con merge inteligente (detectar duplicados por `id` en vez de reemplazo total)
- Copia de seguridad automática antes de "Borrar todo" / antes de importar (rollback de un paso)

### v2
- Notificaciones/recordatorios reales, con su propio toggle en Ajustes (depende de que exista la feature, ver `PRD-control-tareas.md` §11 v2)
- Selector de idioma si se agrega i18n completo
- Ajustes de comportamiento (ej. vista inicial por defecto, orden default)

---

## 12. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Construir `AppTheme.dark()` completo (paleta, contraste AA) es más trabajo del esperado | Se puede lanzar v1 con solo `Claro`/`Sistema` y agregar `Oscuro` en un follow-up corto sin cambiar la UI de Ajustes |
| Un fondo de color mal elegido reduce el contraste o "ensucia" la sensación limpia de la app | Paleta **curada y fija** (no color picker libre) en v1, con degradados/sólidos ya validados contra la paleta de marca; cards siempre opacas encima |
| Fondo de color no se ve bien en Tema Oscuro (mismo hex, luminosidad invertida) | Cada opción del grupo Colores define explícitamente su variante clara y oscura, no se reutiliza el mismo valor en ambos temas |
| El asset ilustrado `Verde` no existe todavía (solo hay arte para `Rosa` en `landing/assets/app_icon.png`) | Encargar/generar el asset `Verde` en el mismo estilo antes del TRD; si no está listo, lanzar v1 solo con `Rosa` y agregar `Verde` en un follow-up corto |
| Imagen personalizada (v1.1) puede romper legibilidad si el usuario elige una foto muy contrastada o oscura | Paso obligatorio de colocación (Cubrir/Ajustar/Mosaico) + reencuadre manual; evaluar en TRD si se necesita un overlay/oscurecido automático adicional |
| Permisos de cámara/galería denegados dejan la función inutilizable (v1.1) | Mensaje explicativo + acceso directo a Ajustes del sistema; el resto de Ajustes sigue funcionando con normalidad |
| Importar un archivo corrupto rompe la app | Validación de esquema antes de tocar el box; si falla, no se modifica nada y se muestra error |
| Usuario borra todo por error | Doble confirmación con copy explícito del alcance; sin acceso directo desde ningún otro punto de la app |
| Mover Archivadas a Ajustes reduce su descubribilidad vs un chip visible | Contador visible en la fila; se puede reevaluar visibilidad en v1.1 si el uso cae mucho |
| Exponer `clear()` fuera de tests introduce riesgo de borrado accidental en código futuro | Nuevo método explícito (`resetAll()` o similar) separado del helper de test, solo invocado desde el flujo confirmado de Ajustes |

---

## 13. Dependencias

- `NotesRepository` — reutiliza `getArchived()`, `restore()`, `delete()`, `getAllTags()`, `renameTag()`, `removeTag()` ya existentes; requiere nuevo método público de reset total (hoy `clear()` es `@visibleForTesting`)
- `NoteItem.toMap()` / `fromMap()` — reutilizados para exportar/importar sin cambios
- Nueva persistencia de preferencias: box Hive `settings` (evita agregar `shared_preferences` si se prefiere mantener un solo mecanismo de storage); guarda tanto `themeMode` como el fondo elegido
- `TodosApp` (`lib/app/app.dart`) — debe pasar de tema fijo a `themeMode` reactivo; requiere `AppTheme.dark()` (no existe hoy, solo `AppTheme.light()`)
- Fondo de la lista v1 (Colores) — reutiliza `AppColors` (nueva paleta de degradados/sólidos ahí o en un archivo hermano), sin dependencias nuevas
- Fondo de la lista v1 (Ilustrados) — nuevos assets en `assets/images/backgrounds/`: `bg_rosa.png` (ya existe el arte en `landing/assets/app_icon.png`, falta exportarlo/optimizarlo) y `bg_verde.png` (arte nuevo a crear, mismo estilo)
- Fondo de la lista v1.1 (Imagen propia) — requiere paquete de selección de imagen (ej. `image_picker`, no presente en `pubspec.yaml`), permisos de cámara/galería en `Info.plist` (iOS) y `AndroidManifest.xml` (Android), y un cropper/preview simple (paquete o implementación propia con `Matrix4`/`InteractiveViewer`)
- Export/Import de archivos — probablemente requiere paquetes nuevos no presentes en `pubspec.yaml` (ej. compartir archivo y seleccionar archivo); evaluar en TRD
- Versión de la app — leer de `pubspec.yaml`/`Config` o paquete de info de plataforma (nuevo si se opta por leerlo en runtime)

---

## 14. Criterios de done (v1)

- [ ] Ícono ⚙ en Home abre `AjustesScreen` (ya no es un no-op)
- [ ] Tema Claro/Oscuro/Sistema cambia la app al instante y persiste entre sesiones
- [ ] Fondo de la lista: se puede elegir un color/degradado o uno de los 2 fondos ilustrados de marca, se aplica al instante y persiste entre sesiones
- [ ] (v1.1, no bloquea v1) Fondo con imagen propia: ventana emergente galería/cámara + paso de colocación funcionan de punta a punta
- [ ] Archivadas accesible desde Ajustes con contador correcto; restaurar y eliminar definitivo funcionan
- [ ] Exportar genera un archivo válido que, importado de nuevo, reproduce los mismos datos (roundtrip)
- [ ] Importar rechaza archivos inválidos sin tocar los datos actuales
- [ ] Borrar todos los datos requiere dos confirmaciones y deja la app en empty state limpio
- [ ] Acerca de muestra versión real de la app y permite enviar feedback
- [ ] QA manual iOS + Android: cambio de tema, export/import, borrado total

---

## 15. Decisiones de producto

### Cerradas (v1 de este PRD)

| # | Pregunta | Decisión |
|---|---|---|
| 1 | ¿El ícono ⚙ abre un bottom sheet rápido o una pantalla completa? | **Pantalla completa** (`AjustesScreen`), por la cantidad de secciones; consistente con el patrón ya usado por `ProfileScreen` |
| 2 | ¿Dónde vive "Archivadas"? | **En Ajustes**, sección Organización. **Resuelve la Decisión pendiente #A de `PRD-control-tareas.md`** (se descarta la alternativa de chip en Home) |
| 3 | ¿Importar hace merge o reemplaza? | **Reemplaza todo** en v1 (más simple, evita conflictos de `id`); merge inteligente queda para v1.1 |
| 4 | ¿Se incluye un toggle de notificaciones en v1? | **No.** La feature de recordatorios no existe aún; agregar un toggle sin funcionalidad real generaría un affordance roto, el mismo problema que este PRD busca resolver |
| 5 | ¿Selector de idioma en v1? | **No.** La app es ES-only hoy; no hay i18n real que alternar |
| 6 | ¿Fondo con color libre/imagen o paleta curada? | **Paleta curada** en v1 (degradados + sólidos + 2 fondos ilustrados de marca); color libre (RGB) no se ofrece nunca; imagen propia queda para v1.1 |
| 7 | ¿Cómo se pide la imagen propia (v1.1)? | **Ventana emergente (action sheet)** con `Elegir de galería` / `Tomar foto`, seguida de un paso de colocación (Cubrir/Ajustar/Mosaico + reencuadre manual) antes de aplicar |
| 8 | ¿Los fondos ilustrados de marca (`Rosa`/`Verde`) cambian con el Tema Oscuro? | **No.** Son ilustraciones fijas de identidad de marca; solo el grupo Colores tiene variante clara/oscura |

### Pendientes (no bloquean v1)

| # | Pregunta | Cuándo decidir |
|---|---|---|
| A | ¿`AppTheme.dark()` se construye completo en este slice o se lanza solo Claro/Sistema primero? | Al iniciar el TRD, según capacidad de diseño disponible |
| B | ¿Backup automático antes de importar/borrar (rollback de un paso)? | v1.1, si el riesgo de error del usuario lo justifica |
| C | ¿Gestionar etiquetas vive en Ajustes u otro punto de entrada? | v1.1, junto con el diseño de esa pantalla |
| D | ¿Quién genera el asset ilustrado `Verde` y con qué herramienta (mismo prompt/estilo que `Rosa`)? | Antes de iniciar el TRD de este slice |
| E | ¿Se necesita overlay/oscurecido automático sobre la imagen propia (v1.1) para garantizar contraste, o alcanza con el paso de colocación? | Al diseñar el TRD de imagen personalizada |

---

## 16. Anexo — Copy sugerido (ES)

| Contexto | Texto |
|---|---|
| Título pantalla | `Ajustes` |
| Sección | `Apariencia` / `Organización` / `Datos` / `Acerca de` |
| Fila tema | `Tema` · valores `Sistema` / `Claro` / `Oscuro` |
| Fila fondo | `Fondo de la lista` |
| Secciones del picker | `Colores` / `Fondos ilustrados` |
| Degradados (grupo A) | `Predeterminado` · 🌊 `Océano` · ❄️ `Glaciar` · 🌸 `Sakura` · 🌍 `Selva` · 🍑 `Durazno` · 🌈 `Aurora` |
| Sólidos (grupo A) | `Menta` / `Arena` / `Lavanda` / `Gris cálido` / `Azul suave` |
| Ilustrados de marca (grupo B) | `Rosa` / `Verde` |
| Acción imagen propia (grupo C, v1.1) | `+ Elegir imagen…` |
| Ventana emergente imagen | `Elegir de galería` / `Tomar foto` |
| Colocación imagen | `Cubrir` / `Ajustar` / `Mosaico` · botones `Aplicar` / `Cancelar` |
| Fila archivadas | `Archivadas` |
| Empty archivadas | `No hay elementos archivados` |
| Fila exportar | `Exportar datos` |
| Fila importar | `Importar datos` |
| Confirmación importar | `Esto reemplazará tus notas y tareas actuales. ¿Continuar?` |
| Fila borrar todo | `Borrar todos los datos` |
| Confirmación 1 borrar todo | `Se eliminarán todas tus notas y tareas, incluidas las archivadas. Esta acción no se puede deshacer.` |
| Confirmación 2 borrar todo | `Borrar todo` / `Cancelar` |
| Toast borrar todo | `Todos los datos fueron eliminados` |
| Toast exportar | `Datos exportados` |
| Fila acerca de | `Acerca de esta app` |
| Fila feedback | `Enviar comentarios` |
| Fila versión | `Versión` |

---

**Owner:** Product / Design
**Engineering:** Flutter app (`todos_app`)
**Próximo paso:** TRD de Ajustes (persistencia de preferencias + `AppTheme.dark()` + `ArchivedScreen` + export/import) → implementación en orden: tema → Archivadas → datos (export/import/borrar) → Acerca de.
