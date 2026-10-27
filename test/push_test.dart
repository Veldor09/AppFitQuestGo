import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/idioma/idioma_app.dart';
import 'package:fit_quest_go/core/navegador_app.dart';
import 'package:fit_quest_go/core/push/push_api.dart';
import 'package:fit_quest_go/core/push/registro_push.dart';
import 'package:fit_quest_go/core/push/servicio_push.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_api.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/preferencias_screen.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

import 'helpers/montar.dart';
import 'helpers/servicio_push_falso.dart';

void main() {
  group('idiomaDeAviso', () {
    test('el servidor solo sabe escribir avisos en es, en y pt', () {
      expect(idiomaDeAviso(const Locale('es')), 'es');
      expect(idiomaDeAviso(const Locale('en', 'US')), 'en');
      expect(idiomaDeAviso(const Locale('pt', 'BR')), 'pt');
      expect(idiomaDeAviso(const Locale('fr')), 'es');
    });
  });

  group('servicio por defecto', () {
    test(
      'en el escritorio (flutter test) es el nulo: ninguna prueba toca Firebase',
      () async {
        final ServicioPush push = ServicioPush.instancia;
        expect(push.disponible, isFalse);
        await push.registrar(idioma: 'es');
        await push.quitar();
      },
    );
  });

  group('PushApi', () {
    test(
      'registra el telefono con su token, plataforma e idioma, y lo da de baja',
      () async {
        final List<http.Request> pedidas = <http.Request>[];
        final PushApi api = PushApi(
          ApiClient(
            client: MockClient((http.Request req) async {
              pedidas.add(req);
              return http.Response(
                '{}',
                200,
                headers: <String, String>{'content-type': 'application/json'},
              );
            }),
            baseUrl: 'http://test',
            tokens: SinTokens(),
          ),
        );

        await api.registrar(token: 'abc', plataforma: 'android', idioma: 'en');
        await api.quitar('abc');

        expect(pedidas[0].url.path, '/notificaciones/push/dispositivo');
        expect(jsonDecode(pedidas[0].body), <String, Object?>{
          'token': 'abc',
          'plataforma': 'android',
          'idioma': 'en',
        });
        expect(pedidas[1].url.path, '/notificaciones/push/dispositivo/baja');
        expect(jsonDecode(pedidas[1].body), <String, Object?>{'token': 'abc'});
      },
    );
  });

  group('RegistroPush', () {
    late ServicioPushFalso push;

    setUp(() {
      push = ServicioPushFalso();
    });

    Widget app(Locale locale, {Locale? nueva}) => MaterialApp(
      navigatorKey: navegadorApp,
      locale: nueva ?? locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RegistroPush(
        servicio: push,
        pantallaNotificaciones: () => const Text('bandeja de notificaciones'),
        child: const Text('inicio'),
      ),
    );

    testWidgets(
      'al entrar registra el telefono en el idioma de la app y puede pedir el permiso',
      (WidgetTester tester) async {
        await tester.pumpWidget(app(const Locale('en')));

        expect(push.registros, <({String idioma, bool pedirPermiso})>[
          (idioma: 'en', pedirPermiso: true),
        ]);
      },
    );

    testWidgets(
      'si la persona cambia el idioma de la app se actualiza el registro, sin volver a preguntar el permiso',
      (WidgetTester tester) async {
        await tester.pumpWidget(app(const Locale('es')));
        await tester.pumpWidget(
          app(const Locale('es'), nueva: const Locale('pt', 'BR')),
        );

        expect(push.registros, <({String idioma, bool pedirPermiso})>[
          (idioma: 'es', pedirPermiso: true),
          (idioma: 'pt', pedirPermiso: false),
        ]);
      },
    );

    testWidgets('un rebuild sin cambio de idioma no registra otra vez', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(app(const Locale('es')));
      await tester.pumpWidget(app(const Locale('es')));
      expect(push.registros, hasLength(1));
    });

    testWidgets('tocar un aviso del sistema abre el centro de notificaciones', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(app(const Locale('es')));
      expect(find.text('bandeja de notificaciones'), findsNothing);

      push.alTocarAviso!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('bandeja de notificaciones'), findsOneWidget);
    });

    testWidgets('al cerrar la sesion deja de escuchar los toques', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(app(const Locale('es')));
      expect(push.alTocarAviso, isNotNull);

      await tester.pumpWidget(
        MaterialApp(navigatorKey: navegadorApp, home: const Text('bienvenida')),
      );

      expect(push.alTocarAviso, isNull);
    });
  });

  group('interruptor "Notificaciones push" en Preferencias', () {
    late ServicioPushFalso push;
    late _PerfilApiFalsa perfil;

    setUp(() {
      push = ServicioPushFalso();
      perfil = _PerfilApiFalsa();
    });

    Future<void> abrir(WidgetTester tester, {required bool activadas}) async {
      await montarApp(
        tester,
        PreferenciasScreen(
          usuario: Usuario(
            id: 1,
            nombreUser: 'Ana',
            emailUser: 'ana@correo.com',
            idrol: 1,
            notificaciones: activadas,
          ),
          api: perfil,
          idioma: ControladorIdioma(_AlmacenIdiomaNulo()),
          push: push,
        ),
      );
      await tester.pump();
    }

    Future<void> cambiarYGuardar(WidgetTester tester) async {
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Guardar preferencias'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Guardar preferencias'));
      await tester.pumpAndSettle();
    }

    testWidgets('apagarlo y guardar da de baja este telefono', (
      WidgetTester tester,
    ) async {
      await abrir(tester, activadas: true);
      await cambiarYGuardar(tester);

      expect(perfil.guardadas, 1);
      expect(push.bajas, 1);
      expect(push.registros, isEmpty);
    });

    testWidgets(
      'prenderlo y guardar registra este telefono en el idioma de la app',
      (WidgetTester tester) async {
        await abrir(tester, activadas: false);
        await cambiarYGuardar(tester);

        expect(push.registros, <({String idioma, bool pedirPermiso})>[
          (idioma: 'es', pedirPermiso: true),
        ]);
        expect(push.bajas, 0);
      },
    );

    testWidgets(
      'guardar sin tocar el interruptor no cambia nada en los avisos',
      (WidgetTester tester) async {
        await abrir(tester, activadas: true);
        await tester.scrollUntilVisible(
          find.text('Guardar preferencias'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Guardar preferencias'));
        await tester.pumpAndSettle();

        expect(perfil.guardadas, 1);
        expect(push.bajas, 0);
        expect(push.registros, isEmpty);
      },
    );
  });

  group('cerrar sesion', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test(
      'da de baja el telefono antes de borrar los tokens (hace falta la sesion para hacerlo)',
      () async {
        final ServicioPush anterior = ServicioPush.instancia;
        final ServicioPushFalso push = ServicioPushFalso();
        ServicioPush.instancia = push;
        addTearDown(() => ServicioPush.instancia = anterior);

        final AlmacenTokens tokens = _TokensEnMemoria();
        await tokens.guardar(access: 'a', refresh: 'r');
        final AuthApi api = AuthApi(
          ApiClient(
            client: MockClient(
              (http.Request req) async => http.Response('{}', 200),
            ),
            baseUrl: 'http://test',
            tokens: tokens,
          ),
        );
        final AuthRepositorio auth = AuthRepositorio(api: api, tokens: tokens);
        String? accesoAlDarseDeBaja;
        push.alQuitar = () async =>
            accesoAlDarseDeBaja = await tokens.leerAccess();

        await auth.cerrarSesion();

        expect(push.bajas, 1);
        expect(accesoAlDarseDeBaja, 'a');
        expect(await tokens.leerAccess(), isNull);
      },
    );

    test('si darse de baja se cuelga, cerrar sesion igual termina', () async {
      final ServicioPush anterior = ServicioPush.instancia;
      ServicioPush.instancia = _PushColgado();
      addTearDown(() => ServicioPush.instancia = anterior);

      final AlmacenTokens tokens = _TokensEnMemoria();
      await tokens.guardar(access: 'a', refresh: 'r');
      final AuthRepositorio auth = AuthRepositorio(
        api: AuthApi(
          ApiClient(
            client: MockClient(
              (http.Request req) async => http.Response('{}', 200),
            ),
            baseUrl: 'http://test',
            tokens: tokens,
          ),
        ),
        tokens: tokens,
      );

      await auth.cerrarSesion();

      expect(auth.autenticado, isFalse);
      expect(await tokens.leerAccess(), isNull);
    });
  });
}

