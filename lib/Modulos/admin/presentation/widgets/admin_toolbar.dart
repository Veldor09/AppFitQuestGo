import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Barra de herramientas de las pantallas de lista (`.fq-admin-toolbar`):
/// buscador + boton "Filtros" + accion opcional a la derecha.
class AdminToolbar extends StatelessWidget {
  const AdminToolbar({
    super.key,
    required this.searchHint,
    this.controller,
    this.onChanged,
    this.trailing,
  });

  final String searchHint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: FqGap.sm,
      runSpacing: FqGap.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 360),
          child: Container(
            height: 37,
            decoration: BoxDecoration(
              color: FqColors.white,
              borderRadius: FqRadius.allMd,
              border: Border.all(color: FqColors.searchBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.search, size: 15, color: FqColors.muted),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    enabled: controller != null || onChanged != null,
                    style: const TextStyle(fontSize: 11, color: FqColors.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      hintText: searchHint,
                      hintStyle: const TextStyle(
                        fontSize: 11,
                        color: FqColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _FiltrosButton(),
        ?trailing,
      ],
    );
  }
}

class _FiltrosButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: FqColors.white,
      borderRadius: FqRadius.allMd,
      child: InkWell(
        borderRadius: FqRadius.allMd,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Filtros: pendiente de backend.')),
        ),
        child: Container(
          height: 37,
          decoration: BoxDecoration(
            borderRadius: FqRadius.allMd,
            border: Border.all(color: FqColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: const Row(
            children: <Widget>[
              Icon(Icons.tune, size: 14, color: FqColors.ink),
              SizedBox(width: 5),
              Text(
                'Filtros',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: FqColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
