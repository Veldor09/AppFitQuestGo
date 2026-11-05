# Pagos en línea con ONVO — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (el plan se ejecuta en esta sesión). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Pagar la suscripción dentro de la app con ONVO (tarjeta y SINPE Móvil, Costa Rica, colones) y que el plan se active solo; PayPal queda como "pronto" fuera de Costa Rica.

**Architecture:** El backend crea una sesión de Checkout de enlace único en ONVO y devuelve su URL; la app la muestra en un WebView que se cierra al llegar a la URL de retorno del backend. Esa URL de retorno y el webhook de ONVO consultan la sesión a ONVO y activan la suscripción de forma idempotente.

**Tech Stack:** NestJS/TypeORM/Postgres/jest (backend `D:\FitQuestGo\backend`), Flutter con `webview_flutter` (app `D:\FitQuestGo\FitQuestGo`).

**Spec:** `docs/superpowers/specs/2026-11-04-pagos-en-linea-design.md`

## Global Constraints
- Nunca `git commit` / `git push` (Diego commitea). Llaves de ONVO nunca en el repo, el chat ni los tests.
- Monto siempre del servidor (`precios_patrocinio`), nunca del cliente. ONVO recibe montos en unidad mínima: `CRC 2500` → `250000`.
- Estados de `EstadoSuscripcion` no cambian. Una suscripción en línea sin pagar es `Solicitada` con `pago_ref` no nulo; la manual antigua tiene `pago_ref` nulo.
- ONVO: base `https://api.onvopay.com`, header `Authorization: Bearer <ONVO_SECRET_KEY>`. Crear: `POST /v1/checkout/sessions/one-time-link` (`lineItems[{quantity,unitAmount,currency,description}]`, `customerName`, `customerEmail`, `redirectUrl`, `cancelUrl`, `paymentMethodTypes:['card','mobile_number']`, `metadata`) → `{id,url}`. Consultar: `GET /v1/checkout/sessions/{id}` → `{status:'open'|'complete'|'expired', paymentStatus:'paid'|'unpaid'}`. Webhook: `POST` con header `X-Webhook-Secret`, cuerpo `{type:'checkout-session.succeeded', data:{id,metadata}}`.
- Env: `ONVO_SECRET_KEY`, `ONVO_WEBHOOK_SECRET`, `PUBLIC_BASE_URL`. Sin `ONVO_SECRET_KEY`, pagar responde 400 `PAGO_NO_DISPONIBLE`.
- Textos nuevos en `app_es/en/pt/pt_BR.arb` con las mismas claves.
- Backend: `node node_modules/jest/bin/jest.js <path> --silent`, `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.build.json`, `node node_modules/eslint/bin/eslint.js --fix <files>`. Flutter: `flutter test --no-pub <path>`, `flutter analyze --no-pub`, `flutter gen-l10n`.

## Review Focus
- Doble activación (webhook + retorno a la vez, o retorno recargado): una sola activación y un solo aviso.
- URL de retorno con un `s=` ajeno o inventado: solo activa si ONVO dice `paid` para el `pago_ref` guardado de esa suscripción.
- Webhook sin o con mal `X-Webhook-Secret`: 401, nada cambia.
- Pago abandonado y nuevo intento: el anterior queda `Rechazada` y no bloquea (índice único de "en proceso").
- Un usuario con plan activo que intenta pagar otro: 409 como hoy.

---

### Task 1: Columnas `pago_ref` y `pagada_en`

**Files:**
- Create: `backend/src/migrations/1793200000000-PagoEnLinea.ts`
- Modify: `backend/src/Modules/Patrocinio/suscripcion.entity.ts`

**Interfaces:**
- Produces: `Suscripcion.pagoRef: string | null` (columna `pago_ref` varchar(64), índice único parcial donde no es nulo) y `Suscripcion.pagadaEn: Date | null` (`pagada_en` timestamptz).

