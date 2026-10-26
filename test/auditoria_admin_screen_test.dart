
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/admin/data/auditoria_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/auditoria_screen.dart';

class _AuditoriaApiFake extends AuditoriaApi {
  final List<Map<String, dynamic>> registros = [
    {
      'id': 1,
      'administradorId': 10,
      'accion': 'USUARIO_CREADO',
      'entidad': 'USUARIO',
      'entidadId': 101,
      'creadoEn': '2026-10-20T10:00:00Z',
      'detalle': {'datosRegistrados': {'nombreUser': 'Carlos'}},
    },
    {
      'id': 2,
      'administradorId': 20,
      'accion': 'USUARIO_ACTUALIZADO',
      'entidad': 'USUARIO',
      'entidadId': 102,
      'creadoEn': '2026-10-21T10:00:00Z',
      'detalle': {
        'cambios': {
          'nombreUser': {
            'anterior': 'Ana',
            'nuevo': 'Ana María',
          },
        },
      },
    },
    {
      'id': 3,
      'administradorId': 10,
      'accion': 'RUTA_APROBADA',
      'entidad': 'RUTA',
      'entidadId': 103,
      'creadoEn': '2026-10-22T10:00:00Z',
      'detalle': null,
    },
  ];

  final List<Map<String, dynamic>> consultas = [];

  @override
  Future<Map<String, dynamic>> consultar({
    int? administradorId,
    String? accion,
    String? entidad,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int pagina = 1,
    int limite = 20,
  }) async {
    consultas.add({
      'administradorId': administradorId,
      'accion': accion,
      'entidad': entidad,
      'pagina': pagina,
      'limite': limite,
    });

    final filtrados = registros.where((registro) {
      if (administradorId != null &&
          registro['administradorId'] != administradorId) {
        return false;
      }

      if (accion != null &&
          accion.isNotEmpty &&
          !registro['accion']
              .toString()
              .toUpperCase()
              .contains(accion.toUpperCase())) {
        return false;
      }

      if (entidad != null &&
          entidad.isNotEmpty &&
          !registro['entidad']
              .toString()
              .toUpperCase()
              .contains(entidad.toUpperCase())) {
        return false;
      }

      return true;
    }).toList();

    final inicio = (pagina - 1) * limite;
    final fin = (inicio + limite).clamp(0, filtrados.length);

    final paginaRegistros = inicio >= filtrados.length
        ? <Map<String, dynamic>>[]
        : filtrados.sublist(inicio, fin);

    return {
      'registros': paginaRegistros,
      'total': filtrados.length,
      'totalPaginas': (filtrados.length / limite).ceil(),
    };
  }
}

