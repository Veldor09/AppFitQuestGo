import 'package:flutter/material.dart';

import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/seleccion_widgets.dart';

/// APP-06 · Registro · Intereses. Nube de chips para personalizar el mapa.
class PasoIntereses extends StatelessWidget {
  const PasoIntereses({
    super.key,
    required this.seleccion,
    required this.onToggle,
  });

  final Set<String> seleccion;
  final ValueChanged<String> onToggle;

  static const List<String> _opciones = <String>[
    'Rutas nuevas',
    'Eventos',
    'Retos',
    'Naturaleza',
    'Cultura',
    'Comunidad',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PasoIntro(
          titulo: 'Personaliza tu mapa',
          bajada: 'Esto mejora tus recomendaciones.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            for (final String label in _opciones)
              SelectableChip(
                label: label,
                selected: seleccion.contains(label),
                onTap: () => onToggle(label),
              ),
          ],
        ),
      ],
    );
  }
}
