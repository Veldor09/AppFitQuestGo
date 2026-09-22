# Cierre de brechas Seguimiento #2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cerrar los tres huecos identificados contra el checklist del Hito de Seguimiento #2 y el checklist de la tarjeta Auth: tracking GPS básico, recuperación de contraseña por correo, y aceptación legal obligatoria en el registro.

**Architecture:** Tres sub-features casi independientes que comparten el módulo Auth (backend) y el árbol `Modulos/auth` (Flutter). El tracking GPS no toca el backend en absoluto — reutiliza `POST /rutas` tal cual. La aceptación legal reutiliza UI ya existente (`RegistroFlujoScreen`, `TerminosModal`) que hoy no se comunica al backend. La recuperación de contraseña es la pieza nueva más grande: entidad + servicio de correo + dos endpoints + dos pantallas.

**Tech Stack:** NestJS + TypeORM + Postgres (backend), Flutter + `geolocator` + `mapbox_maps_flutter` (frontend), `nodemailer` para correo (backend, nuevo), `jest`/`ts-jest` (backend tests), `flutter_test` (Flutter tests).

**Spec:** `docs/superpowers/specs/2026-09-21-cierre-brechas-seguimiento-2-design.md`

**Nota sobre hallazgos durante la investigación (relevante para quien ejecute este plan):** El spec original asumía que había que construir la UI de aceptación legal desde cero (checkbox + pantalla de términos). Al explorar el código se encontró que **ya existe** en `lib/Modulos/auth/presentation/registro/registro_flujo.dart` y `lib/Modulos/auth/presentation/widgets/terminos_modal.dart`: el checkbox, la validación, el modal con texto legal completo. Lo único que falta es que ese `true` viaje hasta el backend y se persista. Las Tasks 1-2 reflejan esto — no crean pantallas nuevas, conectan las que ya existen. De la misma forma, el login (`login_screen.dart`) ya tiene un link "¿Olvidaste tu contraseña?" que hoy solo muestra un toast falso — la Task 8 lo conecta a las pantallas reales en vez de crear un link nuevo.

---

## Task 1: Backend — aceptación legal obligatoria (entidad + DTO + migración)

**Files:**
- Modify: `src/Modules/Usuarios/user.entity.ts`
- Modify: `src/Modules/Auth/dto/registro.dto.ts`
- Create: `src/migrations/1791000000000-AceptacionTerminos.ts`
- Test: `src/Modules/Auth/dto/registro.dto.spec.ts`

- [ ] **Step 1: Escribir el test que falla, para el DTO**

```typescript
// src/Modules/Auth/dto/registro.dto.spec.ts
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { RegistroDto } from './registro.dto';

function dtoValido(overrides: Partial<RegistroDto> = {}): RegistroDto {
  return plainToInstance(RegistroDto, {
    nombre: 'Ana',
    email: 'ana@correo.com',
    contrasena: 'contrasena123',
    aceptaTerminos: true,
    ...overrides,
  });
}

describe('RegistroDto', () => {
  it('es valido cuando aceptaTerminos es true', async () => {
    const errores = await validate(dtoValido());
    expect(errores).toHaveLength(0);
  });

  it('rechaza aceptaTerminos en false', async () => {
    const errores = await validate(dtoValido({ aceptaTerminos: false }));
    const campo = errores.find((e) => e.property === 'aceptaTerminos');
    expect(campo).toBeDefined();
  });

  it('rechaza cuando falta aceptaTerminos', async () => {
    const dto = dtoValido();
    delete (dto as Partial<RegistroDto>).aceptaTerminos;
    const errores = await validate(dto);
    const campo = errores.find((e) => e.property === 'aceptaTerminos');
    expect(campo).toBeDefined();
  });
});
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `pnpm test registro.dto.spec.ts`
Expected: FAIL — `aceptaTerminos` no existe en `RegistroDto`, TypeScript ni siquiera compila el `dtoValido()` con esa propiedad (o el test de "rechaza false" pasa por accidente porque no hay validación). Confirmar que al menos uno de los tres falla.

- [ ] **Step 3: Agregar el campo al DTO**

```typescript
// src/Modules/Auth/dto/registro.dto.ts
import {Equals,IsBoolean,IsEmail,IsNotEmpty,IsString,Matches,MaxLength,MinLength,} from 'class-validator';
import {
  MAX_NOMBRE_USUARIO,
  MENSAJE_NOMBRE_INVALIDO,
  NOMBRE_PERSONA_REGEX,
} from '../../../common/reglas-usuario';

export class RegistroDto {
  @IsString()
  @IsNotEmpty({ message: 'El nombre es obligatorio' })
  @MaxLength(MAX_NOMBRE_USUARIO, {
    message: `El nombre admite maximo ${MAX_NOMBRE_USUARIO} caracteres`,
  })
  @Matches(NOMBRE_PERSONA_REGEX, { message: MENSAJE_NOMBRE_INVALIDO })
  nombre: string;

  @IsEmail({}, { message: 'El correo no tiene un formato valido' })
  @MaxLength(100)
  email: string;

  @IsString()
  @MinLength(8, { message: 'La contrasena debe tener al menos 8 caracteres' })
  @MaxLength(72)
  contrasena: string;

  @IsBoolean({ message: 'aceptaTerminos debe ser booleano' })
  @Equals(true, { message: 'Debes aceptar los terminos y condiciones' })
  aceptaTerminos: boolean;
}
```

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `pnpm test registro.dto.spec.ts`
Expected: PASS — 3 tests.

- [ ] **Step 5: Agregar la columna a la entidad `User`**

```typescript
// src/Modules/Usuarios/user.entity.ts
import { Exclude } from 'class-transformer';
import {Column,Entity,JoinColumn,ManyToOne,OneToMany,PrimaryGeneratedColumn,} from 'typeorm';
import { Auth } from '../Auth/auth.entity';
import { EstadoUsuario } from './estado.enum';
import { Role } from './roles.entity';

@Entity('usuarios')

export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 100 })
  nombreUser: string;

  @Column({ type: 'varchar', length: 100, unique: true })
  emailUser: string;

  @Exclude()
  @Column({ type: 'varchar', length: 255 })
  passwordUserHash: string;

  @Column()
  idrol: number;

  @Column({ type: 'varchar', length: 20, default: EstadoUsuario.Activado })
  estado: EstadoUsuario;

  @Column({ type: 'timestamptz', nullable: true })
  terminosAceptadosEn: Date | null;

  @ManyToOne(() => Role, (role) => role.usuarios, {
    eager: true,
    nullable: false,
    onDelete: 'RESTRICT',
  })
  @JoinColumn({ name: 'idrol' })
  rol: Role;

  @OneToMany(() => Auth, (auth) => auth.usuario)
  sesiones: Auth[];
}
```

`nullable: true` es deliberado: los usuarios ya existentes (admin, usuario de prueba) no tienen este dato y no deben romperse. Solo los registros nuevos lo llenan.

- [ ] **Step 6: Escribir la migración**

```typescript
// src/migrations/1791000000000-AceptacionTerminos.ts
import { MigrationInterface, QueryRunner } from 'typeorm';

export class AceptacionTerminos1791000000000 implements MigrationInterface {
  name = 'AceptacionTerminos1791000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "usuarios" ADD COLUMN "terminos_aceptados_en" TIMESTAMP WITH TIME ZONE NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "usuarios" DROP COLUMN "terminos_aceptados_en"`,
    );
  }
}
```

- [ ] **Step 7: Correr la migración**

Run: `pnpm mig:run`
Expected: salida mostrando `AceptacionTerminos1791000000000` como migración aplicada, sin errores.

- [ ] **Step 8: Nota — sellar la fecha se hace en la Task 2**

Este task solo agrega la columna y la validación del DTO de registro. Setear `terminosAceptadosEn` al crear el usuario (en `CreateUserDto` + `AuthService.registrar()`) es la Task 2 completa — no hay nada más que hacer aquí.

- [ ] **Step 9: Commit**

```bash
git add src/Modules/Usuarios/user.entity.ts src/Modules/Auth/dto/registro.dto.ts src/Modules/Auth/dto/registro.dto.spec.ts src/migrations/1791000000000-AceptacionTerminos.ts
git commit -m "feat(auth): exigir aceptacion de terminos en el registro"
```

---

## Task 2: Backend — persistir `aceptaTerminos` al crear el usuario

**Files:**
- Modify: `src/Modules/Usuarios/dto/UserDTO.ts`
- Modify: `src/Modules/Auth/auth.service.ts`

`UserService.createUser()` hace `this.userRepository.create(dto)` con `dto: CreateUserDto` — TypeORM copia cualquier propiedad del DTO que matchee una columna de la entidad. Como `CreateUserDto` también es el body validado de `POST /usuarios` (admin creando usuarios desde el panel, ver `user.controller.ts`), el campo nuevo tiene que ser **opcional** ahí: un admin creando una cuenta no "acepta terminos" en nombre de otra persona. Por eso este task NO toca `user.service.ts` — con agregar el campo opcional al DTO alcanza, `create(dto)` ya lo recoge solo.

- [ ] **Step 1: Agregar el campo opcional a `CreateUserDto`**

```typescript
// src/Modules/Usuarios/dto/UserDTO.ts
import { PartialType } from '@nestjs/mapped-types';
import {IsDate,IsEmail,IsEnum,IsNotEmpty,IsOptional,IsString,Matches,MaxLength,MinLength,} from 'class-validator';
import {
  MAX_NOMBRE_USUARIO,
  MENSAJE_NOMBRE_INVALIDO,
  NOMBRE_PERSONA_REGEX,
} from '../../../common/reglas-usuario';
import { EstadoUsuario } from '../estado.enum';
import { RoleId } from '../roles.enum';

