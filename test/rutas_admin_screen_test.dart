import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/rutas_admin_screen.dart';

class _RutaApiFake extends RutaApi {
  _RutaApiFake(this.rutas);

  final List<Ruta> rutas;
  int consultas = 0;

  @override
  Future<List<Ruta>> explorar() async {
    consultas++;
    return rutas;
  }
}

List<Ruta> _rutasDePrueba() => <Ruta>[
  const Ruta(
    id: 1,
    nombre: 'Ruta del bosque',
    actividades: <String>['running'],
    dificultad: 'facil',
    distanciaKm: 5,
    puntos: <PuntoRuta>[],
    estado: 'Publicada',
  ),
  const Ruta(
    id: 2,
    nombre: 'Ruta de montaña',
    actividades: <String>['mtb'],
    dificultad: 'dificil',
    distanciaKm: 12,
    puntos: <PuntoRuta>[],
    estado: 'Publicada',
  ),
  const Ruta(
    id: 3,
    nombre: 'Sendero del río',
    actividades: <String>['hiking'],
    dificultad: 'moderada',
    distanciaKm: 7,
    puntos: <PuntoRuta>[],
    estado: 'Publicada',
  ),
];

Future<void> _montar(WidgetTester tester, _RutaApiFake api) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RutasAdminScreen(api: api),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ADM-04 abre detalle de ruta en solo lectura', (tester) async {
    final api = _RutaApiFake(_rutasDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('Ruta de montaña'));
    await tester.pumpAndSettle();

    expect(find.text('Estado: Publicada'), findsOneWidget);
    expect(find.text('Distancia: 12.0 km'), findsOneWidget);
    expect(find.text('Dificultad: Dificil'), findsOneWidget);
    expect(find.text('Puntos GPS: 0'), findsOneWidget);

    expect(find.text('Aprobar'), findsNothing);
    expect(find.text('Rechazar'), findsNothing);
    expect(find.text('Editar'), findsNothing);
    expect(api.consultas, 1);
  });
  testWidgets('ADM-04 cancelar conserva los filtros aplicados', (tester) async {
    final api = _RutaApiFake(_rutasDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('Filtros').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('MTB').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Ruta de montaña'), findsOneWidget);
    expect(find.text('Ruta del bosque'), findsNothing);

    await tester.tap(find.text('Filtros').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Running').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Ruta de montaña'), findsOneWidget);
    expect(find.text('Ruta del bosque'), findsNothing);
    expect(find.text('Sendero del río'), findsNothing);
    expect(api.consultas, 1);
  });
  testWidgets('ADM-04 limpiar filtros restaura todas las rutas', (tester) async {
    final api = _RutaApiFake(_rutasDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('Filtros').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('MTB').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Ruta de montaña'), findsOneWidget);
    expect(find.text('Ruta del bosque'), findsNothing);
    expect(find.text('Sendero del río'), findsNothing);

    await tester.tap(find.text('Filtros').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();

    expect(find.text('Ruta del bosque'), findsOneWidget);
    expect(find.text('Ruta de montaña'), findsOneWidget);
    expect(find.text('Sendero del río'), findsOneWidget);
    expect(api.consultas, 1);
  });
  testWidgets('ADM-04 combina actividad MTB y dificultad dificil', (tester) async {
    final api = _RutaApiFake(_rutasDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('Filtros').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('MTB').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dificil').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Ruta de montaña'), findsOneWidget);
    expect(find.text('Ruta del bosque'), findsNothing);
    expect(find.text('Sendero del río'), findsNothing);
    expect(api.consultas, 1);
  });
  testWidgets('ADM-04 filtra rutas por dificultad dificil', (tester) async {
    final api = _RutaApiFake(_rutasDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('Filtros').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dificil').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Ruta de montaña'), findsOneWidget);
    expect(find.text('Ruta del bosque'), findsNothing);
    expect(find.text('Sendero del río'), findsNothing);
    expect(api.consultas, 1);
  });
  testWidgets('ADM-04 filtra rutas por actividad MTB', (tester) async {
    final api = _RutaApiFake(_rutasDePrueba());

    await _montar(tester, api);

    await tester.tap(find.text('Filtros').first);
    await tester.pumpAndSettle();

    expect(find.text('Filtros de rutas'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('MTB').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Ruta de montaña'), findsOneWidget);
    expect(find.text('Ruta del bosque'), findsNothing);
    expect(find.text('Sendero del río'), findsNothing);
    expect(api.consultas, 1);
  });
  testWidgets('ADM-04 busca rutas por nombre', (tester) async {
    final api = _RutaApiFake(_rutasDePrueba());

    await _montar(tester, api);

    await tester.enterText(
      find.byType(TextField).first,
      'Ruta del bosque',
    );
    await tester.pumpAndSettle();

    expect(find.text('Ruta del bosque').hitTestable().evaluate().where((element) => element.widget is Text).length, 1);
    expect(find.text('Ruta de montaña'), findsNothing);
    expect(find.text('Sendero del río'), findsNothing);
    expect(api.consultas, 1);
  });
  testWidgets('ADM-04 muestra rutas publicadas', (tester) async {
    final api = _RutaApiFake(_rutasDePrueba());

    await _montar(tester, api);

    expect(api.consultas, 1);
    expect(find.text('Ruta del bosque'), findsOneWidget);
    expect(find.text('Ruta de montaña'), findsOneWidget);
    expect(find.text('Sendero del río'), findsOneWidget);
  });
}