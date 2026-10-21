# Investigación de pagos — ONVO, SINPE Móvil y PayPal

**Fecha:** 2026-10-19
**Autor:** Diego Araya Vega (con Claude)
**Estado:** investigación documental. Se leyeron las páginas oficiales y la documentación pública de cada proveedor; **no se probó nada con cuentas reales todavía**. Las cifras son las publicadas el 19/10/2026 y las tarifas cambian: se confirman antes de cualquier cobro real.
**Tarjetas de Trello:** *ADM-09B* (Checklist 1: documentación, API, comisiones, países y monedas, proveedor principal y alterno) y los pilares *Pagos* y *Moneda*.
**Relacionado:** `2026-10-19-monetizacion-destacados-design.md` (sección 8.5 y 8.4).

Lo que no se pudo confirmar en una fuente oficial está marcado **a confirmar** (lista completa en la sección 8).

---

## 1. Conclusión

Una sola configuración, pensada para que todo se pueda construir y demostrar con dinero ficticio el 29/10:

| Papel | Proveedor | Por qué |
|---|---|---|
| **Principal en Costa Rica (₡)** | **ONVO** | Tarjeta y **SINPE Móvil** con conciliación automática, API REST bien documentada, llaves de prueba y **números de prueba de SINPE Móvil** que simulan éxito, demora, fallo y pago parcial. De los dos proveedores locales comparados, tiene la comisión más baja por SINPE Móvil (1,5 %). |
| **Principal fuera de Costa Rica (US$ y €)** | **PayPal** | Sandbox inmediato, API de Orders v2, webhooks verificables, monedas USD y EUR. **No cobra en colones** (confirmado). |
| **Alterno de ONVO** | **Tilopay** | Mismo alcance (tarjeta + SINPE Móvil, CRC y USD, API con OpenAPI), algo más caro. Solo si ONVO no activa la cuenta a tiempo. |
| **Respaldo sin proveedor** | **SINPE Móvil manual** | La persona transfiere y sube el comprobante; el admin lo verifica. Ya está en el diseño y no depende de ninguna cuenta externa. |
| Descartado | Stripe | Costa Rica no figura entre los países donde se puede abrir una cuenta. |

Cuatro hallazgos que cambian cosas del diseño:
1. **SINPE Móvil no tiene API pública para comercios** (no se encontró ninguna del BCCR ni de los bancos consultados). Se cobra a través de un proveedor que concilia las transferencias (ONVO, Tilopay), de un servicio bancario por contrato o a mano.
2. **PayPal no ofrece colones** y cobra más: 5,40 % + US$0,30. La moneda decide qué métodos se ofrecen (sección 4).
3. **La comisión real va de 1,5 % a 6,9 %**, no el 5 % supuesto; aun así el punto de equilibrio sigue en **2 suscriptores** (sección 5).
4. **La documentación del webhook de ONVO no describe una firma del contenido**: solo un secreto fijo en una cabecera. Por eso el servidor debe volver a consultar el pago a ONVO antes de activar un plan (sección 7).

---

## 2. Proveedor por proveedor

### 2.1 ONVO (Costa Rica; también Guatemala y Perú)

