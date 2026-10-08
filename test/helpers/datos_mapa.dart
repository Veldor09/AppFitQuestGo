import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// Donde esta quien usa la app en las pruebas del mapa (San Jose).
const double latBase = 9.9281;
const double lngBase = -84.0907;

/// Un grado de latitud son ~111 km: 0.001 ~ 111 m, 0.01 ~ 1.1 km.
Nodo nodoDePrueba({
  int id = 1,
  String nombre = 'Fuente',
  String categoria = 'agua',
  double lat = latBase,
  double lng = lngBase,
  String? descripcion,
  String? categoriaOtro,
  String estado = 'Aprobado',
}) {
  return Nodo(
    id: id,
    nombre: nombre,
    categoria: categoria,
    lat: lat,
    lng: lng,
    estado: estado,
    descripcion: descripcion,
    categoriaOtro: categoriaOtro,
  );
}

Ruta rutaDePrueba({
  int id = 1,
  String nombre = 'Sendero',
  List<String> actividades = const <String>['running'],
  String dificultad = 'moderada',
  double distanciaKm = 5,
  List<PuntoRuta>? puntos,
  String estado = 'Publicada',
}) {
  return Ruta(
    id: id,
    nombre: nombre,
    actividades: actividades,
    dificultad: dificultad,
    distanciaKm: distanciaKm,
    puntos:
        puntos ??
        const <PuntoRuta>[
          PuntoRuta(lat: latBase, lng: lngBase),
          PuntoRuta(lat: latBase + 0.01, lng: lngBase),
        ],
    estado: estado,
  );
}

Alerta alertaDePrueba({
  int id = 1,
  String tipo = 'bache',
  String gravedad = 'media',
  double lat = latBase,
  double lng = lngBase,
  String estado = 'Activa',
  String? descripcion,
  String? tipoOtro,
  int? creadoPorId,
}) {
  return Alerta(
    id: id,
    tipo: tipo,
    gravedad: gravedad,
    lat: lat,
    lng: lng,
    estado: estado,
    descripcion: descripcion,
    tipoOtro: tipoOtro,
    creadoPorId: creadoPorId,
  );
}

Evento eventoDePrueba({
  int id = 1,
  String nombre = 'Carrera del parque',
  String categoria = 'carrera',
  String? descripcion,
  String? empresa,
  List<ZonaEvento>? areas,
  List<ZonaEvento>? recorridos,
}) {
  return Evento(
    id: id,
    nombre: nombre,
    categoria: categoria,
    descripcion: descripcion,
    creadoPorNombre: empresa,
    fechaInicio: DateTime(2026, 10, 20, 8),
    fechaFin: DateTime(2026, 10, 20, 12),
    areas: areas ?? const <ZonaEvento>[],
    recorridos:
        recorridos ??
        const <ZonaEvento>[
          ZonaEvento(
            nombre: 'Recorrido 1',
            puntos: <PuntoGeo>[
              PuntoGeo(lat: latBase, lng: lngBase),
              PuntoGeo(lat: latBase + 0.005, lng: lngBase),
            ],
          ),
        ],
  );
}
