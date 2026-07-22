# PRD — Cuentas, sincronización y monetización freemium

**Producto:** WODO  
**Versión:** 0.1  
**Fecha:** 21 Jul 2026  
**Estado:** Propuesta para validación  
**Plataformas:** Flutter Web / Android / iOS

---

## 1. Resumen ejecutivo

WODO funciona hoy como una aplicación local-first: las notas, tareas, etiquetas,
actividad y preferencias se guardan localmente con Hive. La aplicación web está
publicada en `app.wodo.app` y se planea distribuir también en Android e iOS.

La siguiente etapa debe permitir:

1. usar una misma cuenta y datos en varios dispositivos;
2. medir adopción y uso real del producto de forma respetuosa con la privacidad;
3. generar ingresos recurrentes suficientes para cubrir la operación;
4. conservar una experiencia gratuita útil y el funcionamiento sin conexión.

### Decisión recomendada

- **Gratis sin cuenta:** notas y tareas locales, actividad local, archivo,
  personalización y respaldo manual.
- **Cuenta gratuita opcional:** identidad, recuperación de cuenta y medición
  agregada; no activa sincronización continua.
- **WODO Plus:** sincronización multidispositivo, respaldo automático en la nube,
  restauración y un historial recuperable de 30 días.
- **Backend:** NestJS + PostgreSQL/Prisma como única fuente de verdad cloud.
  Hive se conserva como almacenamiento local-first y cola de cambios del cliente.
- **Suscripciones recomendadas:** RevenueCat como capa de derechos (*entitlements*)
  sobre App Store, Google Play y el checkout web.
- **Analítica recomendada:** eventos propios enviados al backend/PostHog y
  monitoreo de errores con Sentry, sin enviar contenido de notas.

La sincronización sí es una buena función premium: tiene costo recurrente para
WODO, ofrece valor recurrente al usuario y no inutiliza la aplicación gratuita.
No se recomienda limitar artificialmente el número de notas locales en esta fase.

---

## 2. Evidencia y estado actual

### 2.1 Producto actual

La revisión del código y de `https://app.wodo.app` confirma:

- persistencia local en Hive y backend beta NestJS/PostgreSQL para cuenta y sync;
- notas y tareas con etiquetas, fijado, archivo, fechas y recordatorios;
- captura rápida y búsqueda/filtros;
- actividad, racha y resumen mensual;
- exportación e importación manual en JSON;
- una interfaz adaptativa para móvil, tableta y escritorio.

Esto hace que el valor premium más coherente sea **continuidad + protección de
datos**, y no cobrar por la captura básica.

### 2.2 Restricciones de las tiendas

