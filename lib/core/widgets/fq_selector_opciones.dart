import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/opcion_catalogo.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Opciones de una lista cerrada como chips con icono (en vez de un campo de
/// texto libre, que invita a errores de tipeo). No decide si la seleccion es
/// simple o multiple: avisa con la clave tocada (`onToggle`) y quien lo usa
/// actualiza `seleccion` como corresponda.
class FqSelectorOpciones extends StatelessWidget {
  const FqSelectorOpciones({
    super.key,
    required this.opciones,
    required this.etiqueta,
    required this.seleccion,
    required this.onToggle,
    this.errorTexto,
  });

  final List<OpcionCatalogo> opciones;

  /// Texto visible de una clave (ya traducido).
  final String Function(String clave) etiqueta;
  final Set<String> seleccion;
  final ValueChanged<String> onToggle;

  /// Mensaje en rojo debajo de las opciones (p. ej. "Elegi al menos una").
  final String? errorTexto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final OpcionCatalogo opcion in opciones)
              _Opcion(
                key: ValueKey<String>('opcion-${opcion.clave}'),
                opcion: opcion,
                texto: etiqueta(opcion.clave),
                seleccionada: seleccion.contains(opcion.clave),
                onTap: () => onToggle(opcion.clave),
              ),
          ],
        ),
        if (errorTexto != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            errorTexto!,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: FqColors.risk,
            ),
          ),
        ],
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    super.key,
    required this.opcion,
    required this.texto,
    required this.seleccionada,
    required this.onTap,
  });

  final OpcionCatalogo opcion;
  final String texto;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionada,
      label: texto,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: seleccionada ? FqColors.chipSelectedBg : FqColors.white,
        borderRadius: FqRadius.allPill,
        child: InkWell(
          borderRadius: FqRadius.allPill,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: FqRadius.allPill,
              border: Border.all(
                color: seleccionada ? FqColors.voltDark : const Color(0xFFD9DFD7),
                width: seleccionada ? 1.6 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(opcion.icono, size: 16, color: FqColors.night),
                const SizedBox(width: 6),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: seleccionada ? FontWeight.w800 : FontWeight.w600,
                    color: seleccionada ? FqColors.chipSelectedInk : FqColors.ink,
                  ),
                ),
                if (seleccionada) ...<Widget>[
                  const SizedBox(width: 5),
                  const Icon(Icons.check_circle, size: 14, color: FqColors.voltDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
