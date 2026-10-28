import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/fotos/selector_foto.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

class CampoFoto extends StatelessWidget {
  const CampoFoto({
    super.key,
    required this.foto,
    required this.alCambiar,
    this.selector,
    this.habilitado = true,
    this.yaTiene = false,
  });

  final Uint8List? foto;
  final ValueChanged<Uint8List?> alCambiar;

  final SelectorFoto? selector;
  final bool habilitado;

  final bool yaTiene;

  Future<void> _elegir(OrigenFoto origen) async {
    final Uint8List? bytes = await (selector ?? SelectorFotoImagePicker())
        .elegir(origen);
    if (bytes != null) alCambiar(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Uint8List? elegida = foto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.nodosFotoTitulo,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: FqColors.muted,
          ),
        ),
        if (yaTiene && elegida == null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            l10n.fotoYaTiene,
            style: const TextStyle(fontSize: 11.5, color: FqColors.muted),
          ),
        ],
        const SizedBox(height: 8),
        if (elegida == null)
          Row(
            children: <Widget>[
              Expanded(
                child: FqButton.secondary(
                  key: const ValueKey<String>('foto-camara'),
                  label: l10n.nodosFotoCamara,
                  icon: Icons.photo_camera_outlined,
                  dense: true,
                  onPressed: habilitado
                      ? () => _elegir(OrigenFoto.camara)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FqButton.secondary(
                  key: const ValueKey<String>('foto-galeria'),
                  label: l10n.nodosFotoGaleria,
                  icon: Icons.photo_library_outlined,
                  dense: true,
                  onPressed: habilitado
                      ? () => _elegir(OrigenFoto.galeria)
                      : null,
                ),
              ),
            ],
          )
        else
          Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  elegida,
                  key: const ValueKey<String>('foto-elegida'),
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: TextButton.icon(
                  key: const ValueKey<String>('foto-quitar'),
                  onPressed: habilitado ? () => alCambiar(null) : null,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(
                    l10n.nodosFotoQuitar,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