export class CreateUserDto {
  @IsString()
  @IsNotEmpty({ message: 'El nombre es obligatorio' })
  @MaxLength(MAX_NOMBRE_USUARIO, {
    message: `El nombre admite maximo ${MAX_NOMBRE_USUARIO} caracteres`,
  })
  @Matches(NOMBRE_PERSONA_REGEX, { message: MENSAJE_NOMBRE_INVALIDO })
  nombreUser: string;

  @IsEmail({}, { message: 'El correo no tiene un formato valido' })
  @MaxLength(100, { message: 'El correo admite maximo 100 caracteres' })
  emailUser: string;

  @IsString()
  @IsNotEmpty({ message: 'La contrasena es obligatoria' })
  @MinLength(8, { message: 'La contrasena debe tener al menos 8 caracteres' })
  passwordUserHash: string;

  // La columna idrol es NOT NULL, asi que el rol es obligatorio al crear.
  @IsEnum(RoleId, {
    message: 'El rol debe ser Usuario (1), Empresa (2) o Admin (3)',
  })
  idrol: RoleId;

  // Solo lo setea AuthService.registrar() con la fecha del momento; un admin
  // creando una cuenta desde el panel no lo envia (queda NULL).
  @IsOptional()
  @IsDate()
  terminosAceptadosEn?: Date;
}

// Todos los campos de CreateUserDto pero opcionales, conservando sus validaciones.
export class UpdateUserDto extends PartialType(CreateUserDto) {}

export class CambiarEstadoDto {
  @IsEnum(EstadoUsuario, {
    message: 'El estado debe ser Activado o Desactivado',
  })
  estado: EstadoUsuario;
}
```

- [ ] **Step 2: Pasar la fecha desde `AuthService.registrar`**

```typescript
// src/Modules/Auth/auth.service.ts — dentro de registrar()
async registrar(
  dto: RegistroDto,
  datos: DatosCliente,
): Promise<ResultadoAuth> {
  // `createUser` se encarga de hashear la contrasena.
  const usuario = await this.userService.createUser({
    nombreUser: dto.nombre,
    emailUser: dto.email,
    passwordUserHash: dto.contrasena,
    idrol: RoleId.UserNormal,
    terminosAceptadosEn: new Date(),
  });
  return this.emitirSesion(usuario, datos);
}
```

(`dto.aceptaTerminos` ya viene validado como `true` por el DTO — no hace falta volver a chequearlo aquí, solo usarlo para sellar la fecha.)

- [ ] **Step 3: Test manual con el backend corriendo**

Run: `pnpm run start:dev` (si no está corriendo ya)

```bash
curl -X POST http://localhost:3001/auth/registro \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Test Terminos","email":"test-terminos@x.co","contrasena":"contrasena123","aceptaTerminos":true}'
```

Expected: `201`, cuerpo con `usuario`/`accessToken`. Luego:

```bash
curl -X POST http://localhost:3001/auth/registro \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Test Terminos 2","email":"test-terminos2@x.co","contrasena":"contrasena123","aceptaTerminos":false}'
```

Expected: `400` con mensaje `"Debes aceptar los terminos y condiciones"`.

- [ ] **Step 4: Commit**

```bash
git add src/Modules/Usuarios/dto/UserDTO.ts src/Modules/Auth/auth.service.ts
git commit -m "feat(auth): sellar fecha de aceptacion de terminos al registrar"
```

---

## Task 3: Flutter — enviar `aceptaTerminos` desde el registro ya existente

**Files:**
- Modify: `lib/Modulos/auth/data/auth_api.dart`
- Modify: `lib/Modulos/auth/data/auth_repositorio.dart`
- Modify: `lib/Modulos/auth/presentation/registro/registro_flujo.dart`
- Test: `test/auth_api_test.dart` (nuevo)

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/auth_api_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_api.dart';

void main() {
  test('registrar() envia aceptaTerminos en el cuerpo', () async {
    Map<String, dynamic>? cuerpoRecibido;
    final MockClient client = MockClient((http.Request req) async {
      cuerpoRecibido = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'usuario': <String, dynamic>{
            'id': 1,
            'nombre': 'Ana',
            'email': 'ana@x.co',
            'rol': 1,
          },
          'accessToken': 'a',
          'refreshToken': 'r',
        }),
        201,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final AuthApi api = AuthApi(ApiClient(client: client, baseUrl: 'http://test'));

    await api.registrar(
      nombre: 'Ana',
      email: 'ana@x.co',
      contrasena: 'contrasena123',
      aceptaTerminos: true,
    );

    expect(cuerpoRecibido, isNotNull);
    expect(cuerpoRecibido!['aceptaTerminos'], true);
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/auth_api_test.dart`
Expected: FAIL — `registrar()` no acepta el parámetro nombrado `aceptaTerminos` (error de compilación).

- [ ] **Step 3: Agregar el parámetro en `AuthApi`**

```dart
// lib/Modulos/auth/data/auth_api.dart
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';

class AuthApi {
  AuthApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Sesion> registrar({
    required String nombre,
    required String email,
    required String contrasena,
    required bool aceptaTerminos,
  }) async {
    final dynamic data = await _client.post('/auth/registro', {
      'nombre': nombre,
      'email': email,
      'contrasena': contrasena,
      'aceptaTerminos': aceptaTerminos,
    });
    return Sesion.fromJson(data as Map<String, dynamic>);
  }

  Future<Sesion> iniciarSesion({
    required String email,
    required String contrasena,
  }) async {
    final dynamic data = await _client.post('/auth/inicio-sesion', {
      'email': email,
      'contrasena': contrasena,
    });
    return Sesion.fromJson(data as Map<String, dynamic>);
  }

  Future<UsuarioSesion> obtenerPerfil() async {
    final dynamic data = await _client.get('/auth/yo');
    return UsuarioSesion.fromJson(data as Map<String, dynamic>);
  }

  Future<void> cerrarSesion(String? refreshToken) async {
    await _client.post('/auth/cerrar-sesion', {'refreshToken': ?refreshToken});
  }
}
```

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/auth_api_test.dart`
Expected: PASS.

- [ ] **Step 5: Propagar el parámetro por `AuthRepositorio`**

```dart
// lib/Modulos/auth/data/auth_repositorio.dart — reemplaza el metodo registrar()
Future<void> registrar({
  required String nombre,
  required String email,
  required String contrasena,
  required bool aceptaTerminos,
}) async {
  final Sesion sesion = await _api.registrar(
    nombre: nombre,
    email: email,
    contrasena: contrasena,
    aceptaTerminos: aceptaTerminos,
  );
  await _persistir(sesion);
}
```

(El resto del archivo no cambia.)

- [ ] **Step 6: Pasar `true` desde `RegistroFlujoScreen._crearCuenta()`**

En `lib/Modulos/auth/presentation/registro/registro_flujo.dart`, dentro de `_crearCuenta()`:

```dart
Future<void> _crearCuenta() async {
  setState(() => _enviando = true);
  try {
    await AuthScope.read(context).registrar(
      nombre: _nombre.text.trim(),
      email: _email.text.trim(),
      contrasena: _password.text,
      aceptaTerminos: _aceptaTerminos,
    );
    if (!mounted) return;
    notificarExito('Cuenta creada. Bienvenido a FitQuest Go');
    setState(() {
      _enviando = false;
      _paso = 4; // Paso de confirmacion.
    });
  } on ApiException catch (e) {
    _fallar(
      e.statusCode == 409
          ? 'Ese correo ya tiene una cuenta. Inicia sesion.'
          : e.message,
    );
  } catch (_) {
    _fallar('No se pudo crear la cuenta. Revisa tu conexion.');
  }
}
```

(Único cambio real: se agrega `aceptaTerminos: _aceptaTerminos` a la llamada. `_aceptaTerminos` ya existe como estado del widget y ya se valida como `true` antes de poder llegar al último paso — ver `_avanzarDesdeDatos()` en el mismo archivo — así que en este punto siempre es `true`.)

- [ ] **Step 7: Correr toda la suite de Flutter**

Run: `flutter test`
Expected: PASS, sin regresiones (18+ tests anteriores más el nuevo).

- [ ] **Step 8: Commit**

```bash
git add lib/Modulos/auth/data/auth_api.dart lib/Modulos/auth/data/auth_repositorio.dart lib/Modulos/auth/presentation/registro/registro_flujo.dart test/auth_api_test.dart
git commit -m "feat(auth): enviar aceptacion de terminos al backend"
```

---

## Task 4: Backend — entidad y migración de restablecimiento de contraseña

**Files:**
- Create: `src/Modules/Auth/entities/restablecimiento-contrasena.entity.ts`
- Create: `src/migrations/1791100000000-RestablecimientoContrasena.ts`

- [ ] **Step 1: Crear la entidad**

```typescript
// src/Modules/Auth/entities/restablecimiento-contrasena.entity.ts
import {Column,CreateDateColumn,Entity,Index,PrimaryGeneratedColumn,} from 'typeorm';

