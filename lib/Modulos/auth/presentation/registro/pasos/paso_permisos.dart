import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// APP-07 · Registro · Permisos. Explica y "solicita" los permisos criticos.
///
/// En web no hay permisos nativos que pedir; los interruptores quedan como
/// preferencia inicial del usuario. La creacion de la cuenta se dispara con el
/// boton del flujo, no aqui.
class PasoPermisos extends StatelessWidget {
  const PasoPermisos({
    super.key,
    required this.valores,
    required this.onToggle,
  });

  final Map<String, bool> valores;
  final void Function(String clave, bool valor) onToggle;

  static const List<(String, String, IconData)> _items =
      <(String, String, IconData)>[
    ('Ubicacion', 'Mapa vivo y tracking de rutas', Icons.my_location),
    ('Notificaciones', 'Estados, eventos y alertas cercanas',
        Icons.notifications_none),
    ('Actividad fisica', 'Metricas durante el recorrido',
        Icons.favorite_border),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final (String titulo, String detalle, IconData icon) in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: FqGap.md),
            child: _PermisoTile(
              icon: icon,
              titulo: titulo,
              detalle: detalle,
              valor: valores[titulo] ?? false,
              onChanged: (bool v) => onToggle(titulo, v),
            ),
          ),
      ],
    );
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
