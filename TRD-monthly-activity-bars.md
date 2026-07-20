# TRD — Barras de registros mensuales

**Producto:** Todos App  
**Referencia PRD:** `PRD-perfil-actividad.md` §6.6 (insights bajo heatmap)  
**Fecha:** 20 Jul 2026  
**Estado:** Implementado

---

## 1. Objetivo

Mostrar en **Perfil**, debajo de heatmap + rachas, una card con **barras mensuales** que contrasten el volumen de registros (misma definición de actividad que el heatmap).

## 2. Alcance

### Incluido

- Agregación de `eventCounts` por mes calendario (últimos 12 meses)
- Card “Registros mensuales” con barras tipo píldora y label de letra (E…D)
- Altura relativa al mes con más registros (contraste visual)
- Color relativo vía `ActivityHeatmap.colorForIntensity` (no escala diaria absoluta)
- Tests unitarios de la agregación

### Fuera de alcance

- % del mes, delta vs mes anterior, metas
- Persistencia de snapshots históricos
- Cambiar Home / streak / heatmap

## 3. Decisiones

| Tema | Decisión |
|---|---|
| ¿Qué mide cada barra? | Suma de eventos de escritura del mes (`activityMetricsFrom`) |
| ¿Cuántos meses? | 12 (calendario local, oldest → newest) |
| ¿% / comparación? | No — solo contraste de volumen |
| ¿Posición UI? | Tras `_SecondaryStats`, antes de `_ContentRows` |

## 4. Archivos

| Archivo | Cambio |
|---|---|
| `lib/features/notes/domain/activity_stats.dart` | `MonthActivityBar`, `monthlyEventBars` |
| `lib/features/notes/presentation/widgets/monthly_activity_bars.dart` | Widget card |
| `lib/features/profile/presentation/profile_screen.dart` | Insertar sección |
| `test/features/notes/monthly_activity_bars_test.dart` | Tests |

## 5. Criterios de aceptación

- [ ] En Perfil aparece la card bajo rachas
- [ ] Barras reflejan registros mensuales reales
- [ ] Mes sin actividad → barra mínima gris
- [ ] Archivados no cuentan
- [ ] No altera Home ni el badge diario X/Y
