import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Ajusta un `PointAnnotationManager` para dibujar pines con nombre: que ni los
/// iconos ni los textos se escondan unos a otros (Mapbox oculta por defecto lo
/// que se solapa) y asi cada pin y cada nombre siempre se ven.
Future<void> prepararPines(PointAnnotationManager iconos) async {
  await iconos.setIconAllowOverlap(true);
  await iconos.setIconIgnorePlacement(true);
  await iconos.setTextAllowOverlap(true);
  await iconos.setTextIgnorePlacement(true);
}

/// Las opciones para dibujar un pin con forma de gota en [lat], [lng].
///
/// - La punta de la gota queda justo en la coordenada.
/// - Con [etiqueta], el nombre se escribe a la derecha del pin, en letra
///   oscura con un halo blanco para que se lea sobre cualquier fondo (como en
///   Google Maps). Con [secundario] el texto va en gris.
/// - [densidad] es la densidad de pixeles de la pantalla (`devicePixelRatio`):
///   con ella el pin mide lo mismo en cualquier celular.
PointAnnotationOptions opcionesDePin({
  required double lat,
  required double lng,
  required Uint8List imagen,
  required double densidad,
  String? etiqueta,
  bool secundario = false,
}) {
  final String? texto = etiqueta?.trim();
  final bool conTexto = texto != null && texto.isNotEmpty;
  return PointAnnotationOptions(
    geometry: Point(coordinates: Position(lng, lat)),
    image: imagen,
    iconSize: iconSizePin(densidad),
    iconAnchor: IconAnchor.BOTTOM,
    textField: conTexto ? texto : null,
    textSize: 12.5,
    textMaxWidth: 9,
    textAnchor: TextAnchor.LEFT,
    // En ems del tamaño del texto: a la derecha de la cabeza del pin, a media
    // altura de ella (la cabeza esta unos 28 sobre la punta).
    textOffset: <double?>[1.9, -2.3],
    textColor: (secundario ? FqColors.muted : FqColors.night).toARGB32(),
    textHaloColor: Colors.white.toARGB32(),
    textHaloWidth: 2,
  );
}
