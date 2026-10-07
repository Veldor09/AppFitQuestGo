import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/formulario_nodo_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mis_nodos_screen.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/ficha_nodo.dart';

import 'helpers/montar.dart';

Map<String, dynamic> _json([
  Map<String, dynamic> extra = const <String, dynamic>{},
]) {
  return <String, dynamic>{
    'id': 8,
    'nombre': 'Cafe El Roble',
    'categoria': 'restaurante',
    'lat': 9.93,
    'lng': -84.09,
    'estado': 'Aprobado',
    'descripcion': null,
    'beneficio': '10% de descuento',
    'patrocinado': true,
    'creadoPor': <String, dynamic>{'id': 20, 'nombreUser': 'Cafe El Roble'},
    ...extra,
  };
}

Nodo _nodo({
  int id = 8,
  String nombre = 'Cafe El Roble',
  String? beneficio = '10% de descuento',
  bool patrocinado = true,
  String categoria = 'restaurante',
}) => Nodo(
  id: id,
  nombre: nombre,
  categoria: categoria,
  lat: 9.93,
  lng: -84.09,
  estado: 'Aprobado',
  beneficio: beneficio,
  patrocinado: patrocinado,
  creadoPorNombre: 'Cafe El Roble',
  creadoPorId: 20,
);

class _NodoApiFalsa extends NodoApi {
  _NodoApiFalsa({this.propios = const <Nodo>[]});

  List<Nodo> propios;
  Object? error;
  int listados = 0;
  final List<Map<String, Object?>> propuestos = <Map<String, Object?>>[];
  final List<Map<String, Object?>> actualizados = <Map<String, Object?>>[];
  final List<int> eliminados = <int>[];

  @override
  Future<List<Nodo>> misNodos() async {
    listados++;
    if (error != null) throw error!;
    return propios;
  }

  @override
  Future<Nodo> proponer({
    required String nombre,
    required String categoria,
    String? categoriaOtro,
    required double lat,
    required double lng,
    String? descripcion,
    String? beneficio,
  }) async {
    if (error != null) throw error!;
    propuestos.add(<String, Object?>{
      'nombre': nombre,
      'categoria': categoria,
      'categoriaOtro': categoriaOtro,
      'lat': lat,
      'lng': lng,
      'descripcion': descripcion,
      'beneficio': beneficio,
    });
    return _nodo(id: 50, nombre: nombre, beneficio: beneficio);
  }

  @override
  Future<Nodo> actualizar(
    int id, {
    required String nombre,
    required String categoria,
    String? categoriaOtro,
    required double lat,
    required double lng,
    String? descripcion,
    String? beneficio,
  }) async {
    if (error != null) throw error!;
    actualizados.add(<String, Object?>{
      'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'lat': lat,
      'lng': lng,
      'beneficio': beneficio,
    });
    return _nodo(id: id, nombre: nombre, beneficio: beneficio);
  }

  @override
  Future<void> eliminar(int id) async {
    if (error != null) throw error!;
    eliminados.add(id);
    propios = <Nodo>[
      for (final Nodo n in propios)
        if (n.id != id) n,
    ];
  }
}

/// Selector falso: un boton que "toca" el mapa en un lugar fijo.
Widget _selectorFalso(
  BuildContext _,
  ({double lat, double lng})? inicial,
  void Function(double lat, double lng) onCambio,
) {
  return Column(
    children: <Widget>[
      Text(
        inicial == null
            ? 'sin-ubicacion'
            : 'inicial:${inicial.lat},${inicial.lng}',
      ),
      TextButton(
        key: const ValueKey<String>('marcar-local'),
        onPressed: () => onCambio(9.95, -84.12),
        child: const Text('marcar'),
      ),
    ],
  );
}

