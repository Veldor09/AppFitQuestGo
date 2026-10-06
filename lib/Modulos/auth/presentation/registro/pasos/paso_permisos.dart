import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// APP-07 · Registro · Permisos. Explica y "solicita" los permisos criticos.
///
/// En web no hay permisos nativos que pedir; los interruptores quedan como
/// preferencia inicial del usuario. La creacion de la cuenta se dispara con el
/// boton del flujo, no aqui.
///
/// `valores`/`onToggle` viajan por clave estable (ver `_RegistroFlujoScreenState._permisos`),
/// no por el texto visible: mismo criterio que `PasoActividades`/`PasoIntereses`.
class PasoPermisos extends StatelessWidget {
  const PasoPermisos({
    super.key,
    required this.valores,
    required this.onToggle,
  });

  final Map<String, bool> valores;
  final void Function(String clave, bool valor) onToggle;

  static const List<(String, IconData)> _claves = <(String, IconData)>[
    ('ubicacion', Icons.my_location),
    ('notificaciones', Icons.notifications_none),
    ('actividadFisica', Icons.favorite_border),
  ];

  static (String, String) _textos(AppLocalizations l10n, String clave) {
    switch (clave) {
      case 'ubicacion':
        return (l10n.permisoUbicacionTitulo, l10n.permisoUbicacionDetalle);
      case 'notificaciones':
        return (
          l10n.permisoNotificacionesTitulo,
          l10n.permisoNotificacionesDetalle,
        );
      default:
        return (
          l10n.permisoActividadFisicaTitulo,
          l10n.permisoActividadFisicaDetalle,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<Widget> tiles = <Widget>[];
    for (final (String clave, IconData icon) in _claves) {
      final (String titulo, String detalle) = _textos(l10n, clave);
      tiles.add(
        Padding(
          padding: const EdgeInsets.only(bottom: FqGap.md),
          child: _PermisoTile(
            icon: icon,
            titulo: titulo,
            detalle: detalle,
            valor: valores[clave] ?? false,
            onChanged: (bool v) => onToggle(clave, v),
          ),
        ),
      );
    }
    return Column(children: tiles);
  }
}

class _PermisoTile extends StatelessWidget {
  const _PermisoTile({
    required this.icon,
    required this.titulo,
    required this.detalle,
    required this.valor,
    required this.onChanged,
  });

  final IconData icon;
  final String titulo;
  final String detalle;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 59),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: FqRadius.allLg,
        border: Border.all(color: const Color(0xFFDCE2DA)),
      ),
      padding: const EdgeInsets.all(9),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF3EB),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: FqColors.night),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FqColors.ink,
                  ),
                ),
                Text(
                  detalle,
                  style: const TextStyle(fontSize: 10, color: FqColors.muted),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: valor,
            onChanged: onChanged,
            activeTrackColor: FqColors.voltDark,
            inactiveTrackColor: FqColors.toggleOff,
          ),
        ],
      ),
    );
  }
}
