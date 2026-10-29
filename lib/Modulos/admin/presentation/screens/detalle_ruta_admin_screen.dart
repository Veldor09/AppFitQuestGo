import 'package:flutter/material.dart';

import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// ADM-04: consulta administrativa de una ruta, sin acciones de moderacion.
class DetalleRutaAdminScreen extends StatelessWidget {
  const DetalleRutaAdminScreen({super.key, required this.ruta});

  final Ruta ruta;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ruta.nombre)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              ruta.nombre,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Text('Estado: ${ruta.estado}'),
            const SizedBox(height: 12),
            Text('Distancia: ${ruta.distanciaKm.toStringAsFixed(1)} km'),
            const SizedBox(height: 12),
            Text('Dificultad: ${ruta.dificultad}'),
            const SizedBox(height: 12),
            Text('Puntos GPS: ${ruta.puntos.length}'),
            if (ruta.creadoPorNombre != null) ...<Widget>[
              const SizedBox(height: 12),
              Text('Creada por: ${ruta.creadoPorNombre}'),
            ],
          ],
        ),
      ),
    );
  }
}