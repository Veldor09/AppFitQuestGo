import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/decoracion_flotante.dart';

/// La campana de arriba a la derecha del mapa. Si hay notificaciones sin leer
/// lleva encima un globito rojo con cuantas son (9+ desde 10); si no, va limpia.
/// Es solo presentacion: quien la usa sabe el conteo y que abre al tocarla.
class CampanaNotificaciones extends StatelessWidget {
  const CampanaNotificaciones({
    super.key,
    required this.noLeidas,
    required this.onTap,
  });

  final int noLeidas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool hayNuevas = noLeidas > 0;
    return Semantics(
      button: true,
      label: hayNuevas
          ? l10n.homeNotificacionesSinLeer(noLeidas)
          : l10n.homeNotificaciones,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: decoracionFlotante(radius: 17),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: <Widget>[
              Icon(
                hayNuevas
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                size: 27,
              ),
              if (hayNuevas)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    key: const ValueKey<String>('campana-contador'),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: FqColors.risk,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: FqColors.white, width: 1.5),
                    ),
                    child: Text(
                      noLeidas > 9 ? '9+' : '$noLeidas',
                      style: const TextStyle(
                        color: FqColors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
