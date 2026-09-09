import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';

void main() {
  testWidgets('notificarError / notificarExito muestran un toast global', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) =>
            NotificacionesHost(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (BuildContext context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () => notificarError('Algo fallo'),
                    child: const Text('err'),
                  ),
                  ElevatedButton(
                    onPressed: () => notificarExito('Todo bien'),
                    child: const Text('ok'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Algo fallo'), findsNothing);

    await tester.tap(find.text('err'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('Algo fallo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ok'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('Todo bien'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Se auto-descartan pasados unos segundos (y no dejan timers colgados).
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Algo fallo'), findsNothing);
    expect(find.text('Todo bien'), findsNothing);
  });
}
