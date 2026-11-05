# Pagos en línea de suscripciones con ONVO (modo de prueba)

Fecha: 2026-11-04. Estado: propuesta, pendiente de aprobación de Diego.

## Intención
Hoy una suscripción se paga por SINPE Móvil a mano: la persona transfiere, manda el comprobante por mensaje y un admin activa el plan. Se reemplaza por **un solo método, ONVO**, con activación automática al confirmarse el pago. ONVO cubre tarjeta y SINPE Móvil, así que el SINPE manual se retira. Todo con **llaves de prueba**: no se mueve dinero real ni se piensa usar a gran escala.

PayPal queda como método del resto del mundo pero **sin activar**: se muestra como "pronto" (decisión de Diego, 2026-11-04). Es lo que la app ya hace hoy fuera de Costa Rica.

## Metas
- Pagar dentro de la app y que el plan quede activo solo, sin admin.
- Costa Rica: tarjeta y SINPE Móvil por ONVO, en colones.
- Resto del mundo: se ven los planes en dólares y el método PayPal marcado "pronto"; todavía no se puede pagar.
- El monto sale siempre del servidor (tablas de planes y precios), nunca de la app.

## No metas
- Dinero real, cobros recurrentes automáticos, reembolsos desde la app, factura electrónica.
- Activar PayPal (solo queda como "pronto") y el SINPE manual con comprobante por mensaje.
- Pasar la app por Google Play Billing (aplicaría antes de un lanzamiento real, no a la demo).

## Flujo
1. La persona elige plan y confirma. La región ("Pagar desde") decide el método: Costa Rica paga por ONVO en colones; otro país ve PayPal como "pronto".
2. El backend crea la suscripción en estado `Solicitada` y una sesión de Checkout de enlace único en ONVO (`POST /v1/checkout/sessions/one-time-link`, con `metadata` que lleva el id de la suscripción). Responde con la URL de pago.
3. La app abre esa URL **dentro de la app**, en una pantalla con un WebView (`webview_flutter`), sin salir a un navegador externo.
4. Al pagar, ONVO devuelve a la persona a una página del backend (`/patrocinio/pagos/retorno`). El backend **consulta la sesión a ONVO** (no confía en lo que viene en la URL), y si está pagada activa el plan (`Activa`, 30 días desde ese momento) y manda el aviso.
5. El WebView detecta esa dirección de retorno, se cierra solo y la pantalla del plan se recarga y muestra "Plan activo". Si la persona cierra la pantalla antes, al volver a la pantalla del plan se recarga igual.
6. El webhook `checkout-session.succeeded` hace lo mismo (idempotente, verificado con `X-Webhook-Secret`), por si la persona cierra la app antes de volver. Activar dos veces el mismo pago no hace nada.

## Backend
- Migración: en `suscripciones` agregar `pago_ref` (id de la sesión de ONVO) y `pagada_en`. `numero_solicitud` se conserva como referencia corta de 6 dígitos (va en la descripción del cobro y sirve para buscar en el admin).
- Se retira el flujo de SINPE manual: ya no existe `metodoPago: sinpe`, ni `SINPE_MOVIL_NUMERO`, ni el número 83722969 en las respuestas. `GET /patrocinio/planes` devuelve los planes con el precio en la moneda de la región y `metodoPago` (`onvo` para CR, `paypal` para el resto) con `pagoDisponible` (`true` solo para `onvo`), como hoy.
- `POST /patrocinio/suscripciones/pagar` `{ planId, pais }` → `{ url, suscripcionId, numeroSolicitud }` (reemplaza a `POST /patrocinio/suscripciones`). El plan debe aplicar al rol (como hoy, 403 `PLAN_NO_APLICA`). Con un país que no es CR responde 400 `PAGO_NO_DISPONIBLE`, igual que hoy.
- `GET /patrocinio/pagos/retorno` (público) y `POST /patrocinio/pagos/onvo/webhook` (público, con secreto).
- Un cobro que nunca se pagó no bloquea: si la persona vuelve a pagar, el intento anterior sin pagar se cierra (`Rechazada`, motivo "Pago no completado") y se crea uno nuevo.
- ONVO solo cobra en colones y solo para Costa Rica. Los montos van en la unidad mínima, como pide ONVO. Los precios en dólares y euros del resto del mundo se siguen mostrando, sin cobro.
- Variables de entorno (también en `render.yaml` como `sync: false`): `ONVO_SECRET_KEY`, `ONVO_WEBHOOK_SECRET`, `PUBLIC_BASE_URL` (URL pública del backend, para las URLs de retorno). Sin llaves, el pago responde 400 `PAGO_NO_DISPONIBLE` y la app lo explica.
- Las llaves nunca van al repo ni al chat.
- El admin conserva aprobar, rechazar y suspender (por ejemplo para activar a mano en una demo), pero una suscripción pagada en línea no los necesita.

## App (Flutter)
- La pantalla del plan quita las instrucciones de SINPE manual. Queda: plan, precio en la moneda de la región, el selector "Pagar desde" y el botón de pagar. Fuera de Costa Rica se conserva el aviso "PayPal para tu región estará disponible pronto" y el botón sale deshabilitado ("Pronto disponible").
- Al confirmar, abre una pantalla con WebView (`webview_flutter`, dependencia nueva) con barra superior y botón de cerrar. Un `NavigationDelegate` detecta la URL de retorno, cierra la pantalla y recarga el plan. No se pide el número de tarjeta en pantallas propias (evita PCI).
- Textos en es/en/pt/pt_BR: se quitan los de SINPE manual, se conservan los de PayPal "pronto" y se agregan los del pago.
- La pantalla de Gestión de suscripciones del admin muestra la referencia del pago.

## Pruebas
- Backend: cliente de ONVO detrás de una interfaz inyectable, con un servicio falso en los tests (monto desde el servidor, activación idempotente, webhook sin secreto rechazado, retorno sin pago no activa, rol incorrecto, intento anterior sin pagar se cierra).
- Flutter: pantalla del plan, pantalla de pago que se cierra al detectar la URL de retorno, recarga del plan. A verificar en el emulador: tarjeta aprobada `4242 4242 4242 4242`, declinada `4000 0000 0000 0002`, 3D Secure `4000 0000 0000 3220`, SINPE de prueba `+506 8888 8888`.
- En vivo con la llave de prueba de ONVO. Para el aviso automático hace falta una URL pública (Render); en local el pago se activa igual por la página de retorno.

## Lo que decidí yo (Diego puede cambiarlo)
- Un pago compra 30 días y para renovar se paga de nuevo; no hay cobros automáticos.
- ONVO solo para Costa Rica, aunque acepta tarjetas en dólares: fuera de Costa Rica se espera a PayPal.
- Las suscripciones ya activas o solicitadas por SINPE manual no se tocan: quedan como están.
