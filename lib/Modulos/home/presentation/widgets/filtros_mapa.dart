import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/home/application/filtro_mapa.dart';

/// Los chips de arriba del mapa: Todo, Rutas, Alertas, POIs y Eventos. El
/// seleccionado va oscuro; tocar otro avisa con [onCambio]. Es solo
/// presentacion: quien la usa decide que cambia en el mapa.
///
/// Si no caben en una linea (pantalla angosta, textos largos en portugues) pasan
/// a la siguiente: una fila que se desliza taparia los gestos del mapa en toda
/// esa franja.
class FiltrosMapa extends StatelessWidget {
  const FiltrosMapa({
    super.key,
    required this.seleccionado,
    required this.onCambio,
  });

  final FiltroMapa seleccionado;
  final ValueChanged<FiltroMapa> onCambio;

  static String etiqueta(AppLocalizations l10n, FiltroMapa filtro) {
    return switch (filtro) {
      FiltroMapa.todo => l10n.homeFiltroTodo,
      FiltroMapa.rutas => l10n.rutasTitulo,
      FiltroMapa.alertas => l10n.homeFiltroAlertas,
      FiltroMapa.pois => l10n.homeFiltroPois,
      FiltroMapa.eventos => l10n.comunEventos,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Wrap(
          runSpacing: 7,
          children: <Widget>[
            for (final FiltroMapa filtro in FiltroMapa.values)
              _Chip(
                key: ValueKey<String>('filtro-${filtro.name}'),
                texto: etiqueta(l10n, filtro),
                seleccionado: filtro == seleccionado,
                onTap: () => onCambio(filtro),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.texto,
    required this.seleccionado,
    required this.onTap,
  });

  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionado,
      label: texto,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 7),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: seleccionado
                ? FqColors.night
                : FqColors.paper.withValues(alpha: .88),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: seleccionado ? FqColors.white : FqColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
