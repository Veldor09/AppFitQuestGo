import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/theme/fq_theme.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/home/application/busqueda_mapa.dart';
import 'package:fit_quest_go/Modulos/home/application/cercanos.dart';
import 'package:fit_quest_go/Modulos/home/application/filtro_mapa.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/barra_busqueda_mapa.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/campana_notificaciones.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/filtros_mapa.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/panel_cercano.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/resultados_busqueda.dart';

import 'helpers/datos_mapa.dart';
import 'helpers/montar.dart';

void main() {
  group('FiltrosMapa', () {
    Future<List<FiltroMapa>> montar(
      WidgetTester tester, {
      FiltroMapa seleccionado = FiltroMapa.todo,
    }) async {
      final List<FiltroMapa> elegidos = <FiltroMapa>[];
      await montarApp(
        tester,
        Scaffold(
          body: FiltrosMapa(seleccionado: seleccionado, onCambio: elegidos.add),
        ),
      );
      return elegidos;
    }

    testWidgets('muestra los cinco filtros', (WidgetTester tester) async {
      await montar(tester);

      for (final String etiqueta in <String>['Todo', 'Rutas', 'Alertas', 'POIs', 'Eventos']) {
        expect(find.text(etiqueta), findsOneWidget, reason: etiqueta);
      }
    });

    testWidgets('marca como seleccionado solo el filtro activo', (WidgetTester tester) async {
      final SemanticsHandle semantica = tester.ensureSemantics();
      await montar(tester, seleccionado: FiltroMapa.alertas);

      for (final FiltroMapa f in FiltroMapa.values) {
        expect(
          tester.getSemantics(find.byKey(ValueKey<String>('filtro-${f.name}'))),
          isSemantics(isSelected: f == FiltroMapa.alertas),
          reason: f.name,
        );
      }
      semantica.dispose();
    });

    testWidgets('tocar un filtro avisa cual se eligio', (WidgetTester tester) async {
      final List<FiltroMapa> elegidos = await montar(tester);

      await tester.tap(find.text('Alertas'));
      await tester.tap(find.text('POIs'));
      await tester.tap(find.text('Eventos'));

      expect(elegidos, <FiltroMapa>[FiltroMapa.alertas, FiltroMapa.pois, FiltroMapa.eventos]);
    });

    testWidgets('en una pantalla angosta pasan a otra linea, sin desbordarse', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(280, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final List<FiltroMapa> elegidos = await montar(tester);
      await tester.tap(find.text('Eventos'));

      expect(tester.takeException(), isNull);
      expect(elegidos, <FiltroMapa>[FiltroMapa.eventos]);
      // El ultimo no cabe en la primera linea: queda mas abajo que el primero.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('filtro-eventos'))).dy,
        greaterThan(tester.getTopLeft(find.byKey(const ValueKey<String>('filtro-todo'))).dy),
      );
    });
  });

  group('CampanaNotificaciones', () {
    Future<List<int>> montar(WidgetTester tester, {required int noLeidas}) async {
      final List<int> toques = <int>[];
      await montarApp(
        tester,
        Scaffold(
          body: Center(
            child: CampanaNotificaciones(
              noLeidas: noLeidas,
              onTap: () => toques.add(noLeidas),
            ),
          ),
        ),
      );
      return toques;
    }

    const ValueKey<String> contador = ValueKey<String>('campana-contador');

    testWidgets('sin notificaciones por leer no muestra contador', (WidgetTester tester) async {
      final SemanticsHandle semantica = tester.ensureSemantics();
      await montar(tester, noLeidas: 0);

      expect(find.byKey(contador), findsNothing);
      expect(find.bySemanticsLabel('Notificaciones'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('con notificaciones por leer muestra cuantas son', (WidgetTester tester) async {
      final SemanticsHandle semantica = tester.ensureSemantics();
      await montar(tester, noLeidas: 3);

      expect(find.descendant(of: find.byKey(contador), matching: find.text('3')), findsOneWidget);
      expect(find.bySemanticsLabel('3 notificaciones sin leer'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('con una sola dice "1 notificacion sin leer"', (WidgetTester tester) async {
      final SemanticsHandle semantica = tester.ensureSemantics();
      await montar(tester, noLeidas: 1);

      expect(find.bySemanticsLabel('1 notificacion sin leer'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('de 10 en adelante muestra "9+"', (WidgetTester tester) async {
      await montar(tester, noLeidas: 12);

      expect(find.descendant(of: find.byKey(contador), matching: find.text('9+')), findsOneWidget);
    });

    testWidgets('tocarla avisa', (WidgetTester tester) async {
      final List<int> toques = await montar(tester, noLeidas: 2);

      await tester.tap(find.byType(CampanaNotificaciones));

      expect(toques, hasLength(1));
    });
  });

  group('BarraBusquedaMapa', () {
    testWidgets('muestra el texto de ayuda, avisa lo que se escribe y se puede borrar', (
      WidgetTester tester,
    ) async {
      final TextEditingController controlador = TextEditingController();
      final FocusNode foco = FocusNode();
      addTearDown(controlador.dispose);
      addTearDown(foco.dispose);
      final List<String> escritos = <String>[];
      int borrados = 0;
      await montarApp(
        tester,
        Scaffold(
          body: BarraBusquedaMapa(
            controller: controlador,
            focusNode: foco,
            onChanged: escritos.add,
            onLimpiar: () {
              borrados++;
              controlador.clear();
            },
          ),
        ),
      );

      expect(find.text('Buscar lugar, ruta o evento'), findsOneWidget);
      expect(find.byTooltip('Borrar busqueda'), findsNothing);

      await tester.enterText(find.byType(TextField), 'sendero');
      await tester.pump();

      expect(escritos, <String>['sendero']);
      expect(find.byTooltip('Borrar busqueda'), findsOneWidget);

      await tester.tap(find.byTooltip('Borrar busqueda'));
      await tester.pump();

      expect(borrados, 1);
      expect(find.byTooltip('Borrar busqueda'), findsNothing);
    });
  });

  group('BarraBusquedaMapa con el tema de la app', () {
    testWidgets('el campo no dibuja relleno ni borde propios: la barra ya es la caja', (
      WidgetTester tester,
    ) async {
      final TextEditingController controlador = TextEditingController();
      final FocusNode foco = FocusNode();
      addTearDown(controlador.dispose);
      addTearDown(foco.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildFqTheme(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BarraBusquedaMapa(
              controller: controlador,
              focusNode: foco,
              onChanged: (_) {},
              onLimpiar: () {},
            ),
          ),
        ),
      );

      // El tema global rellena y bordea todos los campos de texto; en la barra
      // eso se veria como una caja dentro de otra caja.
      final InputDecoration decoracion = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration;
      expect(decoracion.filled, isFalse);
      expect(decoracion.border, InputBorder.none);
      expect(decoracion.enabledBorder, InputBorder.none);
      expect(decoracion.focusedBorder, InputBorder.none);
    });
  });

  group('ResultadosBusqueda', () {
    ResultadoBusqueda resultado({
      TipoResultado tipo = TipoResultado.poi,
      String titulo = 'Fuente del parque',
      String detalle = 'Agua',
      double? metros,
    }) {
      return ResultadoBusqueda(
        tipo: tipo,
        origen: Object(),
        titulo: titulo,
        detalle: detalle,
        lat: latBase,
        lng: lngBase,
        metros: metros,
      );
    }

    testWidgets('lista cada resultado con su detalle y su distancia', (WidgetTester tester) async {
      await montarApp(
        tester,
        Scaffold(
          body: ResultadosBusqueda(
            consulta: 'fuente',
            resultados: <ResultadoBusqueda>[
              resultado(metros: 296),
              resultado(
                tipo: TipoResultado.ruta,
                titulo: 'Sendero del Rio',
                detalle: 'Running · 5,0 km',
                metros: 1234,
              ),
              resultado(tipo: TipoResultado.alerta, titulo: 'Bache', detalle: 'Gravedad Alta'),
            ],
            onElegir: (_) {},
          ),
        ),
      );

      expect(find.text('Fuente del parque'), findsOneWidget);
      expect(find.text('Agua'), findsOneWidget);
      expect(find.text('296 m'), findsOneWidget);
      expect(find.text('Sendero del Rio'), findsOneWidget);
      expect(find.text('Running · 5,0 km'), findsOneWidget);
      expect(find.text('1,2 km'), findsOneWidget);
      expect(find.text('Bache'), findsOneWidget);
      expect(find.text('Gravedad Alta'), findsOneWidget);
    });

    testWidgets('tocar un resultado avisa cual', (WidgetTester tester) async {
      final List<ResultadoBusqueda> elegidos = <ResultadoBusqueda>[];
      final ResultadoBusqueda a = resultado(titulo: 'Fuente A');
      final ResultadoBusqueda b = resultado(titulo: 'Fuente B');
      await montarApp(
        tester,
        Scaffold(
          body: ResultadosBusqueda(
            consulta: 'fuente',
            resultados: <ResultadoBusqueda>[a, b],
            onElegir: elegidos.add,
          ),
        ),
      );

      await tester.tap(find.text('Fuente B'));

      expect(elegidos, <ResultadoBusqueda>[b]);
    });

    testWidgets('sin resultados lo dice, con lo que se escribio', (WidgetTester tester) async {
      await montarApp(
        tester,
        Scaffold(
          body: ResultadosBusqueda(
            consulta: '  zzz ',
            resultados: const <ResultadoBusqueda>[],
            onElegir: (_) {},
          ),
        ),
      );

      expect(find.text('Sin resultados para "zzz"'), findsOneWidget);
    });
  });

  group('PanelCercano', () {
    Future<List<String>> montar(
      WidgetTester tester, {
      bool hayUbicacion = true,
      RutaCercana? ruta,
      AlertaCercana? alerta,
    }) async {
      final List<String> toques = <String>[];
      await montarApp(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PanelCercano(
              hayUbicacion: hayUbicacion,
              ruta: ruta,
              alerta: alerta,
              onRuta: () => toques.add('ruta'),
              onAlerta: () => toques.add('alerta'),
              onAgregar: () => toques.add('agregar'),
            ),
          ),
        ),
      );
      return toques;
    }

    testWidgets('lleva el titulo y la pista de siempre', (WidgetTester tester) async {
      await montar(tester);

      expect(find.text('Cerca de ti'), findsOneWidget);
      expect(find.text('Manten presionado el mapa para reportar'), findsOneWidget);
    });

    testWidgets('mientras no hay ubicacion dice que la esta buscando', (WidgetTester tester) async {
      await montar(tester, hayUbicacion: false);

      expect(find.text('Buscando tu ubicacion...'), findsNWidgets(2));
    });

    testWidgets('con ubicacion y nada cerca lo dice', (WidgetTester tester) async {
      await montar(tester);

      expect(find.text('Sin rutas cerca'), findsOneWidget);
      expect(find.text('Sin alertas cerca'), findsOneWidget);
    });

    testWidgets('muestra la ruta y la alerta mas cercanas con su distancia', (
      WidgetTester tester,
    ) async {
      await montar(
        tester,
        ruta: RutaCercana(rutaDePrueba(nombre: 'Sendero del Rio'), 1234),
        alerta: AlertaCercana(alertaDePrueba(tipo: 'bache'), 296.4),
      );

      expect(find.text('Sendero del Rio'), findsOneWidget);
      expect(find.text('1,2 km'), findsOneWidget);
      expect(find.text('Bache'), findsOneWidget);
      expect(find.text('296 m'), findsOneWidget);
      expect(find.text('Sin rutas cerca'), findsNothing);
    });

    testWidgets('tocar la ruta, la alerta o el "+" avisa', (WidgetTester tester) async {
      final List<String> toques = await montar(
        tester,
        ruta: RutaCercana(rutaDePrueba(nombre: 'Sendero del Rio'), 1234),
        alerta: AlertaCercana(alertaDePrueba(tipo: 'bache'), 296),
      );

      await tester.tap(find.text('Sendero del Rio'));
      await tester.tap(find.text('Bache'));
      await tester.tap(find.byTooltip('Reportar aqui'));

      expect(toques, <String>['ruta', 'alerta', 'agregar']);
    });

    testWidgets('las casillas vacias no hacen nada al tocarlas, pero el "+" si', (
      WidgetTester tester,
    ) async {
      final List<String> toques = await montar(tester);

      await tester.tap(find.text('Sin rutas cerca'));
      await tester.tap(find.text('Sin alertas cerca'));
      await tester.tap(find.byTooltip('Reportar aqui'));

      expect(toques, <String>['agregar']);
    });

    testWidgets('un nombre de ruta muy largo no desborda la casilla', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await montar(
        tester,
        ruta: RutaCercana(
          rutaDePrueba(nombre: 'Gran travesia circular por los senderos del volcan y el rio'),
          1234,
        ),
        alerta: AlertaCercana(alertaDePrueba(tipo: 'zona_insegura'), 296),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
