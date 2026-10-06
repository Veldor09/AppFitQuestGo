import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/perfil_screen.dart';

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
      return http.Response('no', 404);
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
              child: PerfilScreen(api: fakeApi()),
            ),
          ),
        ),
      );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    // El entorno de test cae en en_US por defecto; se fuerza espanol para
    // que coincida con `locale: Locale('es')` de montar() (ver nota igual
    // en widget_test.dart / planificar_ruta_screen_test.dart).
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
    expect(find.text('Usuario · Activado'), findsOneWidget);
    expect(find.text('AF'), findsOneWidget);

    // Tira de metricas (de ejemplo) y menu de accesos.
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
    expect(find.text('ana@x.co'), findsOneWidget);
    expect(find.text('Cerrar sesion'), findsNothing); // sin callback en el test
  });
}
