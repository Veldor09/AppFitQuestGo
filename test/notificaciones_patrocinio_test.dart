import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificaciones_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/notificaciones_screen.dart';

import 'helpers/montar.dart';

class _ApiFalsa extends NotificacionesApi {
  final List<int> leidas = <int>[];

  @override
  Future<List<Notificacion>> listar() async => <Notificacion>[
    Notificacion(
      id: 1,
      categoria: 'patrocinio',
      titulo: 'Tu plan de patrocinio fue aprobado',
      mensaje: 'Ya puedes destacar tus comercios y eventos durante 30 días.',
      creadaEn: DateTime.now(),
      referenciaTipo: 'suscripcion',
      referenciaId: 9,
    ),
  ];

  @override
  Future<void> marcarLeida(int id) async => leidas.add(id);
}

void main() {
  test('"patrocinio" es una categoria valida de notificacion', () {
    expect(Notificacion.categorias, contains('patrocinio'));
  });

  testWidgets('una notificacion de patrocinio tiene su filtro, su icono y no navega a otro lado', (
    WidgetTester tester,
  ) async {
    final _ApiFalsa api = _ApiFalsa();
    await montarApp(tester, NotificacionesScreen(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Patrocinio'), findsOneWidget);
    expect(find.text('Tu plan de patrocinio fue aprobado'), findsOneWidget);
    expect(find.byIcon(Icons.campaign_rounded), findsOneWidget);

    // El filtro la encuentra.
    await tester.tap(find.text('Patrocinio'));
    await tester.pumpAndSettle();
    expect(find.text('Tu plan de patrocinio fue aprobado'), findsOneWidget);

    // Tocarla la marca leida y no abre otra pantalla.
    await tester.tap(find.text('Tu plan de patrocinio fue aprobado'));
    await tester.pumpAndSettle();
    expect(api.leidas, <int>[1]);
    expect(find.byType(NotificacionesScreen), findsOneWidget);
  });
}
