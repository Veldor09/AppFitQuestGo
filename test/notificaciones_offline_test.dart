import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/db/daos/notificaciones_cache_dao.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificaciones_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/notificaciones_screen.dart';

import 'helpers/montar.dart';

class _ApiOfflineFalsa extends NotificacionesApi {
  bool debeFallar = true;
  List<Notificacion> remotas = <Notificacion>[];

  @override
  Future<List<Notificacion>> listar() async {
    if (debeFallar) {
      throw Exception('Network error: Sin conexión a internet');
    }
    return remotas;
  }

  @override
  Future<void> marcarTodasLeidas() async {
    if (debeFallar) throw Exception('Network error');
  }

  @override
  Future<void> marcarLeida(int id) async {
    if (debeFallar) throw Exception('Network error');
  }
}

class _CacheFalso extends NotificacionesCacheDao {
  _CacheFalso([List<Notificacion>? iniciales])
      : items = iniciales != null ? List<Notificacion>.from(iniciales) : <Notificacion>[];

  final List<Notificacion> items;

  @override
  Future<void> guardarTodas(List<Notificacion> notificaciones) async {
    items.clear();
    items.addAll(notificaciones);
  }

  @override
  Future<List<Notificacion>> listar({String? categoria}) async {
    if (categoria == null || categoria == 'todas') {
      return List<Notificacion>.from(items);
    }
    return items.where((Notificacion n) => n.categoria == categoria).toList();
  }

  @override
  Future<int> conteoNoLeidas() async {
    return items.where((Notificacion n) => !n.leida).length;
  }

  @override
  Future<void> marcarLeida(int idRemoto) async {
    for (final Notificacion n in items) {
      if (n.id == idRemoto) n.leida = true;
    }
  }

  @override
  Future<void> marcarTodasLeidas() async {
    for (final Notificacion n in items) {
      n.leida = true;
    }
  }

  @override
  Future<void> eliminar(int idRemoto) async {
    items.removeWhere((Notificacion n) => n.id == idRemoto);
  }
}

void main() {
  testWidgets(
    'NotificacionesScreen sin conexión muestra notificaciones en caché y aviso offline',
    (WidgetTester tester) async {
      final _ApiOfflineFalsa api = _ApiOfflineFalsa()..debeFallar = true;
      final _CacheFalso cache = _CacheFalso(<Notificacion>[
        Notificacion(
          id: 101,
          categoria: 'rutas',
          titulo: 'Nueva ruta cercana',
          mensaje: 'Se publicó una ruta en tu zona.',
          creadaEn: DateTime.now().subtract(const Duration(minutes: 5)),
          leida: false,
        ),
        Notificacion(
          id: 102,
          categoria: 'insignias',
          titulo: '¡Insignia desbloqueada!',
          mensaje: 'Ganaste la medalla Explorador.',
          creadaEn: DateTime.now().subtract(const Duration(hours: 1)),
          leida: true,
        ),
      ]);

      await montarApp(
        tester,
        NotificacionesScreen(api: api, cacheDao: cache),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el banner offline
      expect(find.textContaining('Modo sin conexión'), findsOneWidget);

      // Debe mostrar las notificaciones que estaban en caché
      expect(find.text('Nueva ruta cercana'), findsOneWidget);
      expect(find.text('¡Insignia desbloqueada!'), findsOneWidget);

      // Marcar todas como leídas actualiza en local
      await tester.tap(find.byIcon(Icons.done_all_rounded));
      await tester.pumpAndSettle();
      expect(await cache.conteoNoLeidas(), 0);
    },
  );

  testWidgets(
    'NotificacionesScreen sin conexión y sin caché previa muestra estado vacío offline',
    (WidgetTester tester) async {
      final _ApiOfflineFalsa api = _ApiOfflineFalsa()..debeFallar = true;
      final _CacheFalso cache = _CacheFalso(<Notificacion>[]);

      await montarApp(
        tester,
        NotificacionesScreen(api: api, cacheDao: cache),
      );
      await tester.pumpAndSettle();

      // Muestra estado vacío sin datos
      expect(find.text('Sin notificaciones sin conexión'), findsOneWidget);
      expect(
        find.text('No tienes notificaciones guardadas en tu dispositivo.'),
        findsOneWidget,
      );
    },
  );
}
