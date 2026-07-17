# PRD — Perfil local y actividad

**Producto:** Todos App  
**Versión:** 1.0  
**Fecha:** 17 Jul 2026  
**Estado:** Draft  
**Plataforma:** Flutter (iOS / Android / Web)  
**Relación:** Extiende `PRD.md` y mueve la actividad compacta de Home a una pantalla dedicada de Perfil local.

---

## 1. Resumen

Crear una pantalla **Perfil** local donde viva el heatmap de actividad, la racha y métricas simples de uso. La Home vuelve a enfocarse en captura rápida, búsqueda, filtros y lista de notas/tareas, sin que el bloque de actividad compita por espacio en el primer viewport.

En esta etapa no hay cuenta remota, login ni sincronización de perfil. El perfil es un resumen local del uso de la app en el dispositivo.

---

## 2. Problema

El heatmap aporta motivación, pero en Home ocupa atención y altura en una pantalla cuyo objetivo principal es capturar o encontrar contenido rápido.

Problemas actuales:

1. El usuario abre Home para escribir o revisar notas, no necesariamente para ver estadísticas.
2. El heatmap compacto obliga a usar celdas pequeñas, menos legibles en móvil.
3. La actividad necesita contexto adicional (racha, días activos, totales) para ser útil.
4. La Home ya tiene varios elementos prioritarios: header, captura rápida, filtros, fijadas y recientes.

---

## 3. Objetivos

### Objetivos de producto
- Separar **productividad diaria** (Home) de **progreso personal** (Perfil).
- Darle al heatmap espacio suficiente para ser legible y visualmente atractivo.
- Mantener la motivación sin añadir fricción al flujo de captura.
- Preparar una base para futuro perfil sincronizado sin implementarlo ahora.

### Objetivos de UX
- Acceder al Perfil en 1 toque desde el avatar/header.
- Mostrar la racha y actividad con jerarquía clara.
- Usar cuadros del heatmap más grandes que en Home.
- Mantener todo local, rápido y sin estados de autenticación.

### No-objetivos (v1)
- Login, avatar remoto o edición de cuenta.
- Sync multi-dispositivo del perfil.
- Rankings, social, compartir progreso.
- Configuración avanzada de metas.
- Export de métricas.

---

## 4. Usuarios y casos de uso

### Jobs to be done

| Job | Resultado esperado |
|---|---|
| Ver mi constancia | Perfil muestra racha actual y heatmap amplio |
| Entender mi semana | Resumen de días activos esta semana |
| Revisar actividad reciente | Heatmap permite identificar días con más escritura |
| Mantener Home ligera | Home ya no muestra el heatmap completo |
| Usar la app sin cuenta | Perfil funciona con datos locales existentes |

---

## 5. Propuesta de solución

### Concepto

**Perfil = identidad local + progreso personal.**

Estructura v1, top → bottom:

1. **Header de perfil** — avatar local, nombre placeholder y copy corto.
2. **Cards de resumen** — racha actual, días activos esta semana, notas/tareas totales.
3. **Heatmap grande** — grid con celdas más grandes y leyenda.

Los insights de actividad y las preferencias locales quedan fuera de la interfaz v1; no se muestran secciones vacías como placeholder.

Wireframe conceptual:

```text
Perfil

  (avatar)  Tu espacio
            Actividad local en este dispositivo

  ┌────────────┐ ┌────────────┐
  │  4 días    │ │  3/7 días  │
  │  Racha     │ │  Semana    │
  └────────────┘ └────────────┘

Actividad
Ene   Feb   Mar   Abr   May   Jun   Jul
L  ■  ■  □  □  ■  ...
X  □  ■  ■  □  □
V  ■  □  □  ■  ■

Menos □ ■ ■ ■ ■ Más

Resumen
- 18 notas
- 7 tareas
```

---

## 6. Requisitos funcionales

### 6.1 Navegación (P0)

- El avatar/icono del header de Home abre `ProfileScreen`.
- La pantalla puede ser una ruta normal (`Navigator.push`) en v1.
- No se requiere bottom nav para este slice.
- El botón back vuelve a Home conservando filtro y búsqueda previos.

### 6.2 Perfil local (P0)

- Mostrar avatar local placeholder con inicial o icono.
- Mostrar nombre/copy default: `Tu espacio`.
- Subcopy: `Actividad local en este dispositivo`.
- No pedir datos personales.
- No guardar preferencias nuevas en v1 salvo que ya exista infraestructura clara.

