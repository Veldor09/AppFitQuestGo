import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/visor_imagen.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

class FotoNodo extends StatefulWidget {
  const FotoNodo({
    super.key,
    required this.api,
    required this.nodoId,
    this.altura = 200,
    this.titulo,
  });

  final NodoApi api;
  final int nodoId;
  final double altura;

  /// Se muestra al pie de la imagen a pantalla completa (el nombre del punto).
  final String? titulo;

  @override
  State<FotoNodo> createState() => _FotoNodoState();
}

class _FotoNodoState extends State<FotoNodo> {
  late final Future<Uint8List> _bytes = widget.api.foto(widget.nodoId);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.altura,
        width: double.infinity,
        child: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (BuildContext context, AsyncSnapshot<Uint8List> snap) {
            if (snap.hasData) {
              return GestureDetector(
                key: const ValueKey<String>('foto-nodo'),
                onTap: () => mostrarVisorImagen(
                  context,
                  snap.data!,
                  titulo: widget.titulo,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.memory(
                      snap.data!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                          _Aviso(l10n.nodosFotoNoDisponible),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.zoom_out_map_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            if (snap.hasError) return _Aviso(l10n.nodosFotoNoDisponible);
            return const ColoredBox(
              color: FqColors.cloud,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FqColors.cloud,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.image_not_supported_outlined, color: FqColors.muted),
            const SizedBox(height: 6),
            Text(
              mensaje,
              style: const TextStyle(fontSize: 11, color: FqColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
