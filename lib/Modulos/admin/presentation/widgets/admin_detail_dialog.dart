import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';

/// Presentacion comun de los detalles de solo lectura del panel administrativo.
Future<String?> mostrarDetalleAdmin(
  BuildContext context, {
  required String titulo,
  required IconData icono,
  required String estado,
  required Map<String, String> campos,
  Map<String, String> acciones = const <String, String>{},
  Widget? extra,
  Key? dialogKey,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 190),
    pageBuilder: (dialogContext, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(dialogContext).height - 40,
          ),
          child: Material(
            key: dialogKey,
            color: FqColors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: FqColors.volt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icono, size: 23, color: FqColors.night),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: FqColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FqTag(estado, tone: _tonoEstado(estado)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: FqColors.border),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final entry in campos.entries)
                            _DetalleLinea(
                              label: entry.key,
                              value: entry.value,
                              ultimo: entry.key == campos.keys.last,
                            ),
                          ?extra,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cerrar'),
                      ),
                      for (final action in acciones.entries)
                        TextButton(
                          key: ValueKey<String>('accion-${action.key}'),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(action.key),
                          child: Text(action.value),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: ColoredBox(
          color: const Color(0x5A0B1220),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(animation),
            child: child,
          ),
        ),
      ),
    ),
  );
}

FqTagTone _tonoEstado(String estado) {
  final value = estado.toLowerCase();
  if (value.contains('aprob') ||
      value.contains('activ') ||
      value.contains('public')) {
    return FqTagTone.green;
  }
  if (value.contains('pendient')) return FqTagTone.amber;
  if (value.contains('rechaz') ||
      value.contains('deneg') ||
      value.contains('desactiv')) {
    return FqTagTone.red;
  }
  return FqTagTone.dark;
}

class _DetalleLinea extends StatelessWidget {
  const _DetalleLinea({
    required this.label,
    required this.value,
    required this.ultimo,
  });

  final String label;
  final String value;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: ultimo
            ? null
            : const Border(bottom: BorderSide(color: FqColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: FqColors.fieldLabel,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: FqColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
