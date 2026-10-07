import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/editor_evento_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/mapa_trazos_evento.dart';

import 'helpers/montar.dart';

final DateTime _ahora = DateTime(2030, 5, 1, 9);

const List<PuntoGeo> _triangulo = <PuntoGeo>[
  PuntoGeo(lat: 10, lng: -84),
  PuntoGeo(lat: 10.001, lng: -84),
  PuntoGeo(lat: 10.001, lng: -84.001),
];
const List<PuntoGeo> _linea = <PuntoGeo>[
  PuntoGeo(lat: 10, lng: -84),
  PuntoGeo(lat: 10.002, lng: -84.002),
];

Evento _evento({List<ZonaEvento>? areas, List<ZonaEvento>? recorridos}) =>
    Evento(
      id: 7,
      nombre: 'Caminata benefica',
      descripcion: 'Por la escuela',
      categoria: 'caminata',
      fechaInicio: DateTime(2030, 5, 2, 8),
      fechaFin: DateTime(2030, 5, 2, 11),
      areas:
          areas ??
          const <ZonaEvento>[ZonaEvento(nombre: 'Salida', puntos: _triangulo)],
      recorridos:
          recorridos ??
          const <ZonaEvento>[ZonaEvento(nombre: '5k', puntos: _linea)],
      creadoPorNombre: 'Cafe El Roble',
    );

class _EventoApiFalsa extends EventoApi {
  final List<Map<String, Object?>> creados = <Map<String, Object?>>[];
  final List<Map<String, Object?>> actualizados = <Map<String, Object?>>[];
  Object? error;

  Evento _resultado(int id, String nombre) => Evento(
    id: id,
    nombre: nombre,
    categoria: 'otro',
    fechaInicio: DateTime(2030),
    fechaFin: DateTime(2030, 1, 2),
    areas: const <ZonaEvento>[],
    recorridos: const <ZonaEvento>[],
  );

  Map<String, Object?> _datos(
    String nombre,
    String? descripcion,
    String categoria,
    DateTime inicio,
    DateTime fin,
    List<ZonaEvento> areas,
    List<ZonaEvento> recorridos,
  ) => <String, Object?>{
    'nombre': nombre,
    'descripcion': descripcion,
    'categoria': categoria,
    'inicio': inicio,
    'fin': fin,
    'areas': areas,
    'recorridos': recorridos,
  };

  @override
  Future<Evento> crear({
    required String nombre,
    String? descripcion,
    required String categoria,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required List<ZonaEvento> areas,
    required List<ZonaEvento> recorridos,
  }) async {
    if (error != null) throw error!;
    creados.add(
      _datos(
        nombre,
        descripcion,
        categoria,
        fechaInicio,
        fechaFin,
        areas,
        recorridos,
      ),
    );
    return _resultado(99, nombre);
  }

  @override
  Future<Evento> actualizar(
    int id, {
    required String nombre,
    String? descripcion,
    required String categoria,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required List<ZonaEvento> areas,
    required List<ZonaEvento> recorridos,
  }) async {
    if (error != null) throw error!;
    actualizados.add(<String, Object?>{
      'id': id,
      ..._datos(
        nombre,
        descripcion,
        categoria,
        fechaInicio,
        fechaFin,
        areas,
        recorridos,
      ),
    });
    return _resultado(id, nombre);
  }
}

/// Mapa falso: dos botones que "terminan" un trazo (largo y corto) y un texto
/// con el modo de dibujo activo, para comprobar lo que el editor le pasa.
Widget _mapaFalso(
  BuildContext context,
  List<ZonaEvento> areas,
  List<ZonaEvento> recorridos,
  ModoDibujo modo,
  void Function(ModoDibujo, List<PuntoGeo>) onTrazoDibujado,
  VoidCallback onTrazoCorto,
) {
  // Centrado y algo hacia abajo: la barra de modos va superpuesta arriba.
  return Align(
    alignment: const Alignment(0, 0.35),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('modo:${modo.name}', key: const ValueKey<String>('modo-actual')),
        Text('areas:${areas.length} recorridos:${recorridos.length}'),
        TextButton(
          key: const ValueKey<String>('simular-trazo'),
          onPressed: () => onTrazoDibujado(
            modo,
            modo == ModoDibujo.area ? _triangulo : _linea,
          ),
          child: const Text('trazo'),
        ),
        TextButton(
          key: const ValueKey<String>('simular-trazo-corto'),
          onPressed: onTrazoCorto,
          child: const Text('corto'),
        ),
      ],
    ),
  );
}