class _PerfilApiFalsa extends PerfilApi {
  int guardadas = 0;

  @override
  Future<Usuario> actualizarPerfil({
    required int id,
    required String nombreUser,
    required String emailUser,
    String? nuevaContrasena,
    List<String>? intereses,
    List<String>? actividades,
    String? unidad,
    bool? notificaciones,
    String? visibilidad,
  }) async {
    guardadas++;
    return Usuario(
      id: id,
      nombreUser: nombreUser,
      emailUser: emailUser,
      idrol: 1,
      notificaciones: notificaciones ?? true,
    );
  }
}

class _AlmacenIdiomaNulo implements AlmacenIdioma {
  @override
  Future<String?> leer() async => null;

  @override
  Future<void> guardar(String? codigo) async {}
}

class _TokensEnMemoria extends AlmacenTokens {
  String? _access;
  String? _refresh;

  @override
  Future<void> guardar({
    required String access,
    required String refresh,
  }) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<String?> leerAccess() async => _access;

  @override
  Future<String?> leerRefresh() async => _refresh;

  @override
  Future<void> limpiar() async {
    _access = null;
    _refresh = null;
  }
}

/// Un servicio cuya baja nunca contesta (sin red, Firebase colgado).
class _PushColgado extends ServicioPush {
  @override
  bool get disponible => true;

  @override
  Future<void> registrar({
    required String idioma,
    bool pedirPermiso = true,
  }) async {}

  @override
  Future<void> quitar() => Future<void>.delayed(const Duration(hours: 1));
}