- **Documentación:** `docs.onvopay.com`, en español e inglés, con esquema OpenAPI (`/openapi.yaml`) y `llms.txt`. Guías de pagos, checkout, webhooks, suscripciones, reembolsos, SINPE Móvil, SINPE PIN, Credix, Apple Pay y crypto.
- **API:** REST en `https://api.onvopay.com/v1`, JSON, autenticación `Bearer` con llave secreta. Flujo base: `POST /v1/payment-intents` (monto, moneda, descripción) → método de pago → `POST /v1/payment-intents/{id}/confirm`. Los montos son **enteros en la unidad mínima** (en su ejemplo, `500000` es ₡5.000,00).
- **Modo de pruebas:** lo decide la llave (`onvo_test_` / `onvo_live_`). Las pruebas no tocan redes bancarias reales. Tarjetas de prueba (Visa `4242 4242 4242 4242` aprobada, `4000 0000 0000 3220` con 3D Secure, `4000 0000 0000 0002` rechazada, entre otras) y **números de SINPE Móvil de prueba**: `+50688888888` éxito a los 15 s, `+50688884444` éxito a los 6 min, `+50688889521` fallo y `+50688883333` pago parcial (50 % y luego el resto).
- **SINPE Móvil (solo CRC):** se crea la intención, se crea un método de pago `mobile_number` (identificación y número de quien paga), se confirma, se le muestra el número de ONVO y el monto exacto, y **se espera el webhook `payment-intent.succeeded`**. ONVO concilia primero por identificación; `GET /v1/mobile-transfers/list` sirve para revisar transferencias que no se emparejaron solas (`paymentIntentId: null`).
- **Webhooks:** se registra una URL HTTPS en el panel; cada webhook tiene un secreto (`webhook_secret_…`) que llega en la cabecera `X-Webhook-Secret` (la documentación no describe una firma del contenido). Eventos: `payment-intent.succeeded`, `payment-intent.failed`, `payment-intent.deferred` (a la espera, como en SINPE), `subscription.renewal.succeeded` y `.failed`, `checkout-session.succeeded` y `mobile-transfer.received` (solo con un número propio y a pedido). Cualquier respuesta distinta de 2xx cuenta como entrega fallida; **no documentan política de reintentos**.
- **Suscripciones y reembolsos:** hay cargos recurrentes mensuales (el ejemplo usa tarjeta; SINPE Móvil no se menciona) y `POST /v1/refunds` (`paymentIntentId`, `amount`, parcial o total). Qué métodos se pueden reembolsar: **a confirmar**.
- **Países y monedas:** en Costa Rica, **CRC y USD**. El euro no aparece.
- **Comisiones (plan base de Costa Rica):** tarjeta **3,9 % + US$0,35**; SINPE Móvil **1,5 %**; SINPE (transferencia IBAN) 2,5 % con mínimo de US$0,50; Credix 2,50 % + US$0,35. Datáfono y Zapp llevan mensualidad (US$25 y US$5). Liquidación diaria, semanal, quincenal o mensual; la página lista un costo de liquidación de **US$3** sin aclarar si es por cada liquidación (a confirmar).
- **Para empezar:** el registro dice "activación digital en minutos". La guía de integración copia las llaves de prueba desde el panel y pasa a llaves reales "cuando la cuenta esté activada". **No documentan quién puede registrarse (persona física o jurídica), qué documentos piden ni cuánto tarda la activación** (a confirmar con ONVO; la página tiene "Hablá con ventas"). Tampoco dicen si aceptan tarjetas emitidas fuera de Costa Rica.
- **Aviso de su pie de página:** la SUGEF no supervisa la seguridad, estabilidad ni solvencia de la empresa, y no cuenta con el Fondo de Garantías. Para el curso no importa; para dinero real, sí.

### 2.2 SINPE Móvil (un método, no un proveedor)

- Es la transferencia inmediata entre cuentas bancarias por número de teléfono, dentro del sistema de pagos del BCCR. **No se encontró una API pública para comercios**: se cobra de tres maneras.
  1. **Con un proveedor que concilia** (ONVO, Tilopay): la persona transfiere a un número y el proveedor empareja la transferencia y avisa por webhook.
  2. **Con un servicio bancario por contrato** (por ejemplo *SINPE Móvil Empresarial* de Davivienda, que pide desarrollo previo y contrato) o servicios de terceros como CyberSINPE o Greenpay. No evaluados.
  3. **A mano:** número + referencia, comprobante, verificación del admin (es lo que ya prevé el diseño).
- **Tope por canal:** desde el 1/6/2026 las transferencias por mensaje de texto o WhatsApp tienen un máximo de **₡100.000 diarios** si la persona lo configuró así (reforma del BCCR al reglamento del sistema de pagos, según El Financiero del 14/4/2026). Los ₡10.000 del plan quedan muy por debajo; desde la app del banco se puede configurar un tope mayor.
- Según una guía fiscal consultada, cobrar por SINPE Móvil no crea un tributo nuevo pero sí obliga, en una operación real, a emitir comprobante electrónico y declarar el ingreso (fuera del alcance del curso).

### 2.3 PayPal

