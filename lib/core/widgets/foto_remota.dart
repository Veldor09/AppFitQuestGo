import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/visor_imagen.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

class FotoRemota extends StatefulWidget {
  const FotoRemota({
    super.key,
    required this.cargar,
    this.altura = 200,
    this.titulo,
    this.llave = const ValueKey<String>('foto-remota'),
    this.alReportar,
  });

  final Future<Uint8List> Function() cargar;
  final double altura;

  final String? titulo;

  final Key llave;

  final VoidCallback? alReportar;

  @override
  State<FotoRemota> createState() => _FotoRemotaState();
}

class _FotoRemotaState extends State<FotoRemota> {
  late final Future<Uint8List> _bytes = widget.cargar();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.altura,
        width: double.infinity,
        child: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (BuildContext context, AsyncSnapshot<Uint8List> snap) {
            if (snap.hasData) {
              return GestureDetector(
                key: widget.llave,
                onTap: () => mostrarVisorImagen(
                  context,
                  snap.data!,
                  titulo: widget.titulo,
                  alReportar: widget.alReportar,
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
            const Icon(
              Icons.image_not_supported_outlined,
              color: FqColors.muted,
            ),
            const SizedBox(height: 6),
            Text(
              mensaje,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FqColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
