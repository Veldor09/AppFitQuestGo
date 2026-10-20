# Monetización: destacar comercios y eventos — diseño

**Fecha:** 2026-10-19
**Autor:** Diego Araya Vega (con Claude)
**Estado:** aprobado por Diego el 2026-10-19 (los acuerdos con José, sección 8.1.1, siguen por confirmar); nada de esto está construido todavía
**Repos afectados:** `FitQuestGo` (Flutter) y `backend` (NestJS)
**Tarjetas de Trello:** *Modulo - Monetización* (Seguimiento #4, Alondra y Diego), *ADM-09A* (Seguimiento #4, José Vallejos), *ADM-09B* (Seguimiento #5, sin responsable), *6 Pilares de Globalización* (Moneda y Pagos)

Este documento tiene dos partes: la **Parte A** (secciones 1 a 5) explica el negocio y se puede llevar tal cual al profesor; la **Parte B** (secciones 6 a 11 y anexos) es lo que hace falta para construirlo.

---

# Parte A — El negocio

## 1. Qué es y por qué

FitQuest Go es gratis para quien entrena. Para generar ingresos, **vende visibilidad local**: una suscripción mensual de patrocinio con la que una cuenta puede **destacar** en el mapa sus comercios o sus eventos.

La idea de fondo (dicha por Diego): quien pasa cerca de un comercio debe sentir más atracción de entrar *a ese* antes que a otros. Un destacado se ve distinto en el mapa (pin dorado con la marca "Destacado"), aparece primero en la búsqueda y avisa a quien pasa cerca ("¡Destacado cerca de ti!").

Los ingresos son **ficticios** en este curso: nadie paga dinero real. Lo que el profesor evalúa es que *sea posible* cobrar: un modelo coherente, precios por país, métodos de pago que funcionen en Costa Rica y en otras regiones, y un flujo que no se pueda engañar.

Referencias de producto (tarjeta *Benchmarking Strava vs Waze*): Waze vende pines promocionados a negocios cercanos; Strava cobra una suscripción mensual con precio local. Este modelo junta las dos ideas.

## 2. Objetivos, no objetivos y lo que sería un fracaso

**Objetivos**
1. Un modelo de negocio claro, con números, que se pueda defender (sección 5).
2. Que una cuenta con plan vigente destaque lo suyo, se vea en el mapa, y que al vencer el plan todo vuelva a lo normal solo.
3. Precio y moneda según el país, en colones, dólares y euros, con formato regional (pilar *Moneda*).
4. Una capa de pagos preparada para SINPE Móvil y Onvo y con PayPal en modo de pruebas funcionando (pilar *Pagos*; entrega del 29/10).
5. Todo auditable y seguro: el servidor decide importes y activaciones; la app nunca confirma un pago.

**No objetivos (por ahora)**
- Cobros reales, tarjetas procesadas por nosotros, renovación automática, planes anuales, cupones de descuento, pago por impresión o subasta.
- Un perfil de comercio completo con horarios y promociones (tarjeta *Patrocinadores / Comercios*, prioridad P2): "comercio" es lo que ya existe en el proyecto (sección 3).
- Facturación electrónica y detalle de impuestos (IVA): el precio se muestra final.
- Políticas de las tiendas de aplicaciones para compras dentro de la app: se revisan antes de cualquier producción real.

**Sería un fracaso aunque "funcione"**
- Que el mapa se llene de dorado y deje de ser útil.
- Que un destacado tape una alerta de peligro.
- Que un plan quede activo sin cobro confirmado (cuando haya pagos).
- Que alguien pague sin ver antes cuánto y en qué moneda.

## 3. Decisiones tomadas

| Tema | Decisión | Quién |
|---|---|---|
| Plan | Único, mismos beneficios para usuario normal y empresa; renovación manual | Trello 09A |
| Precio | ₡10.000 en Costa Rica, US$20 en el resto, **y una tercera moneda, el euro**, con precio configurable (sugerido €18, a aprobar) | Trello 09A + Diego |
| Duración | 30 días corridos desde la activación. Renovar suma desde el vencimiento si el plan sigue vigente; si ya venció, cuenta desde hoy | Diego |
| Publicaciones destacadas | "Ilimitadas" de cara al cliente, con un tope técnico configurable de **20 encendidas por cuenta** | Diego |
| Vencimiento | El contenido sigue publicado y deja de verse como destacado | Trello 09A |
| Qué es un "comercio" | Un negocio o similar que **ya existe en el proyecto**: un punto de interés propio y autorizado por el admin, o un local de empresa (nodo de abastecimiento) | Diego |
| Activación | En esta etapa, administrativa (el admin aprueba la solicitud). Con pagos (09B), solo tras un pago confirmado por el servidor | Trello 09A/09B |
| Reembolsos | Ninguno una vez activo, salvo cobro duplicado o error. Sin cobro automático no hay "cancelar": simplemente no se renueva. Una suspensión por romper las reglas no se devuelve | Claude, aprobada por Diego |
| Avisos al dueño | Plan aprobado, rechazado, suspendido, por vencer (3 días antes) y vencido | Claude, aprobada por Diego |
| Aviso a quien pasa cerca | A 1 km o menos, uno a la vez (el más cercano), una vez por destacado y por sesión, y nunca antes que una alerta de peligro | Claude, aprobada por Diego |
| Moneda por país | Costa Rica → colones; países de la zona euro → euros; el resto → dólares. El país de facturación lo elige quien paga y el servidor valida | Claude |
| Mapa de Home | Los marcadores, tarjetas y el aviso los dibuja Diego en Home; la API de 09A solo entrega `destacado` | Diego (2026-10-19) |
| Locales de empresa | La empresa destaca sus locales además de sus eventos | Diego (2026-10-19) |

## 4. Resolución de los pendientes de ADM-09A

La tarjeta de José deja cuatro cosas por definir. Con lo anterior quedan así:

1. **¿Qué comercios puede destacar un usuario normal?** Solo los **propios**: sus puntos de interés de categoría comercio, restaurante o taller. La autorización del admin ocurre al **aprobar la solicitud del plan**: al aprobar, revisa que esa persona tenga un comercio real (puede ver sus puntos en el detalle de usuario, ADM-03). No hay una marca aparte por punto en esta versión.
2. **¿Mes calendario o período fijo?** Período fijo de 30 días desde la activación.
3. **Precios y condiciones:** ₡10.000, US$20 y €18 (el euro y su valor, por aprobar), configurables desde el sistema. Condiciones de la sección 6.
4. **Proceso de activación administrativa:** el usuario o la empresa envía una *solicitud* (con su país de facturación); el admin la aprueba o la rechaza; al aprobar, se guardan fechas, precio, moneda y país vigentes en ese momento. Cuando exista 09B, la misma activación se dispara al confirmarse un pago.

## 5. Modelo de negocio (lienzo)

| Bloque | Contenido |
|---|---|
| **Segmentos** | (1) Dueños de comercios pequeños que ya son usuarios (sodas, talleres de bicicletas, tiendas deportivas). (2) Empresas que organizan eventos o tienen locales. (3) *No pagan:* las personas que entrenan, que son quien le da valor al mapa. |
| **Propuesta de valor** | Aparecer primero, en el momento en que la persona está cerca, por un precio fijo mensual; con la marca "Destacado" visible. |
| **Canales** | La propia app (mapa, búsqueda, aviso "cerca de ti") y el panel de empresa. |
| **Relación** | Autoservicio en la app; el admin aprueba y supervisa; avisos de vencimiento. |
| **Ingresos** | Suscripción mensual: ₡10.000 / US$20 / €18, renovación manual. Futuro: planes anuales, paquetes. |
| **Recursos clave** | La comunidad con GPS, el mapa (Mapbox), el backend y la base de datos, la moderación del admin. |
| **Actividades clave** | Moderar y autorizar comercios, operar y conciliar pagos, cuidar la calidad del mapa (tope, reglas). |
| **Socios** | Mapbox, la pasarela de pago (PayPal, Onvo, SINPE Móvil), el hosting (Render). |
| **Costos** | Hosting y base de datos, Mapbox (gratis hasta su cuota), comisión de la pasarela, tiempo de moderación, dominio. |

**Punto de equilibrio** (todos los números son **supuestos** para el curso, a confirmar en la investigación de pagos):
- Costos fijos ≈ US$25 al mes (hosting y base de datos de pago, dominio; Mapbox dentro de su cuota gratuita).
- Comisión de pasarela ≈ 5 %.
- Ingreso neto por suscriptor ≈ US$20 × 0,95 = **US$19** al mes.
- Equilibrio: 25 ÷ 19 ≈ **2 suscriptores**. Con 10 suscriptores, ≈ US$190 netos al mes; con 50, ≈ US$950.
- Riesgo principal del modelo: si todos destacan, nadie destaca. Por eso existen el tope por cuenta, el aviso de a uno y la prioridad de las alertas.

---

# Parte B — Cómo se construye

## 6. Reglas del producto

**Palabras que no hay que mezclar**
- `patrocinado` (ya existe): un local creado por una empresa. Sigue siendo gratis y **no cambia de significado**.
- `destacar` (el interruptor del dueño) y `destacado` (el resultado efectivo): lo nuevo y pagado.

**Quién puede destacar qué**

| Cuenta | Puede destacar | Condición |
|---|---|---|
| Usuario normal | Sus puntos de interés propios de categoría comercio, restaurante o taller | Suscripción vigente |
| Empresa | Sus eventos (con sus áreas y recorridos) y sus locales (nodos de abastecimiento) | Suscripción vigente |
| Admin | No destaca. Aprueba, rechaza y suspende planes; puede retirar contenido | — |

> La tarjeta 09A nombra para la empresa "eventos, áreas y recorridos"; sumar sus **locales** es una extensión de este diseño, confirmada por Diego el 19/10 (el local de una empresa es el "negocio" por excelencia). Las áreas y recorridos viven *dentro* del evento, sin identificador propio, así que se destaca **el evento** y sus zonas salen doradas con él.

**Qué significa "destacado"**

Un contenido está *efectivamente destacado* cuando se cumplen **todas** estas:
1. Su dueño lo tiene **encendido** (interruptor "Destacar").
2. El dueño tiene una **suscripción activa ahora** (inicio ≤ ahora < vencimiento).
3. El contenido está visible (punto aprobado; evento no terminado).
4. Si es un punto de un usuario normal: su categoría es comercio, restaurante o taller.

Nada se "apaga" con un trabajo programado: **se calcula al leer**, así el vencimiento es inmediato y no hay estados a medias. El interruptor del dueño se conserva: al renovar, lo que tenía encendido vuelve a destacarse.

**Límites y prioridades**
- Máximo **20 interruptores encendidos por cuenta** (puntos y eventos juntos); configurable. Se comprueba al encender, no al renovar.
- El aviso "cerca de ti" muestra **uno** a la vez y **cede ante cualquier alerta de peligro** (el aviso por voz y el banner de alertas van primero).
- En la búsqueda, a igual coincidencia, salen primero los destacados; el filtro del mapa y las alertas no cambian.
- Siempre se ve la marca "Destacado" (transparencia: es publicidad pagada).

**Precio y país**
- El importe lo decide **el servidor** según el país de facturación (código ISO de dos letras); la app solo lo muestra y nunca lo envía.
- El país de facturación se elige al solicitar (por defecto el de la región del teléfono) y se guarda con la solicitud junto al precio, la moneda y el país usados.
- Quien paga ve **precio y moneda antes de confirmar**.

**Estados de la suscripción** (nombres estables, a confirmar con 09A): `Solicitada` → `Activa` → `Vencida` o `Suspendida`; o `Rechazada`. "Vigente" significa `Activa` y dentro de fechas.

## 7. Lo que ve cada persona

Referencia visual: la maqueta *Mapa de eventos destacados en Nicoya* adjunta a la tarjeta Monetización.

**Quien usa el mapa (cualquier persona)**
- Pin dorado con estrella y la marca "Destacado", por encima de los demás pines; al tocarlo, una tarjeta con el nombre, "Destacado" y la distancia.
- Banner "¡Destacado cerca de ti!" cuando pasa a 1 km o menos; se cierra con la X y al tocarlo abre la ficha.
- En el cuadro inferior "Cerca de ti", una tarjeta dorada del destacado más cercano, sobre las de ruta y alerta.
- En la búsqueda, los destacados primero.

**Dueño (usuario normal o empresa)**
- **Mi plan:** estado, vencimiento, precio y moneda, "Solicitar" o "Renovar", e historial. *Esta pantalla está en la tarjeta de José (09A) y 09B le agrega el pago.*
- **Interruptor "Destacar"** en la ficha de su punto, y en las listas *Mis locales* y *Mis eventos* de la empresa. Si no se puede, dice por qué: sin plan (con acceso a "Mi plan"), tope de 20, o contenido no elegible.
- Avisos: plan aprobado, rechazado, suspendido, por vencer y vencido.

**Admin:** lo define la tarjeta 09A (pantalla de patrocinadores, aprobar, rechazar, suspender, historial).

## 8. Diseño técnico

### 8.1 Frontera con ADM-09A y lo que esta parte necesita de ella

La tarjeta de José cubre el sistema de suscripciones (entidades, planes y precios configurables, solicitudes y renovaciones, activación, rechazo y suspensión, validaciones, vencimiento, historial), la pantalla de administración y varias pantallas de cliente. **Este diseño no la redefine.** Lo que esta parte construye encima:

| De ADM-09A (como está en su tarjeta) | De este trabajo |
|---|---|
| Entidades de suscripción, planes y precios, solicitudes | Reglas de "destacar" y su interruptor |
| Aprobar, rechazar, suspender; historial | "Destacado" efectivo en lecturas públicas y orden |
| Vencimiento de la condición de destacado | Marcadores, tarjetas y aviso "cerca de ti" en el mapa (*a confirmar: sección 8.1.1*) |
| Pantalla admin y "Mi plan" | Catálogo de monedas, formato regional y país de facturación |
| | Avisos al dueño (textos y categoría) |
| | Pagos (09B) y su investigación |

**8.1.1 Acuerdos a confirmar con José** (lo que esta parte necesita; están en el Anexo B para enviarlos):
1. Una forma barata de saber si una cuenta tiene **suscripción vigente ahora**, utilizable desde SQL y desde un servicio.
2. Un punto único para **activar y renovar** una solicitud, que lo pueda invocar el admin y, en 09B, la confirmación de un pago, dejando auditoría.
3. Endpoints de cliente: planes con precio y moneda por país, mi suscripción actual y crear solicitud (con país de facturación).
4. Estados con nombres estables: `Solicitada`, `Activa`, `Vencida`, `Suspendida`, `Rechazada`.
5. Que cada acción del admin (aprobar, rechazar, suspender) llame a las notificaciones, y un aviso previo al vencimiento.
6. **Quién dibuja los marcadores y tarjetas en el mapa.** Están en la lista de Flutter de 09A, pero el mapa de Home es código de Diego. Confirmado por Diego el 19/10: la API entrega `destacado` y Diego lo dibuja en Home.
7. **Migraciones:** Render despliega `Developer` solo y corre las migraciones (`RUN_MIGRATIONS=true`): se revisan, se respalda la base y se autorizan **antes** de mergear.

### 8.2 Backend (esta parte)

**Datos** (migración nueva, revisada antes de mergear):
- `nodos.destacar_activado boolean not null default false` y `eventos.destacar_activado boolean not null default false`: el interruptor del dueño.
- Límite de destacados por cuenta: ajuste configurable (la forma exacta, junto a los precios de 09A).

**Endpoints**
- `PATCH /nodos/:id/destacar` y `PATCH /eventos/:id/destacar` con `{ destacar: boolean }`, solo el dueño. Reglas: dueño; elegibilidad (local de empresa = `patrocinado` con dueño empresa; punto de usuario normal = `patrocinado` falso y categoría comercio, restaurante o taller; evento = dueño empresa); suscripción vigente (para encender); tope de 20 (para encender). Apagar siempre se puede. Responde con el estado efectivo.
- Lecturas públicas `GET /nodos` y `GET /eventos`: agregan `destacado` (**efectivo**) y devuelven los destacados primero. Se calcula uniendo con las suscripciones vigentes del dueño; no se guarda. Las lecturas del dueño (`/nodos/mios` y equivalentes) devuelven además `destacarActivado`.
- Catálogo de monedas y resolución país → moneda dentro de la respuesta de planes (sección 8.4).

**Avisos:** categoría nueva `patrocinio` (la columna es de texto, sin migración) y referencia `suscripcion`; la pantalla de notificaciones agrega su filtro. Un trabajo programado diario envía "por vencer" y "venció" sin duplicar.

**Seguridad:** JWT y roles validados en el backend; nada se confía de lo que mande Flutter.

### 8.3 Flutter (esta parte)

- `Nodo` y `Evento` ganan `destacado` (y `destacarActivado` en las listas del dueño); un `TipoPin` destacado nuevo (dorado, estrella; `FqColors.amber`) en una capa superior de anotaciones, de modo que quede sobre los demás pines.
- **Home:** capa y tarjeta de destacados, banner "cerca de ti" (con la misma idea de `ProximidadAlertas`, sobre el GPS que ya se escucha), tarjeta dorada en `PanelCercano`, y `buscarEnMapa` con los destacados primero a igualdad.
- **Interruptor "Destacar"** en `FichaNodo` (solo el dueño), y en las listas de la empresa (`mis_nodos_screen`, `mis_eventos_screen`).
- `PatrocinioApi` que consume los endpoints de 09A y un `PrecioPlan` que formatea importe y moneda.
- Textos en es, en, pt y pt_BR; pruebas con fakes (como `home_falsos.dart`); verificación en el emulador.

### 8.4 Moneda y país (pilar *Moneda*)

- Catálogo de **CRC, USD y EUR** con símbolo, decimales y formato regional (`intl`): ₡ sin decimales; US$ y € con dos. Fijado igual en backend y Flutter y blindado con una prueba de contrato (como `catalogos-contrato.spec.ts`).
- País → moneda: Costa Rica → CRC; zona euro → EUR; resto → USD. Es una tabla configurable; el servidor la usa y la app solo muestra.
- **Sin conversión de tipo de cambio:** cada moneda tiene su propio precio configurado (₡10.000, US$20, €18), así que no hace falta ninguna API de cambio.
- PayPal no ofrece colones como moneda de cobro (a confirmar en la investigación); por PayPal a Costa Rica se cobraría el equivalente en dólares.

### 8.5 Pagos (ADM-09B, entrega del 29/10; se prepara antes)

La tarjeta pide métodos **reales** con ONVO, SINPE Móvil y PayPal por investigar; el pilar *Pagos* pide solo **preparar** la integración. Diseño:

- **Interfaz `ProveedorPago`** en el backend: crear cobro, verificar, procesar webhook verificado, reembolsar. Adaptadores:
  - `PayPal` (modo de pruebas): crear y capturar la orden; webhook con firma verificada.
  - `SINPE Móvil`: sin API pública para comercios (a confirmar); se muestran el número, el monto y una referencia, la persona ingresa el número de comprobante y el **admin verifica y confirma**.
  - `Onvo`: investigar si hay modo de pruebas, comisión y soporte; la interfaz queda lista.
- **Tabla `pagos`:** suscripción o solicitud, proveedor, referencia externa (**única por proveedor**, evita procesar dos veces), estado (`Pendiente`, `Aprobado`, `Rechazado`, `Cancelado`, `Reembolsado`), importe en la unidad mínima, moneda, país de facturación, fechas y un resumen sin datos sensibles.
- Reglas de seguridad de la tarjeta: importe y moneda **validados en el servidor**; solo se activa un plan con un pago confirmado por el proveedor (webhook o verificación servidor a servidor, nunca por Flutter); no se guardan datos de tarjeta; credenciales en variables de entorno; pagos fallidos, cancelados y reembolsados quedan registrados; transacción con restricción única para evitar activaciones duplicadas.
- **Flutter:** contratación (precio, moneda, método), estados de la transacción, confirmación, historial, reintentos.
- **Investigación de pagos** (Checklist 1 de 09B: documentación de ONVO, SINPE Móvil y PayPal, comisiones, países y monedas, proveedor principal y alterno): se hace antes del 22/10 y alimenta el pilar.

## 9. Entrega y riesgos

**Antes del 22/10 (Seguimiento #4)**
1. Este diseño aprobado y los acuerdos con José cerrados.
2. Investigación de pagos (ONVO, SINPE Móvil, PayPal) con proveedor principal y alterno.
3. Catálogo de monedas, formato regional y país de facturación.
4. Reglas de "destacar" (backend e interruptor), "destacado" efectivo en lecturas, y pines, tarjeta, aviso y búsqueda en el mapa.
5. Avisos al dueño.
6. Demostración: *el admin activa un plan → la cuenta destaca su comercio o evento → otra persona lo ve dorado y recibe el aviso → vence el plan → todo vuelve a lo normal*.

**Antes del 29/10 (Seguimiento #5):** pagos de 09B (PayPal en pruebas, SINPE Móvil con verificación del admin, Onvo según lo que muestre la investigación).

**Riesgos**
- **09A está en 0/40 a 3 días del hito** y esta parte depende de sus entidades. Mitigación: acordar hoy el contrato (8.1.1); mientras tanto probar contra un servicio falso; para la demostración se puede sembrar una suscripción directamente en la base de pruebas.
- **Cuentas y credenciales de los proveedores** (dependencia de 09B): la de pruebas de PayPal se crea al instante; Onvo, y SINPE Móvil si pasa por una pasarela, piden cuenta comercial y credenciales que pueden tardar más que el plazo.
- **Migraciones en producción:** revisar y respaldar antes de mergear a `Developer`.
- **Conflictos en `home_usuario_screen.dart`** si dos personas lo tocan: por eso la sección 8.1.1 pregunta quién dibuja el mapa.
- El plazo es corto: todo lo que no esté en la lista del 22/10 se corta antes que el modelo o la demostración.

## 10. Pruebas y criterios de aceptación

- Un usuario normal con plan vigente enciende "Destacar" en su punto de comercio y se ve dorado; en un punto de otra categoría, o ajeno, no puede.
- Una empresa con plan vigente destaca eventos y locales; sin plan, no.
- Sin plan, o con el plan vencido, nada aparece destacado, aunque el interruptor siga encendido; al renovar, vuelve.
- El tope de 20 se respeta; apagar siempre funciona.
- El aviso "cerca de ti" sale una vez, a 1 km o menos, y cede ante una alerta de peligro.
- Precio y moneda cambian con el país de facturación y los valida el servidor.
- Pruebas automatizadas del backend y de Flutter en verde, y verificación en el emulador.

**Pruebas:** reglas de destacar (dueño, tipo de cuenta, categoría, vigencia, tope, efectivo al leer), prueba de contrato del catálogo de monedas, orden de la búsqueda, aviso de proximidad (radio, una vez, prioridad de alertas), formato de precio por idioma y moneda.

## 11. Lo que queda a criterio de quien construya

- Nombres exactos de tablas y columnas, y la forma de guardar el límite y los precios (de la mano de 09A).
- Cómo unir con las suscripciones vigentes en SQL para que las lecturas sigan siendo rápidas.
- El detalle visual de los pines dorados de eventos (pin del área o del recorrido), el punto del evento que se usa para la distancia, y la tarjeta.
- Cómo evitar avisos duplicados de "por vencer" y "venció".
- La lista exacta de países de la zona euro para el catálogo país → moneda.
- Qué proveedor concreto queda como principal tras la investigación de pagos.

---

## Anexo A — Checklist para la tarjeta *Modulo - Monetización* ("Que le hace falta")

- [ ] Modelo de negocio aprobado (documento, lienzo y punto de equilibrio)
- [ ] Investigación de pagos: ONVO, SINPE Móvil y PayPal (comparación, proveedor principal y alterno)
- [ ] Acordar con ADM-09A el contrato de vigencia, activación y estados
- [ ] Catálogo de monedas CRC, USD y EUR con formato regional y país → moneda
- [ ] Backend: reglas de "destacar" en puntos y eventos (dueño, tipo de cuenta, vigencia, tope de 20)
- [ ] Backend: "destacado" efectivo en lecturas públicas, destacados primero
- [ ] Flutter: interruptor "Destacar" (ficha del punto, mis locales, mis eventos)
- [ ] Flutter mapa: pines dorados y tarjeta "Destacado" (según la maqueta de Nicoya)
- [ ] Flutter: aviso "¡Destacado cerca de ti!" y destacados primero en la búsqueda
- [ ] Avisos al dueño: aprobado, rechazado, suspendido, por vencer, vencido
- [ ] Textos en es, en, pt y pt_BR
- [ ] Pruebas de backend y Flutter, y verificación en el emulador
- [ ] Guion de demostración para el profesor
- [ ] Documentación y Pull Requests

## Anexo B — Acuerdos para confirmar con José (09A)

Mensaje sugerido:

> José, para que lo de Monetización encaje con 09A necesito acordar:
> 1) Una forma de saber si una cuenta tiene suscripción vigente ahora (que se pueda usar en SQL y en un servicio).
> 2) Un punto único para activar/renovar una solicitud que pueda llamar el admin y, en 09B, la confirmación de un pago, con auditoría.
> 3) Endpoints de cliente: planes con precio y moneda por país, mi suscripción y crear solicitud (con país de facturación).
> 4) Estados: Solicitada, Activa, Vencida, Suspendida, Rechazada.
> 5) Que aprobar, rechazar y suspender llamen a las notificaciones.
> 6) Los marcadores y tarjetas del mapa de Home los dibujo yo: tu API solo me entrega `destacado`.
> 7) Antes de mergear una migración a Developer, avisame: Render la corre sola.
>
> Resolví los 4 pendientes de tu tarjeta (usuarios: comercios propios autorizados al aprobar; mes: 30 días; precios: ₡10.000 / US$20 / €18; activación: solicitud → admin aprueba) en `docs/superpowers/specs/2026-10-19-monetizacion-destacados-design.md`.
