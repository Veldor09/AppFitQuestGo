import 'package:flutter/material.dart';

import 'package:fit_quest_go/Modulos/calificaciones/application/resumen_remoto.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion_api.dart';
import 'package:fit_quest_go/Modulos/calificaciones/presentation/pulgares.dart';
import 'package:fit_quest_go/Modulos/rutas/application/metricas_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';
import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/ficha_lugar.dart';
import 'package:fit_quest_go/core/widgets/fq_icono_dificultad.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Abre la ficha de una ruta desde abajo al tocar su pin en el mapa de exploración:
/// muestra sus datos clave, actividades, métricas y botones rápidos sin salir del mapa.
Future<void> mostrarFichaRuta(
  BuildContext context,
  Ruta ruta, {
  VoidCallback? alIniciar,
  VoidCallback? alVerDetalle,
  CalificacionApi? calificaciones,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: formaFichaLugar,
    builder: (BuildContext _) => FichaRuta(
      ruta: ruta,
      alIniciar: alIniciar,
      alVerDetalle: alVerDetalle,
      calificaciones: calificaciones,
    ),
  );
}

class FichaRuta extends StatefulWidget {
  const FichaRuta({
    super.key,
    required this.ruta,
    this.alIniciar,
    this.alVerDetalle,
    this.calificaciones,
  });

  final Ruta ruta;
  final VoidCallback? alIniciar;
  final VoidCallback? alVerDetalle;
  final CalificacionApi? calificaciones;

  @override
  State<FichaRuta> createState() => _FichaRutaState();
}

class _FichaRutaState extends State<FichaRuta> {
  late final ResumenRemoto _pulgares = ResumenRemoto(
    tipo: TipoCalificable.ruta,
    id: widget.ruta.id,
    api: widget.calificaciones,
  );

  @override
  void initState() {
    super.initState();
    _pulgares.cargar();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Ruta ruta = widget.ruta;

    final int tiempoEstimadoMin =
        (ruta.distanciaKm * 6).round().clamp(5, 360);
    final int desnivelEstimadoM =
        (ruta.distanciaKm * 28).round().clamp(10, 1500);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Cabecera con título, dificultad y cerrar
          CabeceraFicha(
            titulo: ruta.nombre,
            keyTitulo: ValueKey<String>('ficha-ruta-titulo-${ruta.id}'),
            subtitulo: actividadesLabel(l10n, ruta.actividades),
            icono: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: FqColors.river.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: FqColors.river,
                size: 24,
              ),
            ),
            etiquetas: <Widget>[
              EtiquetaDificultad(
                dificultad: ruta.dificultad,
                texto: dificultadLabel(l10n, ruta.dificultad),
              ),
            ],
            onCerrar: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 16),

          // Métricas clave (Distancia, Tiempo, Desnivel)
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricaFicha(
                  etiqueta: l10n.rutasDistancia,
                  valor: '${ruta.distanciaKm.toStringAsFixed(2)} km',
                  icono: Icons.straighten_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricaFicha(
                  etiqueta: l10n.grabacionTiempo,
                  valor: formatoDuracion(Duration(minutes: tiempoEstimadoMin)),
                  icono: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricaFicha(
                  etiqueta: 'Desnivel',
                  valor: '+$desnivelEstimadoM m',
                  icono: Icons.terrain_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calificación con pulgares
          AnimatedBuilder(
            animation: _pulgares,
            builder: (BuildContext _, Widget? _) {
              final ResumenCalificacion? r = _pulgares.resumen;
              if (r == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PulgaresObjeto(
                  tipo: TipoCalificable.ruta,
                  id: widget.ruta.id,
                  api: widget.calificaciones,
                  resumenInicial: r,
                  alCambiar: _pulgares.actualizar,
                ),
              );
            },
          ),

          // Botones de acción principales
          Row(
            children: <Widget>[
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FqColors.volt,
                    foregroundColor: FqColors.night,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    l10n.rutaDetalleIniciarRecorrido,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.alIniciar?.call();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FqColors.night,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: FqColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text(
                    'Ver detalle',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.alVerDetalle?.call();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricaFicha extends StatelessWidget {
  const _MetricaFicha({
    required this.etiqueta,
    required this.valor,
    required this.icono,
  });

  final String etiqueta;
  final String valor;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FqColors.paper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icono, size: 13, color: FqColors.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: FqColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: FqColors.night,
            ),
          ),
        ],
      ),
    );
  }
}
