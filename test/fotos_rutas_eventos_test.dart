import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/fotos/selector_foto.dart';
import 'package:fit_quest_go/core/widgets/campo_foto.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/editor_evento_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/evento_detalle_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/ficha_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/mapa_trazos_evento.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/ruta_detalle_screen.dart';
import 'helpers/calificacion_falsa.dart';
import 'helpers/montar.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _SelectorFalso implements SelectorFoto {
  _SelectorFalso(this.bytes);

  final Uint8List? bytes;
  final List<OrigenFoto> pedidos = <OrigenFoto>[];

  @override
  Future<Uint8List?> elegir(OrigenFoto origen) async {
    pedidos.add(origen);
    return bytes;
  }
}

class _EventoApiFalsa extends EventoApi {
  final List<({int id, Uint8List bytes})> fotosSubidas =
      <({int id, Uint8List bytes})>[];
  final List<int> fotosPedidas = <int>[];
  Object? errorAlSubir;

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
  }) async => _evento(conFoto: false);

  @override
  Future<Evento> subirFoto(int id, Uint8List bytes) async {
    if (errorAlSubir != null) throw errorAlSubir!;
    fotosSubidas.add((id: id, bytes: bytes));
    return _evento(conFoto: true);
  }

  @override
  Future<Uint8List> foto(int id) async {
    fotosPedidas.add(id);
    return _png;
  }
}

class _RutaApiFalsa extends RutaApi {
  final List<int> fotosPedidas = <int>[];

  @override
  Future<Set<int>> favoritasIds() async => <int>{};

  @override
  Future<Uint8List> foto(int id) async {
    fotosPedidas.add(id);
    return _png;
  }
}

const List<PuntoGeo> _triangulo = <PuntoGeo>[
  PuntoGeo(lat: 10, lng: -84),
  PuntoGeo(lat: 10.001, lng: -84),
  PuntoGeo(lat: 10.001, lng: -84.001),
];

Evento _evento({bool conFoto = false}) => Evento(
  id: 7,
  nombre: 'Caminata benefica',
  descripcion: 'Por la escuela',
  categoria: 'caminata',
  fechaInicio: DateTime(2030, 5, 2, 8),
  fechaFin: DateTime(2030, 5, 2, 11),
  areas: const <ZonaEvento>[ZonaEvento(nombre: 'Salida', puntos: _triangulo)],
  recorridos: const <ZonaEvento>[],
  creadoPorNombre: 'Cafe El Roble',
  conFoto: conFoto,
);

Ruta _ruta({bool conFoto = false}) => Ruta(
  id: 5,
  nombre: 'Cerro Grande',
  actividades: const <String>['running'],
  dificultad: 'facil',
  distanciaKm: 3.2,
  puntos: const <PuntoRuta>[
    PuntoRuta(lat: 9.9281, lng: -84.0907),
    PuntoRuta(lat: 9.9291, lng: -84.0917),
  ],
  estado: 'Publicada',
  conFoto: conFoto,
);

Widget _mapaVacio(
  BuildContext context,
  List<ZonaEvento> areas,
  List<ZonaEvento> recorridos,
  String etiqueta,
  ModoDibujo modo,
  void Function(ModoDibujo, List<PuntoGeo>) onTrazoDibujado,
  VoidCallback onTrazoCorto,
) => const SizedBox.shrink();

