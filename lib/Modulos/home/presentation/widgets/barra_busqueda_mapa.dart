import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/decoracion_flotante.dart';

/// La barra de busqueda de arriba del mapa. Quien la usa pone el
/// [controller] y el [focusNode] (para saber si esta escribiendo) y decide que
/// hacer con lo escrito ([onChanged]) y al borrarlo ([onLimpiar], que debe
/// vaciar el controlador).
class BarraBusquedaMapa extends StatelessWidget {
  const BarraBusquedaMapa({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onLimpiar,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 15, right: 4),
      decoration: decoracionFlotante(radius: 18),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search_rounded, color: FqColors.muted, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 13, color: FqColors.ink),
              // El tema global rellena y bordea todos los campos de texto:
              // aqui la propia barra es la caja, asi que se apaga todo.
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: l10n.homeBuscarPlaceholder,
                hintStyle: const TextStyle(color: FqColors.muted, fontSize: 12),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (BuildContext context, Widget? _) {
              if (controller.text.isEmpty) return const SizedBox(width: 11);
              return IconButton(
                onPressed: onLimpiar,
                tooltip: l10n.homeBuscarLimpiar,
                icon: const Icon(Icons.close_rounded, size: 19),
                color: FqColors.muted,
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ],
      ),
    );
  }
}
