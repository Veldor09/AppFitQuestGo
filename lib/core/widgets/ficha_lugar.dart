import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Piezas compartidas de las fichas de detalle (nodo, evento, ruta), con el
/// mismo orden que una ficha de lugar de un mapa: agarre, titulo con su boton
/// de cerrar, una linea de datos (pulgares, categoria...), una fila de
/// acciones en pastilla y secciones de contenido.

/// Abre la app de mapas con la ruta a pie hasta ([lat], [lng]). En pruebas se
/// pasa [abrir] para no lanzar nada de verdad.
Future<void> abrirComoLlegar(
  BuildContext context, {
  required double lat,
  required double lng,
  Future<bool> Function(Uri uri)? abrir,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context)!;
  final Uri uri = Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    'destination': '$lat,$lng',
    'travelmode': 'walking',
  });
  bool abierto = false;
  try {
    abierto = await (abrir?.call(uri) ??
        launchUrl(uri, mode: LaunchMode.externalApplication));
  } catch (_) {
    abierto = false;
  }
  if (!abierto) notificarError(l10n.fichaNoSePudoAbrirMapa);
}

/// La hoja inferior con las esquinas redondeadas de las fichas. Quien abre la
/// ficha usa estos valores en `showModalBottomSheet`.
const ShapeBorder formaFichaLugar = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
);

/// Agarre y cabecera de la ficha: la rayita para arrastrar y, debajo, el
/// titulo grande con el subtitulo y el boton de cerrar.
class CabeceraFicha extends StatelessWidget {
  const CabeceraFicha({
    super.key,
    required this.titulo,
    this.keyTitulo,
    this.subtitulo,
    this.icono,
    this.etiquetas = const <Widget>[],
    this.onCerrar,
  });

  final String titulo;

  /// Llave del texto del titulo (para pruebas).
  final Key? keyTitulo;
  final String? subtitulo;

  /// Icono de la categoria a la izquierda del titulo.
  final Widget? icono;

  /// Etiquetas a la derecha del subtitulo (estado, destacado...).
  final List<Widget> etiquetas;

  /// Por defecto cierra la hoja.
  final VoidCallback? onCerrar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: FqColors.stone,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (icono != null) ...<Widget>[icono!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    titulo,
                    key: keyTitulo ?? const ValueKey<String>('ficha-titulo'),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.4,
                      color: FqColors.ink,
                    ),
                  ),
                  if (subtitulo != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      subtitulo!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: FqColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: FqColors.cloud,
              shape: const CircleBorder(),
              child: IconButton(
                key: const ValueKey<String>('ficha-cerrar'),
                tooltip: l10n.fichaCerrar,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onCerrar ?? () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
        if (etiquetas.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: etiquetas),
        ],
      ],
    );
  }
}

/// Una accion de la fila de la ficha: icono y texto en una pastilla. La
/// [principal] va rellena de oscuro, como "Cómo llegar" en una ficha de lugar.
class AccionFicha extends StatelessWidget {
  const AccionFicha({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.principal = false,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? onTap;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final Color fondo = principal ? FqColors.night : FqColors.chipSelectedBg;
    final Color frente = principal ? FqColors.white : FqColors.chipSelectedInk;
    return Material(
      color: onTap == null ? fondo.withValues(alpha: 0.5) : fondo,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icono, size: 18, color: frente),
              const SizedBox(width: 7),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: frente,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Las acciones de la ficha en una fila que se desplaza si no caben.
class FilaAccionesFicha extends StatelessWidget {
  const FilaAccionesFicha({super.key, required this.acciones});

  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < acciones.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            acciones[i],
          ],
        ],
      ),
    );
  }
}

/// Una seccion de la ficha: un titulo corto y su contenido.
class SeccionFicha extends StatelessWidget {
  const SeccionFicha({super.key, required this.titulo, required this.hijo});

  final String titulo;
  final Widget hijo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: FqColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        hijo,
      ],
    );
  }
}

/// Fila de "icono + texto" de los datos de la ficha (fecha, organizador...).
class DatoFicha extends StatelessWidget {
  const DatoFicha({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icono, size: 18, color: FqColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: FqColors.ink,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo suave con borde para agrupar un bloque dentro de la ficha.
class TarjetaFicha extends StatelessWidget {
  const TarjetaFicha({super.key, required this.hijo, this.color});

  final Widget hijo;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? FqColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FqColors.border),
      ),
      child: hijo,
    );
  }
}
