# Monetización: destacar comercios y eventos (entrega 22/10) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que una cuenta con plan vigente destaque sus comercios o eventos, que se vean dorados en el mapa con aviso "cerca de ti", y que al vencer el plan todo vuelva a lo normal solo.

**Architecture:** Un módulo nuevo `Patrocinio` en el backend (puerto de vigencia sobre la tabla `suscripciones` de ADM-09A, servicio con las reglas de destacar, avisos al dueño) y un módulo `patrocinio` en Flutter (interruptor, capa de pines dorados, aviso). "Destacado" se calcula al leer; nada lo apaga. Los controladores de Nodos y Eventos componen la respuesta con `DestacadosService`, sin tocar `NodoService` ni `EventoService` (así no se rompen sus pruebas).

**Tech Stack:** NestJS + TypeORM + Postgres + `@nestjs/schedule` + jest (backend, `D:\FitQuestGo\backend`); Flutter + `mapbox_maps_flutter` + `intl` + `flutter_test` (`D:\FitQuestGo\FitQuestGo`).

**Spec:** `docs/superpowers/specs/2026-10-19-monetizacion-destacados-design.md` (se lee junto con este plan).

**Fuera de este plan:** los pagos de 09B (plan aparte, después de `docs/superpowers/specs/2026-10-19-investigacion-pagos.md`); "Mi plan", la pantalla admin y los endpoints de planes y solicitudes (09A, de José), y por eso también `PatrocinioApi` y `PrecioPlan` de Flutter, que se escriben cuando 09A publique la forma de sus respuestas. `GET /nodos/:id` y `GET /eventos/:id` no llevan `destacado` (la app no los usa).

## Global Constraints

- **Sin commits ni push** (regla de Diego): cada tarea termina con el árbol compilando y sus pruebas en verde; los commits los hace él. Tampoco se compila ningún APK (los saca el CI de git); solo la compilación de depuración para el emulador.
- Máximo **20** interruptores encendidos por cuenta (puntos y eventos juntos), configurable con `DESTACADOS_LIMITE`; solo cuenta lo que sigue visible (punto `Aprobado`, evento que no terminó).
- Destacado efectivo = interruptor encendido ∧ suscripción `Activa` ahora (inicia ≤ ahora < vence) ∧ contenido visible (punto `Aprobado`; evento no terminado) ∧ elegible. Se calcula al leer.
- Elegibilidad: usuario normal (`RoleId.UserNormal`) → sus puntos propios con `patrocinado` falso y categoría `comercio`, `restaurante` o `taller`; empresa (`RoleId.Empresa`) → sus eventos y sus locales (`patrocinado` verdadero); admin → nada. `patrocinado` no cambia de significado. Los puntos se publican `Aprobado` al crearse; `Rechazado` y `Obsoleto` los sacan del mapa.
- **No copiar entidades al componer respuestas** (`{ ...x }`): el recorte de `creadoPor` a `{ id, nombreUser }` (`@SoloAutorPublico`) depende de que siga siendo la misma instancia. `destacado` se asigna sobre el mismo objeto.
- Aviso "cerca de ti": a **1 km o menos**, **uno a la vez** (el más cercano), **una vez por destacado y por sesión**, y **cede ante cualquier alerta de peligro**.
- Monedas: CRC `₡` (0 decimales), USD `US$` (2), EUR `€` (2); símbolo adelante; `₡10.000` / `US$20,00` / `€18,00` en es, pt y pt_BR; `₡10,000` / `US$20.00` / `€18.00` en en.
- Textos en es, en, pt y pt_BR; las ARB del proyecto usan texto sin tildes ni `¡` `¿`.
- Migraciones: se revisan, se respalda la base y se autorizan **antes de mergear** (Render corre `RUN_MIGRATIONS=true` al desplegar `Developer`); aquí solo se ejecutan en la base local.
- Contrato asumido con ADM-09A (a confirmar con José, Anexo B del spec): tabla `suscripciones(id, usuario_id, estado, inicia_en, vence_en)` con estado `Activa`.
- Pruebas con fakes (en Flutter, `test/helpers/home_falsos.dart` y `datos_mapa.dart`); `flutter analyze` sin avisos nuevos.
- Comandos: backend `node node_modules/jest/bin/jest.js <ruta>`, `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json`, `node node_modules/eslint/bin/eslint.js <archivos>`; Flutter `flutter test <ruta>`, `flutter analyze`, `flutter gen-l10n`.

## Review Focus

1. **Aún no existe `suscripciones`** (09A sin mergear): el servidor sigue respondiendo y nada sale destacado. → Tarea 2.
2. **Plan vencido, o evento terminado, con el interruptor aún encendido:** no se ve destacado; al renovar vuelve sin tocar nada; y lo terminado o retirado no ocupa cupo del tope (su interruptor ya no se puede apagar desde la app). → Tarea 3.
3. **Votar un punto destacado no le quita el dorado**, y el refresco de 60 s del mapa recoge un cambio de `destacado` (hoy solo redibuja si cambian id, estado o votos): sin esto el plan vencido seguiría dorado hasta reiniciar la app. → Tareas 4 y 11.
4. **Una alerta de peligro y un destacado a la vez:** solo se avisa la alerta; **dos destacados** dentro del radio: primero el más cercano y uno cerrado no vuelve. → Tarea 11.
5. **La lectura pública no filtra el correo del dueño:** componer `destacado` no puede copiar la entidad. → Tarea 3.

## Antes de empezar

- [ ] Diego envía a José el **Anexo B** del spec (contrato de vigencia, activación y estados). Sin su respuesta se sigue con el contrato asumido arriba; solo cambiaría la Tarea 2.
- [ ] Ramas al día con `origin` (Diego las sincroniza; o `git fetch --all` y `git merge --ff-only origin/developer` en Flutter y `origin/Developer` en el backend, que no crean commits) y `flutter pub get`. Anotar cuántas pruebas pasan antes de tocar nada (línea base).

---

## Backend (`D:\FitQuestGo\backend`)

### Task 1: Catálogo de monedas y país → moneda

**Files:**
- Create: `src/Modules/Patrocinio/monedas.ts`
- Test: `src/Modules/Patrocinio/monedas.spec.ts`
- Modify: `src/Modules/catalogos-contrato.spec.ts` (un `it('monedas …')` nuevo; la misma lista va en `test/catalogos_test.dart` de Flutter, Tarea 6)

**Interfaces:**
- Produces: `type CodigoMoneda = 'CRC' | 'USD' | 'EUR'`; `interface Moneda { codigo: CodigoMoneda; simbolo: string; decimales: number }`; `const MONEDAS: readonly Moneda[]`; `const PAISES_ZONA_EURO: readonly string[]`; `function monedaParaPais(pais?: string | null): CodigoMoneda`.

- [ ] **Step 1: Escribir las pruebas que fallan**

