# Fase 2: Recuperación de Contraseña por Correo — Implementation Plan

> **Plan Maestro:** [2026-09-21-cierre-brechas-seguimiento-2.md](./2026-09-21-cierre-brechas-seguimiento-2.md) | **Spec:** [2026-09-21-cierre-brechas-seguimiento-2-design.md](../specs/2026-09-21-cierre-brechas-seguimiento-2-design.md)
> **Respaldo original:** [2026-09-21-cierre-brechas-seguimiento-2.backup.md](./2026-09-21-cierre-brechas-seguimiento-2.backup.md)

**Objetivo Fase 2:** Flujo completo de recuperación de contraseña: entidad de token, MailService con Nodemailer (Gmail), endpoints solicitar y 
establecer, y pantallas en Flutter.

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

