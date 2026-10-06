import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';
import 'package:fit_quest_go/Modulos/clima/presentation/banner_clima.dart';

const AlertaClima _lluvia = AlertaClima(
  tipo: TipoClima.lluvia,
  nivel: NivelClima.precaucion,
  enHoras: 1,
  valor: 12,
);
const AlertaClima _tormenta = AlertaClima(
  tipo: TipoClima.tormenta,
  nivel: NivelClima.peligro,
  enHoras: 2,
);
const AlertaClima _calor = AlertaClima(
  tipo: TipoClima.calor,
  nivel: NivelClima.peligro,
  enHoras: 0,
  valor: 41.5,
);

Widget _montar(
  AlertaClima alerta, {
  int masAvisos = 0,
  VoidCallback? onCerrar,
  Locale idioma = const Locale('es'),
}) {
  return MaterialApp(
    locale: idioma,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BannerClima(
        alerta: alerta,
        fuente: 'Open-Meteo',
        masAvisos: masAvisos,
        onCerrar: onCerrar ?? () {},
      ),
    ),
  );
}

void _forzar(WidgetTester tester, Locale idioma) {
  tester.platformDispatcher.localesTestValue = <Locale>[idioma];
  tester.platformDispatcher.localeTestValue = idioma;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}

void main() {
  testWidgets('lluvia fuerte: titulo, cuando, milimetros por hora y consejo', (
    WidgetTester tester,
  ) async {
    _forzar(tester, const Locale('es'));
    await tester.pumpWidget(_montar(_lluvia));

    expect(find.text('Lluvia fuerte en tu zona'), findsOneWidget);
    expect(find.text('En 1 hora · 12 mm/h'), findsOneWidget);
    expect(find.text('Evita cruces de rio y senderos con barro.'), findsOneWidget);
    expect(find.byIcon(Icons.water_drop), findsOneWidget);
  });

  testWidgets('tormenta: sin medida, con consejo de refugio', (WidgetTester tester) async {
    _forzar(tester, const Locale('es'));
    await tester.pumpWidget(_montar(_tormenta));

    expect(find.text('Tormenta electrica en tu zona'), findsOneWidget);
    expect(find.text('En unas 2 horas'), findsOneWidget);
    expect(find.text('Busca refugio y evita cumbres y zonas abiertas.'), findsOneWidget);
    expect(find.byIcon(Icons.thunderstorm), findsOneWidget);
  });

  testWidgets('calor extremo ahora: sensacion termica con coma decimal en espanol', (
    WidgetTester tester,
  ) async {
    _forzar(tester, const Locale('es'));
    await tester.pumpWidget(_montar(_calor));

    expect(find.text('Calor extremo en tu zona'), findsOneWidget);
    expect(find.text('Ahora · sensacion termica de 41,5 °C'), findsOneWidget);
    expect(find.text('Hidratate y evita entrenar al sol del mediodia.'), findsOneWidget);
    expect(find.byIcon(Icons.thermostat), findsOneWidget);
  });

  testWidgets('en ingles usa punto decimal y su propio texto', (WidgetTester tester) async {
    _forzar(tester, const Locale('en'));
    await tester.pumpWidget(_montar(_calor, idioma: const Locale('en')));

    expect(find.text('Extreme heat in your area'), findsOneWidget);
    expect(find.text('Right now · feels like 41.5 °C'), findsOneWidget);
  });

  testWidgets('un valor entero no lleva decimales', (WidgetTester tester) async {
    _forzar(tester, const Locale('es'));
    await tester.pumpWidget(
      _montar(
        const AlertaClima(
          tipo: TipoClima.calor,
          nivel: NivelClima.precaucion,
          enHoras: 0,
          valor: 36,
        ),
      ),
    );

    expect(find.text('Ahora · sensacion termica de 36 °C'), findsOneWidget);
  });

  testWidgets('da credito al proveedor de los datos', (WidgetTester tester) async {
    _forzar(tester, const Locale('es'));
    await tester.pumpWidget(_montar(_lluvia));

    expect(find.text('Datos: Open-Meteo'), findsOneWidget);
  });

  testWidgets('sin fuente no muestra el credito', (WidgetTester tester) async {
    _forzar(tester, const Locale('es'));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BannerClima(
            alerta: _lluvia,
            fuente: '',
            masAvisos: 0,
            onCerrar: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Datos:'), findsNothing);
  });

  testWidgets('avisa cuantos avisos mas esperan', (WidgetTester tester) async {
    _forzar(tester, const Locale('es'));
    await tester.pumpWidget(_montar(_lluvia, masAvisos: 2));

    expect(find.text('+2 mas'), findsOneWidget);
  });

  testWidgets('sin mas avisos no muestra el contador', (WidgetTester tester) async {
    _forzar(tester, const Locale('es'));
    await tester.pumpWidget(_montar(_lluvia));

    expect(find.textContaining('mas'), findsNothing);
  });

  testWidgets('la X cierra el aviso', (WidgetTester tester) async {
    _forzar(tester, const Locale('es'));
    int cierres = 0;
    await tester.pumpWidget(_montar(_lluvia, onCerrar: () => cierres++));

    await tester.tap(find.byTooltip('Ahora no'));

    expect(cierres, 1);
  });
}
