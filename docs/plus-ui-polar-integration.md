# WODO Plus: flujo UI y preparación para Polar

## Decisión de experiencia

Plus no interrumpe la primera apertura. Se presenta cuando la persona entra a
`Ajustes > Cuenta y sincronización > WODO Plus` o expresa intención de
sincronizar. El recorrido tiene tres momentos cortos:

1. **Protección:** respaldo automático y continuidad sin conexión.
2. **Multidispositivo:** Web, Android e iOS, hasta cinco dispositivos.
3. **Oferta:** mensual USD 3.99 o anual USD 29.99, con 14 días de prueba.

La cuenta se solicita después de comunicar el valor y elegir un plan. Esto evita
pedir registro antes de que la persona entienda para qué lo necesita.

## Estados visibles

- **Gratis/local:** la tarjeta de plan explica que los datos viven en el equipo.
- **Cuenta sin Plus:** permite iniciar sesión, conocer Plus y restaurar.
- **Plus activo:** muestra sincronización activa y administración de suscripción.
- **Pagos no configurados:** compra y restauración responden con un mensaje claro;
  nunca se concede Plus desde Flutter.

## Contrato inicial del backend

- `GET /billing/plans`: catálogo comercial público.
- `GET /billing/me`: plan y entitlement autoritativos de la cuenta.
- `POST /billing/checkout`: recibe `planId`; por ahora devuelve
  `not_configured` sin simular una compra.
- `POST /billing/restore`: punto estable para reconciliación futura.

PostgreSQL conserva el entitlement `wodo_plus` separado del proveedor. Las tablas
de suscripción y eventos ya admiten `provider`, identificadores externos y estado
de cancelación. Los stubs antiguos de RevenueCat permanecen temporalmente para no
romper el trabajo previo, pero ya no forman parte de la experiencia comercial.

## Conexión futura de Polar

1. Configurar los IDs mensuales/anuales y secretos en variables de entorno.
2. Implementar la creación de checkout en `BillingService.createCheckoutIntent`.
3. Abrir `checkoutUrl` desde Flutter y usar una URL de retorno/deep link.
4. Añadir webhook Polar con verificación de firma e idempotencia por `eventId`.
5. Reconciliar `Subscription` y `Entitlement` solo desde eventos verificados.
6. Generar el portal de cliente en `GET /billing/me` como `manageUrl`.
7. Activar el enforcement de Plus en sync después de validar migración local.

La app debe seguir funcionando localmente si Polar o el backend no responden.