- **Documentación:** `developer.paypal.com`. Autenticación OAuth 2.0 con credenciales de cliente (`POST /v1/oauth2/token`; en su ejemplo el token dura cerca de 9 h, 8 h 48 min). Sandbox en `https://api-m.sandbox.paypal.com` (el host de producción es `api-m.paypal.com`: confirmarlo al integrar).
- **API para este caso (Orders v2):** `POST /v2/checkout/orders` crea la orden, la persona la aprueba en PayPal y el servidor la **captura** con `POST /v2/checkout/orders/{id}/capture`; ahí se ve `COMPLETED`. La cabecera **`PayPal-Request-Id`** (un UUID) vuelve idempotentes los `POST`: reintentar no cobra dos veces.
- **Sandbox:** entorno virtual con cuentas ficticias de comprador y vendedor que se crean en el panel de desarrollador; mismas funciones que producción salvo algunas (cerrar cuenta, estados mensuales). Solo pide una cuenta de desarrollador verificada por correo.
- **Webhooks:** se suscribe una URL a la app (hasta 10 por app); los eventos que importan son `CHECKOUT.ORDER.APPROVED`, `PAYMENT.CAPTURE.COMPLETED`, `PAYMENT.CAPTURE.PENDING`, `PAYMENT.CAPTURE.REFUNDED` y `PAYMENT.CAPTURE.REVERSED` (la API de pagos v2 llama `…DECLINED` a lo que la v1 llama `…DENIED`). **Verificación de firma:** `POST /v1/notifications/verify-webhook-signature` con `transmission_id`, `transmission_time`, `cert_url`, `auth_algo`, `transmission_sig`, `webhook_id` y el `webhook_event` **tal como llegó** (sin volver a serializarlo). Las cabeceras vienen en `paypal-transmission-id`, `paypal-transmission-time`, `paypal-cert-url` y `paypal-transmission-sig`; el `webhook_id` se guarda al registrar la URL. Los eventos simulados no se pueden verificar así. Si el servidor no responde 2xx, PayPal reintenta hasta 25 veces durante 3 días: el manejo debe ser **idempotente**.
- **Países y monedas:** la lista oficial de monedas para cobrar y mantener saldo incluye **USD y EUR** (y otras 22); **el colón (CRC) no figura**. Su tabla de comisiones para vendedores de Costa Rica contempla compradores de cualquier mercado. PayPal dice operar en más de 200 mercados (cifra repetida por varias fuentes; a confirmar en su página corporativa).
- **Comisiones (vendedor de Costa Rica, página actualizada el 28/9/2026):** **5,40 % + US$0,30** por pago recibido de un comprador de otro mercado, y lo mismo para pagos nacionales; solo a los **pagos nacionales** se les puede aplicar una tarifa de volumen (4,90 % a 4,40 %, sujeta a aprobación), que para nuestro caso, con compradores de fuera, no cuenta. Conversión de moneda al recibir: **3,5 %** sobre el tipo base. Retiros: a un banco de Costa Rica en colones **₡625 por retiro**; en dólares **1,00 %, mínimo US$10** (la página no aclara si el mínimo es del retiro o de la comisión: a confirmar); a un banco de EE. UU., 3,00 %. Contracargo: US$10. La tarifa fija en EUR no apareció en la tabla consultada (a confirmar).

### 2.4 Tilopay (alterno)

- **Documentación:** `tilopay.com/developers` con esquema OpenAPI 3.1. Un solo host (`https://app.tilopay.com`), `POST /api/v1/login` entrega un token de 24 h; el SDK de navegador usa otro token (`loginSdk`).
- **API:** `processPayment` (página de pago alojada), `consult`, `consultTransactions`, `processModification` (capturar, reembolsar o reversar), enlaces de pago, planes y cobros recurrentes con tarjeta guardada. Los avisos (webhook) se configuran con `webhook_url` en los enlaces y planes.
- **Modo de pruebas:** no hay otro host; se activa en el portal del comercio, donde también están las tarjetas de prueba.
- **Métodos y monedas:** tarjetas (Visa, Mastercard, American Express), **SINPE Móvil**, cuotas (BAC, Credix), Google Pay y Apple Pay. Monedas con códigos ISO 4217 (su ejemplo usa USD, CRC y GTQ).
- **Comisiones (tarifas mostradas para Costa Rica):** tarjeta **4,25 % + US$0,35**; SINPE Móvil **2 % + US$0,35**; sin mensualidad. Aprobación de la cuenta hasta 48 h después del registro digital. Costo de liquidación e impuestos: a confirmar.

### 2.5 Stripe (descartado)

