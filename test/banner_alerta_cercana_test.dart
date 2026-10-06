import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/banner_alerta_cercana.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

const Alerta _alerta = Alerta(
  id: 7,
  tipo: 'arbol_caido',
  gravedad: 'alta',
  lat: 9.9281,
  lng: -84.0907,
  estado: 'Activa',
);

Widget _montar({
  bool votando = false,
  VoidCallback? onSigue,
  VoidCallback? onNoEsta,
  VoidCallback? onCerrar,
}) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BannerAlertaCercana(
        alerta: _alerta,
        metros: 56,
        votando: votando,
        onSigue: onSigue ?? () {},
        onNoEsta: onNoEsta ?? () {},
        onCerrar: onCerrar ?? () {},
      ),
    ),
  );
}

void _forzarEspanol(WidgetTester tester) {
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}

void main() {
  testWidgets('muestra el tipo, la distancia y la pregunta', (WidgetTester tester) async {
    _forzarEspanol(tester);
    await tester.pumpWidget(_montar());

    expect(find.text('Alerta cerca de ti'), findsOneWidget);
    expect(find.textContaining('Arbol caido'), findsOneWidget);
    expect(find.textContaining('A unos 56 m'), findsOneWidget);
    expect(find.text('Sigue ahi?'), findsOneWidget);
    expect(find.text('Si, sigue ahi'), findsOneWidget);
    expect(find.text('Ya no esta'), findsOneWidget);
  });

  testWidgets('los botones avisan al toque', (WidgetTester tester) async {
    _forzarEspanol(tester);
    int sigue = 0;
    int noEsta = 0;
    int cerrar = 0;
    await tester.pumpWidget(
      _montar(
        onSigue: () => sigue++,
        onNoEsta: () => noEsta++,
        onCerrar: () => cerrar++,
      ),
    );

    await tester.tap(find.text('Si, sigue ahi'));
    await tester.tap(find.text('Ya no esta'));
    await tester.tap(find.byTooltip('Ahora no'));

    expect((sigue, noEsta, cerrar), (1, 1, 1));
  });

  testWidgets('mientras se vota, los botones no responden', (WidgetTester tester) async {
    _forzarEspanol(tester);
    int toques = 0;
    await tester.pumpWidget(
      _montar(
        votando: true,
        onSigue: () => toques++,
        onNoEsta: () => toques++,
        onCerrar: () => toques++,
      ),
    );

    await tester.tap(find.text('Si, sigue ahi'), warnIfMissed: false);
    await tester.tap(find.text('Ya no esta'), warnIfMissed: false);
    await tester.tap(find.byTooltip('Ahora no'), warnIfMissed: false);

    expect(toques, 0);
  });
}
