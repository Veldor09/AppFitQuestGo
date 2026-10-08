import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/catalogos/tipos_alerta.dart';
import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/formato_distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/home/application/cercanos.dart';
import 'package:fit_quest_go/Modulos/home/application/filtro_mapa.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';

/// Que clase de cosa es un resultado de la busqueda.
enum TipoResultado { ruta, alerta, poi, evento }

/// Una fila de los resultados de la barra de busqueda del mapa.
class ResultadoBusqueda {
  const ResultadoBusqueda({
    required this.tipo,
    required this.origen,
    required this.titulo,
    required this.detalle,
    required this.lat,
    required this.lng,
    this.metros,
  });

  final TipoResultado tipo;

  /// Lo que se encontro: un [Ruta], [Alerta], [Nodo] o [Evento], segun [tipo].
  final Object origen;
  final String titulo;

  /// Segunda linea: la categoria, las actividades, la gravedad...
  final String detalle;

  /// Un punto de lo encontrado (el de un punto o una alerta, el inicio de una
  /// ruta o de un evento).
  final double lat;
  final double lng;

  /// A cuantos metros esta de quien busca (al punto mas cercano, si es una
  /// ruta o un evento); null si no se conoce su posicion.
  final double? metros;
}

const Map<String, String> _sinTilde = <String, String>{
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Minusculas y sin tildes: para que "Café" y "cafe" se encuentren entre si.
String normalizarTexto(String texto) {
  final StringBuffer salida = StringBuffer();
  for (final int rune in texto.toLowerCase().runes) {
    final String letra = String.fromCharCode(rune);
    salida.write(_sinTilde[letra] ?? letra);
  }
  return salida.toString();
}

/// Busca [consulta] entre lo que hay en el mapa, limitado por [filtro]: puntos
/// de interes, rutas, alertas activas y eventos. No toca la red: trabaja con lo
/// que Home ya cargo.
///
/// Todas las palabras de la consulta tienen que aparecer (sin importar
/// mayusculas ni tildes), en el nombre o en lo demas que se muestra de la cosa
/// (su categoria, sus actividades, su descripcion, la empresa de un evento).
/// Salen primero los que empiezan con la consulta, luego los que la tienen en
/// el nombre y al final los que la tienen en otros campos; a igualdad, el mas
/// cercano a [posicion] y despues por orden alfabetico.
List<ResultadoBusqueda> buscarEnMapa({
  required String consulta,
  required FiltroMapa filtro,
  required AppLocalizations l10n,
  required Iterable<Nodo> nodos,
  required Iterable<Ruta> rutas,
  required Iterable<Alerta> alertas,
  required Iterable<Evento> eventos,
  PosicionGps? posicion,
  int limite = 8,
}) {
  final String buscada = normalizarTexto(consulta).trim();
  if (buscada.isEmpty) return const <ResultadoBusqueda>[];
  final List<String> terminos = buscada.split(RegExp(r'\s+'));

  final List<_Candidato> candidatos = <_Candidato>[];

  void considerar({
    required TipoResultado tipo,
    required Object origen,
    required String titulo,
    required String detalle,
    required List<String> otrosCampos,
    required double lat,
    required double lng,
    required double? metros,
  }) {
    final int? puntaje = _puntaje(buscada, terminos, titulo, otrosCampos);
    if (puntaje == null) return;
    candidatos.add(
      _Candidato(
        puntaje,
        normalizarTexto(titulo),
        ResultadoBusqueda(
          tipo: tipo,
          origen: origen,
          titulo: titulo,
          detalle: detalle,
          lat: lat,
          lng: lng,
          metros: metros,
        ),
      ),
    );
  }

  double? desde(double lat, double lng) => posicion == null
      ? null
      : distanciaMetros(posicion.lat, posicion.lng, lat, lng);

  if (filtro.muestra(CapaMapa.pois)) {
    for (final Nodo n in nodos) {
      considerar(
        tipo: TipoResultado.poi,
        origen: n,
        titulo: n.nombre,
        detalle: categoriaNodoLabel(l10n, n.categoria, otro: n.categoriaOtro),
        otrosCampos: <String>[
          categoriaNodoLabel(l10n, n.categoria, otro: n.categoriaOtro),
          n.descripcion ?? '',
        ],
        lat: n.lat,
        lng: n.lng,
        metros: desde(n.lat, n.lng),
      );
    }
  }

  if (filtro.muestra(CapaMapa.rutas)) {
    for (final Ruta r in rutas) {
      if (r.puntos.isEmpty) continue;
      final String actividades = actividadesLabel(l10n, r.actividades);
      considerar(
        tipo: TipoResultado.ruta,
        origen: r,
        titulo: r.nombre,
        detalle: <String>[
          if (actividades.isNotEmpty) actividades,
          formatearDistancia(r.distanciaKm * 1000, locale: l10n.localeName),
        ].join(' · '),
        otrosCampos: <String>[actividades, dificultadLabel(l10n, r.dificultad)],
        lat: r.puntos.first.lat,
        lng: r.puntos.first.lng,
        metros: posicion == null
            ? null
            : distanciaARuta(posicion.lat, posicion.lng, r),
      );
    }
  }

  if (filtro.muestra(CapaMapa.alertas)) {
    for (final Alerta a in alertas) {
      if (!a.estaActiva) continue;
      considerar(
        tipo: TipoResultado.alerta,
        origen: a,
        titulo: tipoAlertaLabel(l10n, a.tipo, otro: a.tipoOtro),
        detalle: l10n.alertasGravedadConValor(gravedadLabel(l10n, a.gravedad)),
        otrosCampos: <String>[a.descripcion ?? ''],
        lat: a.lat,
        lng: a.lng,
        metros: desde(a.lat, a.lng),
      );
    }
  }

  if (filtro.muestra(CapaMapa.eventos)) {
    for (final Evento e in eventos) {
      final List<PuntoGeo> puntos = e.todosLosPuntos;
      if (puntos.isEmpty) continue;
      final String empresa = e.creadoPorNombre?.trim() ?? '';
      double? menor;
      if (posicion != null) {
        for (final PuntoGeo p in puntos) {
          final double d = distanciaMetros(
            posicion.lat,
            posicion.lng,
            p.lat,
            p.lng,
          );
          if (menor == null || d < menor) menor = d;
        }
      }
      considerar(
        tipo: TipoResultado.evento,
        origen: e,
        titulo: e.nombre,
        detalle: <String>[
          categoriaEventoLabel(l10n, e.categoria),
          if (empresa.isNotEmpty) empresa,
        ].join(' · '),
        otrosCampos: <String>[
          categoriaEventoLabel(l10n, e.categoria),
          empresa,
          e.descripcion ?? '',
        ],
        lat: puntos.first.lat,
        lng: puntos.first.lng,
        metros: menor,
      );
    }
  }

  candidatos.sort((_Candidato a, _Candidato b) {
    final int porPuntaje = a.puntaje.compareTo(b.puntaje);
    if (porPuntaje != 0) return porPuntaje;
    final int porDistancia = (a.resultado.metros ?? double.infinity).compareTo(
      b.resultado.metros ?? double.infinity,
    );
    if (porDistancia != 0) return porDistancia;
    return a.tituloNormalizado.compareTo(b.tituloNormalizado);
  });

  return <ResultadoBusqueda>[
    for (final _Candidato c in candidatos.take(limite)) c.resultado,
  ];
}

class _Candidato {
  const _Candidato(this.puntaje, this.tituloNormalizado, this.resultado);

  final int puntaje;
  final String tituloNormalizado;
  final ResultadoBusqueda resultado;
}

/// 0: el nombre empieza con la consulta; 1: una palabra del nombre empieza con
/// ella; 2: el nombre tiene todas sus palabras; 3: las tiene entre el nombre y
/// los otros campos; null: no coincide.
int? _puntaje(
  String buscada,
  List<String> terminos,
  String titulo,
  List<String> otrosCampos,
) {
  final String nombre = normalizarTexto(titulo);
  if (nombre.startsWith(buscada)) return 0;
  if (nombre.contains(' $buscada')) return 1;
  bool tieneTodas(String texto) => terminos.every(texto.contains);
  if (tieneTodas(nombre)) return 2;
  final String todo = <String>[
    nombre,
    ...otrosCampos.map(normalizarTexto),
  ].join(' ');
  return tieneTodas(todo) ? 3 : null;
}
