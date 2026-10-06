import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/rutas_screen.dart';

const List<PuntoRuta> _puntos = <PuntoRuta>[
  PuntoRuta(lat: 9.9281, lng: -84.0907),
  PuntoRuta(lat: 9.9291, lng: -84.0917),
];

Ruta _ruta(int id, String nombre, String estado) {
  return Ruta(
    id: id,
    nombre: nombre,
    actividades: <String>['running'],
    dificultad: 'facil',
    distanciaKm: 3.2,
    puntos: _puntos,
    estado: estado,
  );
}

class _RutaApiFalsa extends RutaApi {
  int cargasDeMisRutas = 0;
  final List<int> solicitudes = <int>[];

  @override
  Future<List<Ruta>> explorar() async => <Ruta>[_ruta(1, 'Sendero del rio', 'Publicada')];

  @override
  Future<List<Ruta>> misRutas() async {
    cargasDeMisRutas++;
    return <Ruta>[_ruta(2, 'Mi vuelta al lago', 'Privada')];
  }

  @override
  Future<Ruta> solicitarPublicacion(int id) async {
    solicitudes.add(id);
    return _ruta(id, 'Mi vuelta al lago', 'Pendiente');
  }
}

Future<_RutaApiFalsa> _montar(WidgetTester tester) async {
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);

  final _RutaApiFalsa api = _RutaApiFalsa();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) =>
          NotificacionesHost(child: child!),
      home: Scaffold(body: RutasScreen(api: api)),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('tocar una ruta de Explorar abre su detalle con el estado publico', (
    WidgetTester tester,
  ) async {
    await _montar(tester);

    await tester.tap(find.text('Sendero del rio'));
    await tester.pumpAndSettle();

    expect(find.text('Ruta publica: la ve toda la comunidad.'), findsOneWidget);
    expect(find.text('Enviar a revision'), findsNothing);
  });

  testWidgets('en Mis rutas el detalle de una ruta privada ofrece enviarla a revision', (
    WidgetTester tester,
  ) async {
    await _montar(tester);

    await tester.tap(find.text('Mis rutas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi vuelta al lago'));
    await tester.pumpAndSettle();

    expect(find.text('Ruta privada: solo vos la ves.'), findsOneWidget);
    expect(find.widgetWithText(FqButton, 'Enviar a revision'), findsOneWidget);
  });

  testWidgets('enviar a revision vuelve a la lista y la recarga', (
    WidgetTester tester,
  ) async {
    final _RutaApiFalsa api = await _montar(tester);
    await tester.tap(find.text('Mis rutas'));
    await tester.pumpAndSettle();
    expect(api.cargasDeMisRutas, 1);

    await tester.tap(find.text('Mi vuelta al lago'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FqButton, 'Enviar a revision'));
    await tester.pumpAndSettle();

    expect(api.solicitudes, <int>[2]);
    expect(api.cargasDeMisRutas, 2);
    expect(find.text('Ruta enviada a revision'), findsOneWidget);
    expect(find.text('Ruta privada: solo vos la ves.'), findsNothing);
  });
}
