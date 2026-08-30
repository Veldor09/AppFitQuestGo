import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Encabezado de un paso de personalizacion: titulo + bajada.
class PasoIntro extends StatelessWidget {
  const PasoIntro({super.key, required this.titulo, required this.bajada});

  final String titulo;
  final String bajada;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: FqColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          bajada,
          style: const TextStyle(fontSize: 11, height: 1.5, color: FqColors.muted),
        ),
      ],
    );
  }
}

/// Opcion de la cuadricula de seleccion (`.fq-choice-grid > button`).
class ChoiceOption extends StatelessWidget {
  const ChoiceOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FqColors.choiceSelectedBg : FqColors.white,
      borderRadius: FqRadius.allButton,
      child: InkWell(
        borderRadius: FqRadius.allButton,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 55),
          decoration: BoxDecoration(
            borderRadius: FqRadius.allButton,
            border: Border.all(
              color: selected ? FqColors.voltDark : const Color(0xFFDAE0D8),
              width: selected ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: FqColors.night),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: FqColors.ink,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    size: 15, color: FqColors.voltDark),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip seleccionable (`.fq-chip-cloud button`).
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FqColors.chipSelectedBg : FqColors.white,
      borderRadius: FqRadius.allPill,
      child: InkWell(
        borderRadius: FqRadius.allPill,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: FqRadius.allPill,
            border: Border.all(
              color: selected ? FqColors.voltDark : const Color(0xFFD9DFD7),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? FqColors.chipSelectedInk : FqColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