- [ ] **Step 1:** Escribir la migración (`ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, índice `UQ_suscripciones_pago_ref` único parcial `WHERE pago_ref IS NOT NULL`, `down` que los quita) y agregar las dos columnas a la entidad.
- [ ] **Step 2:** `tsc --noEmit -p tsconfig.build.json` sin errores. La migración corre al arrancar el backend con `RUN_MIGRATIONS=true` (Task 9).

### Task 2: Cliente de ONVO

**Files:**
- Create: `backend/src/Modules/Patrocinio/pasarela-pagos.ts`, `backend/src/Modules/Patrocinio/pasarela-pagos.spec.ts`

**Interfaces:**
- Produces:
  - `export const PASARELA_PAGOS = Symbol('PASARELA_PAGOS')`
  - `export interface SesionPago { id: string; url: string }`
  - `export interface EstadoSesionPago { id: string; pagada: boolean; expirada: boolean; metadata: Record<string,string> }`
  - `export interface PasarelaPagos { readonly disponible: boolean; crearSesion(datos: { monto: number; moneda: 'CRC'; descripcion: string; clienteNombre: string; clienteEmail: string; redirectUrl: string; cancelUrl: string; metadata: Record<string,string> }): Promise<SesionPago>; obtenerSesion(id: string): Promise<EstadoSesionPago> }`
  - `export class PasarelaOnvo implements PasarelaPagos` con constructor `(env = process.env, fetchFn: typeof fetch = fetch)`.

- [ ] **Step 1:** Test: con `ONVO_SECRET_KEY` ausente `disponible` es `false` y `crearSesion` lanza; con la llave, `crearSesion` hace `POST https://api.onvopay.com/v1/checkout/sessions/one-time-link` con `Authorization: Bearer`, `unitAmount = monto*100`, `paymentMethodTypes ['card','mobile_number']` y devuelve `{id,url}` (fetch falso); `obtenerSesion` mapea `paymentStatus:'paid'` a `pagada:true` y `status:'expired'` a `expirada:true`; un 4xx/5xx lanza `Error` sin incluir la llave.
- [ ] **Step 2:** Implementar `PasarelaOnvo` para que pase; `disponible = Boolean(env.ONVO_SECRET_KEY)`.
- [ ] **Step 3:** `jest pasarela-pagos --silent` pasa.

### Task 3: Servicio — iniciar y confirmar pagos

**Files:**
- Modify: `backend/src/Modules/Patrocinio/pago.ts`, `suscripciones.service.ts`, `solicitar-suscripcion.dto.ts` (se reutiliza tal cual como `{planId, pais}`)
- Create: `backend/src/Modules/Patrocinio/suscripciones-pago.spec.ts` (reemplaza `suscripciones-sinpe.spec.ts`, que se borra)

**Interfaces:**
- Consumes: `PasarelaPagos`, `PASARELA_PAGOS` (Task 2); `Suscripcion.pagoRef/pagadaEn` (Task 1).
- Produces en `pago.ts`: `type MetodoPago = 'onvo' | 'paypal'`; `metodoPagoParaPais(pais)` → `'onvo'` si CR, si no `'paypal'`; `pagoDisponible(metodo)` → `metodo === 'onvo'`; se eliminan `SINPE_MOVIL_NUMERO` y todo `sinpe`.
- Produces en `SuscripcionesService`:
  - `consultarPlanes(pais, audiencia)` devuelve `{pais, moneda, metodoPago, pagoDisponible: pagoDisponible(metodo) && pasarela.disponible (solo para onvo), planes}` (sin `sinpeNumero`).
  - `iniciarPago(usuarioId: number, dto: SolicitarSuscripcionDto, rol: number | undefined, urls: { retorno: (suscripcionId: number) => string; cancelado: string }): Promise<{ suscripcionId: number; numeroSolicitud: string; url: string }>`
  - `confirmarPago(suscripcionId: number): Promise<'activada' | 'ya_activa' | 'pendiente' | 'no_encontrada'>` (consulta `obtenerSesion(pagoRef)`; si `pagada`, activa en transacción con `pessimistic_write`: `Activa`, `precioAplicado`, `iniciaEn=ahora`, `venceEn=+duracionDias`, `pagadaEn=ahora`, auditoría `ACTIVAR_SUSCRIPCION_POR_PAGO` con `administradorId` nulo si la auditoría lo permite; manda `avisos.planAprobado` solo en la primera activación).
  - `confirmarPorSesion(sesionId: string): Promise<void>` (busca por `pagoRef` y llama a `confirmarPago`).
  - `miSuscripcion` pasa a devolver `pagoRef != null` como `pagoEnLinea: boolean` y deja de devolver `metodoPago`/`sinpeNumero`.

- [ ] **Step 1:** Escribir `suscripciones-pago.spec.ts` (servicio con repositorios en memoria/mocks como los specs vecinos y `PasarelaPagos` falsa): iniciar pago crea `Solicitada` con `pagoRef`, monto del precio del plan en CRC (no del cliente), rol incorrecto → 403 `PLAN_NO_APLICA`, país ≠ CR → 400 `PAGO_NO_DISPONIBLE`, pasarela no disponible → 400 `PAGO_NO_DISPONIBLE`, usuario con plan `Activa` → 409; un intento anterior `Solicitada` con `pagoRef` pasa a `Rechazada` y se crea el nuevo; `confirmarPago` activa y avisa una vez, la segunda llamada devuelve `ya_activa` sin nuevo aviso; no pagada → `pendiente` y nada cambia; id inexistente → `no_encontrada`.
- [ ] **Step 2:** Implementar `pago.ts` y los métodos del servicio; quitar `solicitarSuscripcion`, `nuevoNumeroSolicitud` se conserva y se usa en `iniciarPago`. Actualizar los specs vecinos que dependan de lo quitado (`suscripciones.service.spec.ts`, `suscripciones.controller.spec.ts`, `suscripciones-mia.spec.ts`, `suscripciones-avisos.spec.ts`).
- [ ] **Step 3:** `jest src/Modules/Patrocinio --silent` pasa.

### Task 4: Controladores públicos y cableado

**Files:**
- Create: `backend/src/Modules/Patrocinio/pagos.controller.ts`, `pagos.controller.spec.ts`
- Modify: `suscripciones.controller.ts` (reemplazar `POST suscripciones` por `POST suscripciones/pagar`), `patrocinio.module.ts` (provider `{provide: PASARELA_PAGOS, useFactory: () => new PasarelaOnvo()}` y `PagosController`), `render.yaml`, `.env.example` si existe.

**Interfaces:**
- Consumes: `iniciarPago`, `confirmarPago`, `confirmarPorSesion` (Task 3).
- Produces: `POST /patrocinio/suscripciones/pagar` (JWT) → `{suscripcionId, numeroSolicitud, url}` con `urls.retorno = (id) => ${PUBLIC_BASE_URL}/patrocinio/pagos/retorno?s=${id}` y `urls.cancelado = ${PUBLIC_BASE_URL}/patrocinio/pagos/cancelado`; `GET /patrocinio/pagos/retorno?s=` (público) devuelve HTML corto ("Pago recibido" / "Pago pendiente") tras `confirmarPago`; `GET /patrocinio/pagos/cancelado` (público) HTML "Pago cancelado"; `POST /patrocinio/pagos/onvo/webhook` (público): 401 sin `X-Webhook-Secret` igual a `ONVO_WEBHOOK_SECRET`, procesa `checkout-session.succeeded` con `confirmarPorSesion(data.id)`, responde `{recibido:true}`; cualquier otro `type` se ignora con 2xx.

- [ ] **Step 1:** Test del controlador: webhook sin secreto/incorrecto → 401 y no llama al servicio; con secreto correcto llama `confirmarPorSesion`; `s` no numérico en retorno no explota (HTML de pendiente); `ONVO_WEBHOOK_SECRET` ausente rechaza todo.
- [ ] **Step 2:** Implementar el controlador (comparación con `timingSafeEqual`), cablear el módulo y las variables en `render.yaml` (`sync: false`).
- [ ] **Step 3:** `jest src/Modules/Patrocinio --silent`, `tsc`, `eslint --fix` de los archivos tocados pasan.

### Task 5: Listado de admin con la referencia

**Files:** Modify `suscripciones.service.ts` (`listarSuscripciones`), `suscripciones-admin.controller.spec.ts` o spec del servicio.

- [ ] **Step 1:** Test: el listado incluye `pagoRef` y `pagadaEn`. **Step 2:** agregarlos al `select`. **Step 3:** jest del módulo pasa.

### Task 6: Modelos y API de Flutter

**Files:**
- Modify: `FitQuestGo/lib/Modulos/patrocinio/data/plan_api.dart`, `FitQuestGo/test/plan_patrocinio_screen_test.dart` (fakes)

**Interfaces:**
- Produces: `enum MetodoPago { onvo, paypal }` (se quita `sinpe`); `RespuestaPlanes` sin `sinpeNumero`; `MiSuscripcion` sin `sinpeNumero`/`metodoPago`, con `bool pagoEnLinea`; `class PagoIniciado { final int suscripcionId; final String numeroSolicitud; final String url; }`; `PlanApi.iniciarPago({required int planId, required String pais}) → Future<PagoIniciado>` (`POST /patrocinio/suscripciones/pagar`), que reemplaza a `solicitar`.

- [ ] **Step 1:** Ajustar los tests de modelos del archivo `plan_patrocinio_screen_test.dart` (`RespuestaPlanes lee el metodo de pago`, `MiSuscripcion lee el numero de solicitud`) a los nuevos campos. **Step 2:** Implementar. **Step 3:** el grupo `modelos` pasa.

### Task 7: Pantalla de pago (WebView)

**Files:**
- Modify: `FitQuestGo/pubspec.yaml` (`webview_flutter: ^4.10.0`, luego `flutter pub get`)
- Create: `FitQuestGo/lib/Modulos/patrocinio/presentation/pago_webview_screen.dart`, `FitQuestGo/test/pago_webview_screen_test.dart`

**Interfaces:**
- Produces: `class PagoWebViewScreen extends StatefulWidget { const PagoWebViewScreen({super.key, required this.url, this.crearController}) }` que devuelve por `Navigator.pop` un `bool` (`true` si llegó a `/patrocinio/pagos/retorno`, `false` si a `/patrocinio/pagos/cancelado` o la persona cierra). Función pura `ResultadoPago? interpretarNavegacion(String url)` → `ResultadoPago.exito | cancelado | null` según el path. `crearController` inyectable para pruebas (en tests sin plataforma de WebView).

- [ ] **Step 1:** Test de `interpretarNavegacion` (retorno → éxito, cancelado → cancelado, otra URL/inválida → null) y del widget con un controller falso: al emitir una navegación a retorno hace `pop(true)`. **Step 2:** Implementar con `NavigationDelegate.onNavigationRequest` (retorno/cancelado se detienen con `NavigationDecision.prevent`), barra con botón de cerrar, `JavaScriptMode.unrestricted`. **Step 3:** tests pasan.

### Task 8: Pantalla del plan con el pago en línea

**Files:**
- Modify: `FitQuestGo/lib/Modulos/patrocinio/presentation/plan_patrocinio_screen.dart`, `plan_patrocinio_screen_test.dart`, `suscripciones_flujo_test.dart`, `invitar_a_plan` tests si tocan SINPE; `FitQuestGo/lib/l10n/app_{es,en,pt,pt_BR}.arb`

**Interfaces:**
- Consumes: `PlanApi.iniciarPago`, `PagoWebViewScreen` (Tasks 6–7). Inyectable `final Future<bool?> Function(BuildContext, String url)? abrirPago` en el widget para pruebas.

- [ ] **Step 1:** Tests: pagar en Costa Rica llama `iniciarPago` con plan y país, abre el pago con la URL devuelta y, al volver `true`, recarga y muestra "Plan activo"; volver `false` muestra aviso de pago cancelado y deja pedir de nuevo; `PAGO_NO_DISPONIBLE` y 409 como hoy; una suscripción `Solicitada` con `pagoEnLinea` muestra la lista de planes con el aviso "Tu pago anterior no se completó"; ya no existen las claves `instrucciones-sinpe`, `numero-solicitud` ni `copiar-detalle`; fuera de Costa Rica sigue el aviso de PayPal y el botón "Pronto disponible".
- [ ] **Step 2:** Quitar `_InstruccionesSinpe`/`_copiarDetalle`; botón de pagar → confirmación → `iniciarPago` → pantalla de pago → `_recargar()`. Textos nuevos (`planPagoCancelado`, `planPagoPendienteAnterior`, `planPagarTitulo`, `planPagoCierre`) y retiro de los de SINPE manual en las cuatro ARB; `flutter gen-l10n`.
- [ ] **Step 3:** `flutter test --no-pub` de los archivos tocados y `flutter analyze --no-pub` sin errores nuevos.

### Task 9: Admin de Flutter y verificación final

**Files:** Modify `FitQuestGo/lib/Modulos/admin/data/suscripciones_admin_api.dart`, `gestion_suscripciones_screen.dart`, su test y las ARB.

- [ ] **Step 1:** Test: el detalle muestra "Referencia de pago" cuando `pagoRef` no es nulo y las suscripciones pagadas no ofrecen Aprobar. **Step 2:** implementarlo.
- [ ] **Step 3:** Suites completas: `jest --silent`, `tsc`, `eslint`, `flutter test --no-pub`, `flutter analyze --no-pub`. Tests rojos que ya fallaban antes (MailService, nodos_admin) se reportan, no se tocan.
- [ ] **Step 4 (en vivo, requiere la llave de prueba de ONVO que Diego pone en `backend/.env`):** backend local con `RUN_MIGRATIONS=true`, emulador, pagar con `4242 4242 4242 4242`, comprobar "Plan activo" y la fila `Activa` en la base; repetir con `4000 0000 0000 0002` (declinada, sigue sin plan) y la de 3D Secure `4000 0000 0000 3220`. La URL de retorno en local es `PUBLIC_BASE_URL=http://10.0.2.2:3001`.
- [ ] **Step 5:** Actualizar la memoria del proyecto.
