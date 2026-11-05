import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/patrocinio/presentation/pago_webview_screen.dart';

import 'helpers/montar.dart';

void main() {
  group('interpretarNavegacion', () {
    test('la pagina de retorno del backend es un pago exitoso', () {
      expect(
        interpretarNavegacion(
          'https://api.fitquestgo.app/patrocinio/pagos/retorno?s=7',
        ),
        ResultadoPago.exito,
      );
      expect(
        interpretarNavegacion(
          'http://10.0.2.2:3001/patrocinio/pagos/retorno?s=7',
        ),
        ResultadoPago.exito,
      );
    });

    test('la pagina de cancelado es un pago cancelado', () {
      expect(
        interpretarNavegacion(
          'http://10.0.2.2:3001/patrocinio/pagos/cancelado',
        ),
        ResultadoPago.cancelado,
      );
    });

    test('cualquier otra pagina (la de ONVO, 3D Secure) no cierra nada', () {
      expect(
        interpretarNavegacion('https://checkout.onvopay.com/pay/cs_1'),
        isNull,
      );
      expect(interpretarNavegacion('https://bank.example/3ds?x=1'), isNull);
      expect(interpretarNavegacion('no es una url'), isNull);
      expect(interpretarNavegacion(''), isNull);
    });
  });

  group('PagoWebViewScreen', () {
    ResultadoPago? resultado;
    bool cerrada = false;

    Future<void> abrir(WidgetTester tester) async {
      resultado = null;
      cerrada = false;
      await montarApp(
        tester,
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey<String>('abrir'),
                onPressed: () async {
                  resultado = await Navigator.of(context).push<ResultadoPago>(
                    MaterialPageRoute<ResultadoPago>(
                      builder: (_) => PagoWebViewScreen(
                        url: 'https://checkout.onvopay.com/pay/cs_1',
                        construirVista:
                            (
                              BuildContext c,
                              String url,
                              ValueChanged<String> alTerminarCarga,
                            ) => Column(
                              children: <Widget>[
                                Text('vista de $url'),
                                TextButton(
                                  key: const ValueKey<String>('ir-retorno'),
                                  onPressed: () => alTerminarCarga(
                                    'http://x/patrocinio/pagos/retorno?s=7',
                                  ),
                                  child: const Text('retorno'),
                                ),
                                TextButton(
                                  key: const ValueKey<String>('ir-cancelado'),
                                  onPressed: () => alTerminarCarga(
                                    'http://x/patrocinio/pagos/cancelado',
                                  ),
                                  child: const Text('cancelado'),
                                ),
                                TextButton(
                                  key: const ValueKey<String>('ir-otra'),
                                  onPressed: () => alTerminarCarga(
                                    'https://checkout.onvopay.com/pay/cs_1',
                                  ),
                                  child: const Text('otra'),
                                ),
                              ],
                            ),
                      ),
                    ),
                  );
                  cerrada = true;
                },
                child: const Text('Pagar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('abrir')));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra la URL de pago con el titulo y el boton de cerrar', (
      WidgetTester tester,
    ) async {
      await abrir(tester);

      expect(find.text('Pagar suscripción'), findsOneWidget);
      expect(
        find.text('vista de https://checkout.onvopay.com/pay/cs_1'),
        findsOneWidget,
      );
      expect(find.byTooltip('Cerrar'), findsOneWidget);
    });

    testWidgets(
      'al terminar de cargar la pagina de retorno se cierra con exito',
      (WidgetTester tester) async {
        await abrir(tester);

        await tester.tap(find.byKey(const ValueKey<String>('ir-retorno')));
        await tester.pumpAndSettle();

        expect(cerrada, isTrue);
        expect(resultado, ResultadoPago.exito);
      },
    );

    testWidgets('la pagina de cancelado cierra como cancelado', (
      WidgetTester tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.byKey(const ValueKey<String>('ir-cancelado')));
      await tester.pumpAndSettle();

      expect(resultado, ResultadoPago.cancelado);
    });

    testWidgets('otras paginas no cierran la pantalla', (
      WidgetTester tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.byKey(const ValueKey<String>('ir-otra')));
      await tester.pumpAndSettle();

      expect(cerrada, isFalse);
      expect(find.text('Pagar suscripción'), findsOneWidget);
    });

    testWidgets('cerrar a mano devuelve null (no se sabe si se pago)', (
      WidgetTester tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      expect(cerrada, isTrue);
      expect(resultado, isNull);
    });

    testWidgets('si la pagina de retorno carga dos veces, solo cierra una', (
      WidgetTester tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.byKey(const ValueKey<String>('ir-retorno')));
      await tester.tap(
        find.byKey(const ValueKey<String>('ir-retorno')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Sigue en la pantalla de abajo (el boton Pagar), no se cerro de mas.
      expect(find.byKey(const ValueKey<String>('abrir')), findsOneWidget);
    });
  });
}
