import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/mapa/pin_anotacion.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/destacable.dart';

/// Los puntos destacados sobre el mapa de Home: pines dorados con estrella y el
/// nombre, en un administrador propio. Hay que crearla DESPUES de los pines de
/// los demas puntos para que quede encima de todos.
///
/// Tocar un pin avisa con el id del punto ([alTocarNodo]), para abrir su ficha.
class CapaDestacadosMapa {
  CapaDestacadosMapa._(this._iconos);

  static Future<CapaDestacadosMapa> crear(
    MapboxMap mapa, {
    void Function(int nodoId)? alTocarNodo,
  }) async {
    final PointAnnotationManager iconos = await mapa.annotations
        .createPointAnnotationManager();
    await prepararPines(iconos);
    final CapaDestacadosMapa capa = CapaDestacadosMapa._(iconos)
      ..alTocarNodo = alTocarNodo;
    capa._escuchas.add(
      iconos.tapEvents(
        onTap: (PointAnnotation a) {
          final int? nodoId = capa._porPin[a.id];
          if (nodoId != null) capa.alTocarNodo?.call(nodoId);
        },
      ),
    );
    return capa;
  }

  final PointAnnotationManager _iconos;

  /// Se llama con el id del punto cuyo pin se toco.
  void Function(int nodoId)? alTocarNodo;

  final Map<String, int> _porPin = <String, int>{};
  final List<Cancelable> _escuchas = <Cancelable>[];

  /// Deja de escuchar los toques (al cerrarse el mapa).
  void liberar() {
    for (final Cancelable c in _escuchas) {
      c.cancel();
    }
    _escuchas.clear();
  }

  /// Quita del mapa los administradores de anotaciones de esta capa: hace falta
  /// al cambiar de estilo, para volver a crearla limpia sobre el estilo nuevo.
  Future<void> quitar(MapboxMap mapa) async {
    liberar();
    for (final Object m in <Object>[_iconos]) {
      try {
        await mapa.annotations.removeAnnotationManager(
          m as BaseAnnotationManager,
        );
      } catch (_) {
        // Ya no estaba (el estilo nuevo se lo llevo): no importa.
      }
    }
  }

  /// Borra todo y dibuja los destacados de [nodos] (el resto se ignora).
  Future<void> dibujar({
    required double densidad,
    required List<Nodo> nodos,
  }) async {
    await _iconos.deleteAll();
    _porPin.clear();
    // Copia: la lista puede cambiar mientras se espera a Mapbox.
    final List<Nodo> destacados = soloDestacados(nodos);
    if (destacados.isEmpty) return;
    final List<PointAnnotation?> creados = await _iconos
        .createMulti(<PointAnnotationOptions>[
          for (final Nodo n in destacados)
            opcionesDePin(
              lat: n.lat,
              lng: n.lng,
              imagen: await imagenPin(TipoPin.destacado),
              densidad: densidad,
              etiqueta: n.nombre,
            ),
        ]);
    for (int i = 0; i < creados.length; i++) {
      final PointAnnotation? pin = creados[i];
      if (pin != null) _porPin[pin.id] = destacados[i].id;
    }
  }
}