```ts
// catalogos-contrato.spec.ts
it('monedas (codigo, simbolo, decimales)', () => {
  expect(MONEDAS.map((m) => [m.codigo, m.simbolo, m.decimales])).toEqual([
    ['CRC', '₡', 0],
    ['USD', 'US$', 2],
    ['EUR', '€', 2],
  ]);
});

// monedas.spec.ts
it('Costa Rica paga en colones, sin importar mayusculas ni espacios', () => {
  expect(monedaParaPais('CR')).toBe('CRC');
  expect(monedaParaPais(' cr ')).toBe('CRC');
});
it('la zona euro (21 paises, Bulgaria desde 2026) paga en euros', () => {
  expect(PAISES_ZONA_EURO).toEqual(['AT','BE','BG','CY','DE','EE','ES','FI','FR','GR','HR','IE','IT','LT','LU','LV','MT','NL','PT','SI','SK']);
  for (const pais of PAISES_ZONA_EURO) expect(monedaParaPais(pais)).toBe('EUR');
});
it('el resto del mundo, y lo vacio o desconocido, paga en dolares', () => {
  for (const pais of ['US', 'MX', 'BR', 'XX', '', null, undefined]) {
    expect(monedaParaPais(pais)).toBe('USD');
  }
});
```

- [ ] **Step 2: Correrlas y ver que fallan** — `node node_modules/jest/bin/jest.js src/Modules/Patrocinio/monedas.spec.ts src/Modules/catalogos-contrato.spec.ts` → FAIL: `Cannot find module './monedas'`.
- [ ] **Step 3: Implementar `monedas.ts`** con las firmas de arriba; `monedaParaPais` recorta y pasa a mayúsculas antes de comparar.
- [ ] **Step 4: Correrlas** → PASS (4 pruebas nuevas).

### Task 2: Puerto de vigencia sobre `suscripciones`

**Files:**
- Create: `src/Modules/Patrocinio/suscripciones-vigentes.ts`
- Test: `src/Modules/Patrocinio/suscripciones-vigentes.spec.ts`

**Interfaces:**
- Produces: `interface SuscripcionPorVencer { suscripcionId: number; usuarioId: number; venceEn: Date }`; `interface SuscripcionesVigentes { conVigencia(usuarioIds: number[], ahora?: Date): Promise<Set<number>>; vencenEntre(desde: Date, hasta: Date): Promise<SuscripcionPorVencer[]> }`; `const SUSCRIPCIONES_VIGENTES = Symbol('SUSCRIPCIONES_VIGENTES')`; `@Injectable() class SuscripcionesVigentesSql implements SuscripcionesVigentes` con constructor `(private readonly dataSource: DataSource)`.

- [ ] **Step 1: Escribir las pruebas que fallan** (con `dataSource = { query: jest.fn() }`)

```ts
it('sin usuarios no consulta nada', async () => {
  expect(await puerto.conVigencia([])).toEqual(new Set());
  expect(dataSource.query).not.toHaveBeenCalled();
});
it('devuelve los usuarios con suscripcion Activa y vigente ahora', async () => {
  dataSource.query.mockResolvedValue([{ usuario_id: 1 }, { usuario_id: 3 }]);
  const ahora = new Date('2026-10-20T12:00:00Z');
  expect(await puerto.conVigencia([1, 2, 3], ahora)).toEqual(new Set([1, 3]));
  const [sql, parametros] = dataSource.query.mock.calls[0];
  expect(sql).toContain("estado = 'Activa'");
  expect(sql).toContain('inicia_en <= $2');
  expect(sql).toContain('vence_en > $2');
  expect(parametros).toEqual([[1, 2, 3], ahora]);
});
it('si la tabla aun no existe (42P01) responde que nadie tiene plan', async () => {  // Review Focus 1
  dataSource.query.mockRejectedValue(Object.assign(new Error('no existe'), { driverError: { code: '42P01' } }));
  expect(await puerto.conVigencia([1])).toEqual(new Set());
  expect(await puerto.vencenEntre(new Date(), new Date())).toEqual([]);
});
it('cualquier otro error de la base se propaga', async () => {
  dataSource.query.mockRejectedValue(new Error('caida'));
  await expect(puerto.conVigencia([1])).rejects.toThrow('caida');
});
it('vencenEntre devuelve id, usuario y fecha de las Activa o Vencida que vencen en (desde, hasta]', async () => {
  const venceEn = new Date('2026-10-23T18:00:00Z');
  dataSource.query.mockResolvedValue([{ suscripcion_id: 9, usuario_id: 4, vence_en: venceEn }]);
  expect(await puerto.vencenEntre(new Date('2026-10-20T00:00:00Z'), new Date('2026-10-24T00:00:00Z')))
    .toEqual([{ suscripcionId: 9, usuarioId: 4, venceEn }]);
  expect(dataSource.query.mock.calls[0][0]).toContain("estado IN ('Activa', 'Vencida')");
});
```

- [ ] **Step 2: Correrla** → FAIL por módulo inexistente.
- [ ] **Step 3: Implementar `SuscripcionesVigentesSql`** con estas dos consultas (único lugar que conoce la tabla de 09A):
  `SELECT DISTINCT usuario_id FROM suscripciones WHERE usuario_id = ANY($1) AND estado = 'Activa' AND inicia_en <= $2 AND vence_en > $2` y
  `SELECT id AS suscripcion_id, usuario_id, vence_en FROM suscripciones WHERE estado IN ('Activa', 'Vencida') AND vence_en > $1 AND vence_en <= $2 ORDER BY vence_en`.
  El error `42P01` se reconoce en `error.driverError?.code` (como `esViolacionDeUnicidad` en `src/common/postgres.ts`); se registra una sola vez con `Logger.warn`.
- [ ] **Step 4: Correrla** → PASS (5 pruebas).

### Task 3: Columnas, migración y reglas de destacar

**Files:**
- Create: `src/migrations/1792400000000-DestacarActivado.ts`, `src/Modules/Patrocinio/destacados.service.ts`
- Modify: `src/Modules/Nodos/nodo.entity.ts`, `src/Modules/Eventos/evento.entity.ts` (agregar `@Column({ name: 'destacar_activado', type: 'boolean', default: false }) destacarActivado?: boolean;`, **opcional** para no romper los literales `Nodo` de las pruebas existentes)
- Test: `src/Modules/Patrocinio/destacados.service.spec.ts`

**Interfaces:**
- Consumes: `SuscripcionesVigentes` / `SUSCRIPCIONES_VIGENTES` (Tarea 2).
- Produces: `type CodigoDestacar = 'DESTACAR_SIN_PLAN' | 'DESTACAR_TOPE' | 'DESTACAR_NO_ELEGIBLE'`; `interface ResultadoDestacar { id: number; destacarActivado: boolean; destacado: boolean }`; `type ConDestacado<T> = T & { destacado: boolean }`; `const CATEGORIAS_COMERCIO: readonly CategoriaNodo[]` (`Comercio`, `Restaurante`, `Taller`); `function limiteDestacados(): number`; `class DestacadosService` (constructor con `@InjectRepository(Nodo)`, `@InjectRepository(Evento)`, `@Inject(SUSCRIPCIONES_VIGENTES)`):
  - `destacarNodo(id: number, actual: UsuarioAutenticado, destacar: boolean, ahora?: Date): Promise<ResultadoDestacar>` y `destacarEvento(...)` con la misma forma;
  - `nodosConDestacado<T extends { creadoPor: { id: number }; patrocinado: boolean; categoria: string; estado: string; destacarActivado?: boolean }>(nodos: T[], ahora?: Date): Promise<ConDestacado<T>[]>`;
  - `eventosConDestacado<T extends { creadoPor: { id: number }; fechaFin: Date; destacarActivado?: boolean }>(eventos: T[], ahora?: Date): Promise<ConDestacado<T>[]>`;
  - `nodoConDestacado<T>(nodo: T, ahora?: Date): Promise<ConDestacado<T>>` y `eventoConDestacado<T>(evento: T, ahora?: Date)`: lo mismo para uno solo.
  Los errores son `ForbiddenException(<código>)` (el código viaja como `message`, que es lo que lee `ApiException` en Flutter). Los mensajes de dueño son los que ya usan los servicios: `'Este nodo no te pertenece'`, `'Este evento no te pertenece'`, y `NotFoundException` `'Nodo <id> no encontrado'` / `'Evento <id> no encontrado'`.

