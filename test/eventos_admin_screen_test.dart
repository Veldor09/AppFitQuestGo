
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/eventos_admin_screen.dart';

class _EventosApiFake extends ApiClient {
  _EventosApiFake({
    required this.eventos,
    this.errorListado,
    this.errorEliminacion,
  });

  final List<Map<String, dynamic>> eventos;
  final Object? errorListado;
  final Object? errorEliminacion;

  int consultas = 0;
  final List<String> eliminaciones = [];

  @override
  Future<dynamic> get(String path) async {
    consultas++;

    if (path != '/eventos/admin/todos') {
      throw StateError('Ruta GET inesperada: $path');
    }

    if (errorListado != null) {
      throw errorListado!;
    }

    return eventos.map((evento) => Map<String, dynamic>.from(evento)).toList();
  }

  @override
  Future<dynamic> delete(String path) async {
    eliminaciones.add(path);

    if (errorEliminacion != null) {
      throw errorEliminacion!;
    }

    final id = int.parse(path.split('/').last);
    eventos.removeWhere((evento) => evento['id'] == id);

    return null;
  }
}

Map<String, dynamic> _evento({
  required int id,
  required String nombre,
  required String categoria,
  required DateTime inicio,
  required DateTime fin,
  String empresa = 'Empresa de prueba',
}) {
  return <String, dynamic>{
    'id': id,
    'nombre': nombre,
    'categoria': categoria,
    'descripcion': 'Descripción del evento $nombre',
    'fechaInicio': inicio.toUtc().toIso8601String(),
    'fechaFin': fin.toUtc().toIso8601String(),
    'areas': <dynamic>[],
    'recorridos': <dynamic>[],
    'creadoPor': <String, dynamic>{
      'id': id + 100,
      'nombreEmpresa': empresa,
    },
  };
}

List<Map<String, dynamic>> _eventosDePrueba() {
  final ahora = DateTime.now();

  return <Map<String, dynamic>>[
    _evento(
      id: 1,
      nombre: 'Carrera del futuro',
      categoria: 'DEPORTIVO',
      inicio: ahora.add(const Duration(days: 10)),
      fin: ahora.add(const Duration(days: 11)),
      empresa: 'Organización Norte',
    ),
    _evento(
      id: 2,
      nombre: 'Festival activo',
      categoria: 'CULTURAL',
      inicio: ahora.subtract(const Duration(days: 1)),
      fin: ahora.add(const Duration(days: 1)),
      empresa: 'Organización Centro',
    ),
    _evento(
      id: 3,
      nombre: 'Caminata anterior',
      categoria: 'RECREATIVO',
      inicio: ahora.subtract(const Duration(days: 10)),
      fin: ahora.subtract(const Duration(days: 9)),
      empresa: 'Organización Sur',
    ),
  ];
}

