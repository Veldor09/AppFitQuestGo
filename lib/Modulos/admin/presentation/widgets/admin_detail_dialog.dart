import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

Future<void> mostrarDetalleAdmin(
  BuildContext context, {
  required String titulo,
  required IconData icono,
  required String estado,
  required Map<String, String> campos,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: FqColors.listIconBg,
                    child: Icon(icono, size: 17, color: FqColors.ink),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          estado,
                          style: const TextStyle(
                            fontSize: 10,
                            color: FqColors.muted,
                          ),
                        ),
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
              const Divider(height: 22),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final entry in campos.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                entry.key.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: FqColors.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                entry.value.isEmpty ? '—' : entry.value,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: FqColors.ink,
                                ),
                              ),
                              const Divider(height: 12),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