- [ ] **Step 1: Escribir las pruebas que fallan** (repos falsos `{ findOne, save, count }`; `vigentes.conVigencia` devuelve un `Set`; punto base `{ id: 5, categoria: 'comercio', patrocinado: false, estado: 'Aprobado', destacarActivado: false, creadoPor: { id: 7 } }`; reglas en este orden: existe → dueño → si `destacar` es falso, guardar y responder → elegible según el rol → si no estaba encendido: plan, luego tope → guardar):

| Prueba | Aserción clave |
|---|---|
| `UserNormal` con plan enciende su comercio (`comercio`, `restaurante`, `taller`) | resultado `{ id: 5, destacarActivado: true, destacado: true }`; `save` recibe `destacarActivado: true` |
| `Empresa` con plan enciende su local (`patrocinado: true`, cualquier categoría) | igual resultado |
| no elegible al encender: `UserNormal` con categoría `agua`; `Empresa` con punto no patrocinado; `UserNormal` con punto patrocinado; `Admin`; punto `Rechazado` u `Obsoleto` | `rejects` `ForbiddenException` con message `'DESTACAR_NO_ELEGIBLE'`; sin `save` |
| punto de otro dueño / inexistente | `Forbidden` `'Este nodo no te pertenece'` / `NotFoundException` `'Nodo 99 no encontrado'` |
| sin plan | `'DESTACAR_SIN_PLAN'` y sin `save` |
| tope: `count` de puntos 12 + de eventos 8 → `'DESTACAR_TOPE'`; con `process.env.DESTACADOS_LIMITE = '2'` y 1 + 1 también; con 19 + 0 sí deja | y los conteos piden solo lo visible (Review Focus 2): `count` de puntos con `{ creadoPor: { id: 7 }, destacarActivado: true, estado: EstadoNodo.Aprobado }`; de eventos con `fechaFin: MoreThanOrEqual(ahora)` |
| apagar siempre se puede | sin plan y en tope → `{ destacarActivado: false, destacado: false }` y `save` con `false`; también un punto que ya no es elegible (categoría `agua`) |
| encender lo que ya está encendido | sin error, sin `save`, `destacado` según la vigencia |
| evento: solo `Empresa` dueña; terminado no se enciende | `'DESTACAR_NO_ELEGIBLE'`; con plan y vigente sí; ajeno: `'Este evento no te pertenece'` |
| `nodosConDestacado`, con plan vigente solo para los dueños 7 y 8 | A (dueño 7, `comercio`, `Aprobado`, encendido) → `true`; B (dueño 7, `agua`, no patrocinado, encendido) → `false`; C (dueño 9 sin plan, encendido) → `false`; D (apagado) → `false`; E (dueño 8, patrocinado, `agua`, encendido) → `true`; F (dueño 7, `comercio`, encendido, `Rechazado`) → `false`; los `true` salen primero (A, E) y el resto conserva su orden (B, C, D, F); al devolver `conVigencia` también al dueño 9, C pasa a `true` (renovar lo devuelve, Review Focus 2); una sola llamada a `conVigencia` con ids sin repetir; lista vacía no consulta |
| `eventosConDestacado` | evento con `fechaFin` pasada, encendido y dueño con plan → `false` (Review Focus 2); evento futuro encendido con plan → `true` |
| `nodoConDestacado` / `eventoConDestacado` | devuelven el mismo objeto con `destacado` |
| **misma instancia, sin filtrar el correo** (Review Focus 5) | con `evento = Object.assign(new Evento(), { ..., creadoPor: Object.assign(new User(), { id: 7, nombreUser: 'Bici SA', <correo> }) })`: `const [r] = await servicio.eventosConDestacado([evento])` → `expect(r).toBe(evento)` y `instanceToPlain(r).creadoPor` es exactamente `{ id: 7, nombreUser: 'Bici SA' }`; igual con un `Nodo` y `nodosConDestacado` |

- [ ] **Step 2: Correrlas** → FAIL por módulo inexistente.
- [ ] **Step 3: Implementar `DestacadosService`** (reglas de Global Constraints). `limiteDestacados()` lee `Number(process.env.DESTACADOS_LIMITE)` si es mayor que 0, si no 20. `destacado` se asigna con `Object.assign(elemento, { destacado })` y la lista se devuelve reordenada (los `true` primero, estable); nunca `{ ...elemento }`.
- [ ] **Step 4: Implementar la migración** `DestacarActivado1792400000000` (patrón de `1791900000000-UsuarioFotos.ts`): `ALTER TABLE "nodos" ADD COLUMN IF NOT EXISTS "destacar_activado" boolean NOT NULL DEFAULT false` y lo mismo en `"eventos"`; `down` las quita.
- [ ] **Step 5: Correr** `node node_modules/jest/bin/jest.js src/Modules/Patrocinio src/Modules/Nodos src/Modules/Eventos` → PASS (las pruebas existentes no cambian) y `tsc --noEmit` sin errores.
- [ ] **Step 6: Migración en la base local, con respaldo** (desde `D:\FitQuestGo\backend`, con Docker y la base arriba): `docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > ../respaldo-antes-destacar.sql`, luego `npx pnpm run mig:run`; comprobar con `docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\d nodos"'` que aparece `destacar_activado` (y en `eventos`).

### Task 4: Endpoints, lecturas y moneda

**Files:**
- Create: `src/Modules/Patrocinio/dto/destacar.dto.ts`, `src/Modules/Patrocinio/patrocinio.module.ts`, `src/Modules/Patrocinio/patrocinio.controller.ts`, `src/Modules/Patrocinio/patrocinio.controller.spec.ts`, `src/Modules/Nodos/nodo.controller.destacados.spec.ts`, `src/Modules/Eventos/evento.controller.destacados.spec.ts`
- Modify: `src/Modules/Nodos/nodo.controller.ts`, `src/Modules/Eventos/evento.controller.ts`, `src/Modules/Nodos/nodo.module.ts`, `src/Modules/Eventos/evento.module.ts` (importan `PatrocinioModule`; `AppModule` no hace falta: el módulo entra por estos dos)

