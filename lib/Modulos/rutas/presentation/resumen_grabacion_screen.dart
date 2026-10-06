import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/application/metricas_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/mapa_trazo_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/metrica_ruta.dart';

/// Que decidio el usuario en el resumen. Volver atras no decide nada (null).
enum ResultadoResumen { guardar, descartar }

/// Pantalla que sale al detener una grabacion GPS: el trazo sobre el mapa y
/// los datos de la sesion (tiempo, distancia, ritmo medio). Desde aqui se
/// sigue al formulario de guardado o se descarta la grabacion.
class ResumenGrabacionScreen extends StatelessWidget {
  const ResumenGrabacionScreen({
    super.key,
    required this.puntos,
    required this.tiempo,
    required this.distanciaKm,
  });

  final List<PuntoRuta> puntos;
  final Duration tiempo;
  final double distanciaKm;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool sePuedeGuardar = puntos.length >= 2;
    return Scaffold(
      backgroundColor: FqColors.paper,
      appBar: AppBar(
        title: Text(
          l10n.resumenGrabacionTitulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        backgroundColor: FqColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: MapaTrazoRuta(puntos: puntos)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: MetricaRuta(
                      etiqueta: l10n.grabacionTiempo,
                      valor: formatoDuracion(tiempo),
                    ),
                  ),
                  Expanded(
                    child: MetricaRuta(
                      etiqueta: l10n.rutasDistancia,
                      valor: distanciaKm.toStringAsFixed(2),
                      unidad: 'km',
                    ),
                  ),
                  Expanded(
                    child: MetricaRuta(
                      etiqueta: l10n.resumenGrabacionRitmoMedio,
                      valor: formatoRitmo(ritmoPorKm(tiempo, distanciaKm)),
                      unidad: '/km',
                    ),
                  ),
                ],
              ),
            ),
            if (!sePuedeGuardar)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.resumenGrabacionPocosPuntos,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: FqColors.muted),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FqButton.secondary(
                      label: l10n.resumenGrabacionDescartar,
                      onPressed: () =>
                          Navigator.of(context).pop(ResultadoResumen.descartar),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FqButton.primary(
                      label: l10n.resumenGrabacionGuardar,
                      onPressed: sePuedeGuardar
                          ? () => Navigator.of(context).pop(ResultadoResumen.guardar)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
