import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/formulario_alerta.dart';

typedef _Reporte = ({
  String tipo,
  String? tipoOtro,
  String gravedad,
  String? descripcion,
});

class _AlertaApiFalsa extends AlertaApi {
  final List<_Reporte> reportes = <_Reporte>[];
  Object? error;

  @override
  Future<Alerta> reportar({
    required String tipo,
    String? tipoOtro,
    required String gravedad,
    required double lat,
    required double lng,
    String? descripcion,
  }) async {
    if (error != null) throw error!;
    reportes.add((
      tipo: tipo,
      tipoOtro: tipoOtro,
      gravedad: gravedad,
      descripcion: descripcion,
    ));
    return Alerta(
      id: 1,
      tipo: tipo,
      tipoOtro: tipoOtro,
      gravedad: gravedad,
      lat: lat,
      lng: lng,
      estado: 'Activa',
    );
  }
}

class _Escenario {
  final _AlertaApiFalsa api = _AlertaApiFalsa();
  Alerta? resultado;
  bool cerrado = false;

  Future<void> abrir(WidgetTester tester) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    tester.platformDispatcher.localeTestValue = const Locale('es');
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                resultado = await showModalBottomSheet<Alerta>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext _) =>
                      FormularioAlerta(api: api, lat: 9.93, lng: -84.09),
                );
                cerrado = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> publicar(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Publicar alerta'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('ofrece los tipos de alerta para elegir, sin campo de texto', (
    WidgetTester tester,
  ) async {
    final _Escenario e = _Escenario();
    await e.abrir(tester);

    for (final String tipo in <String>[
      'Arbol caido',
      'Bache',
      'Derrumbe',
      'Inundacion',
      'Perro bravo',
      'Via cerrada u obra',
      'Accidente',
      'Zona insegura',
      'Cable o poste caido',
      'Otro',
    ]) {
      expect(find.text(tipo), findsOneWidget, reason: tipo);
    }
    expect(find.widgetWithText(TextFormField, 'Tipo'), findsNothing);
    expect(find.text('Que tipo de alerta es?'), findsNothing);
  });

  testWidgets('sin elegir tipo avisa y no publica', (WidgetTester tester) async {
    final _Escenario e = _Escenario();
    await e.abrir(tester);

    await e.publicar(tester);

    expect(find.text('Elegi un tipo de alerta'), findsOneWidget);
    expect(e.api.reportes, isEmpty);
    expect(e.cerrado, isFalse);
  });

  testWidgets('un tipo del catalogo se publica con su clave y gravedad media', (
    WidgetTester tester,
  ) async {
    final _Escenario e = _Escenario();
    await e.abrir(tester);

    await tester.tap(find.text('Bache'));
    await tester.pump();
    await e.publicar(tester);

    expect(e.api.reportes, hasLength(1));
    expect(e.api.reportes.single.tipo, 'bache');
    expect(e.api.reportes.single.tipoOtro, isNull);
    expect(e.api.reportes.single.gravedad, 'media');
    expect(e.resultado?.tipo, 'bache');
  });

  testWidgets('es de seleccion simple: elegir otro tipo reemplaza al anterior', (
    WidgetTester tester,
  ) async {
    final _Escenario e = _Escenario();
    await e.abrir(tester);

    await tester.tap(find.text('Bache'));
    await tester.tap(find.text('Derrumbe'));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await e.publicar(tester);
    expect(e.api.reportes.single.tipo, 'derrumbe');
  });

  group('"Otro"', () {
    testWidgets('pide escribir de que alerta se trata', (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);

      await tester.tap(find.text('Otro'));
      await tester.pump();

      expect(find.text('Que tipo de alerta es?'), findsOneWidget);
    });

    testWidgets('sin texto no publica', (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);
      await tester.tap(find.text('Otro'));
      await tester.pump();

      await e.publicar(tester);

      expect(find.text('Obligatorio'), findsOneWidget);
      expect(e.api.reportes, isEmpty);
    });

    testWidgets('con texto lo envia junto a la clave "otro"', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);
      await tester.tap(find.text('Otro'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Que tipo de alerta es?'),
        'Poste inclinado',
      );
      await e.publicar(tester);

      expect(e.api.reportes.single.tipo, 'otro');
      expect(e.api.reportes.single.tipoOtro, 'Poste inclinado');
    });

    testWidgets('si cambias a un tipo del catalogo el campo desaparece y su texto no viaja', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);
      await tester.tap(find.text('Otro'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Que tipo de alerta es?'),
        'Poste inclinado',
      );

      await tester.tap(find.text('Bache'));
      await tester.pump();

      expect(find.text('Que tipo de alerta es?'), findsNothing);
      await e.publicar(tester);
      expect(e.api.reportes.single.tipo, 'bache');
      expect(e.api.reportes.single.tipoOtro, isNull);
    });
  });

  testWidgets('la gravedad elegida viaja en el reporte', (WidgetTester tester) async {
    final _Escenario e = _Escenario();
    await e.abrir(tester);
    await tester.tap(find.text('Perro bravo'));
    await tester.pump();

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alta').last);
    await tester.pumpAndSettle();
    await e.publicar(tester);

    expect(e.api.reportes.single.gravedad, 'alta');
  });

  testWidgets('la descripcion es opcional y viaja si se escribe', (
    WidgetTester tester,
  ) async {
    final _Escenario e = _Escenario();
    await e.abrir(tester);
    await tester.tap(find.text('Accidente'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripcion (opcional)'),
      'Dos motos en la curva',
    );

    await e.publicar(tester);

    expect(e.api.reportes.single.descripcion, 'Dos motos en la curva');
  });

  testWidgets('si el servidor falla avisa y la hoja sigue abierta para reintentar', (
    WidgetTester tester,
  ) async {
    final _Escenario e = _Escenario();
    await e.abrir(tester);
    e.api.error = StateError('sin red');
    await tester.tap(find.text('Bache'));
    await tester.pump();

    await e.publicar(tester);

    expect(find.textContaining('No se pudo enviar'), findsOneWidget);
    expect(e.cerrado, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Publicar alerta'))
          .onPressed,
      isNotNull,
    );
  });
}
