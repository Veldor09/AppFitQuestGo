import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/home/application/filtro_mapa.dart';

void main() {
  group('FiltroMapa', () {
    test('Todo deja ver todas las capas del mapa', () {
      for (final CapaMapa capa in CapaMapa.values) {
        expect(FiltroMapa.todo.muestra(capa), isTrue, reason: '$capa');
      }
    });

    test('cada uno de los otros filtros deja ver solo su propia capa', () {
      const Map<FiltroMapa, CapaMapa> propia = <FiltroMapa, CapaMapa>{
        FiltroMapa.rutas: CapaMapa.rutas,
        FiltroMapa.alertas: CapaMapa.alertas,
        FiltroMapa.pois: CapaMapa.pois,
        FiltroMapa.eventos: CapaMapa.eventos,
      };

      for (final MapEntry<FiltroMapa, CapaMapa> par in propia.entries) {
        for (final CapaMapa capa in CapaMapa.values) {
          expect(
            par.key.muestra(capa),
            capa == par.value,
            reason: '${par.key} frente a $capa',
          );
        }
      }
    });

    test('hay un filtro por cada capa, mas Todo', () {
      expect(FiltroMapa.values, hasLength(CapaMapa.values.length + 1));
    });
  });
}
