import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/widgets/carga_lista.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mis_nodos_screen.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/rutas_screen.dart';
import 'helpers/calificacion_falsa.dart';
import 'helpers/montar.dart';

void main() {
  usarCalificacionesFalsas();

  group('CargaLista', () {
    test('la primera carga deja los datos y apaga el "cargando"', () async {
      final CargaLista<int> c = CargaLista<int>(() async => <int>[1, 2, 3]);
      addTearDown(c.dispose);
      expect(c.cargando, isTrue);
      expect(c.datos, isNull);

      await c.cargar();

      expect(c.datos, <int>[1, 2, 3]);
      expect(c.cargando, isFalse);
      expect(c.error, isNull);
    });

    test('un fallo en la primera carga deja el error y ningun dato', () async {
      final CargaLista<int> c = CargaLista<int>(
        () async => throw Exception('sin red'),
      );
      addTearDown(c.dispose);

      await c.cargar();

      expect(c.datos, isNull);
      expect(c.error, isNotNull);
    });

    test('recargar en silencio no borra lo que se ve mientras llegan los datos', () async {
      Completer<List<int>> espera = Completer<List<int>>();
      List<int> respuesta = <int>[1, 2];
      final CargaLista<int> c = CargaLista<int>(() {
        if (respuesta.isEmpty) return espera.future;
        final List<int> r = respuesta;
        respuesta = <int>[];
        return Future<List<int>>.value(r);
      });
      addTearDown(c.dispose);
      await c.cargar();

      final Future<void> recarga = c.cargar(silencioso: true);
      // Mientras el servidor responde, la lista sigue ahi y no hay "error".
      expect(c.datos, <int>[1, 2]);
      expect(c.error, isNull);

      espera.complete(<int>[1, 2, 3]);
      await recarga;
      expect(c.datos, <int>[1, 2, 3]);
    });

    test('si un refresco en silencio falla, se queda lo que habia', () async {
      bool falla = false;
      final CargaLista<int> c = CargaLista<int>(() async {
        if (falla) throw Exception('sin red');
        return <int>[7];
      });
      addTearDown(c.dispose);
      await c.cargar();

      falla = true;
      await c.cargar(silencioso: true);

      expect(c.datos, <int>[7]);
      expect(c.error, isNull);
    });

    test('quitar saca el elemento al instante y avisa una sola vez', () async {
      final CargaLista<int> c = CargaLista<int>(() async => <int>[1, 2, 3]);
      addTearDown(c.dispose);
      await c.cargar();
      int avisos = 0;
      c.addListener(() => avisos++);

      c.quitar((int e) => e == 2);

      expect(c.datos, <int>[1, 3]);
      expect(avisos, 1);
    });

    test('una respuesta vieja no resucita lo que se acaba de quitar', () async {
      final Completer<List<int>> lenta = Completer<List<int>>();
      int llamadas = 0;
      final CargaLista<int> c = CargaLista<int>(() {
        llamadas++;
        return llamadas == 1
            ? Future<List<int>>.value(<int>[1, 2, 3])
            : lenta.future;
      });
      addTearDown(c.dispose);
      await c.cargar();

      final Future<void> recarga = c.cargar(silencioso: true);
      c.quitar((int e) => e == 2);
      // El servidor contesta con la lista de ANTES de borrar.
      lenta.complete(<int>[1, 2, 3]);
      await recarga;

      expect(c.datos, <int>[1, 3]);
    });

    test('reemplazar cambia solo el elemento pedido', () async {
      final CargaLista<String> c = CargaLista<String>(
        () async => <String>['a', 'b', 'c'],
      );
      addTearDown(c.dispose);
      await c.cargar();

      c.reemplazar((String e) => e == 'b', 'B');

      expect(c.datos, <String>['a', 'B', 'c']);
    });

    test('quitar o reemplazar antes de tener datos no hace nada', () {
      final CargaLista<int> c = CargaLista<int>(() async => <int>[1]);
      addTearDown(c.dispose);

      c.quitar((int e) => true);
      c.reemplazar((int e) => true, 9);

      expect(c.datos, isNull);
    });
  });

  group('borrar no repinta toda la pantalla', () {
    testWidgets('Mis rutas: borrar una ruta no vuelve a pedir la lista ni muestra el circulo de carga', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final _RutasContadas api = _RutasContadas();
      await montarApp(
        tester,
        Scaffold(body: RutasScreen(api: api, initialTab: 1)),
      );
      await tester.pumpAndSettle();
      final int antes = api.pedidasMias;
      expect(antes, 1);

      await tester.tap(find.byKey(const ValueKey<String>('eliminar-ruta-2')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('confirmar-eliminar-ruta')),
          matching: find.text('Eliminar ruta'),
        ),
      );
      // Un solo cuadro despues de confirmar: ni circulo ni lista en blanco.
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();

      expect(api.pedidasMias, antes);
      expect(find.text('Mi vuelta al lago'), findsNothing);
      expect(find.text('Cerro grande'), findsOneWidget);
      expect(find.text('Ruta eliminada.'), findsOneWidget);
    });

    testWidgets('Mis nodos: borrar un punto no vuelve a pedir la lista', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final _NodosContados api = _NodosContados();
      await montarApp(tester, MisNodosScreen(api: api));
      await tester.pumpAndSettle();
      expect(api.pedidas, 1);

      await tester.tap(find.byKey(const ValueKey<String>('eliminar-nodo-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('confirmar-eliminar')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();

      expect(api.pedidas, 1);
      expect(find.text('Cafe uno'), findsNothing);
      expect(find.text('Cafe dos'), findsOneWidget);
    });
  });
}

Ruta _ruta(int id, String nombre, String estado) => Ruta(
  id: id,
  nombre: nombre,
  actividades: const <String>['running'],
  dificultad: 'facil',
  distanciaKm: 3.2,
  puntos: const <PuntoRuta>[
    PuntoRuta(lat: 9.9281, lng: -84.0907),
    PuntoRuta(lat: 9.9291, lng: -84.0917),
  ],
  estado: estado,
);

class _RutasContadas extends RutaApi {
  int pedidasMias = 0;
  List<Ruta> mias = <Ruta>[
    _ruta(2, 'Mi vuelta al lago', 'Privada'),
    _ruta(3, 'Cerro grande', 'Publicada'),
  ];

  @override
  Future<Set<int>> favoritasIds() async => <int>{};

  @override
  Future<List<Ruta>> favoritas() async => <Ruta>[];

  @override
  Future<List<Ruta>> explorar() async => <Ruta>[];

  @override
  Future<List<Ruta>> misRutas() async {
    pedidasMias++;
    return List<Ruta>.of(mias);
  }

  @override
  Future<void> eliminar(int id) async {
    mias = mias.where((Ruta r) => r.id != id).toList();
  }
}

class _NodosContados extends NodoApi {
  int pedidas = 0;
  List<Nodo> nodos = const <Nodo>[
    Nodo(
      id: 1,
      nombre: 'Cafe uno',
      categoria: 'restaurante',
      lat: 9.9,
      lng: -84.0,
      estado: 'Aprobado',
      patrocinado: true,
    ),
    Nodo(
      id: 2,
      nombre: 'Cafe dos',
      categoria: 'restaurante',
      lat: 9.91,
      lng: -84.01,
      estado: 'Aprobado',
      patrocinado: true,
    ),
  ];

  @override
  Future<List<Nodo>> misNodos() async {
    pedidas++;
    return List<Nodo>.of(nodos);
  }

  @override
  Future<void> eliminar(int id) async {
    nodos = nodos.where((Nodo n) => n.id != id).toList();
  }
}
