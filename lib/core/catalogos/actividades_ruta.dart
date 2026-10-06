import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/opcion_catalogo.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

export 'package:fit_quest_go/core/catalogos/opcion_catalogo.dart';

/// Actividades de una ruta (se eligen una o varias; no se escriben). Son las
/// mismas del registro de la app, mas "otro" como salida. Contrato con el
/// backend: enum `ActividadRuta`.
const List<OpcionCatalogo> actividadesRuta = <OpcionCatalogo>[
  OpcionCatalogo('running', Icons.directions_run),
  OpcionCatalogo('ciclismo', Icons.directions_bike),
  OpcionCatalogo('mtb', Icons.pedal_bike),
  OpcionCatalogo('hiking', Icons.hiking),
  OpcionCatalogo('caminata', Icons.directions_walk),
  OpcionCatalogo(claveOtro, Icons.more_horiz),
];

/// Texto de una actividad en el idioma de la app. Una clave que no conozca
/// (dato viejo) se muestra tal cual en vez de romper la pantalla.
String actividadLabel(AppLocalizations l10n, String clave) {
  switch (clave) {
    case 'running':
      return l10n.actividadRunning;
    case 'ciclismo':
      return l10n.actividadCiclismo;
    case 'mtb':
      return l10n.actividadMtb;
    case 'hiking':
      return l10n.actividadHiking;
    case 'caminata':
      return l10n.actividadCaminata;
    case claveOtro:
      return l10n.actividadOtro;
    default:
      return clave;
  }
}

/// "Running, Ciclismo": las actividades de una ruta, traducidas y en orden.
String actividadesLabel(AppLocalizations l10n, List<String> claves) {
  return claves.map((String c) => actividadLabel(l10n, c)).join(', ');
}
