
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/dashboard_screen.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/pantallas_lista_maqueta.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/revision_ruta_screen.dart';

/// Comprueba que las pantallas administrativas existentes se rendericen
/// correctamente en tamaños de escritorio y pantallas angostas.
///
/// ADM-11 tiene una pantalla funcional conectada al backend y se verificara
/// mediante pruebas independientes con dependencias simuladas.
void main() {
  final Map<String, Widget> pantallas = <String, Widget>{
    'Dashboard': const DashboardScreen(),
    'Revision de ruta': const RevisionRutaScreen(),
    'Eventos': const EventosScreen(),
    'Patrocinadores': const PatrocinadoresScreen(),
    'Insignias': const InsigniasScreen(),
    'Reportes de contenido': const ReportesContenidoScreen(),
    'Auditoria': const AuditoriaScreen(),
  };

  for (final MapEntry<String, Widget> e in pantallas.entries) {
    testWidgets('pinta ${e.key} sin errores (escritorio y angosto)', (
      WidgetTester tester,
    ) async {
      // Entorno de test sin locale real de dispositivo: se fuerza espanol
      // para que AppLocalizations.of() resuelva sin excepcion.
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
      tester.platformDispatcher.localeTestValue = const Locale('es');
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      for (final Size size in <Size>[
        const Size(1280, 800),
        const Size(760, 760),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox.fromSize(size: size, child: e.value),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 50));

        expect(
          tester.takeException(),
          isNull,
          reason: '${e.key} @ $size',
        );
      }
    });
  }
}