**Interfaces:**
- Consumes: `DestacadosService` (Tarea 3), `monedaParaPais` y `MONEDAS` (Tarea 1).
- Produces: `class DestacarDto { destacar: boolean }` (`@IsBoolean()`); `PATCH /nodos/:id/destacar` (cualquier usuario autenticado: la regla de rol es del servicio) y `PATCH /eventos/:id/destacar` (`@UseGuards(GuardiaRoles) @Roles(RoleId.Empresa)`), cuerpo `{ destacar }`, responden `ResultadoDestacar`; método `destacar(id: number, dto: DestacarDto, actual: UsuarioAutenticado)` en cada controlador; `GET /nodos`, `GET /nodos/mios`, `GET /eventos`, `GET /eventos/mios`, `PATCH /nodos/:id/confirmar` y `PATCH /nodos/:id/obsoleto` devuelven cada elemento con `destacado` (los dos últimos porque la ficha de Flutter reemplaza su punto con esa respuesta); `destacarActivado` viaja en las lecturas porque es columna de la entidad (no es dato sensible, no se oculta); `GET /patrocinio/moneda?pais=CR` (`@UseGuards(GuardiaJwt)`; provisional hasta que 09A devuelva la moneda dentro de sus planes) → `{ pais: string | null; moneda: CodigoMoneda; simbolo: string; decimales: number }`, con `pais` en mayúsculas o `null` si no viene; `NodoController(nodoService, destacadosService)` y `EventoController(eventoService, destacadosService)`; `PatrocinioModule` exporta `DestacadosService` y `SUSCRIPCIONES_VIGENTES` (provee `SuscripcionesVigentesSql` con `useClass`) e importa `TypeOrmModule.forFeature([Nodo, Evento])`.

- [ ] **Step 1: Escribir las pruebas que fallan** (patrón de `src/Modules/Clima/clima.controller.spec.ts`: `Test.createTestingModule` con `overrideGuard(GuardiaJwt)`)

```ts
it('GET /nodos devuelve lo que compone DestacadosService', async () => {
  nodoService.findAprobados.mockResolvedValue([a, b]);
  destacados.nodosConDestacado.mockResolvedValue([{ ...b, destacado: true }, { ...a, destacado: false }]);
  await expect(controlador.findAprobados(actual)).resolves.toEqual([{ ...b, destacado: true }, { ...a, destacado: false }]);
  expect(destacados.nodosConDestacado).toHaveBeenCalledWith([a, b]);
});
it('votar un punto lo devuelve con `destacado`, para que la ficha no pierda el dorado', async () => {  // Review Focus 3
  nodoService.confirmar.mockResolvedValue(votado);
  destacados.nodoConDestacado.mockResolvedValue({ ...votado, destacado: true });
  await expect(controlador.confirmar(5, { lat: 9.9, lng: -84 }, actual)).resolves.toMatchObject({ id: 5, destacado: true });
  expect(destacados.nodoConDestacado).toHaveBeenCalledWith(votado);
  // lo mismo con controlador.marcarObsoleto
});
it('PATCH /nodos/:id/destacar pasa id, actor y bandera al servicio', async () => {
  destacados.destacarNodo.mockResolvedValue({ id: 5, destacarActivado: true, destacado: true });
  await expect(controlador.destacar(5, { destacar: true }, actual)).resolves.toEqual({ id: 5, destacarActivado: true, destacado: true });
  expect(destacados.destacarNodo).toHaveBeenCalledWith(5, actual, true);
});
it('DestacarDto exige un booleano', async () => {
  expect(await validate(plainToInstance(DestacarDto, { destacar: 'si' }))).not.toHaveLength(0);
  expect(await validate(plainToInstance(DestacarDto, {}))).not.toHaveLength(0);
  expect(await validate(plainToInstance(DestacarDto, { destacar: false }))).toHaveLength(0);
});
it('GET /patrocinio/moneda responde la moneda del pais, sin importar mayusculas', () => {
  expect(controlador.moneda('cr')).toEqual({ pais: 'CR', moneda: 'CRC', simbolo: '₡', decimales: 0 });
  expect(controlador.moneda('es')).toEqual({ pais: 'ES', moneda: 'EUR', simbolo: '€', decimales: 2 });
  expect(controlador.moneda(undefined)).toEqual({ pais: null, moneda: 'USD', simbolo: 'US$', decimales: 2 });
});
```
  Y, con la misma forma que las primeras: en `nodo.controller.destacados.spec.ts`, `GET /nodos/mios`; en `evento.controller.destacados.spec.ts`, `GET /eventos`, `GET /eventos/mios` y `PATCH /eventos/:id/destacar` (con `eventosConDestacado` y `destacarEvento`), más `expect(Reflect.getMetadata(CLAVE_ROLES, EventoController.prototype.destacar)).toEqual([RoleId.Empresa])`.

- [ ] **Step 2: Correrlas** → FAIL (los controladores no tienen `destacar` ni `moneda`).
- [ ] **Step 3: Implementar** el DTO, el módulo, el controlador de moneda y los métodos `destacar(...)`, y componer las lecturas con `nodosConDestacado` / `eventosConDestacado` y las dos respuestas de voto con `nodoConDestacado`. Importar `PatrocinioModule` en `NodoModule` y `EventoModule`.
- [ ] **Step 4: Correr** `node node_modules/jest/bin/jest.js src/Modules` y `tsc --noEmit` → todo en verde.

### Task 5: Avisos al dueño y recordatorios de vencimiento

**Files:**
- Create: `src/Modules/Patrocinio/patrocinio-avisos.service.ts`, `src/Modules/Patrocinio/suscripcion-avisos.task.ts`
- Modify: `src/Modules/Notificaciones/notificacion.enum.ts` (`CategoriaNotificacion.Patrocinio = 'patrocinio'`; `ReferenciaTipoNotificacion.Suscripcion = 'suscripcion'`; la columna es de texto, sin migración), `src/Modules/Notificaciones/notificaciones.service.ts`, `src/Modules/Patrocinio/patrocinio.module.ts` (importa `NotificacionesModule`, provee y exporta `PatrocinioAvisosService`)
- Test: `src/Modules/Patrocinio/patrocinio-avisos.service.spec.ts`, `src/Modules/Patrocinio/suscripcion-avisos.task.spec.ts`, y ampliar `src/Modules/Notificaciones/notificaciones.service.spec.ts`

**Interfaces:**
- Consumes: `SuscripcionesVigentes` (Tarea 2); `NotificacionesService.crear(CrearNotificacionParametros)`.
- Produces: `NotificacionesService.yaAvisada(idUsuario: number, referenciaTipo: ReferenciaTipoNotificacion, referenciaId: number, titulo: string): Promise<boolean>`; `PatrocinioAvisosService` con `planAprobado`, `planRechazado`, `planSuspendido(usuarioId: number, suscripcionId: number): Promise<void>` (los llamará José desde las acciones de admin) y `planPorVencer(usuarioId: number, suscripcionId: number, venceEn: Date): Promise<boolean>` y `planVencido(usuarioId: number, suscripcionId: number): Promise<boolean>` (`true` si creó el aviso, `false` si ya existía); `SuscripcionAvisosTask.avisarVencimientos(ahora?: Date): Promise<{ porVencer: number; vencidas: number }>`, con `@Cron('0 9 * * *', { name: 'avisos-suscripciones', timeZone: 'America/Costa_Rica', waitForCompletion: true })` y también una pasada en `onApplicationBootstrap` (como `AlertaExpiracionTask`: el servidor puede estar dormido a las 9:00; los avisos no se duplican).

- [ ] **Step 1: Escribir las pruebas que fallan.** Cada método llama a `notificaciones.crear` con `idUsuario: usuarioId`, `categoria: CategoriaNotificacion.Patrocinio`, `referenciaTipo: ReferenciaTipoNotificacion.Suscripcion`, `referenciaId: suscripcionId` y este texto exacto:

| Método | `titulo` | `mensaje` |
|---|---|---|
| `planAprobado` | `Tu plan de patrocinio fue aprobado` | `Ya puedes destacar tus comercios y eventos durante 30 días.` |
| `planRechazado` | `Tu solicitud de plan fue rechazada` | `Puedes enviar una nueva solicitud cuando quieras.` |
| `planSuspendido` | `Tu plan de patrocinio fue suspendido` | `Tus publicaciones dejaron de verse como destacadas. Si crees que es un error, escribe al equipo de FitQuest Go.` |
| `planVencido` | `Tu plan de patrocinio venció` | `Tus publicaciones siguen visibles, pero ya no aparecen como destacadas. Renueva tu plan para volver a destacarlas.` |
| `planPorVencer` | `Tu plan de patrocinio vence pronto` | `Vence el 23 de octubre de 2026. Renuévalo para que tus publicaciones sigan destacadas.` (para `new Date('2026-10-23T18:00:00Z')`) |

  Más: `planPorVencer` y `planVencido` **no crean nada** y devuelven `false` si `yaAvisada(usuarioId, 'suscripcion', suscripcionId, titulo)` es `true`; `yaAvisada` devuelve `true` si el repositorio cuenta una o más notificaciones con ese usuario, referencia y título (y `false` con cero). La tarea, con `vencenEntre` falso: lo pide para `(ahora, ahora + 3 días]` ("por vencer") y para `(ahora − 7 días, ahora]` ("vencida"; 7 días por si el servidor estuvo dormido); **salta a quien ya renovó** (`conVigencia` con el instante `hasta` de la ventana en "por vencer" y con `ahora` en "vencida" incluye al usuario → ni aviso ni cuenta); devuelve cuántos avisos se crearon de verdad (`{ porVencer: 1, vencidas: 0 }` si el segundo ya estaba avisado); y, si el puerto falla, registra el error y **no lanza**.
- [ ] **Step 2: Correrlas** → FAIL.
- [ ] **Step 3: Implementar** los enums, `yaAvisada`, `PatrocinioAvisosService` (fecha con `toLocaleDateString('es-CR', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'America/Costa_Rica' })`) y la tarea (patrón de `src/Modules/Alertas/alerta-expiracion.task.ts`: `try/catch` con `Logger`).
- [ ] **Step 4: Correr** `node node_modules/jest/bin/jest.js src/Modules/Patrocinio src/Modules/Notificaciones`, `tsc --noEmit` y `node node_modules/eslint/bin/eslint.js "src/Modules/Patrocinio/**/*.ts"` → verde. Después `node node_modules/jest/bin/jest.js` completo: todo lo que pasaba en la línea base más lo nuevo.

---

## Flutter (`D:\FitQuestGo\FitQuestGo`)

### Task 6: Catálogo de monedas y formato de importes

**Files:**
- Create: `lib/core/catalogos/monedas.dart`, `lib/core/moneda/formato_moneda.dart`
- Test: `test/formato_moneda_test.dart`; Modify: `test/catalogos_test.dart` (un test nuevo en el grupo "claves (contrato con el backend)")

**Interfaces:**
- Produces: `class Moneda { const Moneda(this.codigo, this.simbolo, this.decimales); }`; `const List<Moneda> monedas` (CRC `₡` 0, USD `US$` 2, EUR `€` 2, en ese orden); `Moneda? monedaPorCodigo(String codigo)`; `String formatearImporte(num importe, String codigo, {required String locale})`.

- [ ] **Step 1: Escribir las pruebas que fallan**

```dart
// catalogos_test.dart (misma lista que catalogos-contrato.spec.ts del backend)
test('monedas (codigo, simbolo, decimales)', () {
  expect(monedas.map((Moneda m) => (m.codigo, m.simbolo, m.decimales)).toList(),
      <(String, String, int)>[('CRC', '₡', 0), ('USD', 'US\$', 2), ('EUR', '€', 2)]);
});

// formato_moneda_test.dart
test('formatea con el simbolo adelante segun el idioma', () {
  expect(formatearImporte(10000, 'CRC', locale: 'es'), '₡10.000');
  expect(formatearImporte(20, 'USD', locale: 'es'), 'US\$20,00');
  expect(formatearImporte(18, 'EUR', locale: 'pt_BR'), '€18,00');
  expect(formatearImporte(10000, 'CRC', locale: 'en'), '₡10,000');
  expect(formatearImporte(20, 'USD', locale: 'en'), 'US\$20.00');
});
test('una moneda desconocida se muestra con su codigo, sin romper', () {
  expect(formatearImporte(5, 'XYZ', locale: 'es'), '5 XYZ');
});
```

- [ ] **Step 2: Correrlas** (`flutter test test/catalogos_test.dart test/formato_moneda_test.dart`) → FAIL por archivos inexistentes.
- [ ] **Step 3: Implementar** con `NumberFormat.currency(locale: locale, symbol: m.simbolo, decimalDigits: m.decimales, customPattern: m.decimales == 0 ? '\u00A4#,##0' : '\u00A4#,##0.00')` (ya comprobado que produce exactamente esas cadenas).
- [ ] **Step 4: Correrlas** → PASS.

### Task 7: Textos nuevos (es, en, pt, pt_BR)

**Files:**
- Modify: `lib/l10n/app_es.arb` (con `@descripción` en cada clave), `app_en.arb`, `app_pt.arb`, `app_pt_BR.arb`
- Test: `test/l10n_patrocinio_test.dart`

**Interfaces:**
- Produces (getters de `AppLocalizations`, todos sin parámetros): `patrocinioDestacar`, `patrocinioDestacado`, `patrocinioSinPlan`, `patrocinioTope`, `patrocinioNoElegible`, `patrocinioErrorDestacar`, `patrocinioCercaTitulo`.

| Clave | es | en | pt y pt_BR |
|---|---|---|---|
| `patrocinioDestacar` | Destacar en el mapa | Feature on the map | Destacar no mapa |
| `patrocinioDestacado` | Destacado | Featured | Destaque |
| `patrocinioSinPlan` | Necesitas un plan de patrocinio vigente para destacar. | You need an active sponsorship plan to feature this. | Voce precisa de um plano de patrocinio ativo para destacar. |
| `patrocinioTope` | Llegaste al maximo de destacados activos. Apaga alguno para destacar este. | You reached the maximum of active featured items. Turn one off to feature this one. | Voce chegou ao maximo de destaques ativos. Desative um para destacar este. |
| `patrocinioNoElegible` | Este contenido no se puede destacar. | This item cannot be featured. | Este conteudo nao pode ser destacado. |
| `patrocinioErrorDestacar` | No se pudo cambiar el destacado. | The featured status could not be changed. | Nao foi possivel alterar o destaque. |
| `patrocinioCercaTitulo` | Destacado cerca de ti | Featured near you | Destaque perto de voce |

- [ ] **Step 1: Escribir la prueba que falla** — instancia `AppLocalizationsEs()`, `AppLocalizationsEn()`, `AppLocalizationsPt()` y `AppLocalizationsPtBr()` y compara los siete textos de la tabla (es, en y pt exactos; pt_BR igual a pt).
- [ ] **Step 2: Correrla** → FAIL (getters inexistentes).
- [ ] **Step 3: Agregar las claves** a las cuatro ARB y ejecutar `flutter gen-l10n`.
- [ ] **Step 4: Correrla** → PASS; `flutter analyze` sin avisos nuevos.

