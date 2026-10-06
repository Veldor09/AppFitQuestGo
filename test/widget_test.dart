// Prueba de humo: sin sesion, la app abre en la pantalla de Bienvenida.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/app.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';

void main() {
  testWidgets('Arranca en Bienvenida cuando no hay sesion', (
    WidgetTester tester,
  ) async {
    // El entorno de test no tiene un locale real de dispositivo (por defecto
    // cae en en_US); se fuerza espanol para que la prueba sea determinista y
    // coincida con el idioma por defecto real de la app. La resolucion de
    // MaterialApp lee `locales` (la lista), no solo `locale`: hay que fijar
    // ambos o el override no tiene efecto.
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    tester.platformDispatcher.localeTestValue = const Locale('es');
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(FitQuestGoApp(auth: AuthRepositorio()));
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Iniciar sesion'), findsOneWidget);
  });
}