La página oficial de países (`stripe.com/global`) **no incluye Costa Rica**; en Latinoamérica solo lista Brasil y México. Una cuenta costarricense no es posible sin constituir una entidad en otro país, fuera del alcance.

### 2.6 Otras vías locales vistas, no evaluadas

BAC Credomatic (pasarela de comercio electrónico), PixelPay, Greenpay (Splitpay), CyberSINPE y SINPE Móvil Empresarial de Davivienda. Si ONVO y Tilopay fallan, son las siguientes en revisar.

---

## 3. Comparación

| | ONVO | PayPal | Tilopay | SINPE Móvil manual |
|---|---|---|---|---|
| Disponible para un comercio de Costa Rica | Sí | Sí | Sí | Sí |
| Moneda de cobro | CRC, USD (SINPE Móvil solo CRC) | USD, EUR y otras; **no CRC** | ISO 4217 (ejemplos USD, CRC) | CRC |
| Métodos | Tarjeta, SINPE Móvil, SINPE, Credix | PayPal y tarjeta | Tarjeta, SINPE Móvil, cuotas | SINPE Móvil |
| Comisión | Tarjeta 3,9 % + US$0,35; SINPE Móvil 1,5 % | 5,40 % + US$0,30 | Tarjeta 4,25 % + US$0,35; SINPE Móvil 2 % + US$0,35 | Sin comisión de proveedor |
| Modo de pruebas | Llaves `onvo_test_`, tarjetas y números de SINPE Móvil | Sandbox con cuentas ficticias | Interruptor en el portal | No aplica |
| Cómo se confirma | Webhook `payment-intent.succeeded` (+ consulta del pago) | Captura `COMPLETED` + webhook | `webhook_url` + consulta | El admin |
| Cuenta lista para probar | Llaves de prueba desde el panel (activación real: a confirmar) | Inmediata | Hasta 48 h de aprobación | No necesita |
| Riesgo principal | Requisitos de activación sin documentar | Comisión alta; sin colones | Comisión más alta que ONVO | Trabajo manual del admin |

## 4. Cobertura por país y moneda

El servidor ofrece **solo los métodos cuyo proveedor cobra en la moneda de la solicitud** (el país de facturación fija la moneda, como en el diseño).

| País de facturación | Moneda y precio | Métodos |
|---|---|---|
| Costa Rica | CRC, ₡10.000 | SINPE Móvil y tarjeta con ONVO; respaldo: SINPE Móvil manual |
| Zona euro | EUR, €18 (a aprobar) | PayPal |
| Resto del mundo | USD, US$20 | PayPal; tarjeta con ONVO en USD (si acepta tarjetas del exterior: a confirmar) |

PayPal no se ofrece cuando la moneda es CRC. Para la demostración del 29/10 se usan dos recorridos: un país de facturación de Costa Rica (ONVO en pruebas o SINPE Móvil manual) y otro de fuera (PayPal sandbox).

## 5. Costo real por cobro frente al supuesto del 5 %

Con el supuesto del diseño de ₡500 = US$1 (así ₡10.000 ≈ US$20; **supuesto**, no cotización) y sin impuestos ni costo de liquidación:

| Cobro | Comisión | % |
|---|---|---|
| PayPal, US$20,00 | 5,40 % + 0,30 = **US$1,38** | 6,9 % |
| ONVO tarjeta, US$20,00 | 3,9 % + 0,35 = **US$1,13** | 5,7 % |
| ONVO tarjeta, ₡10.000 | ₡390 + ≈₡175 = **≈₡565** | 5,7 % |
| Tilopay tarjeta, ₡10.000 | ₡425 + ≈₡175 = **≈₡600** | 6,0 % |
| Tilopay SINPE Móvil, ₡10.000 | ₡200 + ≈₡175 = **≈₡375** | 3,8 % |
| **ONVO SINPE Móvil, ₡10.000** | **₡150** | **1,5 %** |

Con la comisión más alta (PayPal), el neto por suscriptor es **US$18,62** (no US$19). El equilibrio con costos fijos de US$25 al mes es 25 ÷ 18,62 ≈ 1,3, o sea **2 suscriptores**, igual que en el diseño; con 10 suscriptores ≈ US$186 netos al mes y con 50 ≈ US$931. Conviene empujar SINPE Móvil en Costa Rica: es la vía más barata.

