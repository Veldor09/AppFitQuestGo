
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:fit_quest_go/Modulos/admin/data/catalogo_item.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogos_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/planificar_ruta_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/selector_actividades_catalogo.dart';
import 'package:fit_quest_go/core/fotos/selector_foto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

class _SelectorFalso implements SelectorFoto {
  _SelectorFalso(this.bytes);

  final Uint8List? bytes;

  @override
  Future<Uint8List?> elegir(OrigenFoto origen) async => bytes;
}

class _Reloj {
  DateTime ahora = DateTime(2026, 10, 5, 8);

  void avanzar(int segundos) {
    ahora = ahora.add(Duration(seconds: segundos));
  }
}

/// Evita llamadas reales al backend de rutas.
class _RutaApiFalsa extends RutaApi {
  final List<List<String>> actividadesCreadas = <List<String>>[];
  final List<({int id, Uint8List bytes})> fotosSubidas =
      <({int id, Uint8List bytes})>[];
  Object? errorAlSubirFoto;

  @override
  Future<Ruta> subirFoto(int id, Uint8List bytes) async {
    if (errorAlSubirFoto != null) throw errorAlSubirFoto!;
    fotosSubidas.add((id: id, bytes: bytes));
    return Ruta(
      id: id,
      nombre: 'x',
      actividades: const <String>[],
      dificultad: 'moderada',
      distanciaKm: 1,
      puntos: const <PuntoRuta>[],
      estado: 'Privada',
      conFoto: true,
    );
  }

  @override
  Future<Ruta> crear({
    required String nombre,
    required List<String> actividades,
    String? dificultad,
    required double distanciaKm,
    required List<PuntoRuta> puntos,
    String? visibilidad,
  }) async {
    actividadesCreadas.add(List<String>.of(actividades));

    return Ruta(
      id: 1,
      nombre: nombre,
      actividades: actividades,
      dificultad: dificultad ?? 'moderada',
      distanciaKm: distanciaKm,
      puntos: puntos,
      estado: 'Privada',
    );
  }
}

/// Simula el catálogo de ADM-11 sin realizar solicitudes HTTP.
class _CatalogosApiFalsa extends CatalogosApi {
  _CatalogosApiFalsa({
    List<CatalogoItem>? items,
    this.fallar = false,
  }) : items = items ?? _actividadesOriginales();

  List<CatalogoItem> items;
  bool fallar;
  int consultas = 0;

  @override
  Future<List<CatalogoItem>> listarItemsActivos(String catalogo) async {
    consultas++;

    if (catalogo != 'actividades') {
      throw StateError('Catálogo inesperado: $catalogo');
    }

    if (fallar) {
      throw Exception('Error simulado de conexión');
    }

    return List<CatalogoItem>.of(items);
  }
}

CatalogoItem _actividad(
  int id,
  String clave,
  String nombre, {
  bool activo = true,
}) {
  return CatalogoItem(
    id: id,
    catalogo: 'actividades',
    clave: clave,
    nombre: nombre,
    activo: activo,
  );
}

List<CatalogoItem> _actividadesOriginales() {
  return <CatalogoItem>[
    _actividad(1, 'running', 'Running'),
    _actividad(2, 'ciclismo', 'Ciclismo'),
    _actividad(3, 'mtb', 'MTB'),
    _actividad(4, 'hiking', 'Hiking'),
    _actividad(5, 'caminata', 'Caminata'),
    _actividad(6, 'otro', 'Otro'),
  ];
}

Widget _montar({
  Stream<Position>? streamFalso,
  DateTime Function()? ahora,
  RutaApi? api,
  CatalogosApi? catalogosApi,
  bool permitirFallbackActividades = true,
  SelectorFoto? selectorFoto,
}) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: PlanificarRutaScreen(
        api: api ?? _RutaApiFalsa(),
        catalogosApi: catalogosApi ?? _CatalogosApiFalsa(),
        accessToken: '',
        posicionStream: streamFalso == null ? null : (() => streamFalso),
        ahora: ahora,
        permitirFallbackActividades: permitirFallbackActividades,
        selectorFoto: selectorFoto,
      ),
    ),
  );
}

