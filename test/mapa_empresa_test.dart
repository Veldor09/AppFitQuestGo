import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mapa_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

import 'helpers/montar.dart';

const int _yo = 20;
const int _otraEmpresa = 21;

const List<PuntoGeo> _triangulo = <PuntoGeo>[
  PuntoGeo(lat: 10, lng: -84),
  PuntoGeo(lat: 10.001, lng: -84),
  PuntoGeo(lat: 10.001, lng: -84.001),
];
const List<PuntoGeo> _linea = <PuntoGeo>[
  PuntoGeo(lat: 10, lng: -84),
  PuntoGeo(lat: 10.002, lng: -84.002),
];

Evento _evento(
  int id,
  String nombre, {
  int dueno = _yo,
  int areas = 1,
  int recorridos = 0,
}) => Evento(
  id: id,
  nombre: nombre,
  categoria: 'caminata',
  fechaInicio: DateTime(2030, 5, 10, 8),
  fechaFin: DateTime(2030, 5, 10, 11),
  areas: <ZonaEvento>[
    for (int i = 0; i < areas; i++)
      ZonaEvento(nombre: '$nombre area ${i + 1}', puntos: _triangulo),
  ],
  recorridos: <ZonaEvento>[
    for (int i = 0; i < recorridos; i++)
      ZonaEvento(nombre: '$nombre recorrido ${i + 1}', puntos: _linea),
  ],
  creadoPorId: dueno,
  creadoPorNombre: dueno == _yo ? 'Mi empresa' : 'Otra empresa',
);

Nodo _nodo(int id, {int dueno = _yo, double lat = 9.5}) => Nodo(
  id: id,
  nombre: 'Nodo $id',
  categoria: 'agua',
  lat: lat,
  lng: -84.1,
  estado: 'Aprobado',
  creadoPorId: dueno,
  patrocinado: true,
);

class _EventoApiFalsa extends EventoApi {
  List<Evento> propios = <Evento>[];
  List<Evento> todos = <Evento>[];
  Object? errorMios;
  Object? errorListar;
  int llamadasMios = 0;
  int llamadasListar = 0;

  @override
  Future<List<Evento>> mios() async {
    llamadasMios++;
    if (errorMios != null) throw errorMios!;
    return propios;
  }

  @override
  Future<List<Evento>> listar() async {
    llamadasListar++;
    if (errorListar != null) throw errorListar!;
    return todos;
  }
}

class _NodoApiFalsa extends NodoApi {
  List<Nodo> nodos = <Nodo>[];
  Object? error;

  @override
  Future<List<Nodo>> listar() async {
    if (error != null) throw error!;
    return nodos;
  }
}

/// Lo que el mapa de la empresa le paso al mapa.
class _Captura {
  List<ZonaEvento> areas = const <ZonaEvento>[];
  List<ZonaEvento> recorridos = const <ZonaEvento>[];
  List<ZonaEvento> areasOtras = const <ZonaEvento>[];
  List<ZonaEvento> recorridosOtros = const <ZonaEvento>[];
  List<PuntoGeo> pines = const <PuntoGeo>[];
}

Widget _mapaFalso(
  _Captura c,
  BuildContext _,
  List<ZonaEvento> areas,
  List<ZonaEvento> recorridos,
  List<ZonaEvento> areasOtras,
  List<ZonaEvento> recorridosOtros,
  List<PuntoGeo> pines,
) {
  c.areas = areas;
  c.recorridos = recorridos;
  c.areasOtras = areasOtras;
  c.recorridosOtros = recorridosOtros;
  c.pines = pines;
  return Align(
    alignment: Alignment.bottomLeft,
    child: Text(
      'areas:${areas.length} rec:${recorridos.length} '
      'otras:${areasOtras.length}/${recorridosOtros.length} pines:${pines.length}',
    ),
  );
}

