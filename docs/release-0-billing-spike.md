# Release 0: validación de billing multiplataforma

## Alcance implementado

- RevenueCat Flutter para Web, Android e iOS.
- `appUserID` UUID persistente, sin email ni identificadores publicitarios.
- Override del mismo UUID mediante `WODO_APP_USER_ID` para la prueba cruzada.
- Entitlement único `wodo_plus` y catálogo centralizado.
- Diagnóstico sandbox desde **Ajustes > Plataforma**.
- Compra, actualización de estado y restauración mediante RevenueCat.
- Endpoint NestJS `POST /webhooks/revenuecat` con autorización, HMAC-SHA256,
  tolerancia anti-replay de cinco minutos y detección temporal de duplicados.

La detección de duplicados es deliberadamente en memoria durante el spike. Release 1
debe persistir los IDs de evento y hacer reconciliación autoritativa en PostgreSQL.

## Configuración local

Las claves usadas por Flutter son públicas y se inyectan en compilación. Nunca se
deben incluir claves secretas de RevenueCat o Paddle en `dart-define`.

```bash
flutter run -d web-server \
  --dart-define=RC_WEB_API_KEY=rcb_xxx \
  --dart-define=WODO_APP_USER_ID=11111111-2222-4333-8444-555555555555
```

Para Android e iOS se usa el mismo UUID y se cambia la clave pública:

```bash
flutter run -d android \
  --dart-define=RC_GOOGLE_API_KEY=goog_xxx \
  --dart-define=WODO_APP_USER_ID=11111111-2222-4333-8444-555555555555

flutter run -d ios \
  --dart-define=RC_APPLE_API_KEY=appl_xxx \
  --dart-define=WODO_APP_USER_ID=11111111-2222-4333-8444-555555555555
```

El backend usa secretos exclusivamente desde variables de entorno. Los nombres y
formatos están en `backend/.env.example`.

```bash
cd backend
npm install
npm run start:dev
```

## Catálogo sandbox

| Plan | Apple | Google Play | Paddle/RevenueCat Web |
|---|---|---|---|
| Mensual | `wodo_plus_monthly` | `wodo_plus` + base plan `monthly` | `$rc_monthly` |
| Anual | `wodo_plus_annual` | `wodo_plus` + base plan `annual` | `$rc_annual` |

En RevenueCat:

1. Crear el entitlement `wodo_plus`.
2. Importar los productos de Apple, Google y Paddle sandbox.
3. Asociarlos a un offering actual con paquetes mensual y anual.
4. Crear una configuración Web de Paddle y usar su clave pública en Flutter.
5. Crear el webhook sandbox con Authorization y firma HMAC activadas.

## Gate de validación

- [ ] La cuenta Paddle de WODO es elegible y tiene payouts habilitados.
- [ ] Los dos productos existen en App Store Connect sandbox.
- [ ] Los base plans existen y están activos en Play Console.
- [ ] RevenueCat devuelve el offering en Web, Android e iOS.
- [ ] Una compra Paddle activa `wodo_plus` en móvil usando el mismo UUID.
- [ ] Una compra Apple/Google activa `wodo_plus` en Web usando el mismo UUID.
- [ ] Restaurar no concede derechos a un UUID distinto.
- [ ] RevenueCat entrega un webhook sandbox y NestJS rechaza firma o timestamp inválido.
- [ ] Se confirma margen estimado de al menos 70% para mensual y anual.

No se considera superado el gate hasta completar las pruebas externas anteriores con
las cuentas sandbox reales. OCR queda fuera de esta release según el PRD vigente.

## Threat model resumido

| Riesgo | Control del spike | Pendiente Release 1 |
|---|---|---|
| Suplantar `appUserID` | UUID sin email y override solo de compilación | identidad autenticada y sesiones |
| Falsificar webhook | Authorization, HMAC y comparación constante | rotación de secretos y auditoría |
| Repetir webhook válido | ventana temporal y event ID | idempotencia persistente |
| Conceder Plus desde cliente | el cliente solo refleja RevenueCat | autoridad NestJS + PostgreSQL |
| Filtrar secretos | claves públicas en Flutter, secretos solo backend | secret manager de producción |

## Costos a validar

- RevenueCat: comprobar el umbral y porcentaje vigentes del plan elegido.
- Paddle: comprobar tarifa, moneda de liquidación, reserva y costo de reembolsos.
- Apple/Google: calcular escenarios de comisión por región y programa.
- Infraestructura: estimar PostgreSQL, backups, observabilidad y colas de Release 1.

La hoja final de decisión debe registrar fecha, fuente y tres escenarios de ventas
(conservador, base y alto); los importes no se fijan en código porque cambian por
país, programa y contrato.
