import 'package:flutter/material.dart';

import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/seleccion_widgets.dart';

/// APP-05 · Registro · Actividades. Seleccion multiple de deportes.
/// Presentacion pura: el estado lo mantiene `RegistroFlujoScreen`.
class PasoActividades extends StatelessWidget {
  const PasoActividades({
    super.key,
    required this.seleccion,
    required this.onToggle,
  });

  final Set<String> seleccion;
  final ValueChanged<String> onToggle;

  static const List<(String, IconData)> _opciones = <(String, IconData)>[
    ('Running', Icons.directions_run),
    ('Ciclismo', Icons.directions_bike),
    ('MTB', Icons.pedal_bike),
    ('Hiking', Icons.hiking),
    ('Caminata', Icons.directions_walk),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PasoIntro(
          titulo: 'Que actividades practicas?',
          bajada: 'Selecciona todas las que quieras.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            const double gap = 8;
            final double itemW = (c.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final (String label, IconData icon) in _opciones)
                  SizedBox(
                    width: itemW,
                    child: ChoiceOption(
                      icon: icon,
                      label: label,
                      selected: seleccion.contains(label),
                      onTap: () => onToggle(label),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
