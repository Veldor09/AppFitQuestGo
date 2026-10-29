import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/suscripciones_admin_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/gestion_suscripciones_screen.dart';

SuscripcionAdmin _fila({
  int id = 1,
  String estado = 'Solicitada',
  String numero = '482913',
  String nombre = 'Ana Mora',
  String audiencia = 'usuario',
  num monto = 2500,
}) => SuscripcionAdmin(
  id: id,
  numeroSolicitud: numero,
  estado: estado,
  usuarioId: 10 + id,
  usuarioNombre: nombre,
  usuarioEmail: 'ana@correo.com',
  usuarioRol: audiencia == 'empresa' ? 2 : 1,
  planNombre: audiencia == 'empresa' ? 'Plan Empresa' : 'Plan Explorador',
  planAudiencia: audiencia,
  moneda: 'CRC',
  pais: 'CR',
  monto: monto,
  creadoEn: DateTime(2026, 10, 29, 10),
);

class _ApiFalsa extends SuscripcionesAdminApi {
  List<SuscripcionAdmin> datos = <SuscripcionAdmin>[_fila()];
  final List<({String? estado, String? q})> consultas =
      <({String? estado, String? q})>[];
  final List<String> acciones = <String>[];
  Object? errorAlActuar;
  Object? errorAlListar;

  @override
  Future<List<SuscripcionAdmin>> listar({String? estado, String? q}) async {
    consultas.add((estado: estado, q: q));
    if (errorAlListar != null) throw errorAlListar!;
    return datos;
  }

  Future<void> _actuar(String accion) async {
    if (errorAlActuar != null) throw errorAlActuar!;
    acciones.add(accion);
  }

  @override
  Future<void> aprobar(int id) => _actuar('aprobar $id');

  @override
  Future<void> rechazar(int id, String motivo) =>
      _actuar('rechazar $id "$motivo"');

  @override
  Future<void> suspender(int id) => _actuar('suspender $id');
}

