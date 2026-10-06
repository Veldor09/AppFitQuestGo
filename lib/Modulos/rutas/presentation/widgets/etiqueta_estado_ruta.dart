import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';

/// Etiqueta del estado de una ruta (Privada / Pendiente / Publicada /
/// Rechazada), traducida y con su color.
class EtiquetaEstadoRuta extends StatelessWidget {
  const EtiquetaEstadoRuta(this.estado, {super.key});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return FqTag(estadoRutaLabel(l10n, estado), tone: _tono(estado));
  }

  static FqTagTone _tono(String estado) {
    switch (estado) {
      case 'Publicada':
        return FqTagTone.green;
      case 'Pendiente':
        return FqTagTone.amber;
      case 'Rechazada':
        return FqTagTone.red;
      default:
        return FqTagTone.neutral;
    }
  }
}
