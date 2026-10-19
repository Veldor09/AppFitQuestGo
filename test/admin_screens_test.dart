import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/dashboard_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/dashboard_screen.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/pantallas_lista_maqueta.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/revision_ruta_screen.dart';

/// API simulada para probar el Dashboard sin conexiones HTTP reales.
class _DashboardApiFake extends DashboardApi {
  @override
  Future<Map<String, dynamic>> obtenerResumen() async {
    return <String, dynamic>{
      'usuarios': 120,
      'rutas': 45,
      'alertasActivas': 3,
      'pendientes': 17,
      'colas': <String, dynamic>{
        'rutasPorRevisar': 8,
        'nodosPendientes': 5,
        'reportesNuevos': 4,
      },
    };
  }
}

/// Comprueba que las pantallas administrativas se rendericen
/// correctamente en escritorio y pantallas angostas.
///
/// ADM-01 utiliza una API simulada para evitar peticiones HTTP
/// y temporizadores de reintento durante las pruebas.
void main() {
  final Map<String, Widget> pantallas = <String, Widget>{
    'Dashboard': DashboardScreen(api: _DashboardApiFake()),
    'Revision de ruta': const RevisionRutaScreen(),
    'Eventos': const EventosScreen(),
    'Patrocinadores': const PatrocinadoresScreen(),
    'Insignias': const InsigniasScreen(),
    'Reportes de contenido': const ReportesContenidoScreen(),
    'Auditoria': const AuditoriaScreen(),
  };

  for (final MapEntry<String, Widget> e in pantallas.entries) {
    testWidgets(
      'pinta ${e.key} sin errores (escritorio y angosto)',
      (WidgetTester tester) async {
        // Forzar español en el entorno de pruebas.
        tester.platformDispatcher.localesTestValue = const <Locale>[
          Locale('es'),
        ];
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
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox.fromSize(
                  size: size,
                  child: e.value,
                ),
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
      },
    );
  }
}