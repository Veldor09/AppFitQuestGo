import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/ruta_detalle_screen.dart';

const List<PuntoRuta> _tresPuntos = <PuntoRuta>[
  PuntoRuta(lat: 9.9281, lng: -84.0907),
  PuntoRuta(lat: 9.9291, lng: -84.0917),
  PuntoRuta(lat: 9.9301, lng: -84.0927),
];

Ruta _ruta({
  String estado = 'Privada',
  List<PuntoRuta> puntos = _tresPuntos,
  String? creadoPorNombre = 'Ana',
}) {
  return Ruta(
    id: 5,
    nombre: 'Cerro de la Muerte',
    actividades: <String>['running'],
    dificultad: 'moderada',
    distanciaKm: 5,
    puntos: puntos,
    estado: estado,
    creadoPorNombre: creadoPorNombre,
  );
}

class _RutaApiFalsa extends RutaApi {
  final List<int> solicitudes = <int>[];
  Object? error;

  @override
  Future<Ruta> solicitarPublicacion(int id) async {
    solicitudes.add(id);
    if (error != null) throw error!;
    return _ruta(estado: 'Pendiente');
  }
}

/// Abre el detalle desde una pantalla anterior (para poder ver el `pop`).
Future<void> _abrir(
  WidgetTester tester,
  Ruta ruta, {
  _RutaApiFalsa? api,
  bool puedeEnviarARevision = false,
  VoidCallback? onCambio,
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
      builder: (BuildContext context, Widget? child) =>
          NotificacionesHost(child: child!),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext _) => RutaDetalleScreen(
                  ruta: ruta,
                  api: api,
                  puedeEnviarARevision: puedeEnviarARevision,
                  onCambio: onCambio,
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra el nombre, el estado y los datos de la ruta', (
    WidgetTester tester,
  ) async {
    await _abrir(tester, _ruta());

    expect(find.text('Cerro de la Muerte'), findsOneWidget);
    expect(find.text('PRIVADA'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Moderada'), findsOneWidget);
    expect(find.text('5.0 km'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // puntos del trazo
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('sin autor no muestra la fila "Propuesta por"', (
    WidgetTester tester,
  ) async {
    await _abrir(tester, _ruta(creadoPorNombre: null));

    expect(find.text('Propuesta por'), findsNothing);
  });

  group('visibilidad segun el estado', () {
    const Map<String, String> esperado = <String, String>{
      'Publicada': 'Ruta publica: la ve toda la comunidad.',
      'Privada': 'Ruta privada: solo vos la ves.',
      'Pendiente': 'En revision: todavia no es publica.',
      'Rechazada': 'Rechazada: no se publico.',
    };
    esperado.forEach((String estado, String mensaje) {
      testWidgets('$estado -> "$mensaje"', (WidgetTester tester) async {
        await _abrir(tester, _ruta(estado: estado));

        expect(find.text(mensaje), findsOneWidget);
      });
    });
  });

  testWidgets('con menos de 2 puntos avisa que no hay trazo', (
    WidgetTester tester,
  ) async {
    await _abrir(tester, _ruta(puntos: const <PuntoRuta>[]));

    expect(find.text('Esta ruta no tiene un trazo para mostrar.'), findsOneWidget);
  });

  group('Enviar a revision', () {
    testWidgets('no aparece si no es tu ruta privada', (WidgetTester tester) async {
      await _abrir(tester, _ruta(), puedeEnviarARevision: false);
      expect(find.text('Enviar a revision'), findsNothing);
    });

    testWidgets('no aparece si la ruta ya no es privada', (WidgetTester tester) async {
      await _abrir(tester, _ruta(estado: 'Publicada'), puedeEnviarARevision: true);
      expect(find.text('Enviar a revision'), findsNothing);
    });

    testWidgets('envia, avisa del cambio, cierra y confirma', (
      WidgetTester tester,
    ) async {
      final _RutaApiFalsa api = _RutaApiFalsa();
      int cambios = 0;
      await _abrir(
        tester,
        _ruta(),
        api: api,
        puedeEnviarARevision: true,
        onCambio: () => cambios++,
      );

      await tester.tap(find.widgetWithText(FqButton, 'Enviar a revision'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(api.solicitudes, <int>[5]);
      expect(cambios, 1);
      expect(find.text('Cerro de la Muerte'), findsNothing); // volvio a la lista
      expect(find.text('Ruta enviada a revision'), findsOneWidget);
    });

    testWidgets('si falla, avisa y la pantalla sigue abierta', (
      WidgetTester tester,
    ) async {
      final _RutaApiFalsa api = _RutaApiFalsa()..error = ApiException(500, 'caido');
      int cambios = 0;
      await _abrir(
        tester,
        _ruta(),
        api: api,
        puedeEnviarARevision: true,
        onCambio: () => cambios++,
      );

      await tester.tap(find.widgetWithText(FqButton, 'Enviar a revision'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(cambios, 0);
      expect(find.text('No se pudo enviar la ruta'), findsOneWidget);
      expect(find.text('Cerro de la Muerte'), findsOneWidget);
      expect(
        tester.widget<FqButton>(find.widgetWithText(FqButton, 'Enviar a revision')).onPressed,
        isNotNull,
      );
    });
  });
}
