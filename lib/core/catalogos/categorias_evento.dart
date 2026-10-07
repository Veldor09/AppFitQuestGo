import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/opcion_catalogo.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

export 'package:fit_quest_go/core/catalogos/opcion_catalogo.dart';

/// Categorias de un evento (se elige una; no se escribe). Contrato con el
/// backend: enum `CategoriaEvento`.
const List<OpcionCatalogo> categoriasEvento = <OpcionCatalogo>[
  OpcionCatalogo('benefico', Icons.volunteer_activism_outlined),
  OpcionCatalogo('caminata', Icons.directions_walk),
  OpcionCatalogo('carrera', Icons.directions_run),
  OpcionCatalogo('ciclismo', Icons.directions_bike),
  OpcionCatalogo('senderismo', Icons.hiking),
  OpcionCatalogo(claveOtro, Icons.more_horiz),
];

/// Texto de una categoria en el idioma de la app; una clave desconocida se
/// muestra tal cual.
String categoriaEventoLabel(AppLocalizations l10n, String clave) {
  switch (clave) {
    case 'benefico':
      return l10n.categoriaEventoBenefico;
    case 'caminata':
      return l10n.categoriaEventoCaminata;
    case 'carrera':
      return l10n.categoriaEventoCarrera;
    case 'ciclismo':
      return l10n.categoriaEventoCiclismo;
    case 'senderismo':
      return l10n.categoriaEventoSenderismo;
    case claveOtro:
      return l10n.categoriaEventoOtro;
    default:
      return clave;
  }
}

/// Icono de una categoria (el de "otro" si la clave no se conoce).
IconData iconoCategoriaEvento(String clave) {
  for (final OpcionCatalogo o in categoriasEvento) {
    if (o.clave == clave) return o.icono;
  }
  return Icons.more_horiz;
}

/// Colores de los trazos de un evento en el mapa. No usan el rojo de las
/// alertas ni los colores de los pines de nodos.
const Color colorAreaEvento = FqColors.purple;
const Color colorRecorridoEvento = FqColors.river;
