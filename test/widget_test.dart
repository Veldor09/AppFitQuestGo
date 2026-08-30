// Prueba de humo: sin sesion, la app abre en la pantalla de Bienvenida.

import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/app.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';

void main() {
  testWidgets('Arranca en Bienvenida cuando no hay sesion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(FitQuestGoApp(auth: AuthRepositorio()));
    await tester.pump();

    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Iniciar sesion'), findsOneWidget);
  });
}