### Task 8: Modelos, API y regla de "destacable"

**Files:**
- Modify: `lib/Modulos/nodos/data/nodo.dart`, `lib/Modulos/nodos/data/nodo_api.dart`, `lib/Modulos/eventos/data/evento.dart`, `lib/Modulos/eventos/data/evento_api.dart`
- Create: `lib/Modulos/patrocinio/data/destacable.dart`
- Test: `test/destacar_data_test.dart`

**Interfaces:**
- Produces: `Nodo` y `Evento` con `final bool destacado` y `final bool destacarActivado` (por defecto `false` en el constructor; `fromJson` lee `json['destacado'] as bool? ?? false` y `json['destacarActivado'] as bool? ?? false`); `Nodo conDestacado({required bool destacarActivado, required bool destacado})` (copia con esas dos banderas cambiadas); `typedef ResultadoDestacar = ({bool destacarActivado, bool destacado})` en `destacable.dart`; `Future<ResultadoDestacar> NodoApi.destacar(int id, {required bool destacar})` → `PATCH /nodos/$id/destacar` con `{'destacar': destacar}`; ídem `EventoApi.destacar` en `/eventos/$id/destacar`; `const Set<String> categoriasComercio = {'comercio', 'restaurante', 'taller'}`; `bool nodoDestacable(Nodo n)` = `n.patrocinado || categoriasComercio.contains(n.categoria)`; `bool eventoDestacable(Evento e, DateTime ahora)` = `!e.haTerminado(ahora)`.

- [ ] **Step 1: Escribir las pruebas que fallan**

| Prueba | Aserción |
|---|---|
| `fromJson` sin los campos nuevos (backend viejo) | `Nodo.fromJson({'id': 1, 'nombre': 'Soda', 'categoria': 'comercio', 'lat': 9.9, 'lng': -84.0, 'estado': 'Aprobado'})` → `destacado` y `destacarActivado` son `false`; igual `Evento.fromJson` con `id`, `nombre`, `categoria`, `fechaInicio` y `fechaFin` |
| `fromJson` con los campos | `{..., 'destacado': true, 'destacarActivado': true}` → ambos `true` |
| `Nodo.conDestacado` | cambia solo esas dos banderas: `id`, `nombre`, `patrocinado`, `creadoPorId` y `miVoto` quedan iguales |
| `NodoApi.destacar` (con `MockClient`, como `nodos_data_test.dart`) | `destacar(5, destacar: true)` hace una petición `PATCH /nodos/5/destacar` con cuerpo `{'destacar': true}`; con respuesta `{'id': 5, 'destacarActivado': true, 'destacado': true}` devuelve `(destacarActivado: true, destacado: true)`; `EventoApi.destacar(7, destacar: false)` → `PATCH /eventos/7/destacar` |
| `nodoDestacable` | `true` para `comercio`, `restaurante`, `taller` y para un `patrocinado` de categoría `agua`; `false` para `agua` y `otro` no patrocinados |
| `eventoDestacable` | `false` si `haTerminado(ahora)`; `true` si no |

- [ ] **Step 2: Correrlas** → FAIL.
- [ ] **Step 3: Implementar** lo descrito (los campos nuevos son opcionales en los constructores, para no romper a los demás llamadores).
- [ ] **Step 4: Correr** `flutter test test/destacar_data_test.dart test/nodos_data_test.dart test/eventos_data_test.dart` → PASS.

### Task 9: Interruptor "Destacar" y etiqueta "Destacado"

**Files:**
- Create: `lib/Modulos/patrocinio/presentation/interruptor_destacar.dart`, `lib/Modulos/patrocinio/presentation/etiqueta_destacado.dart`
- Modify: `lib/Modulos/nodos/presentation/ficha_nodo.dart` (y `mostrarFichaNodo`), `lib/Modulos/eventos/presentation/ficha_evento.dart`, `lib/Modulos/empresa/presentation/mis_nodos_screen.dart`, `lib/Modulos/empresa/presentation/mis_eventos_screen.dart`
- Test: `test/interruptor_destacar_test.dart`, y ampliar `test/ficha_nodo_test.dart`, `test/ficha_evento_test.dart`, `test/nodos_empresa_test.dart`, `test/listas_eventos_test.dart`

**Interfaces:**
- Consumes: `NodoApi.destacar`, `EventoApi.destacar`, `Nodo.conDestacado`, `nodoDestacable`, `eventoDestacable` (Tarea 8); textos de la Tarea 7; `ApiException` (`lib/core/api/api_client.dart`) y `notificarError` (`lib/core/notificaciones/notificaciones.dart`).
- Produces: `InterruptorDestacar({super.key, required bool activado, required Future<bool> Function(bool destacar) alCambiar})` (clave `ValueKey('interruptor-destacar')`; el `Switch` queda deshabilitado mientras espera; `alCambiar` devuelve el `destacarActivado` que quedó en el servidor; si lanza, vuelve al estado anterior y avisa con `notificarError`); `String mensajeErrorDestacar(AppLocalizations l10n, ApiException e)`; `EtiquetaDestacado({super.key})` (píldora dorada con estrella y `patrocinioDestacado`, clave `ValueKey('etiqueta-destacado')`); `FichaNodo` y `mostrarFichaNodo` ganan `ValueChanged<Nodo>? alDestacar`, que se llama con el punto actualizado tras un cambio exitoso.

- [ ] **Step 1: Escribir las pruebas que fallan** (con `montarApp`)

| Prueba | Aserción |
|---|---|
| `InterruptorDestacar` apagado, al tocarlo | `alCambiar` recibe `true`; el `Switch` queda con `value == true` |
| rechazo del servidor | `alCambiar` lanza `ApiException(403, 'DESTACAR_SIN_PLAN')` → aparece `Necesitas un plan de patrocinio vigente para destacar.` y el `Switch` vuelve a `false` |
| `mensajeErrorDestacar` | `DESTACAR_SIN_PLAN` → `patrocinioSinPlan`; `DESTACAR_TOPE` → `patrocinioTope`; `DESTACAR_NO_ELEGIBLE` → `patrocinioNoElegible`; `ApiException(500, 'x')` → `patrocinioErrorDestacar` |
| `FichaNodo` | con `usuarioId == creadoPorId` y punto destacable existe `ValueKey('interruptor-destacar')`; con otro `usuarioId`, o con categoría `agua` no patrocinada, no existe; con `destacado: true` existe `ValueKey('etiqueta-destacado')`; al encender, el api falso recibe `destacar(id, destacar: true)`, aparece la etiqueta y `alDestacar` recibe un `Nodo` con `destacado: true` |
| `FichaEvento` | con `destacado: true` existe `ValueKey('etiqueta-destacado')`; sin él, no |
| `MisNodosScreen` y `MisEventosScreen` | la fila de un nodo destacable (y la de un evento no terminado) lleva el interruptor; la de un nodo `agua` y la de un evento terminado, no |