void _forzarLocaleEspanol(WidgetTester tester) {
  tester.platformDispatcher.localesTestValue = const <Locale>[
    Locale('es'),
  ];
  tester.platformDispatcher.localeTestValue = const Locale('es');

  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}

Future<StreamController<Position>> _empezarAGrabar(
  WidgetTester tester, {
  _Reloj? reloj,
  RutaApi? api,
  CatalogosApi? catalogosApi,
  bool permitirFallbackActividades = true,
  SelectorFoto? selectorFoto,
}) async {
  _forzarLocaleEspanol(tester);

  final StreamController<Position> controlador =
      StreamController<Position>.broadcast();

  addTearDown(controlador.close);

  await tester.pumpWidget(
    _montar(
      streamFalso: controlador.stream,
      ahora: reloj == null ? null : () => reloj.ahora,
      api: api,
      catalogosApi: catalogosApi,
      permitirFallbackActividades: permitirFallbackActividades,
      selectorFoto: selectorFoto,
    ),
  );

  await tester.pump();

  await tester.tap(find.text('Grabar GPS'));
  await tester.pump();

  await tester.tap(find.text('Iniciar grabacion'));
  await tester.pump();

  return controlador;
}

Future<void> _emitir(
  WidgetTester tester,
  StreamController<Position> controlador,
  double lat,
  double lng,
) async {
  controlador.add(_posicion(lat, lng));
  await tester.pump();
}

Future<void> _detener(WidgetTester tester) async {
  await tester.tap(find.text('Detener'));

  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });

  await tester.pump();
  await tester.pumpAndSettle();
}

/// Abre el formulario desde una grabación simulada.
Future<_RutaApiFalsa> _abrirFormulario(
  WidgetTester tester, {
  _CatalogosApiFalsa? catalogosApi,
  bool permitirFallbackActividades = true,
  SelectorFoto? selectorFoto,
  _RutaApiFalsa? apiFalsa,
}) async {
  final _RutaApiFalsa api = apiFalsa ?? _RutaApiFalsa();

  final StreamController<Position> controlador = await _empezarAGrabar(
    tester,
    api: api,
    catalogosApi: catalogosApi,
    permitirFallbackActividades: permitirFallbackActividades,
    selectorFoto: selectorFoto,
  );

  await _emitir(tester, controlador, 9.9281, -84.0907);
  await _emitir(tester, controlador, 9.9381, -84.0907);

  await _detener(tester);

  await tester.tap(find.text('Guardar ruta'));

  // Permite completar el primer frame y la consulta simulada.
  await tester.pump();
  await tester.pumpAndSettle();

  return api;
}

Future<void> _escribirNombre(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nombre'),
    'Vuelta al lago',
  );
}

Future<void> _guardarFormulario(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
  await tester.pumpAndSettle();
}

