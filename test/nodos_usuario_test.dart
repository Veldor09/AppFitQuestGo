import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/empresa/presentation/formulario_nodo_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mis_nodos_screen.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/user_nav_bar.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

import 'helpers/montar.dart';

Nodo _nodo(
  int id,
  String nombre,
  String estado, {
  String categoria = 'agua',
  String? descripcion,
}) => Nodo(
  id: id,
  nombre: nombre,
  categoria: categoria,
  lat: 9.93,
  lng: -84.09,
  estado: estado,
  descripcion: descripcion,
  creadoPorNombre: 'Ana',
  creadoPorId: 7,
);

class _NodoApiFalsa extends NodoApi {
  _NodoApiFalsa({this.propios = const <Nodo>[]});

  List<Nodo> propios;
  int eliminados = 0;
  final List<Map<String, Object?>> propuestos = <Map<String, Object?>>[];

  @override
  Future<List<Nodo>> misNodos() async => propios;

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
    propuestos.add(<String, Object?>{
      'nombre': nombre,
      'categoria': categoria,
      'lat': lat,
      'lng': lng,
      'descripcion': descripcion,
      'beneficio': beneficio,
    });
    return _nodo(99, nombre, 'Pendiente', categoria: categoria);
  }

  @override
  Future<void> eliminar(int id) async {
    eliminados++;
  }
}

Widget _selectorFalso(
  BuildContext _,
  ({double lat, double lng})? inicial,
  void Function(double lat, double lng) onCambio,
) {
  return TextButton(
    key: const ValueKey<String>('marcar-local'),
    onPressed: () => onCambio(9.95, -84.12),
    child: const Text('marcar'),
  );
}

Finder _clave(String c) => find.byKey(ValueKey<String>(c));