@Entity('restablecimientos_contrasena')
@Index(['usuarioId'])
export class RestablecimientoContrasena {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  usuarioId: number;

  @Column({ type: 'varchar', length: 64 })
  hashCodigo: string;

  @Column({ type: 'timestamptz' })
  expiraEn: Date;

  @Column({ type: 'boolean', default: false })
  usado: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  creadoEn: Date;
}
```

- [ ] **Step 2: Crear la migración**

```typescript
// src/migrations/1791100000000-RestablecimientoContrasena.ts
import { MigrationInterface, QueryRunner } from 'typeorm';

export class RestablecimientoContrasena1791100000000
  implements MigrationInterface
{
  name = 'RestablecimientoContrasena1791100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "restablecimientos_contrasena" (
        "id" SERIAL PRIMARY KEY,
        "usuario_id" INTEGER NOT NULL,
        "hash_codigo" VARCHAR(64) NOT NULL,
        "expira_en" TIMESTAMP WITH TIME ZONE NOT NULL,
        "usado" BOOLEAN NOT NULL DEFAULT false,
        "creado_en" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_restablecimientos_usuario_id"
      ON "restablecimientos_contrasena" ("usuario_id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "restablecimientos_contrasena"`);
  }
}
```

- [ ] **Step 3: Correr la migración**

Run: `pnpm mig:run`
Expected: `RestablecimientoContrasena1791100000000` aplicada sin errores.

- [ ] **Step 4: Commit**

```bash
git add src/Modules/Auth/entities/restablecimiento-contrasena.entity.ts src/migrations/1791100000000-RestablecimientoContrasena.ts
git commit -m "feat(auth): tabla de restablecimientos de contrasena"
```

---

## Task 5: Backend — `MailService` (nodemailer por Gmail)

**Files:**
- Modify: `package.json` (agregar `nodemailer`, `@types/nodemailer`)
- Modify: `src/Modules/Auth/auth.config.ts`
- Create: `src/Modules/Auth/services/mail.service.ts`
- Test: `src/Modules/Auth/services/mail.service.spec.ts`

- [ ] **Step 1: Instalar dependencias**

Run: `pnpm add nodemailer` y `pnpm add -D @types/nodemailer`
Expected: ambos quedan en `package.json` (`dependencies` y `devDependencies` respectivamente).

- [ ] **Step 2: Agregar getters de configuracion**

```typescript
// src/Modules/Auth/auth.config.ts
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AuthConfig {
  constructor(private readonly config: ConfigService) {}

  get secretoAccessToken(): string {
    return this.config.getOrThrow<string>('JWT_ACCESS_SECRET');
  }

  get duracionAccessToken(): number {
    return Number(this.config.get<string>('JWT_ACCESS_TTL', '900'));
  }

  get duracionRefreshDias(): number {
    return Number(this.config.get<string>('REFRESH_TTL_DIAS', '7'));
  }

  get cookieSegura(): boolean {
    return this.config.get<string>('COOKIE_SECURE', 'false') === 'true';
  }

  get gmailUser(): string | undefined {
    return this.config.get<string>('GMAIL_USER');
  }

  get gmailAppPassword(): string | undefined {
    return this.config.get<string>('GMAIL_APP_PASSWORD');
  }
}
```

- [ ] **Step 3: Escribir el test que falla, para `MailService`**

```typescript
// src/Modules/Auth/services/mail.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { AuthConfig } from '../auth.config';
import { MailService } from './mail.service';

const sendMailMock = jest.fn().mockResolvedValue(undefined);
const createTransportMock = jest.fn().mockReturnValue({ sendMail: sendMailMock });

jest.mock('nodemailer', () => ({
  createTransport: (...args: unknown[]) => createTransportMock(...args),
}));

describe('MailService', () => {
  let service: MailService;
  let config: { gmailUser: string | undefined; gmailAppPassword: string | undefined };

  beforeEach(async () => {
    sendMailMock.mockClear();
    createTransportMock.mockClear();
    config = { gmailUser: 'bot@gmail.com', gmailAppPassword: 'clave-app' };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MailService,
        { provide: AuthConfig, useValue: config },
      ],
    }).compile();

    service = module.get(MailService);
  });

  it('lanza si no hay GMAIL_USER/GMAIL_APP_PASSWORD configurados', async () => {
    config.gmailUser = undefined;
    await expect(
      service.enviarCodigoRecuperacion('user@x.co', '123456'),
    ).rejects.toThrow(/GMAIL_USER|GMAIL_APP_PASSWORD/);
  });

  it('envia el correo con el codigo cuando esta configurado', async () => {
    await service.enviarCodigoRecuperacion('user@x.co', '123456');

    expect(sendMailMock).toHaveBeenCalledTimes(1);
    const llamada = sendMailMock.mock.calls[0][0] as {
      to: string;
      subject: string;
      text: string;
    };
    expect(llamada.to).toBe('user@x.co');
    expect(llamada.text).toContain('123456');
  });
});
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `pnpm test mail.service.spec.ts`
Expected: FAIL — `mail.service.ts` no existe.

- [ ] **Step 3: Implementar `MailService`**

```typescript
// src/Modules/Auth/services/mail.service.ts
import { Injectable } from '@nestjs/common';
import * as nodemailer from 'nodemailer';
import { AuthConfig } from '../auth.config';

@Injectable()
export class MailService {
  constructor(private readonly config: AuthConfig) {}

  async enviarCodigoRecuperacion(
    destinatario: string,
    codigo: string,
  ): Promise<void> {
    const usuario = this.config.gmailUser;
    const clave = this.config.gmailAppPassword;
    if (!usuario || !clave) {
      throw new Error(
        'Correo no configurado: faltan GMAIL_USER y/o GMAIL_APP_PASSWORD en el .env',
      );
    }

    const transporte = nodemailer.createTransport({
      service: 'gmail',
      auth: { user: usuario, pass: clave },
    });

    await transporte.sendMail({
      from: `"FitQuest Go" <${usuario}>`,
      to: destinatario,
      subject: 'Codigo para restablecer tu contrasena',
      text:
        `Tu codigo para restablecer la contrasena de FitQuest Go es: ${codigo}\n\n` +
        'Vence en 15 minutos. Si no pediste este codigo, ignora este correo.',
    });
  }
}
```

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `pnpm test mail.service.spec.ts`
Expected: PASS — 2 tests.

- [ ] **Step 5: Commit**

```bash
git add package.json pnpm-lock.yaml src/Modules/Auth/auth.config.ts src/Modules/Auth/services/mail.service.ts src/Modules/Auth/services/mail.service.spec.ts
git commit -m "feat(auth): servicio de correo por Gmail para recuperacion de contrasena"
```

---

## Task 6: Backend — DTOs y lógica de servicio de recuperación

**Files:**
- Create: `src/Modules/Auth/dto/olvide-contrasena.dto.ts`
- Create: `src/Modules/Auth/dto/restablecer-contrasena.dto.ts`
- Modify: `src/Modules/Auth/auth.service.ts`
- Modify: `src/Modules/Auth/auth.module.ts`
- Test: `src/Modules/Auth/auth.service.spec.ts`

- [ ] **Step 1: Crear los DTOs**

```typescript
// src/Modules/Auth/dto/olvide-contrasena.dto.ts
import { IsEmail, MaxLength } from 'class-validator';

export class OlvideContrasenaDto {
  @IsEmail({}, { message: 'El correo no tiene un formato valido' })
  @MaxLength(100)
  email: string;
}
```

```typescript
// src/Modules/Auth/dto/restablecer-contrasena.dto.ts
import {IsEmail,IsString,Length,MaxLength,MinLength,} from 'class-validator';

export class RestablecerContrasenaDto {
  @IsEmail({}, { message: 'El correo no tiene un formato valido' })
  @MaxLength(100)
  email: string;

  @IsString()
  @Length(6, 6, { message: 'El codigo debe tener 6 digitos' })
  codigo: string;

  @IsString()
  @MinLength(8, { message: 'La contrasena debe tener al menos 8 caracteres' })
  @MaxLength(72)
  nuevaContrasena: string;
}
```

- [ ] **Step 2: Escribir el test que falla, para el service**