void main() {
  late _ApiFalsa api;
  setUp(() => api = _ApiFalsa());

  Future<void> abrir(
    WidgetTester tester, {
    Locale locale = const Locale('es'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: GestionSuscripcionesScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'abre en "Pendientes" y muestra numero de solicitud, nombre, plan y monto',
    (WidgetTester tester) async {
      await abrir(tester);

      expect(api.consultas.first.estado, 'Solicitada');
      expect(find.text('#482913 · Ana Mora'), findsOneWidget);
      expect(find.text('Plan Explorador · ₡2.500 · Usuario'), findsOneWidget);
      expect(find.text('Pendiente'), findsWidgets);
    },
  );

  testWidgets('las pestañas piden cada estado al servidor; "Todas" no filtra', (
    WidgetTester tester,
  ) async {
    await abrir(tester);

    for (final (String pestana, String? estado) in <(String, String?)>[
      ('Activas', 'Activa'),
      ('Rechazadas', 'Rechazada'),
      ('Suspendidas', 'Suspendida'),
      ('Todas', null),
    ]) {
      await tester.tap(find.text(pestana));
      await tester.pumpAndSettle();
      expect(api.consultas.last.estado, estado, reason: pestana);
    }
  });

  testWidgets(
    'buscar por numero de solicitud espera a que termines de escribir',
    (WidgetTester tester) async {
      await abrir(tester);
      final int antes = api.consultas.length;

      await tester.enterText(find.byType(TextField).first, '482913');
      await tester.pump(const Duration(milliseconds: 100));
      expect(api.consultas.length, antes);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(api.consultas.last.q, '482913');
    },
  );

  testWidgets('aprobar: pide confirmar el pago y activa el plan', (
    WidgetTester tester,
  ) async {
    await abrir(tester);

    await tester.tap(find.text('#482913 · Ana Mora'));
    await tester.pumpAndSettle();
    expect(find.text('Solicitud #482913'), findsOneWidget);
    expect(find.text('ana@correo.com'), findsOneWidget);
    expect(find.text('Monto a recibir'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('accion-aprobar')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'recibiste el pago de ₡2.500 con el número de solicitud 482913',
      ),
      findsOneWidget,
    );
    expect(api.acciones, isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('confirmar-aprobar')));
    await tester.pumpAndSettle();

    expect(api.acciones, <String>['aprobar 1']);
    expect(find.text('Suscripción activada correctamente.'), findsOneWidget);
    // Recargo la lista despues de actuar.
    expect(api.consultas.length, greaterThanOrEqualTo(2));
  });

  testWidgets(
    'rechazar: exige un motivo de 10 a 500 caracteres y se lo manda al servidor',
    (WidgetTester tester) async {
      await abrir(tester);
      await tester.tap(find.text('#482913 · Ana Mora'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('accion-rechazar')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-motivo')),
        'corto',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('confirmar-rechazar')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('El motivo debe tener entre 10 y 500 caracteres.'),
        findsOneWidget,
      );
      expect(api.acciones, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey<String>('campo-motivo')),
        'No encontramos el comprobante del pago.',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('confirmar-rechazar')),
      );
      await tester.pumpAndSettle();

      expect(api.acciones, <String>[
        'rechazar 1 "No encontramos el comprobante del pago."',
      ]);
      expect(find.text('Solicitud rechazada.'), findsOneWidget);
    },
  );

  testWidgets(
    'una activa se puede suspender (con confirmacion); una pendiente no',
    (WidgetTester tester) async {
      api.datos = <SuscripcionAdmin>[
        _fila(id: 2, estado: 'Activa', nombre: 'Luis Soto'),
      ];
      await abrir(tester);

      await tester.tap(find.text('#482913 · Luis Soto'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('accion-aprobar')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey<String>('accion-suspender')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('¿Suspender el plan de Luis Soto?'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('confirmar-suspender')),
      );
      await tester.pumpAndSettle();

      expect(api.acciones, <String>['suspender 2']);
    },
  );

  testWidgets('si la accion falla lo dice y la lista sigue en pie', (
    WidgetTester tester,
  ) async {
    api.errorAlActuar = ApiException(
      409,
      'Solo se pueden aprobar solicitudes pendientes',
    );
    await abrir(tester);

    await tester.tap(find.text('#482913 · Ana Mora'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('accion-aprobar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('confirmar-aprobar')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'No se pudo completar la acción: Solo se pueden aprobar',
      ),
      findsOneWidget,
    );
    expect(find.text('#482913 · Ana Mora'), findsOneWidget);
  });

  testWidgets(
    'sin solicitudes muestra el estado vacio; si el servidor falla, el error con Reintentar',
    (WidgetTester tester) async {
      api.datos = <SuscripcionAdmin>[];
      await abrir(tester);
      expect(find.text('Sin suscripciones'), findsOneWidget);

      api.errorAlListar = ApiException(500, 'boom');
      await tester.tap(find.text('Activas'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se pudieron cargar las suscripciones: boom'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets('el panel sale en ingles cuando la app esta en ingles', (
    WidgetTester tester,
  ) async {
    api.datos = <SuscripcionAdmin>[_fila(audiencia: 'empresa', monto: 15000)];
    await abrir(tester, locale: const Locale('en'));

    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Plan Empresa · ₡15,000 · Business'), findsOneWidget);
    expect(find.text('Pendientes'), findsNothing);
  });

  test('SuscripcionAdmin.fromJson lee lo que manda el servidor', () {
    final SuscripcionAdmin s = SuscripcionAdmin.fromJson(<String, dynamic>{
      'id': 5,
      'numeroSolicitud': '123456',
      'estado': 'Activa',
      'usuarioId': 9,
      'usuarioNombre': 'Ana',
      'usuarioEmail': 'a@b.co',
      'usuarioRol': 2,
      'planNombre': 'P',
      'planAudiencia': 'empresa',
      'moneda': 'CRC',
      'pais': 'CR',
      'monto': '15000.00',
      'venceEn': '2026-11-28T19:29:08.623Z',
    });
    expect(s.monto, 15000);
    expect(s.venceEn, isNotNull);
    expect(s.planAudiencia, 'empresa');
  });
}