void main() {
  group('MisNodosScreen para el deportista', () {
    testWidgets('muestra el titulo y el subtitulo de sus propios nodos', (
      WidgetTester tester,
    ) async {
      await montarApp(
        tester,
        MisNodosScreen(modo: ModoNodos.usuario, api: _NodoApiFalsa()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis nodos'), findsOneWidget);
      expect(find.text('Los puntos de interes que publicaste'), findsOneWidget);
      expect(find.text('Publicar nodo'), findsOneWidget);
    });

    testWidgets(
      'cada nodo muestra en que va: en revision, aprobado, rechazado, obsoleto',
      (WidgetTester tester) async {
        final _NodoApiFalsa api = _NodoApiFalsa(
          propios: <Nodo>[
            _nodo(1, 'Fuente nueva', 'Pendiente'),
            _nodo(2, 'Mirador', 'Aprobado'),
            _nodo(3, 'Punto raro', 'Rechazado'),
            _nodo(4, 'Taller cerrado', 'Obsoleto'),
          ],
        );
        await montarApp(
          tester,
          MisNodosScreen(modo: ModoNodos.usuario, api: api),
        );
        await tester.pumpAndSettle();

        expect(find.text('EN REVISION'), findsOneWidget);
        expect(find.text('APROBADO'), findsOneWidget);
        expect(find.text('RECHAZADO'), findsOneWidget);
        expect(find.text('OBSOLETO'), findsOneWidget);
        // Es un punto propuesto, no un negocio publicado.
        expect(find.text('PUBLICADO'), findsNothing);
      },
    );

    testWidgets('no muestra beneficio ni deja eliminar', (
      WidgetTester tester,
    ) async {
      await montarApp(
        tester,
        MisNodosScreen(
          modo: ModoNodos.usuario,
          api: _NodoApiFalsa(propios: <Nodo>[_nodo(1, 'Fuente', 'Aprobado')]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin cupon ni beneficio'), findsNothing);
      expect(_clave('eliminar-nodo-1'), findsNothing);
    });

    testWidgets(
      'tocar un nodo abre su ficha (solo lectura), no el formulario',
      (WidgetTester tester) async {
        await montarApp(
          tester,
          MisNodosScreen(
            modo: ModoNodos.usuario,
            api: _NodoApiFalsa(
              propios: <Nodo>[
                _nodo(
                  1,
                  'Fuente',
                  'Aprobado',
                  descripcion: 'Agua fria todo el dia',
                ),
              ],
            ),
            formularioBuilder: (BuildContext _, Nodo? n) =>
                const Scaffold(body: Text('formulario-falso')),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Fuente'));
        await tester.pumpAndSettle();

        expect(find.text('formulario-falso'), findsNothing);
        expect(find.text('Agua fria todo el dia'), findsOneWidget);
      },
    );

    testWidgets('sin nodos explica que se publican de inmediato', (
      WidgetTester tester,
    ) async {
      await montarApp(
        tester,
        MisNodosScreen(modo: ModoNodos.usuario, api: _NodoApiFalsa()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aun no publicas nodos'), findsOneWidget);
      expect(find.textContaining('Se publica de inmediato'), findsOneWidget);
    });

    testWidgets('"Publicar nodo" abre el formulario vacio', (
      WidgetTester tester,
    ) async {
      Nodo? recibido = _nodo(1, 'x', 'Aprobado');
      await montarApp(
        tester,
        MisNodosScreen(
          modo: ModoNodos.usuario,
          api: _NodoApiFalsa(),
          formularioBuilder: (BuildContext _, Nodo? n) {
            recibido = n;
            return const Scaffold(body: Text('formulario-falso'));
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_clave('nuevo-nodo'));
      await tester.pumpAndSettle();

      expect(find.text('formulario-falso'), findsOneWidget);
      expect(recibido, isNull);
    });

    testWidgets(
      'la empresa, en cambio, sigue viendo "Publicado" y puede eliminar',
      (WidgetTester tester) async {
        await montarApp(
          tester,
          MisNodosScreen(
            api: _NodoApiFalsa(
              propios: <Nodo>[_nodo(1, 'Mi cafe', 'Aprobado')],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('PUBLICADO'), findsOneWidget);
        expect(_clave('eliminar-nodo-1'), findsOneWidget);
        expect(find.text('Nuevo nodo'), findsOneWidget);
      },
    );
  });

  group('FormularioNodoEmpresaScreen para el deportista', () {
    Future<_NodoApiFalsa> abrir(WidgetTester tester) async {
      final _NodoApiFalsa api = _NodoApiFalsa();
      await montarApp(
        tester,
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => Navigator.of(context).push<Nodo>(
              MaterialPageRoute<Nodo>(
                builder: (_) => FormularioNodoEmpresaScreen(
                  api: api,
                  esEmpresa: false,
                  selectorBuilder: _selectorFalso,
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('pide publicar un punto y no ofrece el campo de beneficio', (
      WidgetTester tester,
    ) async {
      await abrir(tester);

      expect(find.text('Publicar un punto'), findsOneWidget);
      expect(find.text('Nombre del punto'), findsOneWidget);
      expect(_clave('campo-beneficio-nodo'), findsNothing);
    });

    testWidgets(
      'enviar publica el punto SIN beneficio y avisa que ya esta publicado',
      (WidgetTester tester) async {
        final _NodoApiFalsa api = await abrir(tester);

        await tester.enterText(
          _clave('campo-nombre-nodo'),
          'Fuente del parque',
        );
        final Finder opcion = _clave('opcion-agua');
        await tester.ensureVisible(opcion);
        await tester.tap(opcion);
        await tester.pump();
        final Finder marcar = _clave('marcar-local');
        await tester.ensureVisible(marcar);
        await tester.tap(marcar);
        await tester.pump();
        await tester.tap(_clave('guardar-nodo-empresa'));
        await tester.pumpAndSettle();

        expect(api.propuestos, hasLength(1));
        expect(api.propuestos.single['nombre'], 'Fuente del parque');
        expect(api.propuestos.single['categoria'], 'agua');
        expect(api.propuestos.single['beneficio'], isNull);
        expect(find.text('Nodo publicado'), findsOneWidget);
        expect(find.byType(FormularioNodoEmpresaScreen), findsNothing);
      },
    );
  });

  group('Barra de navegacion del deportista', () {
    testWidgets('tiene el panel de Nodos junto a los demas', (
      WidgetTester tester,
    ) async {
      int? elegido;
      await montarApp(
        tester,
        Scaffold(
          bottomNavigationBar: UserNavBar(
            currentIndex: 0,
            onSelect: (int i) => elegido = i,
          ),
        ),
      );

      for (final String etiqueta in <String>[
        'Mapa',
        'Rutas',
        'Crear',
        'Eventos',
        'Nodos',
        'Perfil',
      ]) {
        expect(find.text(etiqueta), findsOneWidget, reason: etiqueta);
      }

      await tester.tap(find.text('Nodos'));
      expect(elegido, 4); // entre Eventos y Perfil

      await tester.tap(find.text('Perfil'));
      expect(elegido, 5);
    });

    testWidgets('las seis opciones caben en un celular angosto', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await montarApp(
        tester,
        Scaffold(
          bottomNavigationBar: UserNavBar(currentIndex: 0, onSelect: (_) {}),
        ),
      );

      // Si no cupieran, Flutter lanzaria un overflow y el test fallaria.
      expect(tester.takeException(), isNull);
    });
  });
}
