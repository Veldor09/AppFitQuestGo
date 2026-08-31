import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/app.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const String mapboxAccessToken = String.fromEnvironment('ACCESS_TOKEN');
  if (mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  final AuthRepositorio auth = AuthRepositorio();
  try {
    // Rehidrata la sesion guardada (tokens en almacenamiento seguro). Si falla
    // -por token invalido o backend caido- se arranca sin sesion.
    await auth.cargarSesionGuardada();
  } catch (_) {
    // Silencio deliberado: la app funciona igual sin sesion previa.
  }

  runApp(FitQuestGoApp(auth: auth));
}