### 6.3 Cards de resumen (P0)

Mostrar métricas derivadas de `NoteItem`:

| Card | Fuente | Copy |
|---|---|---|
| Racha actual | `ActivityStats.streak` | `N días` |
| Esta semana | `ActivityStats.activeDaysThisWeek` | `N/7 días` |
| Notas | `type == note` | `N notas` |
| Tareas | `type == task` | `N tareas` |

Reglas:

- Las métricas se recalculan desde Hive/local repository.
- Los conteos incluyen elementos activos, tanto pendientes como completados, pero excluyen archivados y eliminados.
- `Notas` cuenta elementos activos con `type == note`.
- `Tareas` cuenta elementos activos con `type == task`, incluidas las completadas.
- El heatmap excluye acciones de archivar/restaurar y elementos archivados. Al implementar `completedAt`, completar una tarea cuenta en la fecha real de completado, según `PRD-control-tareas.md` §6.10.
- Si no hay contenido, todos los conteos muestran `0` sin empty crash.
- El lenguaje debe ser humano y breve, no técnico.

### 6.4 Heatmap grande (P0)

- Reutilizar `ActivityStats` y `ActivityHeatmap`.
- Mover el heatmap fuera de Home.
- Aumentar el tamaño visual de las celdas respecto al strip actual.
- Mostrar el mayor número posible entre **26 y 18 semanas** que mantenga la celda mínima.
- Si 18 semanas tampoco caben, reducir semanas hasta respetar el tamaño mínimo.
- Celda mínima objetivo: `10 px`.
- Gap recomendado: `3 px`.
- Mantener etiquetas de meses y días (`L`, `X`, `V`).
- Añadir leyenda: `Menos` → tonos → `Más`.

Notas de implementación:

- `ActivityHeatmap` debe soportar `weeks` configurable.
- `ProfileScreen` calcula las semanas con el ancho útil real, labels y gaps incluidos.
- Regla determinista: probar 26 semanas, luego 18 y, si aún no cabe, usar el máximo entero que produzca celdas de al menos `10 px`.
- Evitar scroll horizontal en v1; reducir semanas antes que hacer celdas diminutas.

### 6.5 Home sin heatmap (P0)

- Retirar `ActivityStrip` de la lista principal de Home.
- Home conserva:
  - Header con fecha/avatar.
  - Captura rápida.
  - Filtros.
  - Fijadas/Recientes/lista filtrada.
- El acceso a actividad vive en el avatar o entrada de Perfil.

### 6.6 Resumen de actividad (P1)

Debajo del heatmap, mostrar insights simples:

- `Día más activo: <día>` si hay actividad.
- `Última actividad: hoy / ayer / hace N días`.
- `Promedio semanal: N eventos`.

Esta sección no se renderiza en v1. Se implementa en v1.1 después de definir y probar sus cálculos.

### 6.7 Empty state (P0)

Si no hay notas/tareas:

- Header se mantiene.
- Cards muestran `0`.
- Heatmap renderiza vacío.
- Copy sugerido: `Captura tu primera nota para empezar a ver actividad.`

---

## 7. Requisitos no funcionales

| Área | Requisito |
|---|---|
| Performance | Cálculos en memoria sobre lista local; fluido con 500 items |
| Local-first | No requiere red, cuenta ni permisos |
| Accesibilidad | Cards y heatmap con labels semánticos básicos |
| Legibilidad | Celdas del heatmap no deben bajar de tamaño mínimo objetivo |
| Reuso | Reutilizar `ActivityStats`, `ActivityHeatmap` y repositorio existente |
| Compatibilidad | No requiere migración de datos |

---

## 8. UX / UI

### Perfil

- Fondo neutro igual a Home.
- Cards con bordes suaves y jerarquía compacta.
- Heatmap en una card o sección propia con título `Actividad`.
- Celdas más grandes que el strip actual; el heatmap debe sentirse intencional, no comprimido.
- La leyenda ayuda a entender intensidad sin explicar demasiado.

### Home

- La Home debe sentirse más ligera al quitar actividad.
- El avatar gana significado como entrada al Perfil.
- Si se quiere mantener señal de progreso en Home, solo mostrar un microcopy opcional en header, por ejemplo `Racha 4 días`, sin grid.

---

## 9. Métricas de éxito