- [ ] **Step 2: Correrlas** → FAIL.
- [ ] **Step 3: Implementar** los dos widgets. En `FichaNodo` el interruptor aparece si `widget.usuarioId == _nodo.creadoPorId && nodoDestacable(_nodo)`; su `alCambiar` llama a `widget.api.destacar`, actualiza `_nodo` con `conDestacado`, llama a `widget.alDestacar` y devuelve `destacarActivado`. `FichaNodo` y `FichaEvento` muestran `EtiquetaDestacado` junto al nombre cuando `destacado`. En `mis_nodos_screen.dart` el interruptor entra en `_TarjetaNodo` (nuevo parámetro `Widget? interruptor`); en `mis_eventos_screen.dart` va en el `trailing` de `TarjetaEvento`.
- [ ] **Step 4: Correr** `flutter test test/interruptor_destacar_test.dart test/ficha_nodo_test.dart test/ficha_evento_test.dart test/nodos_empresa_test.dart test/nodos_usuario_test.dart test/listas_eventos_test.dart` → PASS.

### Task 10: Pines dorados en el mapa

**Files:**
- Create: `lib/Modulos/patrocinio/presentation/capa_destacados_mapa.dart`
- Modify: `lib/core/mapa/pin_icono.dart`, `lib/Modulos/eventos/presentation/widgets/capa_eventos_mapa.dart`, `lib/Modulos/home/presentation/home_usuario_screen.dart`, `lib/Modulos/patrocinio/data/destacable.dart`
- Test: `test/pines_mapa_test.dart` (ampliar), `test/destacar_data_test.dart` (ampliar)

**Interfaces:**
- Produces: `TipoPin.destacado` (icono `Icons.star_rounded`, fondo `FqColors.amber`, color del icono `FqColors.night`); `List<Nodo> soloDestacados(Iterable<Nodo> nodos)` en `destacable.dart`; `CapaDestacadosMapa.crear(MapboxMap mapa, {void Function(int nodoId)? alTocarNodo})`, `Future<void> dibujar({required double densidad, required List<Nodo> nodos})` (dibuja solo los destacados, cada uno con su nombre) y `liberar()`, como `CapaRutasMapa`; `CapaEventosMapa.dibujar(..., Set<int> eventosDestacados = const <int>{})`: las zonas cuyo `eventoId` esté en el conjunto usan `TipoPin.destacado`.

- [ ] **Step 1: Escribir las pruebas que fallan** — `estiloPin(TipoPin.destacado)` tiene `icono == Icons.star_rounded`, `fondo == FqColors.amber` y `colorIcono == FqColors.night` (y el test existente "cada tipo tiene su propio icono y color" sigue verde); `soloDestacados` con nodos `[a(destacado), b, c(destacado)]` devuelve `[a, c]` en ese orden.
- [ ] **Step 2: Correrlas** → FAIL.
- [ ] **Step 3: Implementar** el tipo de pin, `soloDestacados` y `CapaDestacadosMapa` (patrón de `CapaRutasMapa`). En Home: la capa se crea en `_onMapCreated` **después** del administrador de pines de puntos (queda encima de todo) y se libera en `dispose`; `_pintarPines` dibuja con `_iconosNodos` los no destacados y con la capa los destacados (respetando el filtro `CapaMapa.pois`); su toque abre `_abrirFicha` con el punto de `_nodos` que tenga ese id; `_abrirFicha` pasa `alDestacar: _reemplazarNodo` para que el pin cambie al instante; `_pintarEventos` pasa `eventosDestacados` con los ids de `_eventos` cuyo `destacado` sea verdadero. La marca de texto "Destacado" va en la ficha, el aviso y la tarjeta; el pin lleva la estrella.
- [ ] **Step 4: Correr** `flutter test test/pines_mapa_test.dart test/destacar_data_test.dart test/home_funcional_test.dart test/home_alertas_cercanas_test.dart test/home_clima_test.dart` → PASS. (El dibujo en el mapa real se comprueba en la Tarea 13.)

### Task 11: Aviso "cerca de ti", tarjeta en el cuadro, orden en la búsqueda y refresco del mapa

**Files:**
- Create: `lib/Modulos/patrocinio/application/proximidad_destacados.dart`, `lib/Modulos/patrocinio/presentation/banner_destacado_cerca.dart`
- Modify: `lib/Modulos/home/presentation/widgets/panel_cercano.dart`, `lib/Modulos/home/application/busqueda_mapa.dart`, `lib/Modulos/home/presentation/home_usuario_screen.dart`, `test/helpers/datos_mapa.dart` (parámetro `destacado` en `nodoDePrueba` y `eventoDePrueba`)
- Test: `test/proximidad_destacados_test.dart`, `test/banner_destacado_cerca_test.dart`, y ampliar `test/home_widgets_test.dart`, `test/busqueda_mapa_test.dart`, `test/home_funcional_test.dart`

**Interfaces:**
- Produces: `class DestacadoCercano { final String tipo; final int id; final String nombre; final double metros; final Object origen; String get clave => '$tipo:$id'; }` (`tipo` es `'nodo'` o `'evento'`; `origen` es el `Nodo` o el `Evento`); `DestacadoCercano? destacadoMasCercano({required double lat, required double lng, required Iterable<Nodo> nodos, required Iterable<Evento> eventos, double radioMetros = 1000, Set<String> excluidos = const <String>{}})` (solo cuentan los `destacado`; la distancia a un evento es al punto más cercano de sus áreas y recorridos); `class ProximidadDestacados extends ChangeNotifier { ProximidadDestacados({this.radioMetros = 1000}); void actualizarDestacables(List<Nodo> nodos, List<Evento> eventos); void alMoverse(PosicionGps pos); DestacadoCercano? get cercano; void cerrar(); }` (sin posición no hay `cercano`; lo que se avisa queda marcado y no vuelve; si quien camina sale del radio sin cerrarlo, también cuenta como avisado; al cerrar pasa al siguiente aún no avisado); `BannerDestacadoCerca({super.key, required DestacadoCercano destacado, required VoidCallback onTap, required VoidCallback onCerrar})`; `PanelCercano` gana `DestacadoCercano? destacado` y `VoidCallback? onDestacado` (una tarjeta dorada de ancho completo sobre las casillas de ruta y alerta); `ResultadoBusqueda` gana `final bool destacado` y `buscarEnMapa` ordena por puntaje → destacado primero → distancia → título.

- [ ] **Step 1: Escribir las pruebas que fallan** (el usuario está en `(latBase, lngBase)`; nodo A destacado a +0.003° N ≈ 334 m; B destacado a +0.008° ≈ 890 m; C destacado a +0.02° ≈ 2,2 km; D no destacado a +0.001°)

| Prueba | Aserción |
|---|---|
| `destacadoMasCercano` | con A, B, C y D → A (`metros` ≈ 334, `clave == 'nodo:<idA>'`); solo con C → `null`; con `excluidos: {'nodo:<idA>'}` → B |
| un evento destacado | con un recorrido cuyo punto más cercano está a +0.002° → `tipo == 'evento'`, `metros` ≈ 222, y gana a A |
| `ProximidadDestacados` sin posición | `cercano == null` |
| dos dentro del radio (Review Focus 4) | con A y B: `cercano.id` es el de A; `cerrar()` → el de B; `cerrar()` → `null`; `alMoverse` otra vez → sigue `null` |
| salir del radio sin cerrar | con A visible, `alMoverse(lejos)` → `cercano == null`; al volver a `alMoverse(aqui)` sigue `null` (ya avisado) |
| `BannerDestacadoCerca` | muestra `Destacado cerca de ti` y `Parque Norte · 296 m`; tocarlo llama a `onTap` una vez; tocar `byTooltip('Ahora no')` llama a `onCerrar` una vez |
| `PanelCercano` con destacado | muestra el nombre, `Destacado` y `296 m` por encima de `Sin rutas cerca`; tocar la tarjeta llama a `onDestacado` |
| `buscarEnMapa` | 'Fuente a' (lejos, destacado) y 'Fuente b' (cerca, no) con posición → `['Fuente a', 'Fuente b']`; sin destacado, el más cercano primero |
| Home: alerta y destacado a la vez (Review Focus 4) | con un destacado a ≈ 334 m aparece `Destacado cerca de ti`; con además una alerta activa a ≈ 56 m (avisa `Alerta cerca de ti`) no aparece el de destacado |
| Home: el refresco de 60 s recoge `destacado` (Review Focus 3) | con el api falso de nodos devolviendo el mismo punto con `destacado: false` en la primera carga y `true` en la segunda, tras `tester.pump(const Duration(seconds: 61))` aparece la tarjeta dorada en "Cerca de ti"; si vuelve a `false`, desaparece; igual con un evento |