```typescript
// src/Modules/Auth/auth.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { UnauthorizedException } from '@nestjs/common';
import { Repository } from 'typeorm';
import { AuthService } from './auth.service';
import { User } from '../Usuarios/user.entity';
import { UserService } from '../Usuarios/user.service';
import { ContrasenasServicio } from './services/contrasenas.service';
import { TokensServicio } from './services/tokens.service';
import { MailService } from './services/mail.service';
import { RestablecimientoContrasena } from './entities/restablecimiento-contrasena.entity';

describe('AuthService — recuperacion de contrasena', () => {
  let service: AuthService;
  let usuarios: jest.Mocked<Pick<Repository<User>, 'findOne' | 'update'>>;
  let restablecimientos: jest.Mocked<
    Pick<Repository<RestablecimientoContrasena>, 'findOne' | 'save' | 'create' | 'update'>
  >;
  let mail: jest.Mocked<Pick<MailService, 'enviarCodigoRecuperacion'>>;
  let contrasenas: jest.Mocked<Pick<ContrasenasServicio, 'hashear' | 'verificar'>>;

  beforeEach(async () => {
    usuarios = { findOne: jest.fn(), update: jest.fn() };
    restablecimientos = {
      findOne: jest.fn(),
      save: jest.fn(),
      create: jest.fn((x) => x as RestablecimientoContrasena),
      update: jest.fn(),
    };
    mail = { enviarCodigoRecuperacion: jest.fn().mockResolvedValue(undefined) };
    contrasenas = {
      hashear: jest.fn().mockResolvedValue('hash-nuevo'),
      verificar: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: getRepositoryToken(User), useValue: usuarios },
        {
          provide: getRepositoryToken(RestablecimientoContrasena),
          useValue: restablecimientos,
        },
        { provide: UserService, useValue: {} },
        { provide: ContrasenasServicio, useValue: contrasenas },
        { provide: TokensServicio, useValue: {} },
        { provide: MailService, useValue: mail },
      ],
    }).compile();

    service = module.get(AuthService);
  });

  describe('olvideContrasena', () => {
    it('no hace nada si el correo no existe, pero no lanza', async () => {
      usuarios.findOne.mockResolvedValue(null);
      await expect(
        service.olvideContrasena('no-existe@x.co'),
      ).resolves.toBeUndefined();
      expect(mail.enviarCodigoRecuperacion).not.toHaveBeenCalled();
    });

    it('genera codigo, lo guarda hasheado y envia el correo si el usuario existe', async () => {
      usuarios.findOne.mockResolvedValue({ id: 5, emailUser: 'ana@x.co' } as User);
      await service.olvideContrasena('ana@x.co');

      expect(restablecimientos.save).toHaveBeenCalledTimes(1);
      const guardado = restablecimientos.save.mock.calls[0][0] as RestablecimientoContrasena;
      expect(guardado.usuarioId).toBe(5);
      expect(guardado.usado).toBe(false);
      expect(guardado.hashCodigo).toHaveLength(64); // sha256 hex

      expect(mail.enviarCodigoRecuperacion).toHaveBeenCalledTimes(1);
      expect(mail.enviarCodigoRecuperacion.mock.calls[0][0]).toBe('ana@x.co');
      const codigoEnviado = mail.enviarCodigoRecuperacion.mock.calls[0][1] as string;
      expect(codigoEnviado).toMatch(/^\d{6}$/);
    });
  });

  describe('restablecerContrasena', () => {
    it('lanza UnauthorizedException si no hay usuario con ese correo', async () => {
      usuarios.findOne.mockResolvedValue(null);
      await expect(
        service.restablecerContrasena({
          email: 'no-existe@x.co',
          codigo: '123456',
          nuevaContrasena: 'nueva12345',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('lanza UnauthorizedException si no hay restablecimiento vigente que matchee', async () => {
      usuarios.findOne.mockResolvedValue({ id: 5, emailUser: 'ana@x.co' } as User);
      restablecimientos.findOne.mockResolvedValue(null);
      await expect(
        service.restablecerContrasena({
          email: 'ana@x.co',
          codigo: '000000',
          nuevaContrasena: 'nueva12345',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('actualiza la contrasena y marca el restablecimiento como usado', async () => {
      usuarios.findOne.mockResolvedValue({ id: 5, emailUser: 'ana@x.co' } as User);
      restablecimientos.findOne.mockResolvedValue({
        id: 9,
        usuarioId: 5,
        usado: false,
        expiraEn: new Date(Date.now() + 60_000),
      } as RestablecimientoContrasena);

      await service.restablecerContrasena({
        email: 'ana@x.co',
        codigo: '123456',
        nuevaContrasena: 'nueva12345',
      });

      expect(contrasenas.hashear).toHaveBeenCalledWith('nueva12345');
      expect(usuarios.update).toHaveBeenCalledWith(
        { id: 5 },
        { passwordUserHash: 'hash-nuevo' },
      );
      expect(restablecimientos.update).toHaveBeenCalledWith(
        { id: 9 },
        { usado: true },
      );
    });
  });
});
```

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `pnpm test auth.service.spec.ts`
Expected: FAIL — `AuthService` no tiene `olvideContrasena` ni `restablecerContrasena`, ni depende de `MailService`/`RestablecimientoContrasena`. Fallo de compilación o de test, cualquiera de los dos confirma que falta implementar.

- [ ] **Step 4: Implementar los métodos en `AuthService`**

```typescript
// src/Modules/Auth/auth.service.ts
import {Injectable,UnauthorizedException,} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { createHash, randomInt } from 'crypto';
import { User } from '../Usuarios/user.entity';
import { UserService } from '../Usuarios/user.service';
import { EstadoUsuario } from '../Usuarios/estado.enum';
import { RoleId } from '../Usuarios/roles.enum';
import { ContrasenasServicio } from './services/contrasenas.service';
import { TokensServicio } from './services/tokens.service';
import { MailService } from './services/mail.service';
import { RestablecimientoContrasena } from './entities/restablecimiento-contrasena.entity';
import { RegistroDto } from './dto/registro.dto';
import { InicioSesionDto } from './dto/inicio-sesion.dto';
import { RestablecerContrasenaDto } from './dto/restablecer-contrasena.dto';

interface DatosCliente {
  agenteUsuario?: string | null;
  ip?: string | null;
}

export interface ResumenUsuario {
  id: number;
  nombre: string;
  email: string;
  rol: number;
}

export interface ResultadoAuth {
  accessToken: string;
  refreshToken: string;
  refreshExpiraEn: Date;
  usuario: ResumenUsuario;
}

const HASH_FALSO =
  '$2b$12$GOaQIwl0Koy33EDKB3xzLuo7yhQdhaXF3PATrMnHFpvFYI8LljMBa';
const MINUTOS_EXPIRACION_CODIGO = 15;

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly usuarios: Repository<User>,
    @InjectRepository(RestablecimientoContrasena)
    private readonly restablecimientos: Repository<RestablecimientoContrasena>,
    private readonly userService: UserService,
    private readonly contrasenas: ContrasenasServicio,
    private readonly tokens: TokensServicio,
    private readonly mail: MailService,
  ) {}

  async registrar(
    dto: RegistroDto,
    datos: DatosCliente,
  ): Promise<ResultadoAuth> {
    // `createUser` se encarga de hashear la contrasena.
    const usuario = await this.userService.createUser({
      nombreUser: dto.nombre,
      emailUser: dto.email,
      passwordUserHash: dto.contrasena,
      idrol: RoleId.UserNormal,
      terminosAceptadosEn: new Date(),
    });
    return this.emitirSesion(usuario, datos);
  }

  async iniciarSesion(
    dto: InicioSesionDto,
    datos: DatosCliente,
  ): Promise<ResultadoAuth> {
    const usuario = await this.usuarios.findOne({
      where: { emailUser: dto.email },
    });
    const valido = await this.contrasenas.verificar(
      dto.contrasena,
      usuario?.passwordUserHash ?? HASH_FALSO,
    );
    if (!usuario || !valido) {
      throw new UnauthorizedException('Credenciales invalidas');
    }
    if (usuario.estado === EstadoUsuario.Desactivado) {
      throw new UnauthorizedException(
        'Tu cuenta esta desactivada. Contacta al administrador.',
      );
    }
    return this.emitirSesion(usuario, datos);
  }

  async renovar(
    refreshTokenPlano: string,
    datos: DatosCliente,
  ): Promise<ResultadoAuth> {
    const { usuarioId, refresh } = await this.tokens.rotarRefreshToken(
      refreshTokenPlano,
      datos,
    );
    const usuario = await this.usuarios.findOne({ where: { id: usuarioId } });
    if (!usuario) {
      throw new UnauthorizedException('Usuario no encontrado');
    }
    if (usuario.estado === EstadoUsuario.Desactivado) {
      throw new UnauthorizedException('Tu cuenta esta desactivada.');
    }
    const accessToken = await this.tokens.firmarAccessToken({
      sub: usuario.id,
      email: usuario.emailUser,
      rol: usuario.idrol,
    });
    return {
      accessToken,
      refreshToken: refresh.tokenPlano,
      refreshExpiraEn: refresh.expiraEn,
      usuario: this.resumen(usuario),
    };
  }

  obtenerPerfil(usuarioId: number): Promise<User> {
    return this.userService.findOneUser(usuarioId);
  }

  async cerrarSesion(refreshTokenPlano: string | undefined): Promise<void> {
    if (refreshTokenPlano) {
      await this.tokens.revocarPorToken(refreshTokenPlano);
    }
  }

  cerrarTodo(usuarioId: number): Promise<void> {
    return this.tokens.revocarTodasDelUsuario(usuarioId);
  }

  async olvideContrasena(email: string): Promise<void> {
    const usuario = await this.usuarios.findOne({ where: { emailUser: email } });
    if (!usuario) return; // no revelar si el correo existe

    const codigo = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const registro = this.restablecimientos.create({
      usuarioId: usuario.id,
      hashCodigo: this.hashCodigo(codigo),
      expiraEn: new Date(Date.now() + MINUTOS_EXPIRACION_CODIGO * 60_000),
      usado: false,
    });
    await this.restablecimientos.save(registro);
    await this.mail.enviarCodigoRecuperacion(usuario.emailUser, codigo);
  }

  async restablecerContrasena(dto: RestablecerContrasenaDto): Promise<void> {
    const usuario = await this.usuarios.findOne({
      where: { emailUser: dto.email },
    });
    if (!usuario) {
      throw new UnauthorizedException('Codigo invalido o expirado');
    }

    const registro = await this.restablecimientos.findOne({
      where: {
        usuarioId: usuario.id,
        hashCodigo: this.hashCodigo(dto.codigo),
        usado: false,
      },
    });
    if (!registro || registro.expiraEn.getTime() < Date.now()) {
      throw new UnauthorizedException('Codigo invalido o expirado');
    }

    const nuevoHash = await this.contrasenas.hashear(dto.nuevaContrasena);
    await this.usuarios.update({ id: usuario.id }, { passwordUserHash: nuevoHash });
    await this.restablecimientos.update({ id: registro.id }, { usado: true });
  }

  private hashCodigo(codigo: string): string {
    return createHash('sha256').update(codigo).digest('hex');
  }

  private async emitirSesion(
    usuario: User,
    datos: DatosCliente,
  ): Promise<ResultadoAuth> {
    const accessToken = await this.tokens.firmarAccessToken({
      sub: usuario.id,
      email: usuario.emailUser,
      rol: usuario.idrol,
    });
    const refresh = await this.tokens.emitirRefreshToken(usuario.id, datos);
    return {
      accessToken,
      refreshToken: refresh.tokenPlano,
      refreshExpiraEn: refresh.expiraEn,
      usuario: this.resumen(usuario),
    };
  }

  private resumen(usuario: User): ResumenUsuario {
    return {
      id: usuario.id,
      nombre: usuario.nombreUser,
      email: usuario.emailUser,
      rol: usuario.idrol,
    };
  }
}
```

