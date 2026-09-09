import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuarios_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/usuarios_screen.dart';

/// Renderiza la pantalla de Usuarios con un backend simulado. Sirve para
/// detectar en modo debug errores de construccion (p. ej. `Container` con
/// `color` y `decoration` a la vez) que un build de release no reporta.
void main() {
  const List<Map<String, dynamic>> respuesta = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'nombreUser': 'Ana Uno',
      'emailUser': 'ana@x.co',
      'idrol': 1,
      'rol': <String, dynamic>{'idrol': 1, 'nombreRol': 'UserNormal'},
    },
    <String, dynamic>{
      'id': 2,
      'nombreUser': 'Beto Dos',
      'emailUser': 'beto@x.co',
      'idrol': 3,
      'rol': <String, dynamic>{'idrol': 3, 'nombreRol': 'Admin'},
    },
  ];

  UsuariosApi fakeApi() {
    final MockClient client = MockClient((http.Request req) async {
      if (req.url.path == '/usuarios' && req.method == 'GET') {
        return http.Response(
          jsonEncode(respuesta),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('no', 404);
    });
    return UsuariosApi(ApiClient(client: client, baseUrl: 'http://test'));
  }

  Widget montar(UsuariosApi api) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1100,
            height: 720,
            child: UsuariosScreen(api: api),
          ),
        ),
      );

  setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

  testWidgets('renderiza la tabla con columnas y filas del backend', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(montar(fakeApi()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('NOMBRE'), findsOneWidget);
    expect(find.text('CORREO'), findsOneWidget);
    expect(find.text('ROL'), findsOneWidget);
    expect(find.text('ESTADO'), findsOneWidget);
    expect(find.text('ACCIONES'), findsOneWidget);

    expect(find.text('Ana Uno'), findsOneWidget);
    expect(find.text('beto@x.co'), findsOneWidget);
    // Estado por defecto + accion de baja.
    expect(find.text('ACTIVADO'), findsWidgets);
    expect(find.text('Desactivar'), findsWidgets);

    expect(find.text('Filtros'), findsOneWidget);
    expect(find.text('Nuevo usuario'), findsOneWidget);
    expect(find.textContaining('de 2'), findsOneWidget);
  });

  testWidgets('el modal "Ver" abre y nunca muestra el ID', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(montar(fakeApi()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Ver').first);
    await tester.pumpAndSettle();

    // "Cerrar" solo existe en el modo "ver" del modal.
    expect(find.text('Cerrar'), findsOneWidget);
    // El ID no aparece en ningun lado.
    expect(find.text('ID'), findsNothing);
    expect(find.textContaining('ID 1'), findsNothing);
  });
}
