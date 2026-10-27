import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/app.dart';
import 'package:fit_quest_go/core/idioma/idioma_app.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/bienvenida_screen.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/preferencias_screen.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

import 'helpers/montar.dart';

class _AlmacenEnMemoria implements AlmacenIdioma {
  _AlmacenEnMemoria([this.guardado]);

  String? guardado;
  int escrituras = 0;

  @override
  Future<String?> leer() async => guardado;

  @override
  Future<void> guardar(String? codigo) async {
    escrituras++;
    guardado = codigo;
  }
}

const Usuario _usuario = Usuario(
  id: 1,
  nombreUser: 'Ana',
  emailUser: 'ana@correo.com',
  idrol: 1,
);

void main() {
  group('ControladorIdioma', () {
    test('sin nada guardado sigue al telefono (locale nulo)', () async {
      final ControladorIdioma c = ControladorIdioma(_AlmacenEnMemoria());
      await c.cargar();
      expect(c.idioma, isNull);
      expect(c.locale, isNull);
    });

    test('elegir cambia el idioma, avisa y lo recuerda', () async {
      final _AlmacenEnMemoria almacen = _AlmacenEnMemoria();
      final ControladorIdioma c = ControladorIdioma(almacen);
      int avisos = 0;
      c.addListener(() => avisos++);

      await c.elegir(IdiomaApp.ingles);

      expect(c.locale, const Locale('en'));
      expect(almacen.guardado, 'en');
      expect(avisos, 1);
    });

    test('portugues usa pt-BR, el unico ARB regional que hay', () async {
      final ControladorIdioma c = ControladorIdioma(_AlmacenEnMemoria());
      await c.elegir(IdiomaApp.portugues);
      expect(c.locale, const Locale('pt', 'BR'));
    });

    test('elegir lo mismo no vuelve a avisar ni a escribir', () async {
      final _AlmacenEnMemoria almacen = _AlmacenEnMemoria();
      final ControladorIdioma c = ControladorIdioma(almacen);
      await c.elegir(IdiomaApp.espanol);
      int avisos = 0;
      c.addListener(() => avisos++);

      await c.elegir(IdiomaApp.espanol);

      expect(avisos, 0);
      expect(almacen.escrituras, 1);
    });

    test('volver a "igual que el celular" borra lo guardado', () async {
      final _AlmacenEnMemoria almacen = _AlmacenEnMemoria('en');
      final ControladorIdioma c = ControladorIdioma(almacen);
      await c.cargar();
      expect(c.idioma, IdiomaApp.ingles);

      await c.elegir(null);

      expect(c.locale, isNull);
      expect(almacen.guardado, isNull);
    });

    test('un codigo guardado que ya no existe se ignora', () async {
      final ControladorIdioma c = ControladorIdioma(
        _AlmacenEnMemoria('klingon'),
      );
      await c.cargar();
      expect(c.idioma, isNull);
    });
  });

  group('la app respeta el idioma elegido', () {
    testWidgets(
      'con el telefono en ingles, elegir español pone la app en español y al reves',
      (WidgetTester tester) async {
        tester.platformDispatcher.localesTestValue = const <Locale>[
          Locale('en'),
        ];
        tester.platformDispatcher.localeTestValue = const Locale('en');
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        final ControladorIdioma c = ControladorIdioma(_AlmacenEnMemoria());

        await tester.pumpWidget(FitQuestGoApp(auth: AuthFalso(), idioma: c));
        await tester.pump();
        String idiomaVisto() => AppLocalizations.of(
          tester.element(find.byType(BienvenidaScreen)),
        )!.localeName;
        expect(idiomaVisto(), 'en');

        await c.elegir(IdiomaApp.espanol);
        await tester.pump();
        expect(idiomaVisto(), 'es');

        await c.elegir(null);
        await tester.pump();
        expect(idiomaVisto(), 'en');
      },
    );
  });

  group('selector en Preferencias', () {
    Future<ControladorIdioma> montar(WidgetTester tester) async {
      final ControladorIdioma c = ControladorIdioma(_AlmacenEnMemoria());
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: c,
          builder: (BuildContext context, Widget? _) => MaterialApp(
            locale: c.locale ?? const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PreferenciasScreen(usuario: _usuario, idioma: c),
          ),
        ),
      );
      await tester.pump();
      return c;
    }

    testWidgets(
      'ofrece el del celular y los tres idiomas con su propio nombre',
      (WidgetTester tester) async {
        await montar(tester);

        expect(find.text('Idioma de la app'), findsOneWidget);
        expect(find.text('Igual que el celular'), findsOneWidget);
        expect(find.text('Español'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Português'), findsOneWidget);
      },
    );

    testWidgets('tocar un idioma cambia la pantalla al instante, sin Guardar', (
      WidgetTester tester,
    ) async {
      final ControladorIdioma c = await montar(tester);
      expect(find.text('Preferencias y privacidad'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('idioma-en')));
      await tester.pump();
      expect(c.idioma, IdiomaApp.ingles);
      expect(find.text('Preferences & privacy'), findsOneWidget);
      expect(find.text('App language'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('idioma-pt')));
      await tester.pump();
      expect(find.text('Preferências e privacidade'), findsOneWidget);
    });
  });
}