- [ ] **Step 5: Registrar la entidad y `MailService` en el módulo**

```typescript
// src/Modules/Auth/auth.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserModule } from '../Usuarios/user.module';
import { SeguridadModule } from './seguridad.module';
import { Auth } from './auth.entity';
import { RestablecimientoContrasena } from './entities/restablecimiento-contrasena.entity';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { TokensServicio } from './services/tokens.service';
import { MailService } from './services/mail.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Auth, RestablecimientoContrasena]),
    SeguridadModule,
    UserModule,
  ],
  controllers: [AuthController],
  providers: [AuthService, TokensServicio, MailService],
})
export class AuthModule {}
```

- [ ] **Step 6: Correr el test y confirmar que pasa**

Run: `pnpm test auth.service.spec.ts`
Expected: PASS — 5 tests.

- [ ] **Step 7: Correr toda la suite del backend**

Run: `pnpm test`
Expected: PASS, todos los `.spec.ts` incluyendo los de las Tasks 1 y 5.

- [ ] **Step 8: Commit**

```bash
git add src/Modules/Auth/dto/olvide-contrasena.dto.ts src/Modules/Auth/dto/restablecer-contrasena.dto.ts src/Modules/Auth/auth.service.ts src/Modules/Auth/auth.service.spec.ts src/Modules/Auth/auth.module.ts
git commit -m "feat(auth): logica de recuperacion de contrasena por codigo"
```

---

## Task 7: Backend — endpoints de recuperación de contraseña

**Files:**
- Modify: `src/Modules/Auth/auth.controller.ts`

- [ ] **Step 1: Agregar los dos endpoints**

```typescript
// src/Modules/Auth/auth.controller.ts
import {Body,Controller,Get,HttpCode,HttpStatus,Post,Req,Res,UnauthorizedException,UseGuards,} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type {Request,Response,} from 'express';
import { AuthConfig } from './auth.config';
import { AuthService } from './auth.service';
import type { ResultadoAuth } from './auth.service';
import { RegistroDto } from './dto/registro.dto';
import { InicioSesionDto } from './dto/inicio-sesion.dto';
import { RenovarDto } from './dto/renovar.dto';
import { OlvideContrasenaDto } from './dto/olvide-contrasena.dto';
import { RestablecerContrasenaDto } from './dto/restablecer-contrasena.dto';
import { GuardiaJwt } from './guards/jwt.guard';
import { UsuarioActual } from './decorators/usuario-actual.decorator';
import type { UsuarioAutenticado } from './types/carga-jwt';
import type { User } from '../Usuarios/user.entity';

const COOKIE_ACCESS = 'access_token';
const COOKIE_REFRESH = 'refresh_token';
const RUTA_REFRESH = '/auth';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly config: AuthConfig,
  ) {}

  @Post('registro')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async registro(
    @Body() dto: RegistroDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const resultado = await this.authService.registrar(
      dto,
      this.datosCliente(req),
    );
    this.escribirCookies(res, resultado);
    return this.cuerpoRespuesta(req, resultado);
  }

  @Post('inicio-sesion')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async inicioSesion(
    @Body() dto: InicioSesionDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const resultado = await this.authService.iniciarSesion(
      dto,
      this.datosCliente(req),
    );
    this.escribirCookies(res, resultado);
    return this.cuerpoRespuesta(req, resultado);
  }

  @Post('renovar')
  @HttpCode(HttpStatus.OK)
  async renovar(
    @Body() dto: RenovarDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const tokenPlano = this.leerRefresh(req, dto);
    if (!tokenPlano) {
      throw new UnauthorizedException('Falta el refresh token');
    }
    const resultado = await this.authService.renovar(
      tokenPlano,
      this.datosCliente(req),
    );
    this.escribirCookies(res, resultado);
    return this.cuerpoRespuesta(req, resultado);
  }

  @Post('cerrar-sesion')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(GuardiaJwt)
  async cerrarSesion(
    @Body() dto: RenovarDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const cookies = req.cookies as Record<string, string> | undefined;
    await this.authService.cerrarSesion(
      cookies?.[COOKIE_REFRESH] ?? dto.refreshToken,
    );
    this.limpiarCookies(res);
  }

  @Post('cerrar-todo')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(GuardiaJwt)
  async cerrarTodo(
    @UsuarioActual() usuario: UsuarioAutenticado,
    @Res({ passthrough: true }) res: Response,
  ) {
    await this.authService.cerrarTodo(usuario.id);
    this.limpiarCookies(res);
  }

  @Get('yo')
  @UseGuards(GuardiaJwt)
  yo(@UsuarioActual() usuario: UsuarioAutenticado): UsuarioAutenticado {
    return usuario;
  }

  @Get('perfil')
  @UseGuards(GuardiaJwt)
  perfil(@UsuarioActual() usuario: UsuarioAutenticado): Promise<User> {
    return this.authService.obtenerPerfil(usuario.id);
  }

  /** Siempre responde 204, exista o no el correo (no revela cuentas). */
  @Post('olvide-contrasena')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async olvideContrasena(@Body() dto: OlvideContrasenaDto): Promise<void> {
    await this.authService.olvideContrasena(dto.email);
  }

  @Post('restablecer-contrasena')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async restablecerContrasena(
    @Body() dto: RestablecerContrasenaDto,
  ): Promise<void> {
    await this.authService.restablecerContrasena(dto);
  }

  private cuerpoRespuesta(
    req: Request,
    resultado: ResultadoAuth,
  ): { usuario: ResultadoAuth['usuario']; accessToken: string; refreshToken?: string } {
    const cuerpo = {
      usuario: resultado.usuario,
      accessToken: resultado.accessToken,
    };
    if (req.headers['x-cliente-movil'] === '1') {
      return { ...cuerpo, refreshToken: resultado.refreshToken };
    }
    return cuerpo;
  }

  private datosCliente(req: Request): {
    agenteUsuario: string | null;
    ip: string | null;
  } {
    return {
      agenteUsuario: req.headers['user-agent'] ?? null,
      ip: req.ip ?? null,
    };
  }

  private leerRefresh(req: Request, dto: RenovarDto): string | undefined {
    const cookies = req.cookies as Record<string, string> | undefined;
    return cookies?.[COOKIE_REFRESH] ?? dto.refreshToken;
  }

  private escribirCookies(res: Response, resultado: ResultadoAuth): void {
    res.cookie(COOKIE_ACCESS, resultado.accessToken, {
      httpOnly: true,
      secure: this.config.cookieSegura,
      sameSite: 'lax',
      path: '/',
    });
    res.cookie(COOKIE_REFRESH, resultado.refreshToken, {
      httpOnly: true,
      secure: this.config.cookieSegura,
      sameSite: 'lax',
      path: RUTA_REFRESH,
      expires: resultado.refreshExpiraEn,
    });
  }

  private limpiarCookies(res: Response): void {
    res.clearCookie(COOKIE_ACCESS, { path: '/' });
    res.clearCookie(COOKIE_REFRESH, { path: RUTA_REFRESH });
  }
}
```

- [ ] **Step 2: Rebuild y arranque limpio**

Run: `pnpm run start:dev`
Expected: en el log de arranque aparecen `Mapped {/auth/olvide-contrasena, POST}` y `Mapped {/auth/restablecer-contrasena, POST}`, sin errores de compilación.