void _pantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  usarCalificacionesFalsas();

  group('CampoFoto', () {
    Future<List<Uint8List?>> montar(
      WidgetTester tester, {
      Uint8List? inicial,
      Uint8List? alElegir,
      bool yaTiene = false,
    }) async {
      final List<Uint8List?> cambios = <Uint8List?>[];
      Uint8List? actual = inicial;
      await montarApp(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => Scaffold(
            body: CampoFoto(
              foto: actual,
              yaTiene: yaTiene,
              selector: _SelectorFalso(alElegir),
              alCambiar: (Uint8List? f) {
                cambios.add(f);
                setState(() => actual = f);
              },
            ),
          ),
        ),
      );
      return cambios;
    }

    testWidgets('ofrece camara y galeria', (tester) async {
      await montar(tester);

      expect(find.text('Foto (opcional)'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('foto-camara')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('foto-galeria')), findsOneWidget);
    });

    testWidgets('elegir de la galeria entrega los bytes y muestra la vista previa', (
      tester,
    ) async {
      final List<Uint8List?> cambios = await montar(tester, alElegir: _png);

      await tester.tap(find.byKey(const ValueKey<String>('foto-galeria')));
      await tester.pumpAndSettle();

      expect(cambios.single, _png);
      expect(find.byKey(const ValueKey<String>('foto-elegida')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('foto-camara')), findsNothing);
    });

    testWidgets('si la persona cancela no cambia nada', (tester) async {
      final List<Uint8List?> cambios = await montar(tester, alElegir: null);

      await tester.tap(find.byKey(const ValueKey<String>('foto-camara')));
      await tester.pumpAndSettle();

      expect(cambios, isEmpty);
    });

    testWidgets('"Quitar foto" la saca', (tester) async {
      final List<Uint8List?> cambios = await montar(tester, inicial: _png);

      await tester.tap(find.byKey(const ValueKey<String>('foto-quitar')));
      await tester.pumpAndSettle();

      expect(cambios.single, isNull);
      expect(find.byKey(const ValueKey<String>('foto-camara')), findsOneWidget);
    });

    testWidgets('al editar algo que ya tiene foto lo avisa', (tester) async {
      await montar(tester, yaTiene: true);

      expect(
        find.text('Ya tiene una foto: elige otra para reemplazarla.'),
        findsOneWidget,
      );
    });
  });

  group('editor de eventos: foto', () {
    Future<void> abrir(
      WidgetTester tester,
      _EventoApiFalsa api,
      _SelectorFalso selector,
      List<Evento?> resultado,
    ) async {
      _pantallaGrande(tester);
      await montarApp(
        tester,
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado.add(
                  await Navigator.of(context).push<Evento>(
                    MaterialPageRoute<Evento>(
                      builder: (_) => EditorEventoScreen(
                        api: api,
                        evento: _evento(),
                        mapaBuilder: _mapaVacio,
                        ahora: () => DateTime(2030, 5, 1, 9),
                        selectorFoto: selector,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('la foto elegida se sube despues de guardar, con el id del evento', (
      tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      final List<Evento?> resultado = <Evento?>[];
      await abrir(tester, api, _SelectorFalso(_png), resultado);

      await tester.ensureVisible(find.byKey(const ValueKey<String>('foto-galeria')));
      await tester.tap(find.byKey(const ValueKey<String>('foto-galeria')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
      await tester.pumpAndSettle();

      expect(api.fotosSubidas, hasLength(1));
      expect(api.fotosSubidas.single.id, 7);
      expect(api.fotosSubidas.single.bytes, _png);
      // El editor entrega el evento que dejo el servidor tras subir la foto.
      expect(resultado.single!.conFoto, isTrue);
    });

    testWidgets('sin elegir foto no se sube nada', (tester) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      final List<Evento?> resultado = <Evento?>[];
      await abrir(tester, api, _SelectorFalso(null), resultado);

      await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
      await tester.pumpAndSettle();

      expect(api.fotosSubidas, isEmpty);
      expect(resultado.single, isNotNull);
    });

    testWidgets('si la foto no sube, el evento igual se guarda y se avisa', (
      tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa()
        ..errorAlSubir = ApiException(500, 'boom');
      final List<Evento?> resultado = <Evento?>[];
      await abrir(tester, api, _SelectorFalso(_png), resultado);

      await tester.ensureVisible(find.byKey(const ValueKey<String>('foto-galeria')));
      await tester.tap(find.byKey(const ValueKey<String>('foto-galeria')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('guardar-evento')));
      await tester.pumpAndSettle();

      expect(resultado.single, isNotNull);
      expect(api.fotosSubidas, isEmpty);
    });
  });

  group('se ve la foto en el detalle', () {
    testWidgets('ruta con foto: la baja por su id y la muestra', (tester) async {
      _pantallaGrande(tester);
      final _RutaApiFalsa api = _RutaApiFalsa();
      await montarApp(
        tester,
        RutaDetalleScreen(
          ruta: _ruta(conFoto: true),
          api: api,
          calificaciones: CalificacionApiFalsa(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('foto-ruta')), findsOneWidget);
      expect(api.fotosPedidas, <int>[5]);
    });

    testWidgets('ruta sin foto: no pide ni muestra nada', (tester) async {
      _pantallaGrande(tester);
      final _RutaApiFalsa api = _RutaApiFalsa();
      await montarApp(
        tester,
        RutaDetalleScreen(
          ruta: _ruta(),
          api: api,
          calificaciones: CalificacionApiFalsa(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('foto-ruta')), findsNothing);
      expect(api.fotosPedidas, isEmpty);
    });

    testWidgets('tocar la foto de la ruta la abre a pantalla completa', (
      tester,
    ) async {
      _pantallaGrande(tester);
      await montarApp(
        tester,
        RutaDetalleScreen(
          ruta: _ruta(conFoto: true),
          api: _RutaApiFalsa(),
          calificaciones: CalificacionApiFalsa(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('foto-ruta')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('visor-imagen')), findsOneWidget);
    });

    testWidgets('ficha de evento con foto: la baja y la muestra', (tester) async {
      _pantallaGrande(tester);
      final _EventoApiFalsa api = _EventoApiFalsa();
      await montarApp(
        tester,
        Scaffold(
          body: FichaEvento(
            evento: _evento(conFoto: true),
            api: api,
            calificaciones: CalificacionApiFalsa(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('foto-evento')), findsOneWidget);
      expect(api.fotosPedidas, <int>[7]);
    });

    testWidgets('detalle de evento con foto: la muestra y se abre grande', (
      tester,
    ) async {
      _pantallaGrande(tester);
      await montarApp(
        tester,
        EventoDetalleScreen(
          evento: _evento(conFoto: true),
          api: _EventoApiFalsa(),
          ahora: () => DateTime(2030, 1, 1),
          mapaBuilder: (BuildContext _) => const SizedBox.shrink(),
          calificaciones: CalificacionApiFalsa(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('foto-evento')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('visor-imagen')), findsOneWidget);
    });

    testWidgets('evento sin foto: no pide nada', (tester) async {
      _pantallaGrande(tester);
      final _EventoApiFalsa api = _EventoApiFalsa();
      await montarApp(
        tester,
        Scaffold(
          body: FichaEvento(
            evento: _evento(),
            api: api,
            calificaciones: CalificacionApiFalsa(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('foto-evento')), findsNothing);
      expect(api.fotosPedidas, isEmpty);
    });
  });
}
