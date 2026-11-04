import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';

void main() {
  testWidgets(
    'las columnas se mantienen separadas al desplazar una tabla angosta',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(15),
              child: AdminDataTable(
                rows: <AdminRow>[
                  AdminRow(
                    icon: Icons.event_outlined,
                    title:
                        'Recorrido con un nombre deliberadamente largo para teléfono',
                    subtitle:
                        'Empresa con un nombre extenso · Pendiente de aprobación',
                    trailing: const Chip(
                      label: Text('Pendiente de aprobación'),
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('NOMBRE'), findsOneWidget);
      expect(find.text('DETALLE'), findsOneWidget);
      expect(find.text('ACCIONES'), findsOneWidget);
      final row = tester.getRect(find.byType(AdminDataTable));
      final title = tester.getRect(
        find.text(
          'Recorrido con un nombre deliberadamente largo para teléfono',
        ),
      );
      final detail = tester.getRect(
        find.text('Empresa con un nombre extenso · Pendiente de aprobación'),
      );
      expect(title.right, lessThan(detail.left));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      final chip = tester.getRect(find.byType(Chip));
      expect(chip.left, greaterThanOrEqualTo(row.left));
      expect(chip.right, lessThanOrEqualTo(row.right));
    },
  );
}