## 6. Orden sugerido para el 29/10

1. **Hoy:** crear la cuenta de ONVO y comprobar que las llaves de prueba salen sin trámite; preguntar a ventas por los requisitos de activación y por tarjetas extranjeras. Crear la cuenta de desarrollador de PayPal (inmediata).
2. **Primero lo que no depende de nadie:** la interfaz `ProveedorPago`, la tabla `pagos`, el adaptador de **PayPal sandbox** y el flujo de **SINPE Móvil manual** con verificación del admin.
3. **Después, si las llaves de ONVO ya están:** el adaptador de ONVO en modo de pruebas (tarjeta y SINPE Móvil con los números de prueba).
4. Si ONVO se atrasa, la demostración de Costa Rica se hace con SINPE Móvil manual; Tilopay queda documentado como alterno.

## 7. Qué se deriva para el diseño de ADM-09B

- **`ProveedorPago` declara sus monedas y métodos**, y el servidor filtra por la moneda de la solicitud (sección 4). La app nunca manda importes ni elige la moneda.
- **Importes en la unidad mínima del proveedor, con el exponente ISO**: ONVO usa `250000` para ₡2.500,00, o sea CRC con **2** decimales internos. El catálogo de monedas del diseño dice `decimales: 0` para el colón, y eso es solo para **mostrar**. La tabla `pagos` guarda enteros en unidad mínima con su propio exponente (CRC 2, USD 2, EUR 2).
- **ONVO: no confiar en el webhook por sí solo.** La cabecera `X-Webhook-Secret` es un secreto compartido, no una firma del contenido: se compara en tiempo constante, solo por HTTPS, y **antes de activar un plan se consulta el pago a ONVO** (`GET` de la intención de pago con la llave secreta) y se comparan importe y moneda con lo que el servidor esperaba. Se deduplica por el identificador del objeto y por la restricción única (proveedor, referencia externa) de `pagos`. Se manejan eventos fuera de orden y `payment-intent.deferred`.
- **PayPal:** la captura hecha por el servidor es la fuente de verdad (`COMPLETED`); el webhook se verifica con `verify-webhook-signature` y se trata como idempotente (reintentos hasta por 3 días). Cada `POST` lleva `PayPal-Request-Id`. El identificador de nuestra solicitud viaja en la orden para emparejar el pago.
- **SINPE Móvil por ONVO:** las transferencias sin pareja (`paymentIntentId: null`) se revisan en la misma herramienta que el admin ya usaría para el modo manual. Los cuatro números de prueba dan un caso por estado de `pagos`: éxito, éxito demorado, fallo y parcial (que debe quedar pendiente hasta completar el monto).
- **Secretos** en variables de entorno (`ONVO_SECRET_KEY`, `ONVO_WEBHOOK_SECRET`, `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET`, `PAYPAL_WEBHOOK_ID`); nunca en el repositorio ni en la app. No se guardan datos de tarjeta: ONVO permite crear el método de pago en el cliente y mandar solo su identificador.

Cambios que esto sugiere al spec aprobado (se aplican si Diego lo confirma): en 8.5, ONVO sí tiene modo de pruebas y sale del "investigar"; en la sección 5, la comisión pasa del 5 % supuesto a un rango de 1,5 % a 6,9 % con el equilibrio sin cambios; en 8.4, "PayPal no ofrece colones" queda confirmado.

## 8. Riesgos y pendientes (**a confirmar**)

Ordenados por cuánto afectan al 29/10:

1. **ONVO — activación:** si las llaves de prueba salen al registrarse; quién puede abrir la cuenta (persona física o jurídica), documentos y plazo. *A quién:* ventas de ONVO.
2. **ONVO:** tarjetas emitidas fuera de Costa Rica; si cobra en euros; si el costo de liquidación de US$3 es por liquidación; retenciones; qué métodos admiten reembolso.
3. **PayPal:** tarifa fija en EUR; mínimo del retiro en dólares; host de producción.
4. **Tilopay:** costo de liquidación e impuestos; plazo real de aprobación.
5. **Tiendas de aplicaciones.** La política de pagos de Google Play exige su sistema de cobro para suscripciones y servicios digitales vendidos dentro de la app, con excepciones (bienes o servicios físicos, entre otras). Un plan que da visibilidad dentro de la app parece caer en la regla; la política consultada no habla expresamente de servicios de publicidad. **Revisar el texto completo y la política de Apple antes de cualquier producción real** (ya es un no objetivo del diseño).
6. **Cobros reales:** comprobante electrónico, IVA y retenciones (no objetivo del curso) y la supervisión de la SUGEF sobre el proveedor.
7. **SINPE Móvil:** el tope de ₡100.000 por mensaje de texto no afecta al plan, pero puede cambiar la normativa (hay una propuesta de Hacienda para registrar los números usados para cobrar, en consulta; no verificada en fuente oficial).

