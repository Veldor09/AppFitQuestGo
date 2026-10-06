import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/resumen_grabacion_screen.dart';

const List<PuntoRuta> _dosPuntos = <PuntoRuta>[
  PuntoRuta(lat: 9.9281, lng: -84.0907),
  PuntoRuta(lat: 9.9381, lng: -84.0907),
];

/// Abre el resumen desde un boton y guarda lo que devuelva al cerrarse.
class _Anfitrion extends StatefulWidget {
  const _Anfitrion({
    required this.puntos,
    required this.tiempo,
    required this.distanciaKm,
  });

  final List<PuntoRuta> puntos;
  final Duration tiempo;
  final double distanciaKm;

  @override
  State<_Anfitrion> createState() => _AnfitrionState();
}

class _AnfitrionState extends State<_Anfitrion> {
  ResultadoResumen? resultado;
  bool cerrado = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Text(cerrado ? 'cerrado:${resultado?.name}' : 'abierto?'),
          TextButton(
            onPressed: () async {
              final ResultadoResumen? r = await Navigator.of(context)
                  .push<ResultadoResumen>(
                MaterialPageRoute<ResultadoResumen>(
                  builder: (BuildContext _) => ResumenGrabacionScreen(
                    puntos: widget.puntos,
                    tiempo: widget.tiempo,
                    distanciaKm: widget.distanciaKm,
                  ),
                ),
              );
              setState(() {
                resultado = r;
                cerrado = true;
              });
            },
            child: const Text('abrir'),
          ),
        ],
      ),
    );
  }
}

Future<void> _abrir(
  WidgetTester tester, {
  List<PuntoRuta> puntos = _dosPuntos,
  Duration tiempo = const Duration(minutes: 30),
  double distanciaKm = 5,
}) async {
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _Anfitrion(puntos: puntos, tiempo: tiempo, distanciaKm: distanciaKm),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra tiempo, distancia y ritmo medio', (WidgetTester tester) async {
    await _abrir(tester);

    expect(find.text('Resumen de la grabacion'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget); // tiempo
    expect(find.text('5.00'), findsOneWidget); // distancia (km)
    expect(find.text('6:00'), findsOneWidget); // ritmo medio: 30 min / 5 km
    expect(find.text('Tiempo'), findsOneWidget);
    expect(find.text('Ritmo medio'), findsOneWidget);
  });

  testWidgets('con una hora o mas el tiempo pasa a h:mm:ss', (WidgetTester tester) async {
    await _abrir(
      tester,
      tiempo: const Duration(hours: 1, minutes: 2, seconds: 3),
      distanciaKm: 10,
    );

    expect(find.text('1:02:03'), findsOneWidget);
  });

  testWidgets('sin distancia suficiente el ritmo muestra guiones', (
    WidgetTester tester,
  ) async {
    await _abrir(tester, distanciaKm: 0.005);

    expect(find.text('--:--'), findsOneWidget);
  });

  testWidgets('"Guardar ruta" devuelve guardar', (WidgetTester tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Guardar ruta'));
    await tester.pumpAndSettle();

    expect(find.text('cerrado:guardar'), findsOneWidget);
  });

  testWidgets('"Descartar" devuelve descartar', (WidgetTester tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('cerrado:descartar'), findsOneWidget);
  });

  testWidgets('volver atras no decide nada (devuelve null)', (WidgetTester tester) async {
    await _abrir(tester);

    // `pageBack()` busca el tooltip "Back" en ingles; aqui la UI esta en espanol.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('cerrado:null'), findsOneWidget);
  });

  testWidgets('con un solo punto avisa y no deja guardar', (WidgetTester tester) async {
    await _abrir(
      tester,
      puntos: const <PuntoRuta>[PuntoRuta(lat: 9.9, lng: -84.0)],
      distanciaKm: 0,
    );

    expect(
      find.text('Se necesitan al menos 2 puntos para guardar la ruta.'),
      findsOneWidget,
    );
    final Finder guardar = find.widgetWithText(FqButton, 'Guardar ruta');
    expect(tester.widget<FqButton>(guardar).onPressed, isNull);
    expect(
      tester.widget<FqButton>(find.widgetWithText(FqButton, 'Descartar')).onPressed,
      isNotNull,
    );
  });
}