- [ ] **Step 3: Test manual end-to-end (sin correo real todavia)**

```bash
curl -i -X POST http://localhost:3001/auth/olvide-contrasena \
  -H "Content-Type: application/json" \
  -d '{"email":"usuario@gmail.com"}'
```

Expected: `204`. Revisar el log del backend — como `GMAIL_USER`/`GMAIL_APP_PASSWORD` todavía no están en el `.env`, la llamada a `mail.enviarCodigoRecuperacion` va a lanzar el error de "Correo no configurado" definido en la Task 5. **Esto va a producir un `500` en vez de `204` hasta que se configuren las credenciales — es el comportamiento esperado y documentado en el spec**, no un bug. Confirmarlo leyendo el mensaje de error en la respuesta.

- [ ] **Step 4: Commit**

```bash
git add src/Modules/Auth/auth.controller.ts
git commit -m "feat(auth): endpoints de recuperacion de contrasena"
```

---

## Task 8: Flutter — pantallas de recuperación de contraseña

**Files:**
- Modify: `lib/Modulos/auth/data/auth_api.dart`
- Create: `lib/Modulos/auth/presentation/olvide_contrasena_screen.dart`
- Create: `lib/Modulos/auth/presentation/restablecer_contrasena_screen.dart`
- Modify: `lib/Modulos/auth/presentation/login_screen.dart`
- Test: `test/auth_api_test.dart` (agregar casos)

- [ ] **Step 1: Escribir los tests que fallan, para los métodos nuevos de `AuthApi`**

Agregar a `test/auth_api_test.dart` (el archivo ya existe desde la Task 3):

```dart
  test('olvideContrasena() llama a /auth/olvide-contrasena con el email', () async {
    String? rutaLlamada;
    Map<String, dynamic>? cuerpoRecibido;
    final MockClient client = MockClient((http.Request req) async {
      rutaLlamada = req.url.path;
      cuerpoRecibido = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response('', 204);
    });
    final AuthApi api = AuthApi(ApiClient(client: client, baseUrl: 'http://test'));

    await api.olvideContrasena(email: 'ana@x.co');

    expect(rutaLlamada, '/auth/olvide-contrasena');
    expect(cuerpoRecibido!['email'], 'ana@x.co');
  });

  test('restablecerContrasena() llama a /auth/restablecer-contrasena con los 3 campos', () async {
    Map<String, dynamic>? cuerpoRecibido;
    final MockClient client = MockClient((http.Request req) async {
      cuerpoRecibido = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response('', 204);
    });
    final AuthApi api = AuthApi(ApiClient(client: client, baseUrl: 'http://test'));

    await api.restablecerContrasena(
      email: 'ana@x.co',
      codigo: '123456',
      nuevaContrasena: 'nueva12345',
    );

    expect(cuerpoRecibido, <String, dynamic>{
      'email': 'ana@x.co',
      'codigo': '123456',
      'nuevaContrasena': 'nueva12345',
    });
  });
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/auth_api_test.dart`
Expected: FAIL — `olvideContrasena`/`restablecerContrasena` no existen en `AuthApi`.

- [ ] **Step 3: Agregar los métodos a `AuthApi`**

```dart
// lib/Modulos/auth/data/auth_api.dart — agregar al final de la clase, antes del cierre
  Future<void> olvideContrasena({required String email}) async {
    await _client.post('/auth/olvide-contrasena', {'email': email});
  }

  Future<void> restablecerContrasena({
    required String email,
    required String codigo,
    required String nuevaContrasena,
  }) async {
    await _client.post('/auth/restablecer-contrasena', {
      'email': email,
      'codigo': codigo,
      'nuevaContrasena': nuevaContrasena,
    });
  }
```

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/auth_api_test.dart`
Expected: PASS — 4 tests en total.

- [ ] **Step 5: Crear `RestablecerContrasenaScreen`**

```dart
// lib/Modulos/auth/presentation/restablecer_contrasena_screen.dart
import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_api.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';

/// Segundo paso de recuperacion: el usuario ya recibio el codigo por correo
/// (ver [OlvideContrasenaScreen]) y lo escribe junto con la contrasena nueva.
class RestablecerContrasenaScreen extends StatefulWidget {
  const RestablecerContrasenaScreen({super.key, required this.email, this.api});

  final String email;

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final AuthApi? api;

  @override
  State<RestablecerContrasenaScreen> createState() =>
      _RestablecerContrasenaScreenState();
}

