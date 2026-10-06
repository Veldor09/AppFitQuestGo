import 'package:flutter/material.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/seleccion_widgets.dart';

/// APP-06 · Registro · Intereses. Nube de chips para personalizar el mapa.
///
/// `seleccion`/`onToggle` viajan por clave estable, no por el texto visible
/// (mismo criterio que `PasoActividades`).
class PasoIntereses extends StatelessWidget {
  const PasoIntereses({
    super.key,
    required this.seleccion,
    required this.onToggle,
  });

  final Set<String> seleccion;
  final ValueChanged<String> onToggle;

  static const List<String> _claves = <String>[
    'rutasNuevas',
    'eventos',
    'retos',
    'naturaleza',
    'cultura',
    'comunidad',
  ];

  static String _etiqueta(AppLocalizations l10n, String clave) {
    switch (clave) {
      case 'rutasNuevas':
        return l10n.interesRutasNuevas;
      case 'eventos':
        return l10n.interesEventos;
      case 'retos':
        return l10n.interesRetos;
      case 'naturaleza':
        return l10n.interesNaturaleza;
      case 'cultura':
        return l10n.interesCultura;
      default:
        return l10n.interesComunidad;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PasoIntro(
          titulo: l10n.registroInteresesTitulo,
          bajada: l10n.registroInteresesBajada,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            for (final String clave in _claves)
              SelectableChip(
                label: _etiqueta(l10n, clave),
                selected: seleccion.contains(clave),
                onTap: () => onToggle(clave),
              ),
          ],
        ),
      ],
    );
  }
}
