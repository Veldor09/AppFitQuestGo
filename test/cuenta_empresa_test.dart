import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/fotos/selector_foto.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_api.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/Modulos/empresa/data/empresa_api.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/cuenta_empresa_screen.dart';

import 'helpers/montar.dart';

/// PNG valido de 1x1 px (para que `MemoryImage` lo pueda decodificar).
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const PerfilEmpresa _perfil = PerfilEmpresa(
  id: 20,
  nombre: 'Cafe El Roble',
  email: 'contacto@elroble.co',
  telefono: '8888-8888',
);

class _EmpresaApiFalsa extends EmpresaApi {
  _EmpresaApiFalsa({this.perfil = _perfil, this.fotoInicial});

  PerfilEmpresa perfil;
  Uint8List? fotoInicial;
  Object? errorAlCargar;
  Object? errorAlActualizar;
  Object? errorAlSubir;
  Object? errorFoto;
  int cargas = 0;
  final List<Map<String, String>> actualizaciones = <Map<String, String>>[];
  final List<Uint8List> subidas = <Uint8List>[];
  int quitadas = 0;

  @override
  Future<PerfilEmpresa> miPerfil() async {
    cargas++;
    if (errorAlCargar != null) throw errorAlCargar!;
    return perfil;
  }

  @override
  Future<PerfilEmpresa> actualizar({
    required String nombreComercial,
    required String telefono,
  }) async {
    if (errorAlActualizar != null) throw errorAlActualizar!;
    actualizaciones.add(<String, String>{
      'nombreComercial': nombreComercial,
      'telefono': telefono,
    });
    perfil = PerfilEmpresa(
      id: perfil.id,
      nombre: nombreComercial.trim(),
      email: perfil.email,
      telefono: telefono.trim().isEmpty ? null : telefono.trim(),
    );
    return perfil;
  }

  @override
  Future<Uint8List?> foto() async {
    if (errorFoto != null) throw errorFoto!;
    return fotoInicial;
  }

  @override
  Future<void> subirFoto(Uint8List bytes) async {
    if (errorAlSubir != null) throw errorAlSubir!;
    subidas.add(bytes);
  }

  @override
  Future<void> quitarFoto() async {
    quitadas++;
  }
}

class _SelectorFalso implements SelectorFoto {
  _SelectorFalso([this.respuesta]);

  Uint8List? respuesta;
  final List<OrigenFoto> pedidos = <OrigenFoto>[];

  @override
  Future<Uint8List?> elegir(OrigenFoto origen) async {
    pedidos.add(origen);
    return respuesta;
  }
}

UsuarioSesion _usuario() => const UsuarioSesion(
  id: 20,
  nombre: 'Cafe El Roble',
  email: 'contacto@elroble.co',
  rol: RolUsuario.empresa,
);

Future<AuthFalso> _abrir(
  WidgetTester tester,
  _EmpresaApiFalsa api, {
  _SelectorFalso? selector,
  VoidCallback? alCerrar,
}) async {
  final AuthFalso auth = AuthFalso(usuario: _usuario());
  await montarApp(
    tester,
    CuentaEmpresaScreen(
      api: api,
      selectorFoto: selector ?? _SelectorFalso(),
      onCerrarSesion: alCerrar ?? () {},
    ),
    auth: auth,
  );
  await tester.pumpAndSettle();
  return auth;
}

Finder _tocable(String clave) => find.byKey(ValueKey<String>(clave));

Future<void> _guardar(WidgetTester tester) async {
  await tester.ensureVisible(_tocable('guardar-cuenta'));
  await tester.tap(_tocable('guardar-cuenta'));
  await tester.pumpAndSettle();
}

