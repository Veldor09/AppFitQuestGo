# Monetización: destacar — guion de demostración

**Fecha:** 2026-10-19 · **Para:** Seguimiento #4 (22/10) · **Diseño:** `2026-10-19-monetizacion-destacados-design.md`

Lo que se muestra: *el admin activa un plan → la cuenta destaca su comercio o evento → otra persona lo ve dorado y recibe el aviso → vence el plan → todo vuelve a lo normal solo.*

## Antes de empezar (preparación, una vez)

1. Base local arriba y el backend en el puerto 3001 con las migraciones al día (la nueva es `DestacarActivado`).
2. Mientras ADM-09A no esté desplegada no existe la tabla real de suscripciones: se siembra una local con `backend/scripts/demo-suscripcion.sql` (solo base local; da un plan de 30 días a `usuario@gmail.com` y a las cuentas Empresa). Cuando 09A llegue, el "plan" lo da el admin desde su pantalla y este script ya no hace falta.
3. En el emulador, la ubicación en San José (`adb emu geo fix -84.0907 9.9281`) y la app apuntando a `http://10.0.2.2:3001`.

## Recorrido (7 pasos)

| # | Quién | Qué hace | Qué se ve |
|---|---|---|---|
| 1 | Admin *(hoy, por la siembra)* | Activa el plan de la cuenta: 30 días, ₡10.000 en Costa Rica, US$20 en el resto, €18 en la zona euro. | La cuenta queda con plan vigente. Se puede consultar la moneda de cada país en `GET /patrocinio/moneda?pais=CR` (₡, sin decimales). |
| 2 | Usuario normal | Crea un punto de interés de categoría *comercio* y abre su ficha. | La ficha del dueño trae el interruptor **"Destacar en el mapa"**. En un punto de agua o de otra persona no aparece. |
| 3 | Usuario normal | Enciende el interruptor. | El pin pasa a **dorado con estrella** y la ficha lleva la etiqueta "Destacado". Sin plan, el interruptor avisa "Necesitas un plan de patrocinio vigente para destacar." |
| 4 | Otra persona | Pasa a menos de 1 km. | Aviso **"Destacado cerca de ti"** (uno a la vez, una sola vez por sesión) y una tarjeta dorada en el cuadro "Cerca de ti". Si hay una alerta de peligro cerca, el aviso de la alerta va primero. |
| 5 | Empresa | Destaca un local suyo y un evento. | El local y el evento salen dorados; el evento terminado ya no se puede destacar. |
| 6 | Sistema | El plan vence (en la demo: se adelanta el vencimiento en la base). | En el siguiente refresco del mapa (hasta 60 s) los pines dejan de ser dorados; **el contenido sigue publicado**, solo deja de estar destacado. El interruptor del dueño se conserva. |
| 7 | Sistema | Se renueva el plan. | Lo que tenía encendido vuelve a destacarse solo. El dueño recibe los avisos "por vencer" (3 días antes) y "venció" en su buzón (categoría **Patrocinio**). |

## Para forzar el vencimiento y la renovación en la demo

```sql
UPDATE suscripciones SET vence_en = now() - interval '1 minute';  -- vence
UPDATE suscripciones SET vence_en = now() + interval '30 days';   -- se renueva
```

## Qué decir sobre el modelo

- Plan único, renovación manual; tope de 20 destacados encendidos por cuenta (solo cuentan los visibles).
- Los ingresos son ficticios: lo que se evalúa es que sea posible cobrar. Proveedores propuestos en `2026-10-19-investigacion-pagos.md`: ONVO en Costa Rica, PayPal fuera, Tilopay de alterno.