void main() {
  group('Planificación y grabación GPS', () {
    testWidgets('arranca en modo Dibujar, con el selector visible', (
      WidgetTester tester,
    ) async {
      _forzarLocaleEspanol(tester);

      await tester.pumpWidget(_montar());
      await tester.pump();

      expect(find.text('Dibujar'), findsOneWidget);
      expect(find.text('Grabar GPS'), findsOneWidget);
      expect(
        find.text('Arrastra el dedo sobre el mapa para trazar tu ruta.'),
        findsOneWidget,
      );
    });

    testWidgets('cambiar a modo GPS muestra el boton Iniciar grabacion', (
      WidgetTester tester,
    ) async {
      _forzarLocaleEspanol(tester);

      await tester.pumpWidget(_montar());
      await tester.pump();

      await tester.tap(find.text('Grabar GPS'));
      await tester.pump();

      expect(find.text('Iniciar grabacion'), findsOneWidget);
    });

    testWidgets('al grabar, cada posicion del stream se agrega como punto', (
      WidgetTester tester,
    ) async {
      final controlador = await _empezarAGrabar(tester);

      await _emitir(tester, controlador, 9.9281, -84.0907);
      await _emitir(tester, controlador, 9.9291, -84.0917);

      expect(find.textContaining('2 puntos'), findsOneWidget);
      expect(find.text('Detener'), findsOneWidget);
    });

    testWidgets('mientras graba muestra tiempo, distancia y ritmo en vivo', (
      WidgetTester tester,
    ) async {
      final _Reloj reloj = _Reloj();
      final controlador = await _empezarAGrabar(
        tester,
        reloj: reloj,
      );

      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);

      await _emitir(tester, controlador, 9.9281, -84.0907);
      await _emitir(tester, controlador, 9.9381, -84.0907);

      reloj.avanzar(360);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('1.11'), findsOneWidget);
      expect(find.text('5:24'), findsOneWidget);
    });

    testWidgets('el cronometro avanza cada segundo', (
      WidgetTester tester,
    ) async {
      final _Reloj reloj = _Reloj();
      await _empezarAGrabar(tester, reloj: reloj);

      reloj.avanzar(1);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:01'), findsOneWidget);

      reloj.avanzar(1);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:02'), findsOneWidget);
    });

    testWidgets(
      'Pausar congela el cronometro y no suma puntos; Reanudar retoma',
      (WidgetTester tester) async {
        final _Reloj reloj = _Reloj();
        final controlador = await _empezarAGrabar(
          tester,
          reloj: reloj,
        );

        await _emitir(tester, controlador, 9.9281, -84.0907);
        await _emitir(tester, controlador, 9.9291, -84.0907);

        reloj.avanzar(10);
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('00:10'), findsOneWidget);

        await tester.tap(find.text('Pausar'));
        await tester.pump();

        expect(find.text('Reanudar'), findsOneWidget);
        expect(find.text('Pausar'), findsNothing);
        expect(
          find.text('En pausa. Toca "Reanudar" para seguir.'),
          findsOneWidget,
        );

        reloj.avanzar(60);
        await tester.pump(const Duration(seconds: 1));
        await _emitir(tester, controlador, 9.9301, -84.0907);

        expect(find.text('00:10'), findsOneWidget);
        expect(find.textContaining('2 puntos'), findsOneWidget);

        await tester.tap(find.text('Reanudar'));
        await tester.pump();

        expect(find.text('Pausar'), findsOneWidget);

        reloj.avanzar(5);
        await _emitir(tester, controlador, 9.9311, -84.0907);
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('00:15'), findsOneWidget);
        expect(find.textContaining('3 puntos'), findsOneWidget);
      },
    );

    testWidgets('Detener abre el resumen con los datos de la sesion', (
      WidgetTester tester,
    ) async {
      final _Reloj reloj = _Reloj();
      final controlador = await _empezarAGrabar(
        tester,
        reloj: reloj,
      );

      await _emitir(tester, controlador, 9.9281, -84.0907);
      await _emitir(tester, controlador, 9.9381, -84.0907);

      reloj.avanzar(360);
      await _detener(tester);

      expect(find.text('Resumen de la grabacion'), findsOneWidget);
      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('1.11'), findsOneWidget);
      expect(find.text('5:24'), findsOneWidget);
      expect(controlador.hasListener, isFalse);
    });

    testWidgets('Detener sin haber grabado nada no abre el resumen', (
      WidgetTester tester,
    ) async {
      await _empezarAGrabar(tester);
      await _detener(tester);

      expect(find.text('Resumen de la grabacion'), findsNothing);
      expect(find.text('Iniciar grabacion'), findsOneWidget);
    });

    testWidgets('"Guardar ruta" abre el formulario de guardado', (
      WidgetTester tester,
    ) async {
      await _abrirFormulario(tester);

      expect(find.text('Resumen de la grabacion'), findsNothing);
      expect(find.text('Nombre'), findsOneWidget);
      expect(find.text('Actividades'), findsOneWidget);
    });

    testWidgets('"Descartar" en el resumen limpia la grabacion', (
      WidgetTester tester,
    ) async {
      final controlador = await _empezarAGrabar(tester);

      await _emitir(tester, controlador, 9.9281, -84.0907);
      await _emitir(tester, controlador, 9.9381, -84.0907);
      await _detener(tester);

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('Sin puntos todavia'), findsOneWidget);
      expect(find.text('Iniciar grabacion'), findsOneWidget);
      expect(find.text('00:00'), findsNothing);
    });

    testWidgets('Iniciar otra vez empieza una grabacion limpia', (
      WidgetTester tester,
    ) async {
      final _Reloj reloj = _Reloj();
      final controlador = await _empezarAGrabar(
        tester,
        reloj: reloj,
      );

      await _emitir(tester, controlador, 9.9281, -84.0907);
      await _emitir(tester, controlador, 9.9381, -84.0907);

      reloj.avanzar(360);
      await _detener(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Iniciar grabacion'));
      await tester.pump();

      expect(find.text('Sin puntos todavia'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('06:00'), findsNothing);
    });

    testWidgets('volver del resumen conserva la ruta y habilita Guardar', (
      WidgetTester tester,
    ) async {
      final controlador = await _empezarAGrabar(tester);

      await _emitir(tester, controlador, 9.9281, -84.0907);
      await _emitir(tester, controlador, 9.9291, -84.0917);
      await _detener(tester);

      expect(controlador.hasListener, isFalse);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Detener'), findsNothing);
      expect(find.text('Iniciar grabacion'), findsOneWidget);

      final Finder guardarFinder = find.widgetWithText(
        FqButton,
        'Guardar',
      );

      expect(guardarFinder, findsOneWidget);
      expect(
        tester.widget<FqButton>(guardarFinder).onPressed,
        isNotNull,
      );
    });
  });

  group('foto de la ruta', () {
    setUp(() {
      SelectorActividadesCatalogo.limpiarCache();
    });
    // PNG valido de 1x1 px (la vista previa lo decodifica de verdad).
    final Uint8List foto = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    testWidgets('el formulario ofrece agregar una foto (camara o galeria)', (
      WidgetTester tester,
    ) async {
      await _abrirFormulario(tester);

      expect(find.text('Foto (opcional)'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('foto-camara')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('foto-galeria')), findsOneWidget);
    });

    testWidgets('con foto elegida, se sube con el id de la ruta recien creada', (
      WidgetTester tester,
    ) async {
      final api = await _abrirFormulario(
        tester,
        selectorFoto: _SelectorFalso(foto),
      );
      await _escribirNombre(tester);
      await tester.tap(find.text('Running'));
      await tester.tap(find.byKey(const ValueKey<String>('foto-galeria')));
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('foto-elegida')), findsOneWidget);

      await _guardarFormulario(tester);

      expect(api.fotosSubidas, hasLength(1));
      expect(api.fotosSubidas.single.id, 1);
      expect(api.fotosSubidas.single.bytes, foto);
    });

    testWidgets('sin foto elegida no se sube nada', (WidgetTester tester) async {
      final api = await _abrirFormulario(
        tester,
        selectorFoto: _SelectorFalso(foto),
      );
      await _escribirNombre(tester);
      await tester.tap(find.text('Running'));

      await _guardarFormulario(tester);

      expect(api.actividadesCreadas, isNotEmpty);
      expect(api.fotosSubidas, isEmpty);
    });

    testWidgets('si la foto no sube, la ruta igual queda guardada', (
      WidgetTester tester,
    ) async {
      final _RutaApiFalsa fallida = _RutaApiFalsa()
        ..errorAlSubirFoto = Exception('sin red');
      final api = await _abrirFormulario(
        tester,
        selectorFoto: _SelectorFalso(foto),
        apiFalsa: fallida,
      );
      await _escribirNombre(tester);
      await tester.tap(find.text('Running'));
      await tester.tap(find.byKey(const ValueKey<String>('foto-galeria')));
      await tester.pump();

      await _guardarFormulario(tester);

      expect(api.actividadesCreadas, isNotEmpty);
      expect(api.fotosSubidas, isEmpty);
    });
  });

  group('ADM-11: catálogo dinámico de actividades', () {
    setUp(() {
      SelectorActividadesCatalogo.limpiarCache();
    });
    testWidgets('muestra las seis actividades originales activas', (
      WidgetTester tester,
    ) async {
      final catalogo = _CatalogosApiFalsa();

      await _abrirFormulario(tester, catalogosApi: catalogo);

      for (final String actividad in <String>[
        'Running',
        'Ciclismo',
        'MTB',
        'Hiking',
        'Caminata',
        'Otro',
      ]) {
        expect(find.text(actividad), findsOneWidget);
      }

      expect(
        find.widgetWithText(TextFormField, 'Actividad'),
        findsNothing,
      );
      expect(catalogo.consultas, 1);
    });

    testWidgets('sin elegir ninguna actividad no guarda', (
      WidgetTester tester,
    ) async {
      final api = await _abrirFormulario(tester);
      await _escribirNombre(tester);
      await _guardarFormulario(tester);

      expect(
        find.text('Elegi al menos una actividad'),
        findsOneWidget,
      );
      expect(find.text('Nombre'), findsOneWidget);
      expect(api.actividadesCreadas, isEmpty);
    });

    testWidgets('permite elegir varias en el orden del catálogo', (
      WidgetTester tester,
    ) async {
      final api = await _abrirFormulario(tester);
      await _escribirNombre(tester);

      await tester.tap(find.text('Hiking'));
      await tester.tap(find.text('Running'));
      await tester.pump();

      await _guardarFormulario(tester);

      expect(api.actividadesCreadas, <List<String>>[
        <String>['running', 'hiking'],
      ]);
    });

    testWidgets('tocar nuevamente una actividad la desmarca', (
      WidgetTester tester,
    ) async {
      final api = await _abrirFormulario(tester);
      await _escribirNombre(tester);

      await tester.tap(find.text('Running'));
      await tester.tap(find.text('Ciclismo'));
      await tester.tap(find.text('Running'));
      await tester.pump();

      await _guardarFormulario(tester);

      expect(api.actividadesCreadas, <List<String>>[
        <String>['ciclismo'],
      ]);
    });

    testWidgets('elegir una actividad elimina el error de validación', (
      WidgetTester tester,
    ) async {
      await _abrirFormulario(tester);
      await _escribirNombre(tester);
      await _guardarFormulario(tester);

      expect(
        find.text('Elegi al menos una actividad'),
        findsOneWidget,
      );

      await tester.tap(find.text('Caminata'));
      await tester.pump();

      expect(
        find.text('Elegi al menos una actividad'),
        findsNothing,
      );
    });

    testWidgets('oculta las actividades desactivadas', (
      WidgetTester tester,
    ) async {
      final catalogo = _CatalogosApiFalsa(
        items: <CatalogoItem>[
          _actividad(1, 'running', 'Running'),
          _actividad(
            2,
            'ciclismo',
            'Ciclismo',
            activo: false,
          ),
          _actividad(3, 'hiking', 'Hiking'),
        ],
      );

      await _abrirFormulario(tester, catalogosApi: catalogo);

      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Hiking'), findsOneWidget);
      expect(find.text('Ciclismo'), findsNothing);
    });

    testWidgets('muestra actividades nuevas creadas por el administrador', (
      WidgetTester tester,
    ) async {
      final catalogo = _CatalogosApiFalsa(
        items: <CatalogoItem>[
          _actividad(1, 'running', 'Running'),
          _actividad(20, 'natacion', 'Natación'),
        ],
      );

      final api = await _abrirFormulario(
        tester,
        catalogosApi: catalogo,
      );

      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Natación'), findsOneWidget);

      await _escribirNombre(tester);
      await tester.tap(find.text('Natación'));
      await tester.pump();

      await _guardarFormulario(tester);

      expect(api.actividadesCreadas, <List<String>>[
        <String>['natacion'],
      ]);
    });

    testWidgets('respeta el orden recibido del backend', (
      WidgetTester tester,
    ) async {
      final catalogo = _CatalogosApiFalsa(
        items: <CatalogoItem>[
          _actividad(20, 'natacion', 'Natación'),
          _actividad(3, 'hiking', 'Hiking'),
          _actividad(1, 'running', 'Running'),
        ],
      );

      final api = await _abrirFormulario(
        tester,
        catalogosApi: catalogo,
      );

      await _escribirNombre(tester);

      await tester.tap(find.text('Running'));
      await tester.tap(find.text('Natación'));
      await tester.pump();

      await _guardarFormulario(tester);

      expect(api.actividadesCreadas, <List<String>>[
        <String>['natacion', 'running'],
      ]);
    });

    testWidgets('un error de conexión activa catálogo offline de respaldo y permite guardar', (
      WidgetTester tester,
    ) async {
      final catalogo = _CatalogosApiFalsa(fallar: true);

      final api = await _abrirFormulario(
        tester,
        catalogosApi: catalogo,
      );

      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Ciclismo'), findsOneWidget);
      expect(
        find.text('Sin conexión: usando catálogo de actividades guardado.'),
        findsOneWidget,
      );

      final Finder guardar = find.widgetWithText(
        FilledButton,
        'Guardar',
      );

      expect(guardar, findsOneWidget);
      expect(
        tester.widget<FilledButton>(guardar).onPressed,
        isNotNull,
      );

      await _escribirNombre(tester);
      await tester.tap(find.text('Running'));
      await tester.pump();
      await _guardarFormulario(tester);

      expect(api.actividadesCreadas, <List<String>>[
        <String>['running'],
      ]);
    });

    testWidgets('con fallback desactivado, un error de conexión impide guardar y permite reintentar', (
      WidgetTester tester,
    ) async {
      final catalogo = _CatalogosApiFalsa(fallar: true);

      await _abrirFormulario(
        tester,
        catalogosApi: catalogo,
        permitirFallbackActividades: false,
      );

      expect(
        find.text('No se pudieron cargar las actividades.'),
        findsOneWidget,
      );

      expect(find.text('Reintentar'), findsOneWidget);

      final Finder guardar = find.widgetWithText(
        FilledButton,
        'Guardar',
      );

      expect(guardar, findsOneWidget);
      expect(
        tester.widget<FilledButton>(guardar).onPressed,
        isNull,
      );

      catalogo.fallar = false;

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Ciclismo'), findsOneWidget);
      expect(catalogo.consultas, 2);

      expect(
        tester.widget<FilledButton>(guardar).onPressed,
        isNotNull,
      );
    });

    testWidgets('un catálogo sin actividades impide guardar', (
      WidgetTester tester,
    ) async {
      final catalogo = _CatalogosApiFalsa(
        items: <CatalogoItem>[],
      );

      final api = await _abrirFormulario(
        tester,
        catalogosApi: catalogo,
      );

      expect(
        find.text('No hay actividades disponibles.'),
        findsOneWidget,
      );

      final Finder guardar = find.widgetWithText(
        FilledButton,
        'Guardar',
      );

      expect(
        tester.widget<FilledButton>(guardar).onPressed,
        isNull,
      );

      expect(api.actividadesCreadas, isEmpty);
    });
  });
}

Position _posicion(double lat, double lng) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}