void main() {
  group('PerfilEmpresa y EmpresaApi', () {
    test('fromJson lee GET /auth/perfil (nombreUser / emailUser)', () {
      final PerfilEmpresa p = PerfilEmpresa.fromJson(<String, dynamic>{
        'id': 1,
        'nombreUser': 'Cafe',
        'emailUser': 'a@b.co',
        'telefono': '8888-8888',
      });
      expect(p.nombre, 'Cafe');
      expect(p.email, 'a@b.co');
      expect(p.telefono, '8888-8888');
    });

    test('fromJson lee PATCH /auth/perfil-empresa (nombre / email)', () {
      final PerfilEmpresa p = PerfilEmpresa.fromJson(<String, dynamic>{
        'id': 1,
        'nombre': 'Cafe',
        'email': 'a@b.co',
        'rol': 2,
        'telefono': null,
      });
      expect(p.nombre, 'Cafe');
      expect(p.telefono, isNull);
    });

    test(
      'actualizar usa PATCH /auth/perfil-empresa con los datos recortados',
      () async {
        final List<Peticion> reg = <Peticion>[];
        final EmpresaApi api = EmpresaApi(
          apiFalso(
            reg,
            (Peticion _) => (
              cuerpo: <String, dynamic>{
                'id': 1,
                'nombre': 'Nuevo',
                'email': 'a@b.co',
                'rol': 2,
                'telefono': '7777-7777',
              },
              estado: 200,
            ),
          ),
        );
        final PerfilEmpresa p = await api.actualizar(
          nombreComercial: '  Nuevo  ',
          telefono: ' 7777-7777 ',
        );
        expect(reg.single.toString(), 'PATCH /auth/perfil-empresa');
        expect(reg.single.cuerpo, <String, dynamic>{
          'nombreComercial': 'Nuevo',
          'telefono': '7777-7777',
        });
        expect(p.nombre, 'Nuevo');
      },
    );

    test('subirFoto hace POST /auth/perfil/foto y acepta el 204', () async {
      final List<Peticion> reg = <Peticion>[];
      final EmpresaApi api = EmpresaApi(
        apiFalso(reg, (Peticion _) => (cuerpo: null, estado: 204)),
      );
      await api.subirFoto(_png);
      expect(reg.single.toString(), 'POST /auth/perfil/foto');
    });

    test('quitarFoto hace DELETE /auth/perfil/foto', () async {
      final List<Peticion> reg = <Peticion>[];
      final EmpresaApi api = EmpresaApi(
        apiFalso(reg, (Peticion _) => (cuerpo: null, estado: 204)),
      );
      await api.quitarFoto();
      expect(reg.single.toString(), 'DELETE /auth/perfil/foto');
    });

    test(
      'foto devuelve null si la cuenta no tiene (404), no un error',
      () async {
        final EmpresaApi api = EmpresaApi(
          apiFalso(
            <Peticion>[],
            (Peticion _) => (
              cuerpo: <String, dynamic>{'message': 'La cuenta no tiene foto'},
              estado: 404,
            ),
          ),
        );
        expect(await api.foto(), isNull);
      },
    );

    test('foto deja pasar cualquier otro error', () async {
      final EmpresaApi api = EmpresaApi(
        apiFalso(
          <Peticion>[],
          (Peticion _) =>
              (cuerpo: <String, dynamic>{'message': 'x'}, estado: 500),
        ),
      );
      await expectLater(api.foto(), throwsA(isA<ApiException>()));
    });
  });

  group('AuthRepositorio.actualizarNombre (el metodo real)', () {
    /// Un repositorio real, con sesion iniciada contra un servidor falso.
    Future<AuthRepositorio> sesionIniciada() async {
      final AuthRepositorio auth = AuthRepositorio(
        api: AuthApi(
          apiFalso(
            <Peticion>[],
            (Peticion _) => (
              cuerpo: <String, dynamic>{
                'usuario': <String, dynamic>{
                  'id': 20,
                  'nombre': 'Cafe El Roble',
                  'email': 'contacto@elroble.co',
                  'rol': 2,
                },
                'accessToken': 'a',
                'refreshToken': 'r',
              },
              estado: 200,
            ),
          ),
        ),
        tokens: SinTokens(),
      );
      await auth.iniciarSesion(email: 'contacto@elroble.co', contrasena: 'x');
      return auth;
    }

    test('cambia el nombre y conserva id, correo y rol', () async {
      final AuthRepositorio auth = await sesionIniciada();
      auth.actualizarNombre('Cafe Nuevo');
      expect(auth.usuario?.nombre, 'Cafe Nuevo');
      expect(auth.usuario?.id, 20);
      expect(auth.usuario?.email, 'contacto@elroble.co');
      expect(auth.usuario?.esEmpresa, isTrue);
    });

    test('avisa a quien escucha', () async {
      final AuthRepositorio auth = await sesionIniciada();
      int avisos = 0;
      auth.addListener(() => avisos++);
      auth.actualizarNombre('X1');
      expect(avisos, 1);
    });

    test('sin sesion no hace nada ni avisa', () {
      final AuthRepositorio auth = AuthRepositorio(tokens: SinTokens());
      int avisos = 0;
      auth.addListener(() => avisos++);
      auth.actualizarNombre('X1');
      expect(auth.usuario, isNull);
      expect(avisos, 0);
    });
  });

  group('CuentaEmpresaScreen', () {
    testWidgets('muestra el nombre, el telefono y el correo de la cuenta', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _EmpresaApiFalsa());

      String texto(String clave) => tester
          .widget<TextField>(
            find.descendant(
              of: _tocable(clave),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text;
      expect(texto('campo-nombre-cuenta'), 'Cafe El Roble');
      expect(texto('campo-telefono-cuenta'), '8888-8888');
      expect(find.text('contacto@elroble.co'), findsOneWidget);
    });

    testWidgets('sin foto muestra las iniciales', (WidgetTester tester) async {
      await _abrir(tester, _EmpresaApiFalsa());

      expect(find.text('CE'), findsOneWidget);
    });

    testWidgets('con foto la muestra en lugar de las iniciales', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _EmpresaApiFalsa(fotoInicial: _png));

      expect(_tocable('avatar-iniciales'), findsNothing);
      final CircleAvatar avatar = tester.widget(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<MemoryImage>());
    });

    testWidgets('si la foto falla igual muestra la cuenta, con iniciales', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _EmpresaApiFalsa()..errorFoto = Exception('x'));

      expect(find.text('Cafe El Roble'), findsOneWidget);
      expect(find.text('CE'), findsOneWidget);
    });

    testWidgets('el correo no se puede editar', (WidgetTester tester) async {
      await _abrir(tester, _EmpresaApiFalsa());

      final TextField campo = tester.widget(
        find.descendant(
          of: _tocable('campo-correo-cuenta'),
          matching: find.byType(TextField),
        ),
      );
      expect(campo.enabled, isFalse);
      expect(
        find.text('El correo no se puede cambiar desde aqui'),
        findsOneWidget,
      );
    });

    testWidgets(
      'cambiar el nombre y el telefono los guarda y actualiza la sesion',
      (WidgetTester tester) async {
        final _EmpresaApiFalsa api = _EmpresaApiFalsa();
        final AuthFalso auth = await _abrir(tester, api);

        await tester.enterText(
          _tocable('campo-nombre-cuenta'),
          '  Cafe El Roble 2 S.A.  ',
        );
        await tester.enterText(_tocable('campo-telefono-cuenta'), '7777-7777');
        await _guardar(tester);

        expect(api.actualizaciones, hasLength(1));
        expect(api.actualizaciones.single, <String, String>{
          'nombreComercial': '  Cafe El Roble 2 S.A.  ',
          'telefono': '7777-7777',
        });
        expect(find.text('Datos actualizados'), findsOneWidget);
        // La sesion queda con el nombre nuevo, ya recortado.
        expect(auth.usuario?.nombre, 'Cafe El Roble 2 S.A.');
      },
    );

    testWidgets('un telefono vacio se envia vacio para borrarlo', (
      WidgetTester tester,
    ) async {
      final _EmpresaApiFalsa api = _EmpresaApiFalsa();
      await _abrir(tester, api);

      await tester.enterText(_tocable('campo-telefono-cuenta'), '');
      await _guardar(tester);

      expect(api.actualizaciones.single['telefono'], '');
    });

    testWidgets('un nombre vacio no se guarda', (WidgetTester tester) async {
      final _EmpresaApiFalsa api = _EmpresaApiFalsa();
      await _abrir(tester, api);

      await tester.enterText(_tocable('campo-nombre-cuenta'), '   ');
      await _guardar(tester);

      expect(api.actualizaciones, isEmpty);
      expect(find.text('El nombre comercial es obligatorio'), findsOneWidget);
    });

    testWidgets('un telefono invalido no se guarda', (
      WidgetTester tester,
    ) async {
      final _EmpresaApiFalsa api = _EmpresaApiFalsa();
      await _abrir(tester, api);

      await tester.enterText(_tocable('campo-telefono-cuenta'), '123');
      await _guardar(tester);

      expect(api.actualizaciones, isEmpty);
      expect(
        find.text('Telefono invalido: usa de 8 a 20 digitos'),
        findsOneWidget,
      );
    });

    testWidgets(
      'un error del servidor se muestra y los datos siguen en pantalla',
      (WidgetTester tester) async {
        final _EmpresaApiFalsa api = _EmpresaApiFalsa()
          ..errorAlActualizar = ApiException(403, 'Solo una cuenta de empresa');
        final AuthFalso auth = await _abrir(tester, api);

        await tester.enterText(_tocable('campo-nombre-cuenta'), 'Otro nombre');
        await _guardar(tester);

        expect(find.text('Solo una cuenta de empresa'), findsOneWidget);
        expect(auth.usuario?.nombre, 'Cafe El Roble'); // la sesion no cambio
      },
    );

    testWidgets('un fallo de red muestra el mensaje generico', (
      WidgetTester tester,
    ) async {
      final _EmpresaApiFalsa api = _EmpresaApiFalsa()
        ..errorAlActualizar = Exception('sin red');
      await _abrir(tester, api);
      await _guardar(tester);

      expect(find.text('No se pudieron guardar los cambios'), findsOneWidget);
    });

    testWidgets('si no carga la cuenta ofrece reintentar y cerrar sesion', (
      WidgetTester tester,
    ) async {
      int cierres = 0;
      final _EmpresaApiFalsa api = _EmpresaApiFalsa()
        ..errorAlCargar = ApiException(500, 'caido');
      await _abrir(tester, api, alCerrar: () => cierres++);

      expect(find.text('No se pudo cargar tu cuenta'), findsOneWidget);

      await tester.tap(_tocable('cerrar-sesion-empresa'));
      expect(cierres, 1);

      api.errorAlCargar = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Cafe El Roble'), findsOneWidget);
    });

    testWidgets('"Cerrar sesion" llama al callback', (
      WidgetTester tester,
    ) async {
      int cierres = 0;
      await _abrir(tester, _EmpresaApiFalsa(), alCerrar: () => cierres++);

      await tester.ensureVisible(_tocable('cerrar-sesion-empresa'));
      await tester.tap(_tocable('cerrar-sesion-empresa'));
      expect(cierres, 1);
    });
  });

  group('foto de perfil', () {
    testWidgets('elegir de la galeria la sube y la muestra', (
      WidgetTester tester,
    ) async {
      final _EmpresaApiFalsa api = _EmpresaApiFalsa();
      final _SelectorFalso selector = _SelectorFalso(_png);
      await _abrir(tester, api, selector: selector);

      await tester.tap(_tocable('avatar-cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(_tocable('foto-galeria'));
      await tester.pumpAndSettle();

      expect(selector.pedidos, <OrigenFoto>[OrigenFoto.galeria]);
      expect(api.subidas, <Uint8List>[_png]);
      expect(find.text('Foto actualizada'), findsOneWidget);
      final CircleAvatar avatar = tester.widget(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<MemoryImage>());
    });

    testWidgets('la camara pide la camara', (WidgetTester tester) async {
      final _SelectorFalso selector = _SelectorFalso(_png);
      await _abrir(tester, _EmpresaApiFalsa(), selector: selector);

      await tester.tap(_tocable('avatar-cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(_tocable('foto-camara'));
      await tester.pumpAndSettle();

      expect(selector.pedidos, <OrigenFoto>[OrigenFoto.camara]);
    });

    testWidgets('si la persona cancela la seleccion no se sube nada', (
      WidgetTester tester,
    ) async {
      final _EmpresaApiFalsa api = _EmpresaApiFalsa();
      await _abrir(tester, api, selector: _SelectorFalso(null));

      await tester.tap(_tocable('avatar-cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(_tocable('foto-galeria'));
      await tester.pumpAndSettle();

      expect(api.subidas, isEmpty);
      expect(find.text('CE'), findsOneWidget);
    });

    testWidgets('si la subida falla avisa y deja la foto de antes', (
      WidgetTester tester,
    ) async {
      final _EmpresaApiFalsa api = _EmpresaApiFalsa()
        ..errorAlSubir = ApiException(413, 'La foto pesa mas de 3 MB');
      await _abrir(tester, api, selector: _SelectorFalso(_png));

      await tester.tap(_tocable('avatar-cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(_tocable('foto-galeria'));
      await tester.pumpAndSettle();

      expect(find.text('La foto pesa mas de 3 MB'), findsOneWidget);
      expect(find.text('CE'), findsOneWidget);
    });

    testWidgets('"Quitar foto" solo aparece si ya hay una', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _EmpresaApiFalsa());
      await tester.tap(_tocable('avatar-cuenta'));
      await tester.pumpAndSettle();
      expect(_tocable('foto-quitar'), findsNothing);
    });

    testWidgets('quitar la foto la borra y vuelven las iniciales', (
      WidgetTester tester,
    ) async {
      final _EmpresaApiFalsa api = _EmpresaApiFalsa(fotoInicial: _png);
      await _abrir(tester, api);

      await tester.tap(_tocable('avatar-cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(_tocable('foto-quitar'));
      await tester.pumpAndSettle();

      expect(api.quitadas, 1);
      expect(find.text('Foto eliminada'), findsOneWidget);
      expect(find.text('CE'), findsOneWidget);
    });
  });
}