## 9. Checklist 1 de ADM-09B

- [x] Documentación de ONVO, SINPE Móvil y PayPal → secciones 2.1 a 2.3 (y 2.4 para el alterno).
- [x] API y flujo de cada uno → secciones 2 y 7.
- [x] Comisiones → secciones 2, 3 y 5.
- [x] Países y monedas → secciones 2, 3 y 4.
- [x] Proveedor principal y alterno → sección 1.
- [ ] Confirmar con ONVO la activación y las tarjetas extranjeras → sección 8, punto 1 (lo hace Diego).

---

## Fuentes (consultadas el 19/10/2026)

**Oficiales**
- ONVO: [documentación](https://docs.onvopay.com), [SINPE Móvil](https://docs.onvopay.com/payments/sinpe-mobile), [webhooks](https://docs.onvopay.com/webhooks), [pruebas](https://docs.onvopay.com/payments/testing), [primeros pasos](https://docs.onvopay.com/getting-started.md), [suscripciones](https://docs.onvopay.com/payments/subscriptions.md), [reembolsos](https://docs.onvopay.com/payments/refunds.md), [precios](https://onvopay.com/pricing), [registro](https://onvopay.com/signup), [desarrolladores](https://onvopay.com/devs).
- PayPal: [comisiones para comercios de Costa Rica](https://www.paypal.com/cr/webapps/mpp/merchant-fees), [monedas admitidas](https://developer.paypal.com/docs/reports/reference/paypal-supported-currencies/), [API REST](https://developer.paypal.com/api/rest/), [Orders v2](https://developer.paypal.com/docs/api/orders/v2/), [webhooks](https://developer.paypal.com/api/rest/webhooks/), [verificación de firma](https://developer.paypal.com/api/rest/webhooks/rest/), [nombres de eventos](https://developer.paypal.com/api/rest/webhooks/event-names/), [idempotencia](https://developer.paypal.com/api/rest/reference/idempotency/), [sandbox](https://developer.paypal.com/api/rest/sandbox/).
- Tilopay: [tarifas](https://tilopay.com/en/tarifas), [especificación OpenAPI](https://tilopay.com/developers/openapi.json), [autenticación](https://tilopay.com/en/developers/api/autenticacion).
- Stripe: [países disponibles](https://stripe.com/global).
- Google Play: [política de pagos](https://support.google.com/googleplay/android-developer/answer/9858738).

**Prensa y terceros (contexto; no son tarifas ni garantías)**
- El Financiero: [nuevo límite en SINPE Móvil](https://www.elfinancierocr.com/finanzas/nuevo-limite-en-sinpe-movil-cambiara-la-forma-de/A5BV5RHR7VCNPONGYGPNJHIFQI/story/).
- Sobre cobrar por SINPE Móvil: [Davivienda, SINPE Móvil Empresarial](https://elmundo.cr/economia-y-negocios/sinpe-movil-empresarial-herramienta-verifica-y-agiliza-el-control-de-pagos-recibidos-de-empresas-y-comercios/), [CyberSINPE](https://www.cybersinpe.com/), [Greenpay](https://greenpay.me/soluciones/transferencia-sinpe/), [guía fiscal](https://siemprealdia.co/costa-rica/impuestos/sinpe-movil-e-impuestos-en-costa-rica/).
- Comparativas de pasarelas en Costa Rica: [pasarelasdepagos.com](https://www.pasarelasdepagos.com/comparador/pasarelas-de-pagos-costa-rica/), [Koderz](https://koderzcr.com/batalla-de-pasarelas-en-costa-rica-tilopay-vs-bac-credomatic-vs-pixelpay-analisis-para-desarrolladores/).