Future<Nodo?> _abrirFormulario(
  WidgetTester tester,
  _NodoApiFalsa api, {
  Nodo? nodo,
}) async {
  Nodo? resultado;
  await montarApp(
    tester,
    Builder(
      builder: (BuildContext context) => TextButton(
        onPressed: () async {
          resultado = await Navigator.of(context).push<Nodo>(
            MaterialPageRoute<Nodo>(
              builder: (_) => FormularioNodoEmpresaScreen(
                api: api,
                nodo: nodo,
                selectorBuilder: _selectorFalso,
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

Future<void> _tocar(WidgetTester tester, String clave) async {
  final Finder f = find.byKey(ValueKey<String>(clave));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pump();
}

Future<void> _guardar(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey<String>('guardar-nodo-empresa')),
  );
  await tester.tap(find.byKey(const ValueKey<String>('guardar-nodo-empresa')));
  await tester.pumpAndSettle();
}

void main() {
  group('Nodo y NodoApi (modulo 5)', () {
    test('Nodo.fromJson lee el beneficio y si es patrocinado', () {
      final Nodo n = Nodo.fromJson(_json());
      expect(n.beneficio, '10% de descuento');
      expect(n.patrocinado, isTrue);
    });

    test('un nodo sin esos campos (punto comun) no es patrocinado', () {
      final Nodo n = Nodo.fromJson(
        _json(<String, dynamic>{'beneficio': null, 'patrocinado': null}),
      );
      expect(n.beneficio, isNull);
      expect(n.patrocinado, isFalse);
    });

    test('proponer envia el beneficio solo si hay texto', () async {
      final List<Peticion> reg = <Peticion>[];
      final NodoApi api = NodoApi(
        apiFalso(reg, (Peticion _) => (cuerpo: _json(), estado: 201)),
      );
      await api.proponer(
        nombre: 'X',
        categoria: 'agua',
        lat: 1,
        lng: 2,
        beneficio: '  2x1  ',
      );
      expect(reg.last.cuerpo?['beneficio'], '2x1');

      await api.proponer(
        nombre: 'X',
        categoria: 'agua',
        lat: 1,
        lng: 2,
        beneficio: '   ',
      );
      expect(reg.last.cuerpo?.containsKey('beneficio'), isFalse);
    });

    test(
      'actualizar usa PATCH /nodos/:id y manda el formulario completo',
      () async {
        final List<Peticion> reg = <Peticion>[];
        final NodoApi api = NodoApi(
          apiFalso(reg, (Peticion _) => (cuerpo: _json(), estado: 200)),
        );
        await api.actualizar(
          8,
          nombre: 'Nuevo',
          categoria: 'taller',
          lat: 1,
          lng: 2,
          descripcion: null,
          beneficio: '',
        );
        expect(reg.single.toString(), 'PATCH /nodos/8');
        // Vacio, no ausente: asi el servidor sabe que hay que borrarlos.
        expect(reg.single.cuerpo?['descripcion'], '');
        expect(reg.single.cuerpo?['beneficio'], '');
        expect(reg.single.cuerpo?['nombre'], 'Nuevo');
      },
    );

    test('eliminar usa DELETE /nodos/:id', () async {
      final List<Peticion> reg = <Peticion>[];
      final NodoApi api = NodoApi(
        apiFalso(reg, (Peticion _) => (cuerpo: null, estado: 204)),
      );
      await api.eliminar(8);
      expect(reg.single.toString(), 'DELETE /nodos/8');
    });
  });

  group('FormularioNodoEmpresaScreen', () {
    testWidgets('vacio no guarda y marca lo que falta', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa();
      await _abrirFormulario(tester, api);
      await _guardar(tester);

      expect(api.propuestos, isEmpty);
      expect(find.text('Revisa los campos marcados en rojo'), findsOneWidget);
      expect(find.text('Elegi una categoria'), findsOneWidget);
    });

    testWidgets('sin marcar el local en el mapa no guarda', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa();
      await _abrirFormulario(tester, api);
      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-nombre-nodo')),
        'Cafe El Roble',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('opcion-restaurante')),
      );
      await tester.pump();
      await _guardar(tester);

      expect(api.propuestos, isEmpty);
      expect(find.text('Toca el mapa para marcar tu local'), findsOneWidget);
    });

    testWidgets('crear: nombre, categoria, beneficio y ubicacion del mapa', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa();
      await _abrirFormulario(tester, api);

      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-nombre-nodo')),
        '  Cafe El Roble  ',
      );
      await _tocar(tester, 'opcion-restaurante');
      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-beneficio-nodo')),
        '10% de descuento',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('marcar-local')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('marcar-local')));
      await tester.pump();
      expect(find.text('9.95000, -84.12000'), findsOneWidget);

      await _guardar(tester);

      expect(api.propuestos, hasLength(1));
      final Map<String, Object?> enviado = api.propuestos.single;
      expect(enviado['nombre'], 'Cafe El Roble');
      expect(enviado['categoria'], 'restaurante');
      expect(enviado['lat'], 9.95);
      expect(enviado['lng'], -84.12);
      expect(enviado['beneficio'], '10% de descuento');
      expect(find.byType(FormularioNodoEmpresaScreen), findsNothing);
      expect(find.text('Nodo publicado'), findsOneWidget);
    });

    testWidgets('la categoria "otro" pide decir cual', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa();
      await _abrirFormulario(tester, api);
      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-nombre-nodo')),
        'Mi local',
      );
      await _tocar(tester, 'opcion-otro');
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('marcar-local')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('marcar-local')));
      await tester.pump();
      await _guardar(tester);

      expect(api.propuestos, isEmpty);
      expect(find.text('Obligatorio'), findsWidgets);
    });

    testWidgets('editar: arranca con los datos, ubicacion incluida', (
      WidgetTester tester,
    ) async {
      await _abrirFormulario(tester, _NodoApiFalsa(), nodo: _nodo());

      expect(find.text('Editar nodo'), findsOneWidget);
      expect(find.text('Cafe El Roble'), findsOneWidget);
      expect(find.text('10% de descuento'), findsOneWidget);
      expect(find.text('inicial:9.93,-84.09'), findsOneWidget);
    });

    testWidgets('editar: guardar llama a actualizar con el id', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa();
      await _abrirFormulario(tester, api, nodo: _nodo());
      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-beneficio-nodo')),
        '2x1 en cafe',
      );
      await _guardar(tester);

      expect(api.propuestos, isEmpty);
      expect(api.actualizados, hasLength(1));
      expect(api.actualizados.single['id'], 8);
      expect(api.actualizados.single['beneficio'], '2x1 en cafe');
      expect(api.actualizados.single['lat'], 9.93); // no la movio
    });

    testWidgets('un error del servidor se muestra y no cierra la pantalla', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa()
        ..error = ApiException(403, 'Este nodo no te pertenece');
      await _abrirFormulario(tester, api, nodo: _nodo());
      await _guardar(tester);

      expect(find.text('Este nodo no te pertenece'), findsOneWidget);
      expect(find.byType(FormularioNodoEmpresaScreen), findsOneWidget);
    });
  });

  group('MisNodosScreen', () {
    testWidgets('lista sus nodos con el beneficio de cada uno', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa(
        propios: <Nodo>[
          _nodo(),
          _nodo(
            id: 9,
            nombre: 'Taller Bici',
            beneficio: null,
            categoria: 'taller',
          ),
        ],
      );
      await montarApp(tester, MisNodosScreen(api: api));
      await tester.pumpAndSettle();

      expect(find.text('Cafe El Roble'), findsOneWidget);
      expect(find.text('10% de descuento'), findsOneWidget);
      expect(find.text('Taller Bici'), findsOneWidget);
      expect(find.text('Sin cupon ni beneficio'), findsOneWidget);
      expect(find.text('PUBLICADO'), findsNWidgets(2));
    });

    testWidgets('sin nodos invita a publicar el local', (
      WidgetTester tester,
    ) async {
      await montarApp(tester, MisNodosScreen(api: _NodoApiFalsa()));
      await tester.pumpAndSettle();

      expect(find.text('Aun no tienes nodos'), findsOneWidget);
    });

    testWidgets('"Nuevo nodo" abre el formulario vacio', (
      WidgetTester tester,
    ) async {
      Nodo? recibido = _nodo();
      await montarApp(
        tester,
        MisNodosScreen(
          api: _NodoApiFalsa(),
          formularioBuilder: (BuildContext _, Nodo? n) {
            recibido = n;
            return const Scaffold(body: Text('formulario-falso'));
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('nuevo-nodo')));
      await tester.pumpAndSettle();

      expect(find.text('formulario-falso'), findsOneWidget);
      expect(recibido, isNull);
    });

    testWidgets('tocar un nodo lo abre para editar', (
      WidgetTester tester,
    ) async {
      Nodo? recibido;
      await montarApp(
        tester,
        MisNodosScreen(
          api: _NodoApiFalsa(propios: <Nodo>[_nodo()]),
          formularioBuilder: (BuildContext _, Nodo? n) {
            recibido = n;
            return const Scaffold(body: Text('formulario-falso'));
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cafe El Roble'));
      await tester.pumpAndSettle();

      expect(recibido?.id, 8);
    });

    testWidgets('eliminar pide confirmacion y luego lo da de baja', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa(propios: <Nodo>[_nodo()]);
      await montarApp(tester, MisNodosScreen(api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('eliminar-nodo-8')));
      await tester.pumpAndSettle();
      expect(api.eliminados, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('confirmar-eliminar')),
      );
      await tester.pumpAndSettle();

      expect(api.eliminados, <int>[8]);
      expect(find.text('Cafe El Roble'), findsNothing);
      expect(find.text('Nodo eliminado'), findsOneWidget);
    });

    testWidgets('si falla la carga ofrece reintentar', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa(propios: <Nodo>[_nodo()])
        ..error = ApiException(500, 'caido');
      await montarApp(tester, MisNodosScreen(api: api));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo cargar'), findsOneWidget);

      api.error = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Cafe El Roble'), findsOneWidget);
    });
  });

  group('FichaNodo de un nodo patrocinado', () {
    Future<void> abrir(WidgetTester tester, Nodo nodo) async {
      await montarApp(
        tester,
        Scaffold(
          body: FichaNodo(nodo: nodo, api: NodoApi()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra el beneficio destacado y quien lo patrocina', (
      WidgetTester tester,
    ) async {
      await abrir(tester, _nodo());

      expect(
        find.byKey(const ValueKey<String>('ficha-beneficio')),
        findsOneWidget,
      );
      expect(find.text('10% de descuento'), findsOneWidget);
      expect(find.text('Beneficio para ti'), findsOneWidget);
      expect(
        find.textContaining('Patrocinado por Cafe El Roble'),
        findsOneWidget,
      );
    });

    testWidgets('un punto comun no muestra beneficio y dice "propuesto por"', (
      WidgetTester tester,
    ) async {
      await abrir(tester, _nodo(patrocinado: false, beneficio: null));

      expect(
        find.byKey(const ValueKey<String>('ficha-beneficio')),
        findsNothing,
      );
      expect(find.textContaining('Patrocinado'), findsNothing);
    });

    testWidgets('un beneficio en blanco no dibuja la caja', (
      WidgetTester tester,
    ) async {
      await abrir(tester, _nodo(beneficio: '   '));

      expect(
        find.byKey(const ValueKey<String>('ficha-beneficio')),
        findsNothing,
      );
    });
  });
}
