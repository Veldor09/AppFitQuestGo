import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/home/presentation/widgets/panel_cercano.dart';
import 'package:fit_quest_go/Modulos/patrocinio/application/proximidad_destacados.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/banner_destacado_cerca.dart';

import 'helpers/datos_mapa.dart';
import 'helpers/montar.dart';

DestacadoCercano _cercano() => DestacadoCercano(
  tipo: 'nodo',
  id: 1,
  nombre: 'Parque Norte',
  metros: 296,
  origen: nodoDePrueba(id: 1, nombre: 'Parque Norte', destacado: true),
);

void main() {
  group('BannerDestacadoCerca', () {
    testWidgets('dice que hay un destacado cerca, con su nombre y distancia', (
      WidgetTester tester,
    ) async {
      await montarApp(
        tester,
        Scaffold(
          body: BannerDestacadoCerca(
            destacado: _cercano(),
            onTap: () {},
            onCerrar: () {},
          ),
        ),
      );

      expect(find.text('Destacado cerca de ti'), findsOneWidget);
      expect(find.text('Parque Norte · 296 m'), findsOneWidget);
    });

    testWidgets('tocarlo lo abre y la X lo cierra, una vez cada uno', (
      WidgetTester tester,
    ) async {
      int abierto = 0;
      int cerrado = 0;
      await montarApp(
        tester,
        Scaffold(
          body: BannerDestacadoCerca(
            destacado: _cercano(),
            onTap: () => abierto++,
            onCerrar: () => cerrado++,
          ),
        ),
      );

      await tester.tap(find.text('Destacado cerca de ti'));
      await tester.pump();
      expect(abierto, 1);
      expect(cerrado, 0);

      await tester.tap(find.byTooltip('Ahora no'));
      await tester.pump();
      expect(cerrado, 1);
      expect(abierto, 1);
    });
  });

  group('PanelCercano con destacado', () {
    testWidgets('la tarjeta dorada va arriba de las casillas y se puede tocar', (
      WidgetTester tester,
    ) async {
      int toques = 0;
      await montarApp(
        tester,
        Scaffold(
          body: PanelCercano(
            hayUbicacion: true,
            ruta: null,
            alerta: null,
            destacado: _cercano(),
            onDestacado: () => toques++,
            onRuta: () {},
            onAlerta: () {},
            onAgregar: () {},
          ),
        ),
      );

      expect(find.text('Parque Norte'), findsOneWidget);
      expect(find.text('Destacado'), findsOneWidget);
      expect(find.text('296 m'), findsOneWidget);
      final double yTarjeta = tester.getTopLeft(find.byKey(const ValueKey<String>('cerca-destacado'))).dy;
      final double yCasillas = tester.getTopLeft(find.text('Sin rutas cerca')).dy;
      expect(yTarjeta, lessThan(yCasillas));

      await tester.tap(find.byKey(const ValueKey<String>('cerca-destacado')));
      expect(toques, 1);
    });

    testWidgets('sin destacado no aparece la tarjeta', (WidgetTester tester) async {
      await montarApp(
        tester,
        Scaffold(
          body: PanelCercano(
            hayUbicacion: true,
            ruta: null,
            alerta: null,
            onRuta: () {},
            onAlerta: () {},
            onAgregar: () {},
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('cerca-destacado')), findsNothing);
    });
  });
}