- Apple permite que una suscripción comprada en otro lugar se use en una app
  multiplataforma, pero las funciones ofrecidas fuera también deben estar
  disponibles como compra dentro de la app. Ver
  [App Review Guidelines, 3.1.3(b)](https://developer.apple.com/app-store/review/guidelines/).
- Google considera la funcionalidad de app, el software de productividad y el
  almacenamiento cloud como bienes digitales sujetos a su política de pagos.
  Ver [Google Play Payments](https://support.google.com/googleplay/android-developer/answer/9858738).
- Las suscripciones de Google Play tienen una comisión general del 15%; Apple
  ofrece 15% a desarrolladores que califican para su Small Business Program.
  Fuentes: [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622)
  y [App Store Small Business Program](https://developer.apple.com/app-store/small-business-program/).

Por ello, WODO debe implementar compras nativas y no depender únicamente de un
enlace de pago externo para todos los países.

---

## 3. Problema

### Para el usuario

- Sus datos están atados a un navegador o dispositivo.
- Cambiar de teléfono, borrar almacenamiento o usar modo privado puede causar
  pérdida de información.
- El respaldo manual existe, pero requiere disciplina y no permite continuidad
  inmediata.

### Para el producto

- No existe una identidad que permita medir personas activas entre dispositivos.
- No hay métricas confiables de adquisición, activación, retención o conversión.
- No existe un ingreso recurrente ligado al costo de ofrecer nube y soporte.
- Implementar cobro web por separado de las tiendas crea estados de suscripción
  difíciles de reconciliar.

---

## 4. Objetivos y no objetivos

### Objetivos

- Permitir que un usuario vea sus datos en Web, Android e iOS.
- Mantener creación, edición y búsqueda disponibles sin conexión.
- Evitar pérdida de datos al vincular una cuenta o resolver conflictos.
- Crear un plan pago con valor recurrente y margen positivo.
- Obtener evidencia verificable de usuarios, plataformas, actividad y retención.
- Cumplir las reglas de pago, privacidad y eliminación de cuenta de las tiendas.

### No objetivos de la primera versión

- Edición colaborativa simultánea entre varias personas.
- Compartir libretas o tareas con otros usuarios.
- Cifrado de extremo a extremo.
- Adjuntos pesados de audio, foto o video.
- Más de un plan pago o precios por equipo.
- Construir un motor propio de facturación o validación de recibos.

---

## 5. Usuarios y trabajos a resolver

### Usuario local gratuito

Quiere capturar y organizar información rápidamente sin crear una cuenta y sin
entregar sus notas a un servidor.

### Usuario multidispositivo

Usa computadora y teléfono, o cambia de dispositivo, y necesita que su información
esté disponible y protegida sin exportar archivos manualmente.

### Responsable del producto

Necesita comprobar cuántas personas usan la aplicación, en qué plataformas,
con qué frecuencia y durante cuánto tiempo, sin leer ni recolectar el contenido
privado de las notas.

---

## 6. Propuesta freemium

| Capacidad | WODO Gratis | WODO Plus |
|---|---:|---:|
| Notas y tareas locales | Ilimitadas | Ilimitadas |
| Etiquetas, filtros, archivo y actividad | Sí | Sí |
| Recordatorios locales | Sí | Sí |
| Temas y fondos actuales | Sí | Sí |
| Exportar/importar JSON manual | Sí | Sí |
| Uso sin conexión | Sí | Sí |
| Cuenta | Opcional | Requerida |
| Sincronización Web/Android/iOS | No | Sí |
| Respaldo automático cloud | No | Sí |
| Historial y restauración | No | 30 días |
| Dispositivos vinculados | 1 local | Hasta 5 inicialmente |
| Soporte | Comunidad/email | Prioridad razonable |

### Principio de *paywall*

El usuario debe experimentar el valor local antes de ver una oferta. Mostrar Plus
cuando ocurra una intención relevante:

- selecciona “Sincronizar dispositivos”;
- inicia sesión en un segundo dispositivo;
- termina una exportación manual;
- lleva al menos 7 días activo o ha creado al menos 10 elementos.

No mostrar el paywall al abrir la aplicación por primera vez.

### Hipótesis inicial de precio

- **Mensual:** USD 3.99.
- **Anual:** USD 29.99 (USD 2.50/mes equivalente).
- **Prueba:** 14 días, una sola vez por cuenta.
- **Oferta de lanzamiento:** primer año a USD 19.99 para una cohorte limitada,
  no como precio permanente.
- Usar precios regionales de App Store y Google Play cuando estén disponibles.

El precio anual queda por debajo de referentes completos como TickTick
(USD 35.99/año) y Todoist Pro, sin posicionar WODO como un producto de igual
amplitud. Fuentes: [TickTick Premium](https://www.ticktick.com/upgrade) y
[Todoist Pricing](https://www.todoist.com/pricing/).

Esta es una hipótesis, no una decisión definitiva. Debe validarse con una pantalla
de interés y entrevistas antes de implementar todo el backend.

---

## 7. Requisitos funcionales

### 7.1 Identidad (P0)

- Continuar sin cuenta debe seguir siendo la ruta principal para uso local.
- Permitir registro/inicio de sesión con email, Google y Apple.
- Usar un `userId` interno; no usar email como clave de datos o analítica.
- Al cerrar sesión, preguntar si se conservan o eliminan los datos descargados.
- Permitir eliminación de cuenta y datos desde la app y desde una página web.
- Eliminar cuenta no cancela automáticamente una suscripción activa: dirigir al
  portal de la tienda correspondiente antes de confirmar.

### 7.2 Vinculación de datos existentes (P0)

Al iniciar sesión por primera vez con datos locales:

1. explicar qué se subirá;
2. crear un respaldo local previo;
3. comparar local y cloud;
4. ofrecer “Combinar” como opción recomendada;
5. nunca borrar silenciosamente datos locales.

Si un elemento tiene el mismo ID y cambios divergentes, preservar ambos: la copia
secundaria se crea como “Conflicto de sincronización” y puede revisarse después.

### 7.3 Sincronización (P0)

- Mantener Hive como fuente local para todos los planes y usar una capa de sync
  que intercambie mutaciones idempotentes con NestJS.
- Al activar Plus, respaldar los datos locales y subirlos a PostgreSQL mediante
  los endpoints de sync después de la confirmación descrita en 7.2.
- Hive conserva el trabajo offline y la cola local. PostgreSQL es la fuente cloud
  autoritativa y Prisma aplica revisiones, tombstones y aislamiento por `userId`.
- La sincronización ocurre al recuperar conexión y mientras la app está activa.
- Cada entidad sincronizable incluye como mínimo:
  `id`, `userId`, `revision`, `updatedAt`, `deletedAt`, `originDeviceId`.
- Las eliminaciones se conservan temporalmente como marcas (*tombstones*) para
  evitar restauraciones accidentales y permitir historial.
- Mostrar estados: “Sin conexión”, “Sincronizando”, “Actualizado” y “Error”.
- Reintentos con *backoff*; ninguna falla cloud debe impedir crear o editar.
- Límite inicial: 5 dispositivos activos por cuenta Plus.

Entidades P0: notas/tareas, etiquetas y registros de actividad necesarios para
las estadísticas. Preferencias visuales pueden quedar locales hasta P1.

### 7.4 Suscripción y derechos (P0)

- Un solo derecho lógico: `wodo_plus`.
- Ofertas separadas mensual/anual para App Store, Google Play y web.
- El mismo `userId` de WODO debe usarse como identidad de RevenueCat en todas las
  plataformas.
- Mostrar precio, periodo, renovación y condiciones antes de comprar.
- Incluir “Restaurar compras” en iOS y Android.
- Incluir “Administrar suscripción” con la URL correcta según el origen.
- Mantener un periodo de gracia ante fallos de renovación.
- Si Plus vence, crear una copia local completa en Hive, detener nuevas subidas y
  ofrecer exportación. Mantener la copia cloud 90 días antes de eliminarla.

### 7.5 Analítica de uso (P0)

Registrar solo metadatos de producto. Nunca enviar títulos, cuerpos, nombres de
etiquetas, búsquedas, archivos ni texto escrito.

Eventos mínimos:

| Evento | Propiedades permitidas |
|---|---|
| `app_opened` | plataforma, versión, idioma |
| `onboarding_completed` | plataforma, duración aproximada |
| `item_created` | tipo nota/tarea, plataforma |
| `task_completed` | plataforma |
| `search_used` | plataforma; nunca el query |
| `backup_exported` | plataforma |
| `sign_up_completed` | método, plataforma |
| `sync_started` | causa, plataforma |
| `sync_completed` | duración, conteos, plataforma |
| `sync_failed` | categoría de error; sin datos privados |
| `paywall_viewed` | disparador, oferta, plataforma |
| `trial_started` | oferta, plataforma |
| `subscription_started` | oferta, tienda, moneda |
| `subscription_renewed` | oferta, tienda |
| `subscription_canceled` | oferta, tienda, motivo opcional |

Propiedades de usuario: fecha de alta, plataforma inicial, plan actual, número de
dispositivos y país aproximado proporcionado por la tienda/servicio. No guardar
identificadores publicitarios ni huellas persistentes del dispositivo.

### 7.6 Panel mínimo (P0)

El responsable del producto debe poder consultar por rango de fechas:

- instalaciones/aperturas por Web, Android e iOS;
- usuarios activos diarios, semanales y mensuales;
- usuarios anónimos frente a cuentas registradas;
- activación: creó el primer elemento dentro de 24 horas;
- retención D1, D7 y D30;
- cuentas con 1, 2 o más dispositivos;
- vistas de paywall, inicio de prueba y conversión a pago;
- MRR, suscripciones activas, cancelaciones y *churn*;
- errores y cierres inesperados por versión/plataforma.

Para evidencia profesional, conservar capturas/exportaciones fechadas de PostHog,
el proveedor de billing, App Store Connect y Play Console. No presentar instalaciones como si
fueran usuarios activos; cada métrica debe indicar fuente y periodo.

---

## 8. Arquitectura recomendada

### 8.1 Componentes

| Necesidad | Elección | Razón |
|---|---|---|
| Identidad | NestJS Auth + PostgreSQL | identidad interna, sesiones y OAuth bajo control de WODO |
| Datos cloud | PostgreSQL + Prisma | fuente cloud transaccional y auditable |
| Persistencia local gratuita | Hive existente | conserva privacidad, rapidez y uso sin cuenta |
| Persistencia offline Plus | Hive + outbox de sync | una sola base local y reintentos controlados |
| Suscripciones | Entitlement interno + adaptadores | desacopla WODO de Polar/tiendas |
| Analítica | Eventos propios/PostHog | métricas sin contenido privado |
| Estabilidad | Sentry | errores y rendimiento multiplataforma |
| Hosting web | infraestructura actual | no requiere cambio para esta fase |

No se incorporará Firebase Authentication ni Cloud Firestore. Hacerlo duplicaría
identidad, persistencia, autorización y resolución de conflictos. El contrato REST
de NestJS es la única frontera cloud y PostgreSQL la única fuente de verdad remota.

### 8.2 Seguridad

- Guards de NestJS y consultas Prisma siempre acotadas al `userId` autenticado.
- Access token corto y refresh token rotativo, hasheado en PostgreSQL.
- Tokens del cliente en Keychain/Keystore mediante almacenamiento seguro; nunca
  en Hive. En Web se requiere HTTPS y se priorizará cookie HttpOnly para refresh.
- Rate limiting para reducir abuso automatizado.
- Claves secretas y webhooks solo en NestJS, nunca en Flutter.
- HTTPS en tránsito y cifrado administrado por el proveedor en reposo.
- Exportación y eliminación completa de datos.
- Backups cifrados, restauración probada y alertas de capacidad/costo.

### 8.3 Nota sobre local-first

Hive conserva el estado operativo local y PostgreSQL conserva el estado cloud de
la cuenta. La capa de sync es la única responsable de reconciliarlos mediante
revisiones, IDs estables, mutaciones idempotentes y tombstones; ninguna tercera
base cloud participa en el flujo.
Antes de desarrollar, crear pruebas de dos dispositivos, modo avión, cambios
concurrentes, eliminación, reinstalación, migración y expiración de plan.

---

## 9. Comparación de pagos

### RevenueCat — recomendado para el lanzamiento multiplataforma

Ventajas:

- SDK Flutter para StoreKit y Google Play Billing;
- soporte Web con un mismo sistema de entitlements;
- portal/gestión, restauración y estado de suscripción unificados;
- gratuito hasta USD 2,500 de ingreso mensual rastreado; luego 1%.

Fuentes: [RevenueCat Flutter](https://www.revenuecat.com/docs/getting-started/installation/flutter)
y [RevenueCat Pricing](https://www.revenuecat.com/pricing).

### Polar — bueno para web, no como capa principal de WODO móvil

Ventajas:

- Merchant of Record: maneja impuestos internacionales de venta digital;
- suscripciones, cupones/descuentos, recuperación de pagos y portal;
- webhooks y feature flags para conceder/revocar beneficios;
- plan Starter sin mensualidad.

Costos Starter publicados: 5% + USD 0.50 por transacción. Fuentes:
[Polar Pricing](https://polar.sh/resources/pricing),
[Merchant of Record](https://polar.sh/features/merchant-of-record) y
[Subscriptions](https://polar.sh/docs/features/subscriptions/introduction).

Limitación para este caso: la documentación oficial revisada está centrada en
checkout web, API y webhooks; no ofrece una capa Flutter equivalente que valide y
unifique compras nativas de App Store y Google Play. Usarlo como proveedor web y
las tiendas por separado obligaría a construir un backend propio de entitlements.

### Decisión

Comenzar con RevenueCat para reducir riesgo de publicación y mantenimiento.
Configurar su facturación web con una opción Merchant of Record disponible
(por ejemplo Paddle, o Stripe Managed Payments si aplica a la cuenta/país).
Reevaluar Polar si WODO vende primero solo en Web, lanza una oferta de fundador o
si Polar añade integración nativa/unificación de recibos adecuada.

---

## 10. Costos y sostenibilidad

### Base inicial

- NestJS/PostgreSQL reutilizan la infraestructura del proyecto; presupuestar
  backups externos, almacenamiento y observabilidad desde el inicio.
- RevenueCat no cobra hasta superar USD 2,500 de MTR.
- La comisión principal será la de cada tienda o Merchant of Record.
- No se incluyen en este cálculo horas de desarrollo, soporte ni marketing.

Con precio anual de USD 29.99:

- venta en tienda con comisión de 15%: ingreso aproximado USD 25.49;
- venta web con Polar Starter: ingreso aproximado USD 27.99 antes de otros ajustes.

El plan anual reduce comisiones fijas, cancelación mensual y variabilidad. El
objetivo no debe ser solo “pagar el servidor”: primero debe demostrarse retención y
disposición de pago, y después fijar un objetivo de margen mínimo del 70% sobre
costos variables de infraestructura y cobro.

### Guardrails de costo

- presupuesto cloud mensual con alertas al 50%, 80% y 100%;
- límite de 5 dispositivos;
- listeners y consultas acotadas, no descargas completas frecuentes;
- no incluir adjuntos en P0;
- tablero mensual: MRR, costo cloud, comisiones, margen y soporte.

---

## 11. Métricas de éxito

### Activación y uso

- ≥ 55% de instalaciones crean una nota/tarea en 24 horas.
- ≥ 25% de usuarios activados regresan en D7 durante la beta.
- ≥ 95% de sincronizaciones terminan sin error recuperable.
- < 0.5% de sesiones con crash en versiones de producción.

### Monetización

- ≥ 8% de usuarios elegibles abren el paywall.
- ≥ 20% de quienes inician prueba llegan a suscripción pagada.
- Conversión de usuario activo a Plus inicial: 2–5%.
- ≥ 70% de nuevas suscripciones eligen anual.
- Churn mensual equivalente < 6% después de contar con una cohorte suficiente.

Los objetivos iniciales son hipótesis. No tomar decisiones fuertes con menos de
100 usuarios activados o menos de 20 pruebas iniciadas; antes usar entrevistas y
señales cualitativas.

---

## 12. Fases propuestas

### Fase 0 — Instrumentar y validar demanda (1–2 semanas)

- privacidad, consentimiento y política de datos;
- eventos mínimos anónimos y dashboard de plataforma/retención;
- pantalla de “Sincronización multidispositivo — próximamente” con precio hipotético;
- medir clic “Me interesa” y entrevistar a 5–10 usuarios;
- no cobrar todavía ni prometer una fecha.

### Fase 1 — Cuenta y respaldo cloud beta (2–4 semanas)

- Auth, eliminación de cuenta y vinculación segura de datos;
- subida/restauración manual desde cloud para beta cerrada;
- guards/autorización por `userId`, rate limits y pruebas de migración;
- Sentry, backups y alertas de capacidad.

### Fase 2 — Sincronización Plus (3–5 semanas)

- endpoints NestJS/Prisma, outbox Hive, tombstones, revisiones y conflictos;
- sincronización automática entre Web y un móvil;
- estados visibles y suite de pruebas multi-dispositivo;
- beta gratuita temporal para validar confiabilidad.

### Fase 3 — Cobro y publicación (2–4 semanas)

- RevenueCat, productos de tiendas y checkout web;
- paywall contextual, prueba, restaurar y administrar suscripción;
- términos, privacidad, Data Safety y fichas de App Store;
- rollout gradual y monitoreo de conversión/errores.

### Fase 4 — Optimización

- precios regionales y prueba anual vs mensual;
- historial de 30 días y recuperación de eliminados;
- ofertas de retorno y cupones solo donde las reglas lo permitan;
- evaluar adjuntos, colaboración o plan de equipos según demanda observada.

---

## 13. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Pérdida/duplicación al vincular cuenta | respaldo previo, combinar por defecto, conflictos preservados |
| Rechazo de tiendas por pagos | IAP nativo y revisión de reglas por región antes del release |
| Usuario siente que se le quitó algo | todas las funciones locales actuales permanecen gratis |
| Factura cloud inesperada | cuotas, alertas, sync incremental, App Check y límites |
| Analítica invade privacidad | sin contenido, catálogo cerrado, opt-out y política clara |
| Suscripción vence con datos cloud | modo lectura/gracia, exportación y retención temporal |
| Un proveedor cambia precios | entitlement propio lógico y exportación periódica de datos |

---

## 14. Preguntas por validar

- ¿Los usuarios valoran más “usar en varios dispositivos” o “no perder mis datos”?
- ¿Qué combinación real usan: Web+móvil, dos móviles o tableta+móvil?
- ¿USD 29.99/año es aceptable para el público inicial de WODO?
- ¿La cuenta debe existir gratis para facilitar futuras conversiones o solo para Plus?
- ¿30 días de historial es suficiente o el respaldo continuo ya cubre el valor?
- ¿WODO quiere prometer privacidad local-first solamente o invertir después en E2EE?

---

## 15. Criterio Go / No-Go

Avanzar de Fase 0 a sincronización completa si en una cohorte inicial ocurre al
menos una de estas señales:

- 15% o más de usuarios activos pulsa “Me interesa” al ver la propuesta y precio;
- 5 o más usuarios aceptan una preventa/lista prioritaria con intención explícita;
- entrevistas confirman pérdida de datos o multidispositivo como problema frecuente.

Si no ocurre, instrumentar y mejorar retención del producto local antes de añadir
la complejidad de cuenta, nube y facturación.
