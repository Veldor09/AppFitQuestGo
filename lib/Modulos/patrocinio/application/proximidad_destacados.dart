import 'package:flutter/foundation.dart';

import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';

/// A cuantos metros de un destacado la app avisa "Destacado cerca de ti".
const double radioAvisoDestacadoMetros = 1000;

/// Un destacado (punto o evento) y a cuantos metros esta.
class DestacadoCercano {
  const DestacadoCercano({
    required this.tipo,
    required this.id,
    required this.nombre,
    required this.metros,
    required this.origen,
  });

  /// `'nodo'` o `'evento'`.
  final String tipo;
  final int id;
  final String nombre;
  final double metros;

  /// El [Nodo] o el [Evento] del que sale.
  final Object origen;

  String get clave => '$tipo:$id';
}

/// El destacado mas cercano a ([lat], [lng]) dentro de [radioMetros]. Solo
/// cuentan los que el servidor marca `destacado`; la distancia a un evento es
/// al punto mas cercano de sus areas y recorridos. Los [excluidos] (por
/// [DestacadoCercano.clave]) se saltan.
DestacadoCercano? destacadoMasCercano({
  required double lat,
  required double lng,
  required Iterable<Nodo> nodos,
  required Iterable<Evento> eventos,
  double radioMetros = radioAvisoDestacadoMetros,
  Set<String> excluidos = const <String>{},
}) {
  DestacadoCercano? elegido;
  void considerar(DestacadoCercano candidato) {
    if (excluidos.contains(candidato.clave)) return;
    if (candidato.metros > radioMetros) return;
    if (elegido == null || candidato.metros < elegido!.metros) {
      elegido = candidato;
    }
  }

  for (final Nodo n in nodos) {
    if (!n.destacado) continue;
    considerar(
      DestacadoCercano(
        tipo: 'nodo',
        id: n.id,
        nombre: n.nombre,
        metros: distanciaMetros(lat, lng, n.lat, n.lng),
        origen: n,
      ),
    );
  }
  for (final Evento e in eventos) {
    if (!e.destacado) continue;
    double? menor;
    for (final PuntoGeo p in e.todosLosPuntos) {
      final double d = distanciaMetros(lat, lng, p.lat, p.lng);
      if (menor == null || d < menor) menor = d;
    }
    if (menor == null) continue;
    considerar(
      DestacadoCercano(
        tipo: 'evento',
        id: e.id,
        nombre: e.nombre,
        metros: menor,
        origen: e,
      ),
    );
  }
  return elegido;
}

/// Vigila la posicion contra los destacados y deja en [cercano] el que toca
/// avisar: uno a la vez (el mas cercano) y una sola vez por destacado y por
/// sesion, lo cierres o te alejes sin cerrarlo. No sabe de mapas ni de red.
class ProximidadDestacados extends ChangeNotifier {
  ProximidadDestacados({this.radioMetros = radioAvisoDestacadoMetros});

  final double radioMetros;

  List<Nodo> _nodos = const <Nodo>[];
  List<Evento> _eventos = const <Evento>[];
  PosicionGps? _posicion;
  DestacadoCercano? _cercano;
  final Set<String> _avisados = <String>{};

  /// El destacado que se esta avisando, o null.
  DestacadoCercano? get cercano => _cercano;

  /// Reemplaza lo destacable (cada carga del mapa).
  void actualizarDestacables(List<Nodo> nodos, List<Evento> eventos) {
    _nodos = nodos;
    _eventos = eventos;
    _evaluar();
  }

  void alMoverse(PosicionGps posicion) {
    _posicion = posicion;
    _evaluar();
  }

  /// "Ahora no" o abrirlo: pasa al siguiente, si hay otro dentro del radio.
  void cerrar() => _evaluar(cerrarActual: true);

  void _evaluar({bool cerrarActual = false}) {
    final DestacadoCercano? antes = _cercano;
    final PosicionGps? pos = _posicion;
    if (cerrarActual) _cercano = null;

    final DestacadoCercano? actual = _cercano;
    if (actual != null) {
      // Sigue mientras siga destacado y estes dentro del radio (con la
      // distancia al dia); si no, ya se avisó y no vuelve.
      _cercano = pos == null ? null : _medirDeNuevo(actual, pos);
    }

    if (_cercano == null && pos != null) {
      final DestacadoCercano? nuevo = destacadoMasCercano(
        lat: pos.lat,
        lng: pos.lng,
        nodos: _nodos,
        eventos: _eventos,
        radioMetros: radioMetros,
        excluidos: _avisados,
      );
      if (nuevo != null) {
        _avisados.add(nuevo.clave);
        _cercano = nuevo;
      }
    }

    if (_cercano?.clave != antes?.clave ||
        _cercano?.metros.round() != antes?.metros.round()) {
      notifyListeners();
    }
  }

  /// El mismo destacado medido desde [pos], o null si ya no es destacado o
  /// quedo fuera del radio.
  DestacadoCercano? _medirDeNuevo(DestacadoCercano actual, PosicionGps pos) {
    return destacadoMasCercano(
      lat: pos.lat,
      lng: pos.lng,
      nodos: _nodos.where((Nodo n) => 'nodo:${n.id}' == actual.clave),
      eventos: _eventos.where((Evento e) => 'evento:${e.id}' == actual.clave),
      radioMetros: radioMetros,
    );
  }
}
