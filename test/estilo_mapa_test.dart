import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/mapa/estilo_mapa.dart';
import 'helpers/montar.dart';

void main() {
  final ValueNotifier<EstiloMapa> preferencia =
      PreferenciaEstiloMapa.instancia.estilo;

  setUp(() => preferencia.value = EstiloMapa.calles);
  tearDown(() => preferencia.value = EstiloMapa.calles);

  test('cada estilo apunta al suyo en Mapbox', () {
    expect(EstiloMapa.calles.uri, MapboxStyles.MAPBOX_STREETS);
    expect(EstiloMapa.satelite.uri, MapboxStyles.SATELLITE_STREETS);
  });

  group('GestorEstiloMapa', () {
    test('la carga inicial del estilo no recrea las capas', () async {
      int recreadas = 0;
      final GestorEstiloMapa gestor = GestorEstiloMapa(
        mapa: () => null,
        alCambiarEstilo: () async => recreadas++,
      );

      await gestor.alEstiloCargado();

      expect(recreadas, 0);
    });

    test('sin mapa elegir un estilo no hace nada ni lanza', () async {
      int recreadas = 0;
      final GestorEstiloMapa gestor = GestorEstiloMapa(
        mapa: () => null,
        alCambiarEstilo: () async => recreadas++,
      )..iniciar();
      addTearDown(gestor.liberar);

      preferencia.value = EstiloMapa.satelite;
      await Future<void>.delayed(Duration.zero);
      await gestor.alEstiloCargado();

      expect(recreadas, 0);
      expect(gestor.aplicado, EstiloMapa.calles);
    });

    test('un mapa ya liberado deja de escuchar la preferencia', () {
      final GestorEstiloMapa gestor = GestorEstiloMapa(
        mapa: () => null,
        alCambiarEstilo: () async {},
      )..iniciar();
      gestor.liberar();

      // No lanza ni queda escuchando: cambiar la preferencia es inocuo.
      preferencia.value = EstiloMapa.satelite;
      expect(preferencia.hasListeners, isFalse);
    });
  });

  group('BotonTipoMapa', () {
    testWidgets('abre "Tipo de mapa" con Mapa y Satelite, marcando el actual', (
      tester,
    ) async {
      await montarApp(tester, const Scaffold(body: Center(child: BotonTipoMapa())));

      await tester.tap(find.byKey(const ValueKey<String>('boton-tipo-mapa')));
      await tester.pumpAndSettle();

      expect(find.text('Tipo de mapa'), findsOneWidget);
      expect(find.text('Mapa'), findsOneWidget);
      expect(find.text('Satélite'), findsOneWidget);
    });

    testWidgets('elegir Satelite cambia la preferencia de todos los mapas y cierra la hoja', (
      tester,
    ) async {
      await montarApp(tester, const Scaffold(body: Center(child: BotonTipoMapa())));
      await tester.tap(find.byKey(const ValueKey<String>('boton-tipo-mapa')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('estilo-satelite')));
      await tester.pumpAndSettle();

      expect(preferencia.value, EstiloMapa.satelite);
      expect(find.text('Satélite'), findsNothing);
    });

    testWidgets('elegir Mapa de nuevo vuelve a las calles', (tester) async {
      preferencia.value = EstiloMapa.satelite;
      await montarApp(tester, const Scaffold(body: Center(child: BotonTipoMapa())));
      await tester.tap(find.byKey(const ValueKey<String>('boton-tipo-mapa')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('estilo-calles')));
      await tester.pumpAndSettle();

      expect(preferencia.value, EstiloMapa.calles);
    });
  });
}
