import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/Modulos/clima/application/clima_zona.dart';
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';
import 'package:fit_quest_go/Modulos/clima/data/clima_api.dart';

class _ClimaApiFalsa extends ClimaApi {
  final List<({double lat, double lng})> consultas = <({double lat, double lng})>[];
  List<AlertaClima> respuesta = <AlertaClima>[];
  Object? error;
  Completer<void>? espera;

  @override
  Future<RespuestaClima> alertas({required double lat, required double lng}) async {
    consultas.add((lat: lat, lng: lng));
    if (espera != null) await espera!.future;
    if (error != null) throw error!;
    return RespuestaClima(alertas: respuesta, fuente: 'Open-Meteo');
  }
}

const AlertaClima _calor = AlertaClima(
  tipo: TipoClima.calor,
  nivel: NivelClima.peligro,
  enHoras: 0,
  valor: 41.5,
);
const AlertaClima _lluvia = AlertaClima(
  tipo: TipoClima.lluvia,
  nivel: NivelClima.precaucion,
  enHoras: 1,
  valor: 12,
);
const AlertaClima _lluviaPeligro = AlertaClima(
  tipo: TipoClima.lluvia,
  nivel: NivelClima.peligro,
  enHoras: 1,
  valor: 30,
);

void main() {
  late _ClimaApiFalsa api;
  PosicionGps? posicion;
  late ClimaZona zona;
  late int avisos;

  setUp(() {
    api = _ClimaApiFalsa();
    posicion = (lat: 9.9281, lng: -84.0907);
    zona = ClimaZona(api: api, posicion: () => posicion);
    avisos = 0;
    zona.addListener(() => avisos++);
  });

  tearDown(() => zona.dispose());

  test('sin posicion todavia no consulta nada', () async {
    posicion = null;

    await zona.actualizar();

    expect(api.consultas, isEmpty);
    expect(zona.visibles, isEmpty);
  });

  test('consulta con la posicion actual y expone los avisos', () async {
    api.respuesta = <AlertaClima>[_calor, _lluvia];

    await zona.actualizar();

    expect(api.consultas, <({double lat, double lng})>[(lat: 9.9281, lng: -84.0907)]);
    expect(zona.visibles, <AlertaClima>[_calor, _lluvia]);
    expect(zona.principal, _calor);
    expect(zona.fuente, 'Open-Meteo');
  });

  test('avisa a quien escucha cuando llegan los avisos', () async {
    api.respuesta = <AlertaClima>[_calor];

    await zona.actualizar();

    expect(avisos, 1);
  });

  test('sin mal tiempo no hay principal', () async {
    await zona.actualizar();

    expect(zona.principal, isNull);
    expect(zona.visibles, isEmpty);
  });

  test('si la consulta falla conserva lo ultimo que sabia y no lanza', () async {
    api.respuesta = <AlertaClima>[_calor];
    await zona.actualizar();

    api.error = ApiException(503, 'no disponible');
    await zona.actualizar();

    expect(zona.visibles, <AlertaClima>[_calor]);
  });

  test('un error de red tampoco lanza', () async {
    api.error = StateError('sin red');

    await expectLater(zona.actualizar(), completes);

    expect(zona.visibles, isEmpty);
  });

  test('si el mal tiempo pasa, el aviso desaparece en la siguiente consulta', () async {
    api.respuesta = <AlertaClima>[_calor];
    await zona.actualizar();

    api.respuesta = <AlertaClima>[];
    await zona.actualizar();

    expect(zona.principal, isNull);
  });

  group('cerrar un aviso', () {
    test('lo oculta pero deja los demas', () async {
      api.respuesta = <AlertaClima>[_calor, _lluvia];
      await zona.actualizar();

      zona.cerrar(_calor);

      expect(zona.visibles, <AlertaClima>[_lluvia]);
      expect(zona.principal, _lluvia);
    });

    test('avisa a quien escucha', () async {
      api.respuesta = <AlertaClima>[_calor];
      await zona.actualizar();
      avisos = 0;

      zona.cerrar(_calor);

      expect(avisos, 1);
    });

    test('sigue cerrado si la siguiente consulta trae lo mismo', () async {
      api.respuesta = <AlertaClima>[_calor];
      await zona.actualizar();
      zona.cerrar(_calor);

      await zona.actualizar();

      expect(zona.visibles, isEmpty);
    });

    test('vuelve a avisar si el mismo tipo sube de nivel', () async {
      api.respuesta = <AlertaClima>[_lluvia];
      await zona.actualizar();
      zona.cerrar(_lluvia);

      api.respuesta = <AlertaClima>[_lluviaPeligro];
      await zona.actualizar();

      expect(zona.principal, _lluviaPeligro);
    });
  });

  test('si ya hay una consulta en vuelo no lanza otra', () async {
    api.espera = Completer<void>();
    api.respuesta = <AlertaClima>[_calor];

    final Future<void> primera = zona.actualizar();
    final Future<void> segunda = zona.actualizar();
    api.espera!.complete();
    await Future.wait(<Future<void>>[primera, segunda]);

    expect(api.consultas, hasLength(1));
  });

  test('despues de terminar una consulta se puede lanzar otra', () async {
    await zona.actualizar();
    await zona.actualizar();

    expect(api.consultas, hasLength(2));
  });

  test('si se descarta mientras consulta, no avisa ni lanza', () async {
    final ClimaZona efimera = ClimaZona(api: api, posicion: () => posicion);
    api.espera = Completer<void>();
    api.respuesta = <AlertaClima>[_calor];
    int llamadas = 0;
    efimera.addListener(() => llamadas++);

    final Future<void> consulta = efimera.actualizar();
    efimera.dispose();
    api.espera!.complete();
    await consulta;

    expect(llamadas, 0);
  });
}
