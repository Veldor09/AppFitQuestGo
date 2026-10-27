import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/perfil/data/insignia.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/insignias_screen.dart';
import 'package:fit_quest_go/core/db/daos/insignias_cache_dao.dart';

import 'helpers/montar.dart';

class _ApiOfflineFalsa extends PerfilApi {
  bool debeFallar = true;
  List<Insignia> remotas = <Insignia>[];

  @override
  Future<List<Insignia>> misInsignias() async {
    if (debeFallar) {
      throw Exception('Network error: Sin conexión a internet');
    }
    return remotas;
  }
}

class _CacheFalso extends InsigniasCacheDao {
  _CacheFalso([List<Insignia>? iniciales])
      : items = iniciales != null ? List<Insignia>.from(iniciales) : <Insignia>[];

  final List<Insignia> items;

  @override
  Future<void> guardarTodas(List<Insignia> insignias) async {
    items.clear();
    items.addAll(insignias);
  }

  @override
  Future<List<Insignia>> listar() async {
    return List<Insignia>.from(items);
  }
}

void main() {
  final Insignia ins1 = Insignia(
    codigo: 'primera_ruta',
    nombre: 'Primera Ruta',
    descripcion: 'Completaste tu primera ruta',
    emoji: '🏃',
    desbloqueada: true,
  );

  testWidgets('InsigniasScreen sin conexión muestra insignias en caché y aviso offline', (
    WidgetTester tester,
  ) async {
    final _ApiOfflineFalsa api = _ApiOfflineFalsa()..debeFallar = true;
    final _CacheFalso cache = _CacheFalso(<Insignia>[ins1]);

    await montarApp(
      tester,
      InsigniasScreen(
        api: api,
        cacheDao: cache,
      ),
    );

    await tester.pumpAndSettle();

    // Debe mostrar la insignia guardada
    expect(find.text('Primera Ruta'), findsOneWidget);
    // Debe mostrar el banner offline
    expect(
      find.text('Modo sin conexión: mostrando insignias guardadas en tu dispositivo.'),
      findsOneWidget,
    );
  });

  testWidgets('InsigniasScreen sin conexión y sin caché previa muestra estado vacío de offline', (
    WidgetTester tester,
  ) async {
    final _ApiOfflineFalsa api = _ApiOfflineFalsa()..debeFallar = true;
    final _CacheFalso cache = _CacheFalso(<Insignia>[]);

    await montarApp(
      tester,
      InsigniasScreen(
        api: api,
        cacheDao: cache,
      ),
    );

    await tester.pumpAndSettle();

    // Debe mostrar mensaje de error amigable offline
    expect(
      find.text('No tienes insignias guardadas en tu dispositivo.'),
      findsOneWidget,
    );
  });
}
