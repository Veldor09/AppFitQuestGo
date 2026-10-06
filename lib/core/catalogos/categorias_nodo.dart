import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/opcion_catalogo.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

export 'package:fit_quest_go/core/catalogos/opcion_catalogo.dart';

/// Categorias de un punto de interes (se elige una; no se escribe). Si ninguna
/// encaja, "otro" y la persona escribe cual. Contrato con el backend: enum
/// `CategoriaNodo`.
const List<OpcionCatalogo> categoriasNodo = <OpcionCatalogo>[
  OpcionCatalogo('agua', Icons.water_drop_outlined),
  OpcionCatalogo('mirador', Icons.landscape_outlined),
  OpcionCatalogo('taller', Icons.build_outlined),
  OpcionCatalogo('restaurante', Icons.restaurant_outlined),
  OpcionCatalogo('comercio', Icons.storefront_outlined),
  OpcionCatalogo('banos', Icons.wc),
  OpcionCatalogo('parqueo', Icons.local_parking),
  OpcionCatalogo('primeros_auxilios', Icons.medical_services_outlined),
  OpcionCatalogo(claveOtro, Icons.more_horiz),
];

/// Texto de una categoria en el idioma de la app. Con "otro" muestra lo que
/// escribio quien lo propuso; una clave desconocida se muestra tal cual.
String categoriaNodoLabel(AppLocalizations l10n, String clave, {String? otro}) {
  switch (clave) {
    case 'agua':
      return l10n.categoriaNodoAgua;
    case 'mirador':
      return l10n.categoriaNodoMirador;
    case 'taller':
      return l10n.categoriaNodoTaller;
    case 'restaurante':
      return l10n.categoriaNodoRestaurante;
    case 'comercio':
      return l10n.categoriaNodoComercio;
    case 'banos':
      return l10n.categoriaNodoBanos;
    case 'parqueo':
      return l10n.categoriaNodoParqueo;
    case 'primeros_auxilios':
      return l10n.categoriaNodoPrimerosAuxilios;
    case claveOtro:
      final String texto = otro?.trim() ?? '';
      return texto.isEmpty ? l10n.categoriaNodoOtro : texto;
    default:
      return clave;
  }
}

/// Color del pin de un nodo en el mapa. Nunca el rojo de las alertas.
Color colorCategoriaNodo(String clave) {
  switch (clave) {
    case 'agua':
      return FqColors.river;
    case 'mirador':
      return FqColors.amber;
    case 'restaurante':
    case 'comercio':
      return FqColors.pink;
    case 'taller':
      return FqColors.purple;
    case 'primeros_auxilios':
      return FqColors.voltDark;
    default:
      return FqColors.trail;
  }
}
