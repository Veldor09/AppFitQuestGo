# Fase 1: Aceptación Legal Obligatoria — Implementation Plan

> **Plan Maestro:** [2026-09-21-cierre-brechas-seguimiento-2.md](./2026-09-21-cierre-brechas-seguimiento-2.md) | **Spec:** [2026-09-21-cierre-brechas-seguimiento-2-design.md](../specs/2026-09-21-cierre-brechas-seguimiento-2-design.md)
> **Respaldo original:** [2026-09-21-cierre-brechas-seguimiento-2.backup.md](./2026-09-21-cierre-brechas-seguimiento-2.backup.md)

**Objetivo Fase 1:** Persistir la aceptación legal obligatoria (ceptaTerminos: true) al registrarse. Conecta la UI existente en Flutter con el backend NestJS.

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

