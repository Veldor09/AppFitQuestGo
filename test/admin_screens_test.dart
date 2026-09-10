import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/admin/presentation/screens/dashboard_screen.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/pantallas_lista_maqueta.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/revision_ruta_screen.dart';

/// Cada pantalla de maqueta del panel se pinta en varios tamanos para detectar
/// en modo debug errores de construccion / overflow que un build de release no
/// reporta.
void main() {
  final Map<String, Widget> pantallas = <String, Widget>{
    'Dashboard': const DashboardScreen(),
    'Revision de ruta': const RevisionRutaScreen(),
    'Eventos': const EventosScreen(),
    'Patrocinadores': const PatrocinadoresScreen(),
    'Insignias': const InsigniasScreen(),
    'Catalogos': const CatalogosScreen(),
    'Reportes de contenido': const ReportesContenidoScreen(),
    'Auditoria': const AuditoriaScreen(),
  };

  for (final MapEntry<String, Widget> e in pantallas.entries) {
    testWidgets('pinta ${e.key} sin errores (escritorio y angosto)', (
      WidgetTester tester,
    ) async {
      for (final Size size in <Size>[
        const Size(1280, 800),
        const Size(760, 760),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox.fromSize(size: size, child: e.value),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: '${e.key} @ $size');
      }
    });
  }
}