Future<Evento?> _abrir(
  WidgetTester tester,
  _EventoApiFalsa api, {
  Evento? evento,
}) async {
  Evento? resultado;
  await montarApp(
    tester,
    Builder(
      builder: (BuildContext context) => TextButton(
        onPressed: () async {
          resultado = await Navigator.of(context).push<Evento>(
            MaterialPageRoute<Evento>(
              builder: (_) => EditorEventoScreen(
                api: api,
                evento: evento,
                mapaBuilder: _mapaFalso,
                ahora: () => _ahora,
              ),
            ),
          );
        },
        child: const Text('abrir'),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return resultado;
}

Future<void> _irAlMapa(WidgetTester tester) async {
  await tester.tap(find.text('Mapa'));
  await tester.pumpAndSettle();
}

/// Elige la fecha y la hora que ofrece el selector (la sugerida) en una fila.
Future<void> _elegirFecha(WidgetTester tester, String clave) async {
  await tester.ensureVisible(find.byKey(ValueKey<String>(clave)));
  await tester.tap(find.byKey(ValueKey<String>(clave)));
  await tester.pumpAndSettle();
  await _aceptarDialogo(tester); // fecha
  await _aceptarDialogo(tester); // hora
}

/// El boton de confirmar de un selector: el ultimo boton de texto del dialogo.
Future<void> _aceptarDialogo(WidgetTester tester) async {
  await tester.tap(
    find
        .descendant(of: find.byType(Dialog), matching: find.byType(TextButton))
        .last,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('crear un evento', () {
    testWidgets('sin llenar nada avisa y no llama a la API', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await _abrir(tester, api);

      await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
      await tester.pumpAndSettle();

      expect(find.text('Revisa los campos marcados en rojo'), findsOneWidget);
      expect(api.creados, isEmpty);
    });

    testWidgets('falta la categoria: lo dice y no guarda', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await _abrir(tester, api);
      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-nombre-evento')),
        'Mi evento',
      );
      await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
      await tester.pumpAndSettle();

      expect(find.text('Elige una categoria'), findsOneWidget);
      expect(api.creados, isEmpty);
    });

    testWidgets('sin fechas pide elegirlas', (WidgetTester tester) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await _abrir(tester, api);
      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-nombre-evento')),
        'Mi evento',
      );
      await tester.tap(find.byKey(const ValueKey<String>('opcion-caminata')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
      await tester.pumpAndSettle();

      expect(
        find.text('Elige cuando empieza y cuando termina'),
        findsOneWidget,
      );
      expect(api.creados, isEmpty);
    });

    testWidgets('con fechas pero sin trazos pasa al mapa y lo pide', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await _abrir(tester, api);
      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-nombre-evento')),
        'Mi evento',
      );
      await tester.tap(find.byKey(const ValueKey<String>('opcion-caminata')));
      await tester.pump();
      await _elegirFecha(tester, 'fecha-inicio');
      await _elegirFecha(tester, 'fecha-fin');

      await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
      await tester.pumpAndSettle();

      expect(
        find.text('Dibuja al menos un area o un recorrido en el mapa'),
        findsOneWidget,
      );
      // Cambio a la pestaña del mapa.
      expect(
        find.byKey(const ValueKey<String>('simular-trazo')),
        findsOneWidget,
      );
      expect(api.creados, isEmpty);
    });

    testWidgets('flujo completo: datos, un area y un recorrido, guardar', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await _abrir(tester, api);

      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-nombre-evento')),
        '  Evento Benefico  ',
      );
      await tester.tap(find.byKey(const ValueKey<String>('opcion-benefico')));
      await tester.pump();
      await _elegirFecha(tester, 'fecha-inicio');
      await _elegirFecha(tester, 'fecha-fin');

      await _irAlMapa(tester);
      // Trazar un area.
      await tester.tap(find.byKey(const ValueKey<String>('modo-area')));
      await tester.pump();
      expect(find.text('modo:area'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('simular-trazo')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('aceptar-nombre-trazo')),
      );
      await tester.pumpAndSettle();
      // Tras nombrar el trazo vuelve a "mover mapa".
      expect(find.text('modo:ninguno'), findsOneWidget);
      expect(find.text('Area 1'), findsOneWidget);

      // Trazar un recorrido con nombre propio.
      await tester.tap(find.byKey(const ValueKey<String>('modo-recorrido')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('simular-trazo')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-nombre-trazo')),
        'Caminata 5k',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('aceptar-nombre-trazo')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Caminata 5k'), findsOneWidget);
      expect(find.text('areas:1 recorridos:1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
      await tester.pumpAndSettle();

      expect(api.creados, hasLength(1));
      final Map<String, Object?> enviado = api.creados.single;
      expect(enviado['nombre'], '  Evento Benefico  ');
      expect(enviado['categoria'], 'benefico');
      final DateTime inicio = enviado['inicio']! as DateTime;
      final DateTime fin = enviado['fin']! as DateTime;
      expect(fin.isAfter(inicio), isTrue);
      final List<ZonaEvento> areas = enviado['areas']! as List<ZonaEvento>;
      final List<ZonaEvento> recorridos =
          enviado['recorridos']! as List<ZonaEvento>;
      expect(areas.single.nombre, 'Area 1');
      expect(areas.single.puntos, _triangulo);
      expect(recorridos.single.nombre, 'Caminata 5k');
      expect(recorridos.single.puntos, _linea);
      // Cerro la pantalla y avisa.
      expect(find.byType(EditorEventoScreen), findsNothing);
      expect(find.text('Evento guardado'), findsOneWidget);
    });

    testWidgets('cancelar el nombre del trazo lo descarta', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await _abrir(tester, api);
      await _irAlMapa(tester);
      await tester.tap(find.byKey(const ValueKey<String>('modo-recorrido')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('simular-trazo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('areas:0 recorridos:0'), findsOneWidget);
      expect(find.text('Aun no dibujas nada'), findsOneWidget);
    });

    testWidgets('un trazo demasiado corto avisa y no agrega nada', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await _abrir(tester, api);
      await _irAlMapa(tester);
      await tester.tap(find.byKey(const ValueKey<String>('modo-area')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('simular-trazo-corto')),
      );
      await tester.pump();

      expect(
        find.text('El trazo es muy corto. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('areas:0 recorridos:0'), findsOneWidget);
    });

    testWidgets('quitar un trazo con la X lo saca de la lista', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await _abrir(tester, api, evento: _evento());
      await _irAlMapa(tester);
      expect(find.text('Salida'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('trazo-area-Salida')),
          matching: find.byTooltip('Eliminar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Salida'), findsNothing);
      expect(find.text('5k'), findsOneWidget);
      expect(find.text('areas:0 recorridos:1'), findsOneWidget);
    });

    testWidgets(
      'un error del servidor se muestra y la pantalla sigue abierta',
      (WidgetTester tester) async {
        final _EventoApiFalsa api = _EventoApiFalsa()
          ..error = ApiException(
            400,
            'El evento no puede terminar en el pasado',
          );
        await _abrir(tester, api, evento: _evento());

        await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
        await tester.pumpAndSettle();

        expect(
          find.text('El evento no puede terminar en el pasado'),
          findsOneWidget,
        );
        expect(find.byType(EditorEventoScreen), findsOneWidget);
      },
    );

    testWidgets('un fallo de red muestra el mensaje generico', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa()
        ..error = Exception('sin red');
      await _abrir(tester, api, evento: _evento());

      await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo guardar el evento'), findsOneWidget);
    });
  });

  group('editar un evento', () {
    testWidgets('arranca con los datos y los trazos del evento', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _EventoApiFalsa(), evento: _evento());

      expect(find.text('Editar evento'), findsOneWidget);
      expect(find.text('Caminata benefica'), findsOneWidget);
      expect(find.text('Por la escuela'), findsOneWidget);
      expect(find.text('Areas: 1 - Recorridos: 1'), findsOneWidget);
    });

    testWidgets('guardar llama a actualizar con el id y los mismos datos', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await _abrir(tester, api, evento: _evento());

      await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
      await tester.pumpAndSettle();

      expect(api.creados, isEmpty);
      expect(api.actualizados, hasLength(1));
      final Map<String, Object?> enviado = api.actualizados.single;
      expect(enviado['id'], 7);
      expect(enviado['nombre'], 'Caminata benefica');
      expect(enviado['categoria'], 'caminata');
      expect(enviado['inicio'], DateTime(2030, 5, 2, 8));
      expect(enviado['fin'], DateTime(2030, 5, 2, 11));
    });

    testWidgets(
      'permite guardar un evento que ya empezo (no exige fecha futura)',
      (WidgetTester tester) async {
        final _EventoApiFalsa api = _EventoApiFalsa();
        final Evento enCurso = Evento(
          id: 8,
          nombre: 'En marcha',
          categoria: 'carrera',
          fechaInicio: DateTime(2030, 4, 30),
          fechaFin: DateTime(2030, 4, 30, 5), // ya paso respecto de _ahora
          areas: const <ZonaEvento>[
            ZonaEvento(nombre: 'A', puntos: _triangulo),
          ],
          recorridos: const <ZonaEvento>[],
        );
        await _abrir(tester, api, evento: enCurso);

        await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
        await tester.pumpAndSettle();

        expect(api.actualizados, hasLength(1));
      },
    );

    testWidgets('quitar todos los trazos impide guardar', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await _abrir(
        tester,
        api,
        evento: _evento(recorridos: const <ZonaEvento>[]),
      );
      await _irAlMapa(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('trazo-area-Salida')),
          matching: find.byTooltip('Eliminar'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
      await tester.pumpAndSettle();

      expect(
        find.text('Dibuja al menos un area o un recorrido en el mapa'),
        findsWidgets,
      );
      expect(api.actualizados, isEmpty);
    });
  });
}
