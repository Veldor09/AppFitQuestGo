import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/catalogos/opcion_catalogo.dart';
import 'package:fit_quest_go/core/widgets/fq_selector_opciones.dart';

const List<OpcionCatalogo> _opciones = <OpcionCatalogo>[
  OpcionCatalogo('uno', Icons.looks_one),
  OpcionCatalogo('dos', Icons.looks_two),
  OpcionCatalogo('otro', Icons.more_horiz),
];

String _etiqueta(String clave) => 'Etiqueta ${clave.toUpperCase()}';

Widget _montar({
  required Set<String> seleccion,
  required ValueChanged<String> onToggle,
  String? errorTexto,
}) {
  return MaterialApp(
    home: Scaffold(
      body: FqSelectorOpciones(
        opciones: _opciones,
        etiqueta: _etiqueta,
        seleccion: seleccion,
        onToggle: onToggle,
        errorTexto: errorTexto,
      ),
    ),
  );
}

void main() {
  testWidgets('muestra todas las opciones con su etiqueta', (WidgetTester tester) async {
    await tester.pumpWidget(_montar(seleccion: <String>{}, onToggle: (_) {}));

    expect(find.text('Etiqueta UNO'), findsOneWidget);
    expect(find.text('Etiqueta DOS'), findsOneWidget);
    expect(find.text('Etiqueta OTRO'), findsOneWidget);
  });

  testWidgets('tocar una opcion avisa con su clave', (WidgetTester tester) async {
    final List<String> tocadas = <String>[];
    await tester.pumpWidget(_montar(seleccion: <String>{}, onToggle: tocadas.add));

    await tester.tap(find.text('Etiqueta DOS'));
    await tester.tap(find.text('Etiqueta OTRO'));

    expect(tocadas, <String>['dos', 'otro']);
  });

  testWidgets('las seleccionadas muestran la marca y quedan como seleccionadas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _montar(seleccion: <String>{'uno', 'dos'}, onToggle: (_) {}),
    );

    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    final Finder seleccionada = find.byKey(const ValueKey<String>('opcion-uno'));
    expect(
      tester.getSemantics(seleccionada),
      isSemantics(
        label: 'Etiqueta UNO',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
      ),
    );
  });

  testWidgets('sin seleccion no hay marcas', (WidgetTester tester) async {
    await tester.pumpWidget(_montar(seleccion: <String>{}, onToggle: (_) {}));
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('muestra el texto de error cuando lo hay', (WidgetTester tester) async {
    await tester.pumpWidget(
      _montar(seleccion: <String>{}, onToggle: (_) {}, errorTexto: 'Elegi una'),
    );
    expect(find.text('Elegi una'), findsOneWidget);
  });

  testWidgets('sin error no ocupa lugar', (WidgetTester tester) async {
    await tester.pumpWidget(_montar(seleccion: <String>{}, onToggle: (_) {}));
    expect(find.text('Elegi una'), findsNothing);
  });
}