Future<void> _montar(
  WidgetTester tester,
  AuditoriaApi api,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AuditoriaScreen(api: api),
      ),
    ),
  );

  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ADM-13 consulta el historial de auditoría', (tester) async {
    final api = _AuditoriaApiFake();

    await _montar(tester, api);

    expect(api.consultas.length, 1);
    expect(api.consultas.first['pagina'], 1);
    expect(api.consultas.first['limite'], 20);

    expect(find.text('Usuario creado'), findsOneWidget);
    expect(find.text('Usuario actualizado'), findsOneWidget);
    expect(find.text('RUTA APROBADA'), findsOneWidget);
  });

  testWidgets('ADM-13 filtra por administrador', (tester) async {
    final api = _AuditoriaApiFake();

    await _montar(tester, api);

    await tester.enterText(
      find.widgetWithText(TextField, 'ID administrador'),
      '10',
    );

    await tester.tap(find.text('Buscar'));
    await tester.pump();

    expect(api.consultas.last['administradorId'], 10);
    expect(find.text('Usuario creado'), findsOneWidget);
    expect(find.text('RUTA APROBADA'), findsOneWidget);
    expect(find.text('Usuario actualizado'), findsNothing);
  });

  testWidgets('ADM-13 filtra por acción y entidad', (tester) async {
    final api = _AuditoriaApiFake();

    await _montar(tester, api);

    await tester.enterText(
      find.widgetWithText(TextField, 'Acción'),
      'RUTA_APROBADA',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Entidad'),
      'RUTA',
    );

    await tester.tap(find.text('Buscar'));
    await tester.pump();

    expect(api.consultas.last['accion'], 'RUTA_APROBADA');
    expect(api.consultas.last['entidad'], 'RUTA');

    expect(find.text('RUTA APROBADA'), findsOneWidget);
    expect(find.text('Usuario creado'), findsNothing);
  });

  testWidgets('ADM-13 rechaza ID de administrador inválido',
      (tester) async {
    final api = _AuditoriaApiFake();

    await _montar(tester, api);

    await tester.enterText(
      find.widgetWithText(TextField, 'ID administrador'),
      'abc',
    );

    await tester.tap(find.text('Buscar'));
    await tester.pump();

    expect(api.consultas.length, 1);
    expect(
      find.text('Ingrese un ID de administrador válido.'),
      findsOneWidget,
    );
  });

  testWidgets('ADM-13 limpia los filtros', (tester) async {
    final api = _AuditoriaApiFake();

    await _montar(tester, api);

    await tester.enterText(
      find.widgetWithText(TextField, 'ID administrador'),
      '10',
    );

    await tester.tap(find.text('Buscar'));
    await tester.pump();

    await tester.tap(find.text('Limpiar'));
    await tester.pump();

    expect(api.consultas.last['administradorId'], isNull);
    expect(api.consultas.last['pagina'], 1);
    expect(find.text('Usuario actualizado'), findsOneWidget);
  });

  testWidgets('ADM-13 permite consultar detalles sin eliminarlos',
      (tester) async {
    final api = _AuditoriaApiFake();

    await _montar(tester, api);

    expect(find.text('Eliminar'), findsNothing);
    expect(find.text('Archivar'), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    final ver = find.text('Ver').first;
    await tester.ensureVisible(ver);
    await tester.pump();
    await tester.tap(ver);
    await tester.pumpAndSettle();

    expect(find.text('Auditoría #1'), findsOneWidget);
    expect(find.text('Carlos'), findsWidgets);

    expect(find.text('Eliminar'), findsNothing);
    expect(find.text('Archivar'), findsNothing);
    expect(api.registros.length, 3);
  });

  testWidgets('ADM-13 permite avanzar y retroceder páginas',
      (tester) async {
    final api = _AuditoriaApiFake();

    api.registros.clear();

    for (var i = 1; i <= 25; i++) {
      api.registros.add({
        'id': i,
        'administradorId': 10,
        'accion': 'PRUEBA_$i',
        'entidad': 'USUARIO',
        'entidadId': i,
        'creadoEn': '2026-10-20T10:00:00Z',
        'detalle': null,
      });
    }

    await _montar(tester, api);

    expect(find.text('Página 1 de 2'), findsOneWidget);

    final siguiente = find.byTooltip('Página siguiente');
    await tester.ensureVisible(siguiente);
    await tester.pump();
    await tester.tap(siguiente);
    await tester.pump();

    expect(api.consultas.last['pagina'], 2);
    expect(find.text('Página 2 de 2'), findsOneWidget);

    final anterior = find.byTooltip('Página anterior');
    await tester.ensureVisible(anterior);
    await tester.pump();
    await tester.tap(anterior);
    await tester.pump();

    expect(api.consultas.last['pagina'], 1);
    expect(find.text('Página 1 de 2'), findsOneWidget);
  });

  testWidgets('ADM-13 actualiza automáticamente el historial',
      (tester) async {
    final api = _AuditoriaApiFake();

    await _montar(tester, api);

    expect(api.consultas.length, 1);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(api.consultas.length, greaterThanOrEqualTo(2));
  });
}
