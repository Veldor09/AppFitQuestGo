import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_field_display.dart';
import 'package:fit_quest_go/core/widgets/fq_map_view.dart';
import 'package:fit_quest_go/core/widgets/fq_panel.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_note.dart';

/// ADM-05 · Revision de ruta. Mapa + ficha de decision (aprobar / pedir
/// correccion / rechazar).
///
/// Maqueta: sin ruta seleccionada los datos son "—" y las acciones quedan
/// deshabilitadas. La disposicion mapa + ficha es la del diseno.
class RevisionRutaScreen extends StatelessWidget {
  const RevisionRutaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final Widget mapa = FqPanel(
            child: Stack(
              children: <Widget>[
                const FqMapView(height: 320, showRoute: true),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: _ReviewWarning(
                    'Aqui se marcaria una advertencia de trazado (p. ej. cruce '
                    'por zona privada).',
                  ),
                ),
              ],
            ),
          );

          final Widget ficha = FqPanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: FqTag('Pendiente', tone: FqTagTone.amber),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sin ruta seleccionada',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: FqColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Elige una ruta en "Gestion de rutas" para revisarla.',
                  style: TextStyle(fontSize: 9, color: FqColors.muted),
                ),
                const SizedBox(height: FqGap.lg),
                const _MetricGrid(
                  items: <(String, String)>[
                    ('km', '—'),
                    ('m elev.', '—'),
                    ('estimado', '—'),
                  ],
                ),
                const SizedBox(height: FqGap.lg),
                const AdminNote(
                  title: 'Verificacion de GPS',
                  detail: 'Aqui se resumiria el analisis del trazado.',
                  icon: Icons.gps_fixed,
                ),
                const SizedBox(height: FqGap.lg),
                const FqFieldDisplay(label: 'Nota interna', multiline: true),
                const SizedBox(height: FqGap.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FqButton.secondary(
                        label: 'Pedir correccion',
                        dense: true,
                        onPressed: null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FqButton.danger(
                        label: 'Rechazar',
                        dense: true,
                        onPressed: null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FqButton.primary(
                        label: 'Aprobar',
                        dense: true,
                        onPressed: null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (c.maxWidth < 780) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[mapa, const SizedBox(height: FqGap.lg), ficha],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 115, child: mapa),
              const SizedBox(width: FqGap.lg),
              Expanded(flex: 85, child: ficha),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewWarning extends StatelessWidget {
  const _ReviewWarning(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0C9),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded,
              size: 14, color: Color(0xFF8C4E0C)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: Color(0xFF8C4E0C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: FqRadius.allLg,
        border: Border.all(color: FqColors.border),
      ),
      child: ClipRRect(
        borderRadius: FqRadius.allLg,
        child: IntrinsicHeight(
          child: Row(
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: i == items.length - 1
                              ? Colors.transparent
                              : FqColors.border,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: <Widget>[
                        Text(
                          items[i].$2,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: FqColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$1.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 7,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w600,
                            color: FqColors.muted,
                          ),
                        ),
                      ],
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