Future<void> _montar(
  WidgetTester tester,
  _EventosApiFake api,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EventosAdminScreen(api: api),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ADM-08 carga y muestra todos los eventos', (tester) async {
    final api = _EventosApiFake(eventos: _eventosDePrueba());

    await _montar(tester, api);

    expect(api.consultas, 1);
    expect(find.text('Carrera del futuro'), findsOneWidget);
    expect(find.text('Festival activo'), findsOneWidget);
    expect(find.text('Caminata anterior'), findsOneWidget);
  });

  testWidgets('ADM-08 busca eventos por nombre', (tester) async {
    final api = _EventosApiFake(eventos: _eventosDePrueba());

    await _montar(tester, api);

    await tester.enterText(
      find.byType(TextField).first,
      'Carrera del futuro',
    );
    await tester.pumpAndSettle();

    expect(find.text('Carrera del futuro'), findsNWidgets(2));
    expect(find.text('Festival activo'), findsNothing);
    expect(find.text('Caminata anterior'), findsNothing);
  });

  testWidgets('ADM-08 busca eventos por categoría', (tester) async {
    final api = _EventosApiFake(eventos: _eventosDePrueba());

    await _montar(tester, api);

    await tester.enterText(
      find.byType(TextField).first,
      'CULTURAL',
    );
    await tester.pumpAndSettle();

    expect(find.text('Festival activo'), findsOneWidget);
    expect(find.text('Carrera del futuro'), findsNothing);
  });

  testWidgets('ADM-08 busca eventos por empresa', (tester) async {
    final api = _EventosApiFake(eventos: _eventosDePrueba());

    await _montar(tester, api);

    await tester.enterText(
      find.byType(TextField).first,
      'Organización Sur',
    );
    await tester.pumpAndSettle();

    expect(find.text('Caminata anterior'), findsOneWidget);
    expect(find.text('Festival activo'), findsNothing);
  });

  testWidgets('ADM-08 filtra eventos próximos', (tester) async {
    final api = _EventosApiFake(eventos: _eventosDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('Próximos'));
    await tester.pumpAndSettle();

    expect(find.text('Carrera del futuro'), findsOneWidget);
    expect(find.text('Festival activo'), findsNothing);
    expect(find.text('Caminata anterior'), findsNothing);
  });

  testWidgets('ADM-08 filtra eventos en curso', (tester) async {
    final api = _EventosApiFake(eventos: _eventosDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('En curso').first);
    await tester.pumpAndSettle();

    expect(find.text('Festival activo'), findsOneWidget);
    expect(find.text('Carrera del futuro'), findsNothing);
    expect(find.text('Caminata anterior'), findsNothing);
  });

  testWidgets('ADM-08 filtra eventos finalizados', (tester) async {
    final api = _EventosApiFake(eventos: _eventosDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('Finalizados'));
    await tester.pumpAndSettle();

    expect(find.text('Caminata anterior'), findsOneWidget);
    expect(find.text('Carrera del futuro'), findsNothing);
    expect(find.text('Festival activo'), findsNothing);
  });

  testWidgets('ADM-08 muestra detalles del evento', (tester) async {
    final api = _EventosApiFake(eventos: _eventosDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('Carrera del futuro'));
    await tester.pumpAndSettle();

    expect(find.text('Descripción'), findsOneWidget);
    expect(
      find.text('Descripción del evento Carrera del futuro'),
      findsOneWidget,
    );
    expect(find.text('Eliminar evento'), findsOneWidget);
  });

  testWidgets('ADM-08 muestra error de permisos 403', (tester) async {
    final api = _EventosApiFake(
      eventos: [],
      errorListado: ApiException(403, 'Forbidden'),
    );

    await _montar(tester, api);

    expect(
      find.text('No tenés permisos para administrar eventos.'),
      findsOneWidget,
    );
  });

  testWidgets('ADM-08 muestra error de sesión 401', (tester) async {
    final api = _EventosApiFake(
      eventos: [],
      errorListado: ApiException(401, 'Unauthorized'),
    );

    await _montar(tester, api);

    expect(
      find.text('Tu sesión expiró. Iniciá sesión nuevamente.'),
      findsOneWidget,
    );
  });

  testWidgets('ADM-08 cancelar eliminación conserva el evento', (
    tester,
  ) async {
    final api = _EventosApiFake(eventos: _eventosDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('Carrera del futuro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eliminar evento'));
    await tester.pumpAndSettle();

    expect(find.text('¿Eliminar este evento?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(api.eliminaciones, isEmpty);
    expect(find.text('Carrera del futuro'), findsOneWidget);
  });

  testWidgets('ADM-08 eliminación confirmada actualiza el listado', (
    tester,
  ) async {
    final api = _EventosApiFake(eventos: _eventosDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('Carrera del futuro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eliminar evento'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eliminar definitivamente'));
    await tester.pumpAndSettle();

    expect(api.eliminaciones, <String>['/eventos/1']);
    expect(api.consultas, 2);
    expect(find.text('Carrera del futuro'), findsNothing);
    expect(find.text('Festival activo'), findsOneWidget);
  });

  testWidgets('ADM-08 muestra error si falla la eliminación', (
    tester,
  ) async {
    final api = _EventosApiFake(
      eventos: _eventosDePrueba(),
      errorEliminacion: ApiException(
        500,
        'No fue posible eliminar el evento',
      ),
    );

    await _montar(tester, api);

    await tester.tap(find.text('Carrera del futuro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eliminar evento'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eliminar definitivamente'));
    await tester.pumpAndSettle();

    expect(
      find.text('No fue posible eliminar el evento'),
      findsOneWidget,
    );
  expect(find.text('Carrera del futuro'), findsOneWidget);
  });
}