class _RestablecerContrasenaScreenState
    extends State<RestablecerContrasenaScreen> {
  late final AuthApi _api = widget.api ?? AuthApi();

  final TextEditingController _codigo = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _cargando = false;
  bool _forzarError = false;

  @override
  void dispose() {
    _codigo.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _valido() {
    return todoValido(<(String, List<Validador>)>[
      (_codigo.text, <Validador>[
        requerido('Ingresa el codigo'),
        (String v) => v.trim().length == 6 ? null : 'El codigo tiene 6 digitos',
      ]),
      (_password.text, <Validador>[
        requerido('Ingresa la nueva contrasena'),
        minCaracteres(8),
      ]),
    ]);
  }

  Future<void> _confirmar() async {
    FocusScope.of(context).unfocus();
    if (!_valido()) {
      setState(() => _forzarError = true);
      notificarError('Revisa los campos marcados en rojo');
      return;
    }
    setState(() => _cargando = true);
    try {
      await _api.restablecerContrasena(
        email: widget.email,
        codigo: _codigo.text.trim(),
        nuevaContrasena: _password.text,
      );
      if (!mounted) return;
      notificarExito('Contrasena actualizada. Inicia sesion con la nueva.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      _fallar(
        e.statusCode == 401 ? 'Codigo invalido o expirado' : e.message,
      );
    } catch (_) {
      _fallar('No se pudo conectar con el servidor. Intenta de nuevo.');
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    setState(() => _cargando = false);
    notificarError(mensaje);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FqColors.paper,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FqAppHeader(
              title: 'Ingresa el codigo',
              subtitle: 'Lo enviamos a ${widget.email}',
              onLeading: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    FqGap.xl,
                    32,
                    FqGap.xl,
                    FqGap.xl,
                  ),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: kAuthContentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        CampoTexto(
                          label: 'Codigo de 6 digitos',
                          controller: _codigo,
                          keyboardType: TextInputType.number,
                          maxCaracteres: 6,
                          forzarError: _forzarError,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: FqGap.sm),
                        CampoTexto(
                          label: 'Contrasena nueva',
                          controller: _password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[
                            AutofillHints.newPassword,
                          ],
                          forzarError: _forzarError,
                          onSubmitted: (_) => _confirmar(),
                          reglas: <Validador>[
                            requerido('Ingresa la nueva contrasena'),
                            minCaracteres(8),
                          ],
                        ),
                        const SizedBox(height: FqGap.xl),
                        FqButton.primary(
                          label: 'Actualizar contrasena',
                          loading: _cargando,
                          onPressed: _cargando ? null : _confirmar,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Crear `OlvideContrasenaScreen`**

```dart
// lib/Modulos/auth/presentation/olvide_contrasena_screen.dart
import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_api.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/restablecer_contrasena_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';

/// Primer paso de recuperacion: pedir el correo. Siempre avanza al siguiente
/// paso (exista o no la cuenta) para no revelar que correos estan registrados.
class OlvideContrasenaScreen extends StatefulWidget {
  const OlvideContrasenaScreen({super.key, this.api});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final AuthApi? api;

  @override
  State<OlvideContrasenaScreen> createState() =>
      _OlvideContrasenaScreenState();
}

class _OlvideContrasenaScreenState extends State<OlvideContrasenaScreen> {
  late final AuthApi _api = widget.api ?? AuthApi();

  final TextEditingController _email = TextEditingController();

  bool _cargando = false;
  bool _forzarError = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!todoValido(<(String, List<Validador>)>[(_email.text, reglasCorreo())])) {
      setState(() => _forzarError = true);
      notificarError('Ingresa un correo valido');
      return;
    }
    setState(() => _cargando = true);
    try {
      await _api.olvideContrasena(email: _email.text.trim());
      if (!mounted) return;
      notificarInfo('Si el correo existe, te enviamos un codigo');
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RestablecerContrasenaScreen(
            email: _email.text.trim(),
            api: widget.api,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      notificarError('No se pudo conectar con el servidor. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FqColors.paper,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FqAppHeader(
              title: 'Recuperar acceso',
              subtitle: 'Te enviamos un codigo a tu correo',
              onLeading: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    FqGap.xl,
                    32,
                    FqGap.xl,
                    FqGap.xl,
                  ),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: kAuthContentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        CampoTexto(
                          label: 'Correo',
                          controller: _email,
                          hintText: 'tucorreo@dominio.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[AutofillHints.email],
                          forzarError: _forzarError,
                          onSubmitted: (_) => _enviar(),
                          reglas: reglasCorreo(),
                        ),
                        const SizedBox(height: FqGap.xl),
                        FqButton.primary(
                          label: 'Enviar codigo',
                          loading: _cargando,
                          onPressed: _cargando ? null : _enviar,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Conectar el link ya existente en `LoginScreen`**

En `lib/Modulos/auth/presentation/login_screen.dart`, agregar el import:

```dart
import 'package:fit_quest_go/Modulos/auth/presentation/olvide_contrasena_screen.dart';
```

Y reemplazar el `onPressed` del `TextButton` "Olvidaste tu contrasena?" (hoy es `() => notificarInfo('Si el correo existe, te enviaremos instrucciones')`):

```dart
onPressed: () => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => const OlvideContrasenaScreen(),
  ),
),
```

(El resto de `login_screen.dart` no cambia — solo esa línea dentro del `TextButton`.)

- [ ] **Step 8: Correr toda la suite de Flutter**

Run: `flutter test`
Expected: PASS, sin regresiones.

- [ ] **Step 9: Verificación manual en el emulador**

Con el backend y el emulador corriendo: Login → "Olvidaste tu contrasena?" → ingresar `usuario@gmail.com` → "Enviar codigo" → confirmar que navega a la pantalla de código (aunque el envío de correo real falle por falta de credenciales Gmail, la navegación y el flujo de UI deben verse correctos). Anotar en el reporte final que el envío real de correo queda pendiente de `GMAIL_USER`/`GMAIL_APP_PASSWORD`.

- [ ] **Step 10: Commit**

```bash
git add lib/Modulos/auth/data/auth_api.dart lib/Modulos/auth/presentation/olvide_contrasena_screen.dart lib/Modulos/auth/presentation/restablecer_contrasena_screen.dart lib/Modulos/auth/presentation/login_screen.dart test/auth_api_test.dart
git commit -m "feat(auth): pantallas de recuperacion de contrasena"
```

---

## Task 9: Flutter — dependencia `geolocator` y permisos Android

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Agregar la dependencia**

```yaml
# pubspec.yaml — dentro de dependencies:
  geolocator: ^13.0.0
```

Run: `flutter pub get`
Expected: resuelve sin conflictos de versión.

- [ ] **Step 2: Agregar los permisos de ubicación**

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <application
        android:label="fit_quest_go"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

(Solo se agregan las dos líneas de `uses-permission` nuevas; todo lo demás queda igual.)

- [ ] **Step 3: Confirmar que el proyecto sigue compilando**

Run: `flutter analyze`
Expected: mismos 4 avisos preexistentes de Mapbox, ninguno nuevo.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "feat(rutas): agregar geolocator y permisos de ubicacion"
```

---

## Task 10: Flutter — modo GPS en `PlanificarRutaScreen`

**Files:**
- Modify: `lib/Modulos/rutas/presentation/planificar_ruta_screen.dart`
- Test: `test/planificar_ruta_screen_test.dart` (nuevo)

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/planificar_ruta_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/planificar_ruta_screen.dart';
import 'package:geolocator/geolocator.dart';

Widget _montar({Stream<Position>? streamFalso}) {
  return MaterialApp(
    home: Scaffold(
      body: PlanificarRutaScreen(
        api: RutaApi(),
        posicionStream: streamFalso == null ? null : (() => streamFalso),
      ),
    ),
  );
}

void main() {
  testWidgets('arranca en modo Dibujar, con el selector visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_montar());
    await tester.pump();

    expect(find.text('Dibujar'), findsOneWidget);
    expect(find.text('Grabar GPS'), findsOneWidget);
    expect(find.text('Toca el mapa para trazar tu ruta, punto por punto.'),
        findsOneWidget);
  });

  testWidgets('cambiar a modo GPS muestra el boton Iniciar grabacion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_montar());
    await tester.pump();

    await tester.tap(find.text('Grabar GPS'));
    await tester.pump();

    expect(find.text('Iniciar grabacion'), findsOneWidget);
  });

  testWidgets('al grabar, cada posicion del stream se agrega como punto', (
    WidgetTester tester,
  ) async {
    final StreamController<Position> controlador =
        StreamController<Position>();
    addTearDown(controlador.close);

    await tester.pumpWidget(_montar(streamFalso: controlador.stream));
    await tester.pump();
    await tester.tap(find.text('Grabar GPS'));
    await tester.pump();
    await tester.tap(find.text('Iniciar grabacion'));
    await tester.pump();

    controlador.add(_posicion(9.9281, -84.0907));
    await tester.pump();
    controlador.add(_posicion(9.9291, -84.0917));
    await tester.pump();

    expect(find.textContaining('2 puntos'), findsOneWidget);
    expect(find.text('Detener'), findsOneWidget);
  });
}

Position _posicion(double lat, double lng) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
```

Agregar el import de `dart:async` (`StreamController`) al inicio del archivo de test.

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/planificar_ruta_screen_test.dart`
Expected: FAIL — `PlanificarRutaScreen` no tiene parámetro `posicionStream`, no existe el selector "Dibujar"/"Grabar GPS", ni "Iniciar grabacion".

- [ ] **Step 3: Implementar el modo GPS**

Reemplazar todo `lib/Modulos/rutas/presentation/planificar_ruta_screen.dart`:

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';

enum _ModoRuta { dibujar, gps }

/// RTE-05/06/07 · Planificar ruta. Modo "Dibujar": cada toque en el mapa
/// agrega un punto. Modo "Grabar GPS": cada posicion del dispositivo (con un
/// filtro de distancia minima) agrega un punto mientras se graba. En ambos
/// modos "Guardar" abre el mismo formulario y crea la ruta como Privada
/// (`POST /rutas`); la distancia se calcula sola (haversine) a partir de los
/// puntos, vengan de donde vengan.
class PlanificarRutaScreen extends StatefulWidget {
  const PlanificarRutaScreen({super.key, this.api, this.posicionStream});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final RutaApi? api;

  /// Fabrica del stream de posicion, inyectable para pruebas. En produccion
  /// usa `Geolocator.getPositionStream`.
  final Stream<Position> Function()? posicionStream;

  @override
  State<PlanificarRutaScreen> createState() => _PlanificarRutaScreenState();
}

class _PlanificarRutaScreenState extends State<PlanificarRutaScreen> {
  static const String _accessToken = String.fromEnvironment('ACCESS_TOKEN');
  static const double _distanciaMinimaEntrePuntosM = 8;

  late final RutaApi _api = widget.api ?? RutaApi();
  CircleAnnotationManager? _pines;
  PolylineAnnotationManager? _lineas;

  final List<PuntoRuta> _puntos = <PuntoRuta>[];
  bool _guardando = false;

  _ModoRuta _modo = _ModoRuta.dibujar;
  StreamSubscription<Position>? _suscripcionGps;
  bool _grabando = false;
  DateTime? _inicioGrabacion;

  @override
  void dispose() {
    _suscripcionGps?.cancel();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _pines = await controller.annotations.createCircleAnnotationManager();
    _lineas = await controller.annotations.createPolylineAnnotationManager();
  }

  Future<void> _onTap(MapContentGestureContext contexto) async {
    if (_guardando || _modo != _ModoRuta.dibujar) return;
    final Position posicion = contexto.point.coordinates;
    setState(() {
      _puntos.add(
        PuntoRuta(lat: posicion[1]!.toDouble(), lng: posicion[0]!.toDouble()),
      );
    });
    await _redibujar();
  }

  Future<void> _deshacer() async {
    if (_puntos.isEmpty || _grabando) return;
    setState(() => _puntos.removeLast());
    await _redibujar();
  }

  Future<void> _limpiar() async {
    if (_puntos.isEmpty || _grabando) return;
    setState(() => _puntos.clear());
    await _redibujar();
  }

  void _cambiarModo(_ModoRuta modo) {
    if (_grabando || _guardando) return;
    setState(() => _modo = modo);
  }

  Future<void> _iniciarGrabacion() async {
    final bool servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      notificarError('Activa la ubicacion del dispositivo para grabar');
      return;
    }

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      notificarError('Se necesita permiso de ubicacion para grabar');
      return;
    }
    if (permiso == LocationPermission.deniedForever) {
      notificarError(
        'Permiso de ubicacion bloqueado. Habilitalo desde Ajustes del sistema.',
      );
      return;
    }

    final Stream<Position> stream = widget.posicionStream != null
        ? widget.posicionStream!()
        : Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: _distanciaMinimaEntrePuntosM.toInt(),
            ),
          );

    setState(() {
      _grabando = true;
      _inicioGrabacion = DateTime.now();
    });

    _suscripcionGps = stream.listen((Position posicion) async {
      if (!mounted) return;
      setState(() {
        _puntos.add(PuntoRuta(lat: posicion.latitude, lng: posicion.longitude));
      });
      await _redibujar();
    });
  }

  Future<void> _detenerGrabacion() async {
    await _suscripcionGps?.cancel();
    _suscripcionGps = null;
    if (!mounted) return;
    setState(() => _grabando = false);
  }

  Future<void> _redibujar() async {
    await _pines?.deleteAll();
    await _lineas?.deleteAll();
    for (final PuntoRuta p in _puntos) {
      await _pines?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(p.lng, p.lat)),
          circleColor: FqColors.voltDark.toARGB32(),
          circleRadius: 6,
          circleStrokeColor: FqColors.white.toARGB32(),
          circleStrokeWidth: 2,
        ),
      );
    }
    if (_puntos.length >= 2) {
      await _lineas?.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: <Position>[
              for (final PuntoRuta p in _puntos) Position(p.lng, p.lat),
            ],
          ),
          lineColor: FqColors.river.toARGB32(),
          lineWidth: 4,
        ),
      );
    }
  }

  double get _distanciaKm {
    double total = 0;
    for (int i = 0; i < _puntos.length - 1; i++) {
      total += _haversineKm(_puntos[i], _puntos[i + 1]);
    }
    return total;
  }

  double _haversineKm(PuntoRuta a, PuntoRuta b) {
    const double radioTierra = 6371;
    final double dLat = _aRadianes(b.lat - a.lat);
    final double dLng = _aRadianes(b.lng - a.lng);
    final double lat1 = _aRadianes(a.lat);
    final double lat2 = _aRadianes(b.lat);
    final double h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return radioTierra * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _aRadianes(double grados) => grados * math.pi / 180;

  Future<void> _guardar() async {
    if (_puntos.length < 2) return;
    final _DatosRuta? datos = await _mostrarFormulario();
    if (datos == null) return;
    setState(() => _guardando = true);
    try {
      await _api.crear(
        nombre: datos.nombre,
        actividad: datos.actividad,
        dificultad: datos.dificultad,
        distanciaKm: _distanciaKm,
        puntos: _puntos,
      );
      if (!mounted) return;
      notificarExito('Ruta guardada como privada. Podes publicarla desde "Mis rutas".');
      setState(() {
        _puntos.clear();
        _inicioGrabacion = null;
      });
      await _redibujar();
    } catch (_) {
      if (mounted) notificarError('No se pudo guardar la ruta');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<_DatosRuta?> _mostrarFormulario() {
    final TextEditingController nombre = TextEditingController();
    final TextEditingController actividad = TextEditingController();
    String dificultad = 'moderada';
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showModalBottomSheet<_DatosRuta>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Guardar ruta',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_puntos.length} puntos · ${_distanciaKm.toStringAsFixed(1)} km aprox.',
                      style: const TextStyle(fontSize: 11, color: FqColors.muted),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nombre,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (String? v) =>
                          (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: actividad,
                      decoration: const InputDecoration(
                        labelText: 'Actividad',
                        hintText: 'Running, Ciclismo, Hiking...',
                      ),
                      validator: (String? v) =>
                          (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: dificultad,
                      decoration: const InputDecoration(labelText: 'Dificultad'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'facil', child: Text('Facil')),
                        DropdownMenuItem<String>(
                          value: 'moderada',
                          child: Text('Moderada'),
                        ),
                        DropdownMenuItem<String>(value: 'dificil', child: Text('Dificil')),
                      ],
                      onChanged: (String? v) =>
                          setSheetState(() => dificultad = v ?? dificultad),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        Navigator.of(ctx).pop(
                          _DatosRuta(
                            nombre: nombre.text.trim(),
                            actividad: actividad.text.trim(),
                            dificultad: dificultad,
                          ),
                        );
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_accessToken.isNotEmpty)
          MapWidget(
            key: const ValueKey<String>('planificar-ruta-map'),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(-84.0907, 9.9281)),
              zoom: 13.5,
            ),
            onMapCreated: _onMapCreated,
            onTapListener: _onTap,
          )
        else
          const ColoredBox(
            color: Color(0xFFE8EEE5),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Mapbox necesita ACCESS_TOKEN.\nInicia con --dart-define=ACCESS_TOKEN=pk…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FqColors.muted, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: _SelectorModo(
                  modo: _modo,
                  habilitado: !_grabando && !_guardando,
                  onCambiar: _cambiarModo,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: FqColors.white.withValues(alpha: .97),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: FqColors.softShadow,
                  ),
                  child: Text(
                    _modo == _ModoRuta.dibujar
                        ? 'Toca el mapa para trazar tu ruta, punto por punto.'
                        : (_grabando
                            ? 'Grabando... camina para trazar la ruta.'
                            : 'Toca "Iniciar grabacion" y empeza a caminar.'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FqColors.white.withValues(alpha: .97),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: FqColors.softShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        _puntos.isEmpty
                            ? 'Sin puntos todavia'
                            : '${_puntos.length} puntos · ${_distanciaKm.toStringAsFixed(1)} km aprox.'
                                '${_grabando ? _tiempoTranscurrido() : ''}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      _modo == _ModoRuta.dibujar
                          ? Row(
                              children: <Widget>[
                                Expanded(
                                  child: FqButton.secondary(
                                    label: 'Deshacer',
                                    dense: true,
                                    onPressed:
                                        _puntos.isEmpty || _guardando ? null : _deshacer,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FqButton.secondary(
                                    label: 'Limpiar',
                                    dense: true,
                                    onPressed:
                                        _puntos.isEmpty || _guardando ? null : _limpiar,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FqButton.primary(
                                    label: _guardando ? 'Guardando...' : 'Guardar',
                                    dense: true,
                                    onPressed: (_puntos.length < 2 || _guardando)
                                        ? null
                                        : _guardar,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: <Widget>[
                                Expanded(
                                  child: _grabando
                                      ? FqButton.danger(
                                          label: 'Detener',
                                          dense: true,
                                          onPressed: _detenerGrabacion,
                                        )
                                      : FqButton.secondary(
                                          label: 'Iniciar grabacion',
                                          dense: true,
                                          onPressed:
                                              _guardando ? null : _iniciarGrabacion,
                                        ),
                                ),
                                if (!_grabando) ...<Widget>[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FqButton.primary(
                                      label: _guardando ? 'Guardando...' : 'Guardar',
                                      dense: true,
                                      onPressed: (_puntos.length < 2 || _guardando)
                                          ? null
                                          : _guardar,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _tiempoTranscurrido() {
    if (_inicioGrabacion == null) return '';
    final Duration transcurrido = DateTime.now().difference(_inicioGrabacion!);
    final String mm = transcurrido.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String ss = transcurrido.inSeconds.remainder(60).toString().padLeft(2, '0');
    return ' · $mm:$ss';
  }
}

class _SelectorModo extends StatelessWidget {
  const _SelectorModo({
    required this.modo,
    required this.habilitado,
    required this.onCambiar,
  });

  final _ModoRuta modo;
  final bool habilitado;
  final ValueChanged<_ModoRuta> onCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FqColors.white.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(12),
        boxShadow: FqColors.softShadow,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Opcion(
              label: 'Dibujar',
              seleccionado: modo == _ModoRuta.dibujar,
              habilitado: habilitado,
              onTap: () => onCambiar(_ModoRuta.dibujar),
            ),
          ),
          Expanded(
            child: _Opcion(
              label: 'Grabar GPS',
              seleccionado: modo == _ModoRuta.gps,
              habilitado: habilitado,
              onTap: () => onCambiar(_ModoRuta.gps),
            ),
          ),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.label,
    required this.seleccionado,
    required this.habilitado,
    required this.onTap,
  });

  final String label;
  final bool seleccionado;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: habilitado ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? FqColors.voltDark : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: seleccionado ? FqColors.white : FqColors.ink,
          ),
        ),
      ),
    );
  }
}

class _DatosRuta {
  const _DatosRuta({
    required this.nombre,
    required this.actividad,
    required this.dificultad,
  });

  final String nombre;
  final String actividad;
  final String dificultad;
}
```

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/planificar_ruta_screen_test.dart`
Expected: PASS — 3 tests.

- [ ] **Step 5: Correr toda la suite de Flutter**

Run: `flutter test`
Expected: PASS completo, sin regresiones en ningún archivo de test existente.

- [ ] **Step 6: Verificación manual en el emulador con GPS simulado**

Con el emulador corriendo y la app abierta en la pestaña "Crear":

```bash
adb emu geo fix -84.0907 9.9281
```

En la app: tocar "Grabar GPS" → "Iniciar grabacion". Luego, para simular movimiento:

```bash
adb emu geo fix -84.0917 9.9291
```

Expected: aparece un segundo punto en el mapa, el contador sube a "2 puntos" y muestra distancia + tiempo transcurrido. Tocar "Detener" → "Guardar" → completar el formulario → confirmar que se guarda igual que una ruta dibujada a mano (toast de éxito, aparece luego en "Mis rutas").

- [ ] **Step 7: Commit**

```bash
git add lib/Modulos/rutas/presentation/planificar_ruta_screen.dart test/planificar_ruta_screen_test.dart
git commit -m "feat(rutas): modo de grabacion GPS en Planificar ruta"
```

---

## Self-Review Notes (para quien ejecute)

- **Cobertura del spec:** las 3 secciones del spec tienen tareas — Tracking GPS → Tasks 9-10; Recuperación de contraseña → Tasks 4-8; Aceptación legal → Tasks 1-3.
- **Desviación documentada del spec original:** Tasks 1-3 son más chicas de lo que el spec sugería, porque la UI de términos ya existía (ver nota al inicio del documento). Esto es una mejora, no un problema — menos código nuevo, menos riesgo.
- **Pendiente fuera de este plan:** las credenciales reales de Gmail (`GMAIL_USER`, `GMAIL_APP_PASSWORD`) — Task 5 deja el servicio listo pero no funcional hasta que el usuario las proporcione y se agreguen al `.env`. Background tracking (segundo plano) queda registrado como trabajo futuro en el spec, no en este plan.
