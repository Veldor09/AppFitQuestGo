import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/opcion_catalogo.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

export 'package:fit_quest_go/core/catalogos/opcion_catalogo.dart';

/// Tipos de alerta (se elige uno; no se escribe). Si ninguno encaja, "otro" y
/// la persona escribe cual. Contrato con el backend: enum `TipoAlerta`.
const List<OpcionCatalogo> tiposAlerta = <OpcionCatalogo>[
  OpcionCatalogo('arbol_caido', Icons.park_outlined),
  OpcionCatalogo('bache', Icons.report_problem_outlined),
  OpcionCatalogo('derrumbe', Icons.landscape_outlined),
  OpcionCatalogo('inundacion', Icons.flood_outlined),
  OpcionCatalogo('perro', Icons.pets),
  OpcionCatalogo('via_cerrada', Icons.block),
  OpcionCatalogo('accidente', Icons.car_crash_outlined),
  OpcionCatalogo('zona_insegura', Icons.shield_outlined),
  OpcionCatalogo('cable_caido', Icons.electrical_services),
  OpcionCatalogo(claveOtro, Icons.more_horiz),
];

/// Texto de un tipo de alerta en el idioma de la app. Con "otro" muestra lo
/// que escribio quien reporto (si escribio algo); una clave desconocida (dato
/// viejo de texto libre) se muestra tal cual.
String tipoAlertaLabel(AppLocalizations l10n, String clave, {String? otro}) {
  switch (clave) {
    case 'arbol_caido':
      return l10n.alertaTipoArbolCaido;
    case 'bache':
      return l10n.alertaTipoBache;
    case 'derrumbe':
      return l10n.alertaTipoDerrumbe;
    case 'inundacion':
      return l10n.alertaTipoInundacion;
    case 'perro':
      return l10n.alertaTipoPerro;
    case 'via_cerrada':
      return l10n.alertaTipoViaCerrada;
    case 'accidente':
      return l10n.alertaTipoAccidente;
    case 'zona_insegura':
      return l10n.alertaTipoZonaInsegura;
    case 'cable_caido':
      return l10n.alertaTipoCableCaido;
    case claveOtro:
      final String texto = otro?.trim() ?? '';
      return texto.isEmpty ? l10n.alertaTipoOtro : texto;
    default:
      return clave;
  }
}

/// El icono "lleno" de cada tipo de alerta, el que va dentro de su pin en el
/// mapa y en su ficha (los de [tiposAlerta] son de contorno, para el selector).
/// Un tipo desconocido usa el triangulo de advertencia.
IconData iconoAlerta(String tipo) {
  switch (tipo) {
    case 'arbol_caido':
      return Icons.park_rounded;
    case 'bache':
      return Icons.report_problem_rounded;
    case 'derrumbe':
      return Icons.landscape_rounded;
    case 'inundacion':
      return Icons.flood_rounded;
    case 'perro':
      return Icons.pets_rounded;
    case 'via_cerrada':
      return Icons.block_rounded;
    case 'accidente':
      return Icons.car_crash_rounded;
    case 'zona_insegura':
      return Icons.shield_rounded;
    case 'cable_caido':
      return Icons.electrical_services_rounded;
    default:
      return Icons.warning_amber_rounded;
  }
}

/// El color de una alerta segun su gravedad (`baja`, `media`, `alta`): ambar,
/// naranja y rojo.
Color colorGravedadAlerta(String gravedad) {
  switch (gravedad) {
    case 'alta':
      return FqColors.risk;
    case 'baja':
      return FqColors.amber;
    default:
      return const Color(0xFFF08A24);
  }
}
