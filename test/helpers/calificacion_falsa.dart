import 'package:flutter_test/flutter_test.dart' show setUp, tearDown;

import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion_api.dart';

/// Calificaciones sin red: responde lo que se le configure y apunta lo que le
/// piden, para probar las pantallas que muestran pulgares.
class CalificacionApiFalsa extends CalificacionApi {
  CalificacionApiFalsa({this.respuesta = const ResumenCalificacion()});

  /// Lo que responde el servidor al pedir el resumen.
  ResumenCalificacion respuesta;

  /// Error al pedir el resumen o calificar (por ejemplo una `ApiException`).
  Object? error;

  final List<({TipoCalificable tipo, int id})> resumenesPedidos =
      <({TipoCalificable tipo, int id})>[];

  /// Calificaciones enviadas: tipo, id, valor (null = retirar), area y posicion.
  final List<
    ({
      TipoCalificable tipo,
      int id,
      ValorCalificacion? valor,
      int? area,
      double? lat,
      double? lng,
    })
  >
  enviadas =
      <
        ({
          TipoCalificable tipo,
          int id,
          ValorCalificacion? valor,
          int? area,
          double? lat,
          double? lng,
        })
      >[];

  @override
  Future<ResumenCalificacion> resumen(TipoCalificable tipo, int id) async {
    resumenesPedidos.add((tipo: tipo, id: id));
    if (error != null) throw error!;
    return respuesta;
  }

  @override
  Future<ResumenCalificacion> calificar(
    TipoCalificable tipo,
    int id,
    ValorCalificacion? valor, {
    int? area,
    double? lat,
    double? lng,
  }) async {
    enviadas.add((
      tipo: tipo,
      id: id,
      valor: valor,
      area: area,
      lat: lat,
      lng: lng,
    ));
    if (error != null) throw error!;
    // Como el servidor: suma el voto nuevo, retira el anterior. Con `area`
    // cambia solo esa area; el resumen que vuelve es siempre el del objeto.
    final ResumenCalificacion antes = respuesta;
    if (area != null) {
      final List<ResumenCalificacion> areas = List<ResumenCalificacion>.of(
        antes.areas,
      );
      if (area < areas.length) areas[area] = _aplicar(areas[area], valor);
      respuesta = ResumenCalificacion(
        arriba: antes.arriba,
        abajo: antes.abajo,
        mia: antes.mia,
        puedeCalificar: antes.puedeCalificar,
        motivo: antes.motivo,
        areas: areas,
      );
      return respuesta;
    }
    final ResumenCalificacion nuevo = _aplicar(antes, valor);
    respuesta = ResumenCalificacion(
      arriba: nuevo.arriba,
      abajo: nuevo.abajo,
      mia: nuevo.mia,
      puedeCalificar: antes.puedeCalificar,
      motivo: antes.motivo,
      areas: antes.areas,
    );
    return respuesta;
  }

  static ResumenCalificacion _aplicar(
    ResumenCalificacion antes,
    ValorCalificacion? valor,
  ) {
    int arriba = antes.arriba - (antes.mia == ValorCalificacion.arriba ? 1 : 0);
    int abajo = antes.abajo - (antes.mia == ValorCalificacion.abajo ? 1 : 0);
    if (valor == ValorCalificacion.arriba) arriba++;
    if (valor == ValorCalificacion.abajo) abajo++;
    return ResumenCalificacion(
      arriba: arriba,
      abajo: abajo,
      mia: valor,
      puedeCalificar: antes.puedeCalificar,
      motivo: antes.motivo,
    );
  }
}

/// Las pantallas que abren fichas por dentro (listas, mapa) usan estas
/// calificaciones falsas en vez de pedirlas a la red. Llamarla al principio de
/// `main()` de la prueba.
void usarCalificacionesFalsas() {
  setUp(() => CalificacionApi.sustituto = CalificacionApiFalsa());
  tearDown(() => CalificacionApi.sustituto = null);
}
