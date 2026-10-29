import 'package:flutter/material.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';

/// ADM-04: consulta administrativa de una ruta, sin acciones de moderacion.
class DetalleRutaAdminScreen extends StatelessWidget {
  const DetalleRutaAdminScreen({super.key, required this.ruta});

  final Ruta ruta;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(ruta.nombre)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(ruta.nombre, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Text(l10n.admRutaDetEstado(ruta.estado)),
            const SizedBox(height: 12),
            Text(l10n.admRutaDetDistancia(ruta.distanciaKm.toStringAsFixed(1))),
            const SizedBox(height: 12),
            Text(
              l10n.admRutaDetDificultad(dificultadLabel(l10n, ruta.dificultad)),
            ),
            const SizedBox(height: 12),
            Text(l10n.admRutaDetPuntos(ruta.puntos.length)),
            if (ruta.creadoPorNombre != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(l10n.rutasCreadaPor(ruta.creadoPorNombre!)),
            ],
          ],
        ),
      ),
    );
  }
}
