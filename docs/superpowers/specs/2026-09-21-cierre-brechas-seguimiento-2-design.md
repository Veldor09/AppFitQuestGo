# Cierre de brechas para Seguimiento #2 — diseño

**Fecha:** 2026-09-21
**Repos afectados:** `FitQuestGo` (Flutter, principal) y `backend` (NestJS)
**Motivación:** la tarjeta "Hito de Seguimiento #2 — 24/09" en Trello quedó en 9/10 tras la auditoría del 2026-09-21. El único criterio faltante es "Tracking básico funcionando". Además, la tarjeta "Auth / Login / Register" tenía dos huecos propios en su checklist: recuperación de contraseña y aceptación legal obligatoria en el registro. El usuario pidió cerrar los tres antes de la entrega.

Este spec cubre tres features independientes que comparten fecha límite pero no código entre sí (excepto que las tres tocan el módulo Auth/Rutas ya existente):

1. Tracking GPS básico (grabar una ruta caminando)
2. Recuperación de contraseña por correo
3. Aceptación legal obligatoria en el registro

---

## 1. Tracking GPS básico

### Objetivo
Que un usuario pueda grabar una ruta caminando con el GPS del teléfono, en vez de solo dibujarla tocando el mapa. Cumple literalmente "Ruta GPS" (checklist de la tarjeta Rutas) y "Tracking básico funcionando" (checklist del Hito #2).

### Alcance de esta ronda
- Grabación **solo en primer plano**: si el usuario apaga la pantalla o sale de la app, la grabación se corta. Ir a segundo plano (foreground service + `ACCESS_BACKGROUND_LOCATION`) es la forma correcta a largo plazo, pero queda fuera de esta ronda por tiempo — **anotado aquí como trabajo futuro explícito**, no lo pierdas de vista.
- La ruta grabada se guarda como una Ruta nueva e independiente, con el mismo flujo de moderación que ya existe (Privada → enviar a revisión → aprobación admin → Explorar). No hay verificación cruzada contra una ruta previamente planificada a mano.

### Arquitectura
Se extiende `PlanificarRutaScreen` (no se crea una pantalla paralela) porque ya tiene todo lo reutilizable: el `MapWidget`, el manejo de `_puntos`/`_pines`/`_lineas`, `_redibujar()`, el cálculo de distancia por haversine, y `_mostrarFormulario()` + `_guardar()` que llaman a `RutaApi.crear()`. Lo único que cambia según el modo es *cómo* se llenan los `_puntos`.

Se agrega:
- Un selector de modo arriba del mapa: **Dibujar** (comportamiento actual, sin cambios) / **Grabar GPS** (nuevo).
- En modo GPS, un botón **Iniciar grabación** reemplaza el banner de instrucciones. Al tocarlo:
  1. Pide permiso de ubicación con `Geolocator.requestPermission()` (paquete nuevo `geolocator`). Si lo niegan, muestra un mensaje claro y no arranca.
  2. Se suscribe a `Geolocator.getPositionStream()` con un `LocationSettings` que filtra por distancia mínima (`distanceFilter: 8` metros) para no ensuciar el trazo con ruido del GPS estando quieto.
  3. Cada posición nueva se agrega a `_puntos` (mismo tipo `PuntoRuta` de siempre) y dispara `_redibujar()`, igual que en modo Dibujar.
  4. La tarjeta inferior muestra distancia acumulada (ya calculada) + tiempo transcurrido desde que se inició.
- Botón **Detener** cancela la suscripción al stream. A partir de ahí el flujo es idéntico al existente: aparece "Guardar", abre el mismo formulario, llama a `RutaApi.crear()` sin cambios.
- Mientras graba, "Deshacer" y "Limpiar" quedan deshabilitados (no tiene sentido deshacer un punto de GPS en vivo).

### Backend
**Sin cambios.** `POST /rutas` ya acepta cualquier array de `puntos: {lat, lng}[]`; no le importa si vinieron de toques o de un stream de GPS.

### Permisos Android
Agregar a `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
No se agrega `ACCESS_BACKGROUND_LOCATION` en esta ronda (ver alcance arriba).

### Dependencia nueva
`geolocator: ^13.0.0` (o la última estable) en `pubspec.yaml`. Trae su propio manejo de permisos; no hace falta `permission_handler` aparte.

### Manejo de errores
- Permiso denegado → notificación de error clara, no intenta grabar.
- Permiso denegado permanentemente (`deniedForever`) → mensaje indicando que hay que habilitarlo desde Ajustes del sistema.
- Servicio de ubicación del dispositivo apagado → `Geolocator.isLocationServiceEnabled()` antes de suscribirse; si está apagado, mensaje pidiendo activarlo.
- Grabación con menos de 2 puntos al detener → igual que hoy, el botón "Guardar" sigue deshabilitado hasta tener al menos 2.

### Testing
No hay infraestructura de test de integración con GPS real (no tiene sentido simularlo en CI). Verificación será manual en el emulador vía `adb emu geo fix <lng> <lat>` para simular movimiento, igual que se hizo con las otras features este mismo mes.

---

## 2. Recuperación de contraseña por correo

### Objetivo
Que un usuario que olvidó su contraseña pueda recuperarla sin intervención de un admin, usando un correo real (Gmail).

### Decisión de diseño clave
La app no tiene dominio web ni deep-linking configurado, así que el correo **no lleva un link clickeable** — lleva un código de 6 dígitos que el usuario escribe a mano en la app. Evita tener que montar universal links / app links para esta única pantalla.

### Backend

**Entidad nueva** `RestablecimientoContrasena` (mismo patrón que `Auth` para refresh tokens — token opaco, hasheado con SHA-256, nunca se guarda en texto plano):

```ts
@Entity('restablecimientos_contrasena')
export class RestablecimientoContrasena {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  usuarioId: number;

  @Column({ type: 'varchar', length: 64 })
  hashCodigo: string; // sha256 del código de 6 dígitos

  @Column({ type: 'timestamptz' })
  expiraEn: Date; // creadoEn + 15 minutos

  @Column({ type: 'boolean', default: false })
  usado: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  creadoEn: Date;
}
```

**`MailService`** (nuevo, en `Modules/Auth/services/mail.service.ts`): envuelve `nodemailer` con un transport SMTP de Gmail, configurado desde `ConfigService` (agrego los getters a `AuthConfig`, mismo patrón que `secretoAccessToken` etc.):
- `GMAIL_USER`
- `GMAIL_APP_PASSWORD`

Si esas variables no están seteadas, el servicio lanza un error claro al intentar enviar (no falla silenciosamente) — así queda evidente en desarrollo que falta configurarlas, en vez de que el usuario piense que el correo se envió cuando no.

**Endpoints nuevos en `AuthController`:**
- `POST /auth/olvide-contrasena` `{ email }` → si el email existe, genera código de 6 dígitos, lo guarda hasheado con expiración de 15 min, envía el correo. Responde `204` en ambos casos (exista o no el email) para no filtrar qué correos están registrados. Con `@Throttle` como los otros endpoints de auth.
- `POST /auth/restablecer-contrasena` `{ email, codigo, nuevaContrasena }` → busca el restablecimiento vigente (no usado, no expirado) para ese email+código, si es válido actualiza `passwordUserHash` y marca `usado: true`. Si no es válido, `401` con mensaje genérico ("Código inválido o expirado").

**Migración nueva:** crea la tabla `restablecimientos_contrasena`.

### Flutter
- Link "¿Olvidaste tu contraseña?" en la pantalla de login.
- Pantalla 1: pedir email → llama a `/auth/olvide-contrasena` → siempre pasa a la pantalla 2 (no revela si el correo existe).
- Pantalla 2: campos código + nueva contraseña + confirmar contraseña → llama a `/auth/restablecer-contrasena` → si OK, vuelve al login con un toast de éxito; si falla, muestra el error y deja reintentar.
- Nuevos métodos en el cliente API de auth (`olvideContrasena`, `restablecerContrasena`).

### Configuración pendiente del usuario
El código queda completo y funcional, pero **no va a enviar correos reales hasta que agregues `GMAIL_USER` y `GMAIL_APP_PASSWORD` al `.env` del backend**. La contraseña de aplicación se genera en `myaccount.google.com/apppasswords` (requiere verificación en 2 pasos activada en la cuenta de Gmail). Avisame cuando la tengas y la agregamos.

### Testing
Test unitario del `MailService` con el transport de nodemailer mockeado (no se manda correo real en tests). Test del flujo `olvide-contrasena` → `restablecer-contrasena` en el service layer, verificando que un código usado o expirado se rechaza.

---

## 3. Aceptación legal obligatoria en el registro

### Objetivo
Que el registro exija aceptar términos de uso y política de privacidad, y quede registrado cuándo.

### Contenido
Redacto un texto estándar de Términos de Uso + Política de Privacidad para FitQuestGo (cubre: cuenta y uso aceptable, contenido generado por usuarios — nodos/rutas/alertas —, datos de ubicación, moderación, limitación de responsabilidad). Es un borrador razonable para un proyecto académico, no reemplaza asesoría legal profesional si el proyecto se usa en producción real.

### Backend
- `RegistroDto`: nuevo campo `aceptaTerminos: boolean`, con `@IsBoolean()` y una validación custom que rechace `false`.
- `User`: nueva columna `terminosAceptadosEn: timestamptz` (nullable en la entidad por compatibilidad con usuarios ya existentes, se setea al registrarse).
- Migración nueva: agrega la columna.

### Flutter
- Checkbox en el formulario de registro: "Acepto los Términos de Uso y la Política de Privacidad" con la frase "Términos de Uso y Política de Privacidad" como texto tocable que abre una pantalla (o bottom sheet) con el texto completo.
- El botón "Crear cuenta" queda deshabilitado hasta marcar el checkbox.
- El texto vive como una constante Dart simple (no hace falta traerlo del backend).

### Testing
Test de widget: el botón de registro está deshabilitado con el checkbox sin marcar, habilitado al marcarlo. Test del DTO en backend: rechaza `aceptaTerminos: false` o ausente.

---

## Resumen de archivos nuevos/tocados

**Backend:**
- `src/Modules/Auth/entities/restablecimiento-contrasena.entity.ts` (nuevo)
- `src/Modules/Auth/services/mail.service.ts` (nuevo)
- `src/Modules/Auth/auth.config.ts` (agrega getters de Gmail)
- `src/Modules/Auth/auth.controller.ts` (2 endpoints nuevos)
- `src/Modules/Auth/auth.service.ts` (2 métodos nuevos)
- `src/Modules/Auth/dto/registro.dto.ts` (+ `aceptaTerminos`)
- `src/Modules/Auth/dto/olvide-contrasena.dto.ts`, `restablecer-contrasena.dto.ts` (nuevos)
- `src/Modules/Usuarios/user.entity.ts` (+ `terminosAceptadosEn`)
- `src/migrations/` (2 migraciones nuevas: tabla de restablecimientos, columna de términos)
- `package.json` (+ `nodemailer`, `@types/nodemailer`)

**Flutter:**
- `lib/Modulos/rutas/presentation/planificar_ruta_screen.dart` (modo GPS)
- `lib/Modulos/auth/presentation/olvide_contrasena_screen.dart`, `restablecer_contrasena_screen.dart` (nuevas)
- `lib/Modulos/auth/presentation/login_screen.dart` (link "¿Olvidaste tu contraseña?")
- `lib/Modulos/auth/presentation/registro_screen.dart` (checkbox + link a términos)
- `lib/Modulos/auth/presentation/terminos_screen.dart` (nueva, texto legal)
- `lib/Modulos/auth/data/auth_api.dart` (2 métodos nuevos)
- `android/app/src/main/AndroidManifest.xml` (permisos de ubicación)
- `pubspec.yaml` (+ `geolocator`)
