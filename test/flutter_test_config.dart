import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/db/app_database.dart';

/// Corre antes de cada archivo de pruebas. La base local es un singleton: si un
/// intento de abrirla queda a medias cuando termina una prueba, el de la
/// siguiente reutilizaria ese intento muerto y se colgaria (pasaba segun el
/// orden). Aqui cada prueba empieza con la base sin abrir.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => AppDatabase.instancia.reiniciar());
  await testMain();
}
