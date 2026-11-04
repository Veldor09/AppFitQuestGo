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
    this.onFilters,
    this.filtersKey,
    this.trailing,
    this.onRefresh,
    this.refreshing = false,
    this.showSearch = true,
  });

  final String searchHint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Accion personalizada del boton Filtros.
  /// Si no se proporciona, conserva el comportamiento anterior.
  final VoidCallback? onFilters;
  final Key? filtersKey;

  final Widget? trailing;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;
        return Wrap(
          spacing: FqGap.sm,
          runSpacing: FqGap.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (showSearch)
              SizedBox(
                width: mobile ? constraints.maxWidth : 360,
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
                          style: const TextStyle(
                            fontSize: 11,
                            color: FqColors.ink,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
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
            _FiltrosButton(key: filtersKey, onPressed: onFilters),
            if (onRefresh != null)
              AdminRefreshButton(onPressed: refreshing ? null : onRefresh),
            ?trailing,
          ],
        );
      },
    );
  }
}

class AdminRefreshButton extends StatelessWidget {
  const AdminRefreshButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Actualizar',
      child: Material(
        color: FqColors.white,
        borderRadius: FqRadius.allMd,
        child: InkWell(
          onTap: onPressed,
          borderRadius: FqRadius.allMd,
          child: Container(
            height: 37,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: FqRadius.allMd,
              border: Border.all(color: FqColors.border),
            ),
            child: const Icon(
              Icons.refresh_rounded,
              size: 19,
              color: FqColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltrosButton extends StatelessWidget {
  const _FiltrosButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FqColors.white,
      borderRadius: FqRadius.allMd,
      child: InkWell(
        borderRadius: FqRadius.allMd,
        onTap:
            onPressed ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filtros: pendiente de backend.')),
              );
            },
        child: Container(
          height: 37,
          decoration: BoxDecoration(
            borderRadius: FqRadius.allMd,
            border: Border.all(color: FqColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
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
