import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/mapa/redibujo_unico.dart';

void main() {
  group('RedibujoUnico', () {
    late List<Completer<void>> pasos;
    late int dibujos;
    late int simultaneos;
    late int maximoSimultaneos;
    late RedibujoUnico redibujo;

    setUp(() {
      pasos = <Completer<void>>[];
      dibujos = 0;
      simultaneos = 0;
      maximoSimultaneos = 0;
      redibujo = RedibujoUnico(() async {
        dibujos++;
        simultaneos++;
        if (simultaneos > maximoSimultaneos) maximoSimultaneos = simultaneos;
        final Completer<void> paso = Completer<void>();
        pasos.add(paso);
        try {
          await paso.future;
        } finally {
          simultaneos--;
        }
      });
    });

    Future<void> dejarCorrer() => Future<void>.delayed(Duration.zero);

    test('si no hay un dibujo en curso, dibuja de inmediato', () async {
      final Future<void> hecho = redibujo.pedir();

      expect(dibujos, 1);
      pasos.single.complete();
      await hecho;
      expect(dibujos, 1);
    });

    test('lo que se pide mientras dibuja se junta en un solo dibujo mas, al terminar', () async {
      final Future<void> hecho = redibujo.pedir();
      unawaited(redibujo.pedir());
      unawaited(redibujo.pedir());
      unawaited(redibujo.pedir());
      expect(dibujos, 1);

      pasos[0].complete();
      await dejarCorrer();
      expect(dibujos, 2);

      pasos[1].complete();
      await hecho;
      expect(dibujos, 2);
    });

    test('nunca hay dos dibujos a la vez', () async {
      final Future<void> hecho = redibujo.pedir();
      unawaited(redibujo.pedir());

      pasos[0].complete();
      await dejarCorrer();
      pasos[1].complete();
      await hecho;

      expect(maximoSimultaneos, 1);
    });

    test('despues de terminar, un pedido nuevo vuelve a dibujar', () async {
      final Future<void> primero = redibujo.pedir();
      pasos[0].complete();
      await primero;

      final Future<void> segundo = redibujo.pedir();
      expect(dibujos, 2);
      pasos[1].complete();
      await segundo;
    });

    test('si un dibujo falla no se queda trabado: el siguiente pedido dibuja', () async {
      final Future<void> primero = redibujo.pedir();
      pasos[0].completeError(StateError('Mapbox fallo'));
      await primero;

      final Future<void> segundo = redibujo.pedir();
      expect(dibujos, 2);
      pasos[1].complete();
      await segundo;
    });
  });
}
