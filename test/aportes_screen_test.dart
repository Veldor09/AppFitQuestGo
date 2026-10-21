import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificaciones_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/aportes_screen.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/notificaciones_screen.dart';

class _FakeNotificacionesApi extends NotificacionesApi {
  _FakeNotificacionesApi(this.lista);

  final List<Notificacion> lista;

  @override
  Future<List<Notificacion>> listar() async => lista;

  @override
  Future<int> conteoNoLeidas() async => lista.where((n) => !n.leida).length;

  @override
  Future<void> marcarLeida(int id) async {}
}

void main() {
  Widget envolver(Widget child) {
    return MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('AportesScreen respeta initialTab: 1 para abrir Alertas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(envolver(const AportesScreen(initialTab: 1)));
    await tester.pumpAndSettle();

    final TabBarView tabBarView = tester.widget<TabBarView>(find.byType(TabBarView));
    expect(tabBarView.controller!.index, 1);
  });

  testWidgets(
      'NotificacionesScreen abre AportesScreen en la pestaña de Alertas al tocar una notificación de alerta',
      (WidgetTester tester) async {
    final Notificacion notifAlerta = Notificacion(
      id: 1,
      categoria: 'alertas',
      referenciaTipo: 'alerta',
      titulo: 'Alerta reportada con éxito',
      mensaje: 'Tu alerta ha sido publicada',
      creadaEn: DateTime.now(),
      leida: false,
    );

    final _FakeNotificacionesApi api = _FakeNotificacionesApi(<Notificacion>[notifAlerta]);

    await tester.pumpWidget(envolver(NotificacionesScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Alerta reportada con éxito'), findsOneWidget);

    await tester.tap(find.text('Alerta reportada con éxito'));
    await tester.pumpAndSettle();

    expect(find.byType(AportesScreen), findsOneWidget);
    final AportesScreen aportes = tester.widget<AportesScreen>(find.byType(AportesScreen));
    expect(aportes.initialTab, 1);
  });
}