- [ ] **Step 2: Correrlas** → FAIL.
- [ ] **Step 3: Implementar.** En Home: un `ProximidadDestacados` en el `State`, alimentado con `_proximidad.posicion` (el `ValueListenable` que ya existe) y con `actualizarDestacables(_nodos, _eventos)` tras cada carga; **`_mismosNodos` y `_mismosEventos` comparan también `destacado`**, si no el refresco periódico no redibuja ni actualiza nada cuando solo cambia eso; el banner se muestra con `ListenableBuilder(listenable: Listenable.merge(<Listenable>[_proximidad, _destacados]))` solo si `_proximidad.alertaCercana == null` y no se está escribiendo en el buscador; tocarlo abre la ficha (`_abrirFicha` o `mostrarFichaEvento`) y llama a `cerrar()`; el cuadro recibe `destacadoMasCercano(...)` calculado en el mismo `ValueListenableBuilder` del cuadro, sin `excluidos`.
- [ ] **Step 4: Correr** `flutter test test/proximidad_destacados_test.dart test/banner_destacado_cerca_test.dart test/home_widgets_test.dart test/busqueda_mapa_test.dart test/home_funcional_test.dart test/home_alertas_cercanas_test.dart test/home_clima_test.dart` → PASS.

### Task 12: Categoría "Patrocinio" en las notificaciones

**Files:**
- Modify: `lib/Modulos/perfil/data/notificacion.dart` (agregar `'patrocinio'` a `Notificacion.categorias`), `lib/Modulos/perfil/presentation/notificaciones_screen.dart` (píldora `'patrocinio': 'Patrocinio'` y un caso en `_estiloDe`: icono `Icons.campaign_rounded`, color `FqColors.purple`, fondo `Color(0xFFEFEBFB)`, sin acción)
- Test: `test/notificaciones_patrocinio_test.dart`

**Interfaces:**
- Consumes: `NotificacionesApi` existente; en la prueba, un falso cuyo `listar()` devuelve una `Notificacion` con `categoria: 'patrocinio'`, `titulo: 'Tu plan de patrocinio fue aprobado'` y `referenciaTipo: 'suscripcion'`.

- [ ] **Step 1: Escribir la prueba que falla** — monta `NotificacionesScreen(api: falsa)`; esperado: `find.text('Patrocinio')` encuentra un widget (la píldora) con el contador `1`; la tarjeta muestra el título; tocar la tarjeta no abre otra pantalla ni falla (`find.byType(NotificacionesScreen)` sigue siendo uno).
- [ ] **Step 2: Correrla** → FAIL (no existe la píldora).
- [ ] **Step 3: Implementar** lo descrito en **Files**.
- [ ] **Step 4: Correr** `flutter test test/notificaciones_patrocinio_test.dart test/notificaciones_test.dart test/perfil_screen_test.dart` → PASS.

### Task 13: Verificación de punta a punta, siembra local y guion de demostración

**Files:**
- Create: `D:\FitQuestGo\backend\scripts\demo-suscripcion.sql`, `docs/superpowers/specs/2026-10-19-monetizacion-guion-demo.md`

- [ ] **Step 1: Suites completas.** Backend: `node node_modules/jest/bin/jest.js`, `tsc --noEmit` y `node node_modules/eslint/bin/eslint.js "src/Modules/Patrocinio/**/*.ts"`. Flutter: `flutter test` y `flutter analyze`. Esperado: verde, con las pruebas de la línea base más las nuevas, y `flutter analyze` sin avisos nuevos. Si `pubspec.lock` quedó modificado, `git checkout -- pubspec.lock`.
- [ ] **Step 2: Siembra local** `scripts/demo-suscripcion.sql` (solo base local, nunca como migración, y solo mientras no exista la migración de 09A): `CREATE TABLE IF NOT EXISTS suscripciones (id serial PRIMARY KEY, usuario_id integer NOT NULL REFERENCES usuarios(id), estado varchar(20) NOT NULL, inicia_en timestamptz NOT NULL, vence_en timestamptz NOT NULL);` y una fila `Activa` por 30 días para `usuario@gmail.com` y otra para una cuenta Empresa de prueba (creada con `POST /auth/registro-empresa`; los usuarios se buscan por `email_user` en `usuarios`).
- [ ] **Step 3: Recorrido en el emulador** (receta del proyecto, desde `D:\FitQuestGo\backend`: Docker Desktop arriba, `docker compose up -d db`, `npx pnpm run mig:run`, `npx pnpm run start`; `adb emu geo fix -84.0907 9.9281`; compilación de depuración con `--dart-define=API_BASE_URL=http://10.0.2.2:3001`): (1) como `usuario@gmail.com`, crear un punto de categoría comercio y encender "Destacar" en su ficha; (2) sin plan (borrar la fila) el interruptor responde con el mensaje de plan; (3) con plan, el pin sale dorado con su nombre; (4) con otra cuenta cerca (`adb emu geo fix`), sale el aviso "Destacado cerca de ti" y la tarjeta dorada en "Cerca de ti"; (5) con el plan vencido (`UPDATE suscripciones SET vence_en = now() - interval '1 minute'`) todo se apaga en el siguiente refresco del mapa (hasta 60 s) y al renovar vuelve; (6) una alerta de peligro a menos de 100 m tapa el aviso; (7) una empresa destaca un local y un evento.
- [ ] **Step 4: Escribir el guion** `…-guion-demo.md` con los siete pasos de arriba como narración para el profesor (quién hace qué, qué se ve) y las cuentas de prueba usadas.

---

## Cobertura del spec (autorrevisión)

- Reglas de destacar, efectivo al leer y orden, tope, vencimiento inmediato: T3, T4. Avisos al dueño: T5, T12. Moneda y formato: T1, T4, T6, T7. Interruptor y etiqueta: T9. Pines, tarjeta, aviso y búsqueda: T10, T11. Migración revisada: T3. Demostración: T13.
- Fuera, por decisión: pagos (09B), "Mi plan", pantalla admin y `PatrocinioApi`/`PrecioPlan` (09A).
- Nombres consistentes entre capas: `destacar` (cuerpo del PATCH), `destacarActivado` (interruptor) y `destacado` (efectivo) son los mismos en backend, API y modelos Flutter; el backend responde `ResultadoDestacar` como `{ id, destacarActivado, destacado }` y Flutter solo usa las dos banderas.