Future<_Captura> _abrir(
  WidgetTester tester, {
  required _EventoApiFalsa eventos,
  _NodoApiFalsa? nodos,
  ValueNotifier<int>? senal,
  WidgetBuilder? editor,
}) async {
  final _Captura captura = _Captura();
  await montarApp(
    tester,
    MapaEmpresaScreen(
      eventoApi: eventos,
      nodoApi: nodos ?? _NodoApiFalsa(),
      senal: senal,
      editorBuilder: editor,
      mapaBuilder: (BuildContext c, a, r, ao, ro, p) =>
          _mapaFalso(captura, c, a, r, ao, ro, p),
    ),
    auth: AuthFalso(
      usuario: const UsuarioSesion(
        id: _yo,
        nombre: 'Mi empresa',
        email: 'yo@x.co',
        rol: RolUsuario.empresa,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captura;
}

Finder _clave(String c) => find.byKey(ValueKey<String>(c));

void main() {
  group('lo que dibuja', () {
    testWidgets('todas las areas y recorridos de los eventos de la empresa', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa()
        ..propios = <Evento>[
          _evento(1, 'Caminata', areas: 2, recorridos: 1),
          _evento(2, 'Carrera', areas: 1, recorridos: 2),
        ];
      final _Captura c = await _abrir(tester, eventos: api);

      expect(c.areas, hasLength(3));
      expect(c.recorridos, hasLength(3));
      expect(find.text('Tus eventos en el mapa: 2'), findsOneWidget);
    });

    testWidgets('incluye tambien los eventos ya terminados', (
      WidgetTester tester,
    ) async {
      final Evento viejo = Evento(
        id: 9,
        nombre: 'Viejo',
        categoria: 'carrera',
        fechaInicio: DateTime(2020),
        fechaFin: DateTime(2020, 1, 2),
        areas: const <ZonaEvento>[ZonaEvento(nombre: 'A', puntos: _triangulo)],
        recorridos: const <ZonaEvento>[],
        creadoPorId: _yo,
      );
      final _EventoApiFalsa api = _EventoApiFalsa()..propios = <Evento>[viejo];
      final _Captura c = await _abrir(tester, eventos: api);

      expect(c.areas, hasLength(1));
    });

    testWidgets(
      'por defecto NO dibuja nada de otras empresas ni pide sus eventos',
      (WidgetTester tester) async {
        final _EventoApiFalsa api = _EventoApiFalsa()
          ..propios = <Evento>[_evento(1, 'Mio')]
          ..todos = <Evento>[
            _evento(1, 'Mio'),
            _evento(2, 'Ajeno', dueno: _otraEmpresa),
          ];
        final _Captura c = await _abrir(tester, eventos: api);

        expect(c.areasOtras, isEmpty);
        expect(c.recorridosOtros, isEmpty);
        expect(api.llamadasListar, 0);
      },
    );

    testWidgets('siempre dibuja sus propios nodos, no los de otras empresas', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      final _NodoApiFalsa nodos = _NodoApiFalsa()
        ..nodos = <Nodo>[
          _nodo(1, lat: 9.1),
          _nodo(2, dueno: _otraEmpresa, lat: 9.2),
        ];
      final _Captura c = await _abrir(tester, eventos: api, nodos: nodos);

      expect(c.pines, <PuntoGeo>[const PuntoGeo(lat: 9.1, lng: -84.1)]);
    });
  });

  group('"Ver otras empresas"', () {
    testWidgets(
      'suma en gris los eventos de las demas empresas, sin repetir los propios',
      (WidgetTester tester) async {
        final _EventoApiFalsa api = _EventoApiFalsa()
          ..propios = <Evento>[_evento(1, 'Mio')]
          ..todos = <Evento>[
            _evento(1, 'Mio'),
            _evento(2, 'Ajeno', dueno: _otraEmpresa, areas: 2, recorridos: 1),
          ];
        final _Captura c = await _abrir(tester, eventos: api);

        await tester.tap(_clave('ver-otras-empresas'));
        await tester.pumpAndSettle();

        expect(c.areasOtras, hasLength(2));
        expect(c.recorridosOtros, hasLength(1));
        expect(c.areas, hasLength(1)); // los propios siguen igual
        expect(find.text('Otras empresas'), findsOneWidget); // leyenda
      },
    );

    testWidgets('tambien suma los nodos de las otras empresas', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa nodos = _NodoApiFalsa()
        ..nodos = <Nodo>[_nodo(1), _nodo(2, dueno: _otraEmpresa)];
      final _Captura c = await _abrir(
        tester,
        eventos: _EventoApiFalsa(),
        nodos: nodos,
      );
      expect(c.pines, hasLength(1));

      await tester.tap(_clave('ver-otras-empresas'));
      await tester.pumpAndSettle();

      expect(c.pines, hasLength(2));
    });

    testWidgets('apagarlo las vuelve a quitar', (WidgetTester tester) async {
      final _EventoApiFalsa api = _EventoApiFalsa()
        ..todos = <Evento>[_evento(2, 'Ajeno', dueno: _otraEmpresa)];
      final _Captura c = await _abrir(tester, eventos: api);

      await tester.tap(_clave('ver-otras-empresas'));
      await tester.pumpAndSettle();
      expect(c.areasOtras, hasLength(1));

      await tester.tap(_clave('ver-otras-empresas'));
      await tester.pumpAndSettle();
      expect(c.areasOtras, isEmpty);
      expect(find.text('Otras empresas'), findsNothing);
    });

    testWidgets('si falla pedir las de otras empresas, los propios siguen', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa()
        ..propios = <Evento>[_evento(1, 'Mio')]
        ..errorListar = ApiException(500, 'caido');
      final _Captura c = await _abrir(tester, eventos: api);

      await tester.tap(_clave('ver-otras-empresas'));
      await tester.pumpAndSettle();

      expect(c.areas, hasLength(1));
      expect(c.areasOtras, isEmpty);
    });
  });

  group('estados', () {
    testWidgets('sin eventos invita a crear el primero', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, eventos: _EventoApiFalsa());

      expect(_clave('mapa-vacio'), findsOneWidget);
      expect(find.text('Aun no tienes eventos'), findsOneWidget);
      expect(find.text('Tus eventos en el mapa: 0'), findsOneWidget);
    });

    testWidgets('con eventos no muestra el aviso de vacio', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa()
        ..propios = <Evento>[_evento(1, 'Mio')];
      await _abrir(tester, eventos: api);

      expect(_clave('mapa-vacio'), findsNothing);
    });

    testWidgets(
      'si falla la carga lo dice, no muestra "vacio" y deja reintentar',
      (WidgetTester tester) async {
        final _EventoApiFalsa api = _EventoApiFalsa()
          ..errorMios = ApiException(500, 'caido');
        await _abrir(tester, eventos: api);

        expect(find.text('No se pudieron cargar tus eventos'), findsOneWidget);
        expect(_clave('mapa-vacio'), findsNothing);

        api.errorMios = null;
        api.propios = <Evento>[_evento(1, 'Mio')];
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(find.text('Tus eventos en el mapa: 1'), findsOneWidget);
      },
    );

    testWidgets('si fallan los nodos, el mapa muestra igual los eventos', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa()
        ..propios = <Evento>[_evento(1, 'Mio')];
      final _NodoApiFalsa nodos = _NodoApiFalsa()
        ..error = ApiException(500, 'caido');
      final _Captura c = await _abrir(tester, eventos: api, nodos: nodos);

      expect(c.areas, hasLength(1));
      expect(c.pines, isEmpty);
      expect(find.text('No se pudieron cargar tus eventos'), findsNothing);
    });
  });

  group('Nuevo evento', () {
    testWidgets('el boton existe en el mapa', (WidgetTester tester) async {
      await _abrir(tester, eventos: _EventoApiFalsa());

      expect(_clave('nuevo-evento-mapa'), findsOneWidget);
      expect(find.text('Nuevo evento'), findsOneWidget);
    });

    testWidgets('abre el editor', (WidgetTester tester) async {
      await _abrir(
        tester,
        eventos: _EventoApiFalsa(),
        editor: (BuildContext _) => const Scaffold(body: Text('editor-falso')),
      );

      await tester.tap(_clave('nuevo-evento-mapa'));
      await tester.pumpAndSettle();

      expect(find.text('editor-falso'), findsOneWidget);
    });

    testWidgets('al guardar recarga el mapa y se ve el evento nuevo', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await _abrir(
        tester,
        eventos: api,
        editor: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(ctx).pop(_evento(5, 'Nuevo')),
            child: const Text('guardar-falso'),
          ),
        ),
      );
      expect(find.text('Tus eventos en el mapa: 0'), findsOneWidget);

      api.propios = <Evento>[_evento(5, 'Nuevo')];
      await tester.tap(_clave('nuevo-evento-mapa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('guardar-falso'));
      await tester.pumpAndSettle();

      expect(api.llamadasMios, 2);
      expect(find.text('Tus eventos en el mapa: 1'), findsOneWidget);
    });

    testWidgets(
      'con señal compartida avisa a las demas pantallas en vez de recargar solo',
      (WidgetTester tester) async {
        final _EventoApiFalsa api = _EventoApiFalsa();
        final ValueNotifier<int> senal = ValueNotifier<int>(0);
        addTearDown(senal.dispose);
        await _abrir(
          tester,
          eventos: api,
          senal: senal,
          editor: (BuildContext ctx) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(ctx).pop(_evento(5, 'Nuevo')),
              child: const Text('guardar-falso'),
            ),
          ),
        );

        await tester.tap(_clave('nuevo-evento-mapa'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('guardar-falso'));
        await tester.pumpAndSettle();

        expect(senal.value, 1);
        // La señal la escucha esta misma pantalla: recarga una sola vez.
        expect(api.llamadasMios, 2);
      },
    );

    testWidgets('cancelar el editor no recarga ni avisa', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      final ValueNotifier<int> senal = ValueNotifier<int>(0);
      addTearDown(senal.dispose);
      await _abrir(
        tester,
        eventos: api,
        senal: senal,
        editor: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('cancelar-falso'),
          ),
        ),
      );

      await tester.tap(_clave('nuevo-evento-mapa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cancelar-falso'));
      await tester.pumpAndSettle();

      expect(senal.value, 0);
      expect(api.llamadasMios, 1);
    });
  });

  testWidgets(
    'una señal externa (se creo/borro un evento en otra pestaña) recarga el mapa',
    (WidgetTester tester) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      final ValueNotifier<int> senal = ValueNotifier<int>(0);
      addTearDown(senal.dispose);
      await _abrir(tester, eventos: api, senal: senal);
      expect(find.text('Tus eventos en el mapa: 0'), findsOneWidget);

      api.propios = <Evento>[_evento(1, 'Creado en la otra pestana')];
      senal.value++;
      await tester.pumpAndSettle();

      expect(find.text('Tus eventos en el mapa: 1'), findsOneWidget);
    },
  );
}