| Métrica | Target v1 |
|---|---|
| Tiempo hasta captura desde Home | No empeora vs baseline |
| Uso de Perfil local | Medir taps en avatar/perfil |
| Legibilidad percibida | Heatmap visible sin zoom en viewport pequeño |
| Primer viewport de Home | Captura rápida + filtros visibles sin scroll excesivo |

Instrumentación futura: `profile_opened`, `activity_heatmap_viewed`. En v1 local sin analytics puede omitirse.

---

## 10. Alcance por fases

### v1

- Crear `ProfileScreen`.
- Navegar desde avatar/header de Home.
- Mover heatmap fuera de Home.
- Configurar heatmap con semanas dinámicas y celdas de al menos `10 px`.
- Cards: racha, semana activa, notas, tareas.
- Empty state local.
- Tests de `ActivityStats` se mantienen; agregar widget test básico si el entorno lo permite.

### v1.1

- Insights simples de actividad reciente.
- Microcopy opcional de racha en Home.
- Ajustes locales de perfil (nombre/avatar local).
- Semantics más detallados por semana/día en heatmap.

### v2

- Perfil sincronizado.
- Cuenta remota.
- Export o compartir resumen.
- Metas configurables.

---

## 11. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Perfil se siente vacío al inicio | Empty state claro + cards en cero |
| Usuario no descubre Perfil local | Avatar con affordance y tooltip `Perfil` |
| Heatmap grande ocupa demasiado | Limitar semanas visibles y priorizar tamaño de celda |
| Se duplica lógica de stats | Reutilizar `ActivityStats`; si hacen falta totales, agregar helpers puros |
| Home pierde motivación visible | Mantener microcopy opcional de racha en header si se valida necesario |

---

## 12. Criterios de done

- [x] Home ya no renderiza el heatmap/strip de actividad.
- [x] Avatar/header abre pantalla Perfil.
- [x] Perfil funciona sin login ni datos remotos.
- [x] Perfil muestra racha actual y días activos de la semana.
- [x] Perfil muestra conteo de notas y tareas.
- [x] Heatmap mantiene celdas de al menos `10 px` y ajusta las semanas sin scroll horizontal.
- [x] Heatmap vacío no rompe layout.
- [x] Archivados y eliminados no cuentan en cards ni heatmap.
- [x] Back navigation vuelve a Home sin perder estado visible.
- [x] No hay migración de datos.
- [x] Tests existentes de `ActivityStats` siguen pasando.

---

## 13. Decisiones de producto

### Cerradas (v1)

| # | Pregunta | Decisión |
|---|---|---|
| 1 | ¿Dónde vive el heatmap? | En Perfil, no en Home |
| 2 | ¿Perfil requiere cuenta? | No, es local en v1 |
| 3 | ¿Cómo hacer celdas más grandes? | Probar 26, luego 18 y reducir más si hace falta para mantener celdas ≥ 10 px |
| 4 | ¿Bottom nav ahora? | No, navegación desde avatar/header |
| 5 | ¿Home mantiene señal de racha? | No en v1; puede evaluarse como microcopy en v1.1, nunca como grid |

### Pendientes

| # | Pregunta | Cuándo decidir |
|---|---|---|
| A | ¿Nombre/avatar local editable? | v1.1 |
| B | ¿Qué insights mostrar bajo el heatmap? | Diseño de Perfil local v1.1 |
| C | ¿Perfil local entra a bottom nav? | Cuando haya 3+ pantallas principales estables |

---

## 14. Anexo — Copy sugerido

| Contexto | Texto |
|---|---|
| Título pantalla | `Perfil` |
| Nombre default | `Tu espacio` |
| Subcopy | `Actividad local en este dispositivo` |
| Sección heatmap | `Actividad` |
| Leyenda | `Menos` / `Más` |
| Card racha | `Racha actual` |
| Card semana | `Esta semana` |
| Card notas | `Notas` |
| Card tareas | `Tareas` |
| Empty | `Captura tu primera nota para empezar a ver actividad.` |
| Tooltip avatar | `Perfil` |

---

**Owner:** Product / Design  
**Engineering:** Flutter app (`todos_app`)  
**Próximo paso:** TRD/implementación del slice v1: `ProfileScreen` → navegación desde Home → reutilizar `ActivityHeatmap` fuera de Home → ajustar semanas/celdas → cards locales.
