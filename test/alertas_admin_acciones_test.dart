import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/alertas_admin_screen.dart';

class _AlertaApiFalsa extends AlertaApi {
  @override
  Future<List<Alerta>> listar() async => const <Alerta>[
    Alerta(
      id: 1,
      tipo: 'bache',
      gravedad: 'alta',
      lat: 9.93,
      lng: -84.08,
      estado: 'Activa',
      descripcion: 'Descripción de prueba',
    ),
  ];
}

void main() {
  testWidgets('alerta ofrece Ver y Desactivar en tres puntos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AlertasAdminScreen(api: _AlertaApiFalsa())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('Ver'), findsOneWidget);
    expect(find.text('Desactivar'), findsOneWidget);
    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(find.text('Descripción de prueba'), findsOneWidget);
  });
}
