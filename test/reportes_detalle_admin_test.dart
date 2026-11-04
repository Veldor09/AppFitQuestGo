import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/reporte_contenido_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/reportes_contenido_screen.dart';

class _ReporteApiFalsa extends ReporteContenidoApi {
  @override
  Future<List<Map<String, dynamic>>> listar() async => <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 7,
      'estado': 'pendiente',
      'tipoContenido': 'nodo',
      'contenidoId': 3,
      'motivo': 'otro',
      'descripcion': 'Descripción detallada del reporte',
      'esFoto': false,
      'contenido': <String, dynamic>{'nombre': 'Nodo con reporte'},
    },
  ];
}

void main() {
  testWidgets('reporte abre el detalle administrativo compartido', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReportesContenidoScreen(api: _ReporteApiFalsa())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Nodo con reporte').first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('detalle-reporte')),
      findsOneWidget,
    );
    expect(find.text('Descripción detallada del reporte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
