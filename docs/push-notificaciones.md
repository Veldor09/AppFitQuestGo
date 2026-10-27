# Avisos fuera de la app (push)

Cuando alguien tiene FitQuest Go cerrada, el celular le avisa **solo de lo que
de verdad importa**: el resultado de algo que pidió y que decide otra persona o
el tiempo. Todo lo demás se queda dentro de la app, en la campana.

## Qué avisa y qué no

| Sale del celular | Se queda en la campana |
| --- | --- |
| Tu ruta fue aprobada / no fue aprobada | "Ruta creada con éxito", "Alerta reportada" (lo acabas de hacer tú) |
| Tu punto de interés fue aprobado / no fue aprobado | Insignias nuevas |
| Tu alerta fue marcada como resuelta | Clima, "alerta cerca de ti", "destacado cerca de ti" (son del momento) |
| Tu plan de patrocinio: aprobado, rechazado, suspendido, vence pronto, venció | Cualquier otra cosa |

Reglas para no ser pesados:

- Solo salen los tipos de la lista cerrada `TipoPush`
  (`backend/src/Modules/Notificaciones/push/push-plantillas.ts`). Para avisar de
  algo nuevo hay que agregarlo ahí **a propósito**; nada sale "por defecto".
- Se respeta el interruptor **Notificaciones push** de Preferencias: apagado,
  no sale nada y el celular se da de baja.
- Máximo **5 avisos por persona por hora**. El resto queda en la campana sin sonar.
- Prioridad normal (no despierta el celular a la fuerza) y un aviso nuevo sobre
  lo mismo **reemplaza** al anterior en vez de apilarse.
- El texto sale en el **idioma de la app** de ese celular (es, en, pt).
- El permiso del sistema se pide **una sola vez**, unos segundos después de
  entrar; si la persona dice que no, no se insiste.

## Cómo funciona

```
admin aprueba una ruta
   └─ RutaService → NotificacionesService.crear({ ..., push: { tipo: RutaAprobada } })
        ├─ guarda la notificación (campana)            ← siempre
        └─ PushService.notificar(...)                   ← solo si trae `push`
             ├─ ¿la persona tiene "Notificaciones push" prendido?
             ├─ ¿le quedan avisos esta hora?
             └─ por cada celular suyo: ProveedorPush.enviar(texto en su idioma)
                    ├─ Firebase (si hay credenciales)
                    └─ nulo   (si no: no sale nada, todo lo demás funciona igual)
```

En el celular: `RegistroPush` (se monta al iniciar sesión) registra el
celular en `POST /notificaciones/push/dispositivo`; al cerrar sesión o apagar el
interruptor lo da de baja (`.../dispositivo/baja`). Tocar el aviso abre el
centro de notificaciones.

## Lo que hay que hacer una vez (Firebase)

Sin esto la app y el servidor funcionan igual; simplemente no sale nada del
celular. El servidor lo dice al arrancar: `Avisos fuera de la app desactivados`
o `Avisos fuera de la app: Firebase (<proyecto>)`.

1. Entrar a <https://console.firebase.google.com> → **Agregar proyecto**
   (por ejemplo `fitquestgo`). Google Analytics no hace falta.
2. En el proyecto → **Agregar app → Android**. Nombre del paquete:
   `com.veldor09.fit_quest_go`. Descargar **`google-services.json`** y ponerlo en
   `FitQuestGo/android/app/google-services.json`.
   - Ese archivo **no es secreto** (Firebase lo pone en toda app publicada) y
     **sí hay que hacerle commit**: los APK salen de la CI, que solo ve lo que
     está en git. Sin el archivo el APK sale sin avisos.
3. En el proyecto → ⚙ **Configuración → Cuentas de servicio → Generar nueva
   clave privada**. Baja un `.json`. **Ese sí es secreto: nunca va a git.**
4. En Render (servicio del backend) → **Environment** → crear
   `FIREBASE_SERVICE_ACCOUNT_BASE64` con el `.json` de la clave en base64:
   - PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("clave.json"))`
   - (alternativa: pegar el JSON tal cual en `FIREBASE_SERVICE_ACCOUNT_JSON`)
5. Reiniciar el backend. Render corre solo la migración
   `DispositivosPush1793000000000` (tabla `dispositivos_push`).

Para ensayarlo en local, las mismas variables en `backend/.env`.

## Cómo probarlo

1. Instalar un APK construido **con** `google-services.json`, iniciar sesión y
   aceptar el permiso (Android 13+ lo pide una vez).
2. Cerrar la app del todo (deslizarla).
3. Desde el panel de admin, aprobar o rechazar una ruta/punto de esa cuenta, o
   aprobar su solicitud de plan.
4. Debe sonar el aviso; tocarlo abre el centro de notificaciones.

Si no llega: revisar el log del backend (`FCM respondio ...`), que el interruptor
de Preferencias esté prendido y que ese celular aparezca en la tabla
`dispositivos_push`.

## Pendiente / límites conocidos

- **iOS**: no se va a presentar en iOS, asi que no se configuro (el codigo lo tolera, pero faltaria la llave APNs y una cuenta de Apple Developer).
- Los textos de las **notificaciones guardadas** (la campana) los escribe el
  servidor en español; solo el aviso del celular sale traducido. Traducir la
  campana pide guardar una clave + datos en vez de texto (cambio de modelo).
- Los avisos de la campana que genera la app sola (clima, alerta o destacado
  cerca) se guardan en el celular **en el idioma que tenía la app** al verlos.
