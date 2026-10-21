# Cierre de brechas Seguimiento #2 — Plan Maestro (Índice)

> 💾 **Respaldo original completo:** [2026-09-21-cierre-brechas-seguimiento-2.backup.md](./2026-09-21-cierre-brechas-seguimiento-2.backup.md) (2,608 líneas preservadas intactas por seguridad).
>
> ⚡ **Estructura modular:** Este plan se dividió en **3 sub-planes modulares** para agilizar la ejecución y edición en el entorno de desarrollo. Cada sub-plan contiene las tareas detalladas paso a paso con código de prueba y comandos ejecutables.

**Goal:** Cerrar los tres huecos identificados contra el checklist del Hito de Seguimiento #2 y el checklist de la tarjeta Auth: tracking GPS básico, recuperación de contraseña por correo, y aceptación legal obligatoria en el registro.

**Architecture:** Tres sub-features casi independientes que comparten el módulo Auth (backend) y el árbol `Modulos/auth` (Flutter). El tracking GPS no toca el backend en absoluto — reutiliza `POST /rutas` tal cual. La aceptación legal reutiliza UI ya existente (`RegistroFlujoScreen`, `TerminosModal`) que hoy no se comunica al backend. La recuperación de contraseña es la pieza nueva más grande: entidad + servicio de correo + dos endpoints + dos pantallas.

**Tech Stack:** NestJS + TypeORM + Postgres (backend), Flutter + `geolocator` + `mapbox_maps_flutter` (frontend), `nodemailer` para correo (backend, nuevo), `jest`/`ts-jest` (backend tests), `flutter_test` (Flutter tests).

**Spec:** [2026-09-21-cierre-brechas-seguimiento-2-design.md](../specs/2026-09-21-cierre-brechas-seguimiento-2-design.md)

**Nota sobre hallazgos durante la investigación:** El spec original asumía que había que construir la UI de aceptación legal desde cero (checkbox + pantalla de términos). Al explorar el código se encontró que **ya existe** en `lib/Modulos/auth/presentation/registro/registro_flujo.dart` y `lib/Modulos/auth/presentation/widgets/terminos_modal.dart`: el checkbox, la validación, el modal con texto legal completo. Lo único que falta es que ese `true` viaje hasta el backend y se persista. Las Tasks 1-2 reflejan esto — no crean pantallas nuevas, conectan las que ya existen. De la misma forma, el login (`login_screen.dart`) ya tiene un link "¿Olvidaste tu contraseña?" que hoy solo muestra un toast falso — la Task 8 lo conecta a las pantallas reales en vez de crear un link nuevo.

---

## Módulos y Sub-Planes

### [Fase 1: Aceptación Legal Obligatoria](./fase-1-legal.md)
*Plan detallado paso a paso en [fase-1-legal.md](./fase-1-legal.md)* (~480 líneas)
- [ ] **Task 1:** Backend — aceptación legal obligatoria (entidad + DTO + migración)
- [ ] **Task 2:** Backend — persistir `aceptaTerminos` al crear el usuario
- [ ] **Task 3:** Flutter — enviar `aceptaTerminos` desde el registro ya existente

---

### [Fase 2: Recuperación de Contraseña por Correo](./fase-2-recuperacion-auth.md)
*Plan detallado paso a paso en [fase-2-recuperacion-auth.md](./fase-2-recuperacion-auth.md)* (~1,300 líneas)
- [ ] **Task 4:** Backend — entidad y migración de restablecimiento de contraseña
- [ ] **Task 5:** Backend — `MailService` (nodemailer por Gmail)
- [ ] **Task 6:** Backend — DTOs y lógica de servicio de recuperación
- [ ] **Task 7:** Backend — endpoints de recuperación de contraseña
- [ ] **Task 8:** Flutter — pantallas de recuperación de contraseña

---

### [Fase 3: Tracking GPS Básico](./fase-3-tracking-gps.md)
*Plan detallado paso a paso en [fase-3-tracking-gps.md](./fase-3-tracking-gps.md)* (~790 líneas)
- [ ] **Task 9:** Flutter — dependencia `geolocator` y permisos Android
- [ ] **Task 10:** Flutter — modo GPS en `PlanificarRutaScreen`

---

## Notas de Ejecución y Cierre

- **Cobertura del spec:** Las 3 secciones del spec tienen cobertura completa.
- **Pendiente fuera de este plan:** Credenciales reales de Gmail (`GMAIL_USER`, `GMAIL_APP_PASSWORD`) para el `.env` en producción/pruebas.
