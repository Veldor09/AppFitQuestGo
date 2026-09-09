import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';

void main() {
  testWidgets('marca el error en vivo al escribir un numero en el nombre', (
    WidgetTester tester,
  ) async {
    final TextEditingController c = TextEditingController();
    addTearDown(c.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampoTexto(
            label: 'Nombre',
            controller: c,
            reglas: reglasNombre(),
            maxCaracteres: kMaxNombreUsuario,
          ),
        ),
      ),
    );

    expect(find.text('No se pueden digitar numeros'), findsNothing);
    expect(find.text('0/20'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ana2');
    await tester.pump();

    expect(find.text('No se pueden digitar numeros'), findsOneWidget);
    expect(find.text('4/20'), findsOneWidget);
  });

  testWidgets('forzarError revela el error sin interaccion previa', (
    WidgetTester tester,
  ) async {
    final TextEditingController c = TextEditingController();
    addTearDown(c.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampoTexto(
            label: 'Correo',
            controller: c,
            reglas: reglasCorreo(),
            maxCaracteres: kMaxCorreoUsuario,
            forzarError: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('El correo es obligatorio'), findsOneWidget);
  });

  testWidgets('no deja escribir mas alla del limite', (
    WidgetTester tester,
  ) async {
    final TextEditingController c = TextEditingController();
    addTearDown(c.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampoTexto(
            label: 'Nombre',
            controller: c,
            reglas: reglasNombre(),
            maxCaracteres: kMaxNombreUsuario,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'Nombre demasiado largo para el limite',
    );
    await tester.pump();

    expect(c.text.length, kMaxNombreUsuario);
  });
}
