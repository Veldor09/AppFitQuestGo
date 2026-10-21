import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/core/db/daos/perfil_cache_dao.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificaciones_api.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/perfil_screen.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

class _FakeNotificacionesApi extends NotificacionesApi {
  @override
  Future<int> conteoNoLeidas() async => 0;
}

class _FakePerfilCacheDao extends PerfilCacheDao {
  _FakePerfilCacheDao(this.cachedUser);
  final Usuario? cachedUser;
  @override
  Future<Usuario?> leerUsuario(int idUsuario) async => cachedUser;
  @override
  Future<Usuario?> leerUltimoUsuario() async => cachedUser;
  @override
  Future<void> guardarUsuario(Usuario usuario) async {}
}

class _FakeAuthRepositorio extends AuthRepositorio {
  _FakeAuthRepositorio(this._u);
  final UsuarioSesion _u;
  @override
  UsuarioSesion? get usuario => _u;
  @override
  bool get autenticado => true;
}

void main() {
  const Map<String, dynamic> perfil = <String, dynamic>{
    'id': 7,
    'nombreUser': 'Ana Fernandez',
    'emailUser': 'ana@x.co',
    'idrol': 1,
    'estado': 'Activado',
    'rol': <String, dynamic>{'idrol': 1, 'nombreRol': 'UserNormal'},
  };

  PerfilApi fakeApi() {
    final MockClient client = MockClient((http.Request req) async {
      if (req.url.path == '/auth/perfil' && req.method == 'GET') {
        return http.Response(
          jsonEncode(perfil),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (req.url.path == '/usuarios/yo/estadisticas') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'kmRecorridos': 12,
            'rutasCompletadas': 3,
            'insignias': 5,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('{"conteo": 0}', 200, headers: <String, String>{'content-type': 'application/json'});
    });
    return PerfilApi(ApiClient(client: client, baseUrl: 'http://test'));
  }

  Widget montar(Size size) => MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox.fromSize(
              size: size,
              child: PerfilScreen(
                api: fakeApi(),
                notificacionesApi: _FakeNotificacionesApi(),
              ),
            ),
          ),
        ),
      );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final TestPlatformDispatcher dispatcher =
        TestWidgetsFlutterBinding.instance.platformDispatcher;
    dispatcher.localesTestValue = const <Locale>[Locale('es')];
    dispatcher.localeTestValue = const Locale('es');
  });

  tearDown(() {
    final TestPlatformDispatcher dispatcher =
        TestWidgetsFlutterBinding.instance.platformDispatcher;
    dispatcher.clearLocalesTestValue();
    dispatcher.clearLocaleTestValue();
  });

  testWidgets('muestra datos reales de la cuenta y el menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(montar(const Size(390, 844)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Cabecera con datos del backend.
    expect(find.text('Ana Fernandez'), findsOneWidget);
    expect(find.text('ana@x.co'), findsOneWidget);
    expect(find.text('AF'), findsOneWidget);

    // Tira de metricas y menu de accesos.
    expect(find.text('KM'), findsOneWidget);
    expect(find.text('RUTAS'), findsOneWidget);
    expect(find.text('INSIGNIAS'), findsOneWidget);
    for (final String fila in <String>[
      'Mis rutas',
      'Mis aportes',
      'Insignias',
      'Notificaciones',
      'Mapas offline',
      'Preferencias y privacidad',
    ]) {
      expect(find.text(fila), findsOneWidget);
    }
  });

  testWidgets('se pinta sin overflow en varios tamanos', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[
      const Size(390, 844),
      const Size(320, 600),
      const Size(600, 900),
    ]) {
      await tester.pumpWidget(montar(size));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'PRF-01 @ $size');
    }
  });

  testWidgets('la hoja de ajustes lista nombre y correo reales', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(montar(const Size(390, 844)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Ajustes de la cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Ajustes de la cuenta'), findsOneWidget);
    expect(find.text('ana@x.co'), findsAtLeastNWidgets(1));
    expect(find.text('Cerrar sesion'), findsNothing);
  });

  testWidgets('en modo offline sin conexion muestra datos guardados y acceso a mapas offline', (
    WidgetTester tester,
  ) async {
    final MockClient offlineClient = MockClient((http.Request req) async {
      throw http.ClientException('Sin conexión a internet');
    });
    final PerfilApi offlineApi = PerfilApi(ApiClient(client: offlineClient, baseUrl: 'http://test'));
    final _FakeAuthRepositorio auth = _FakeAuthRepositorio(
      const UsuarioSesion(
        id: 7,
        nombre: 'Ana Fernandez',
        email: 'ana@x.co',
        rol: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AuthScope(
          auth: auth,
          child: Scaffold(
            body: PerfilScreen(
              api: offlineApi,
              notificacionesApi: _FakeNotificacionesApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // NO debe bloquear la pantalla con FqEmptyState de error
    expect(find.text('No se pudo cargar tu perfil'), findsNothing);

    // Muestra los datos del perfil
    expect(find.text('Ana Fernandez'), findsOneWidget);
    expect(find.text('ana@x.co'), findsOneWidget);

    // Muestra el banner explicativo de modo sin conexión
    expect(find.textContaining('Modo sin conexión'), findsOneWidget);

    // Las opciones clave de la sección siguen visibles y accesibles
    expect(find.text('Mapas offline'), findsOneWidget);
    expect(find.text('Mis rutas'), findsOneWidget);
  });

  testWidgets('en modo offline sin sesion pero con SQLite cache muestra el usuario cacheado', (
    WidgetTester tester,
  ) async {
    final MockClient offlineClient = MockClient((http.Request req) async {
      throw http.ClientException('Sin red');
    });
    final PerfilApi offlineApi = PerfilApi(ApiClient(client: offlineClient, baseUrl: 'http://test'));
    final _FakePerfilCacheDao cache = _FakePerfilCacheDao(
      const Usuario(
        id: 99,
        nombreUser: 'Carlos Offline',
        emailUser: 'carlos@offline.com',
        idrol: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PerfilScreen(
            api: offlineApi,
            cacheDao: cache,
            notificacionesApi: _FakeNotificacionesApi(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Carlos Offline'), findsOneWidget);
    expect(find.text('carlos@offline.com'), findsOneWidget);
    expect(find.textContaining('Modo sin conexión'), findsOneWidget);
    expect(find.text('Mapas offline'), findsOneWidget);
  });
}
