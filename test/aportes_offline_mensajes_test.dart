import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/perfil/presentation/aportes_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';

import 'helpers/montar.dart';

class _RutaApiFallo extends RutaApi {
  @override
  Future<List<Ruta>> misRutas() async {
    throw Exception('ClientException with SocketException: Connection failed (OS Error: Network unreachable)');
  }
}

class _AlertaApiFallo extends AlertaApi {
  @override
  Future<List<Alerta>> misAlertas() async {
    throw Exception('ClientException with SocketException: Connection failed');
  }
}

class _NodoApiFallo extends NodoApi {
  @override
  Future<List<Nodo>> misNodos() async {
    throw Exception('ClientException with SocketException: Connection failed');
  }
}

void main() {
  testWidgets('AportesScreen muestra mensaje amigable sin internet en lugar de ClientException', (
    WidgetTester tester,
  ) async {
    await montarApp(
      tester,
      AportesScreen(
        rutaApi: _RutaApiFallo(),
        alertaApi: _AlertaApiFallo(),
        nodoApi: _NodoApiFallo(),
      ),
    );

    await tester.pumpAndSettle();

    // Tab 1: Rutas
    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
    expect(find.textContaining('ClientException'), findsNothing);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

    // Cambiar a Tab 2: Alertas
    await tester.tap(find.text('Alertas'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
    expect(find.textContaining('ClientException'), findsNothing);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

    // Cambiar a Tab 3: Puntos / Nodos
    await tester.tap(find.text('Puntos / Nodos'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
    expect(find.textContaining('ClientException'), findsNothing);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });
}
