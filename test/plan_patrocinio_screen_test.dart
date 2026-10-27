import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/plan_api.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/plan_patrocinio_screen.dart';

import 'helpers/montar.dart';

const PlanPatrocinio _mensual = PlanPatrocinio(
  id: 1,
  nombre: 'Plan Mensual',
  duracionDias: 30,
  moneda: 'CRC',
  importe: 10000,
);

class _PlanApiFalsa extends PlanApi {
  MiSuscripcion? suscripcion;
  List<PlanPatrocinio> lista = <PlanPatrocinio>[_mensual];
  Object? errorAlSolicitar;
  Object? errorAlCargar;
  final List<({int planId, String pais})> pedidos =
      <({int planId, String pais})>[];
  final List<String> paisesConsultados = <String>[];

  @override
  Future<MiSuscripcion?> miSuscripcion() async {
    if (errorAlCargar != null) throw errorAlCargar!;
    return suscripcion;
  }

  @override
  Future<List<PlanPatrocinio>> planes(String pais) async {
    paisesConsultados.add(pais);
    return lista;
  }

  @override
  Future<void> solicitar({required int planId, required String pais}) async {
    if (errorAlSolicitar != null) throw errorAlSolicitar!;
    pedidos.add((planId: planId, pais: pais));
    // Como el servidor: lo recien pedido queda en revision.
    suscripcion = const MiSuscripcion(
      id: 9,
      estado: EstadoSuscripcion.solicitada,
      vigente: false,
      planNombre: 'Plan Mensual',
    );
  }
}

final DateTime _hoy = DateTime(2026, 10, 27, 10);

void main() {
  late _PlanApiFalsa api;

  setUp(() => api = _PlanApiFalsa());

  Future<void> abrir(WidgetTester tester) async {
    await montarApp(
      tester,
      PlanPatrocinioScreen(api: api, pais: 'CR', ahora: () => _hoy),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sin plan muestra los planes con su precio en colones y duracion',
    (WidgetTester tester) async {
      await abrir(tester);

      expect(find.text('Plan de patrocinio'), findsOneWidget);
      expect(find.text('Plan Mensual'), findsOneWidget);
      expect(find.text('₡10.000'), findsOneWidget);
      expect(find.text('30 días'), findsOneWidget);
      expect(api.paisesConsultados, <String>['CR']);
    },
  );

  testWidgets('pedir un plan: confirma, envia y pasa a "en revision"', (
    WidgetTester tester,
  ) async {
    await abrir(tester);

    await tester.tap(find.byKey(const ValueKey<String>('solicitar-plan-1')));
    await tester.pumpAndSettle();
    expect(find.text('¿Solicitar este plan?'), findsOneWidget);
    expect(find.textContaining('₡10.000 por 30 días'), findsOneWidget);
    expect(api.pedidos, isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('confirmar-plan')));
    await tester.pumpAndSettle();

    expect(api.pedidos, <({int planId, String pais})>[(planId: 1, pais: 'CR')]);
    expect(find.text('Solicitud en revisión'), findsOneWidget);
    // Ya no se ofrece pedir otro mientras esta en revision.
    expect(
      find.byKey(const ValueKey<String>('solicitar-plan-1')),
      findsNothing,
    );
    expect(
      find.text('Solicitud enviada. Te avisaremos cuando la revisen.'),
      findsOneWidget,
    );
  });

  testWidgets('cancelar la confirmacion no envia nada', (
    WidgetTester tester,
  ) async {
    await abrir(tester);

    await tester.tap(find.byKey(const ValueKey<String>('solicitar-plan-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(api.pedidos, isEmpty);
    expect(
      find.byKey(const ValueKey<String>('solicitar-plan-1')),
      findsOneWidget,
    );
  });

  testWidgets('si ya tenia una pendiente (409) lo dice y muestra la real', (
    WidgetTester tester,
  ) async {
    await abrir(tester);
    api.errorAlSolicitar = ApiException(
      409,
      'Ya tiene una solicitud pendiente',
    );
    api.suscripcion = const MiSuscripcion(
      id: 3,
      estado: EstadoSuscripcion.solicitada,
      vigente: false,
      planNombre: 'Plan Mensual',
    );

    await tester.tap(find.byKey(const ValueKey<String>('solicitar-plan-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('confirmar-plan')));
    await tester.pumpAndSettle();

    expect(
      find.text('Ya tienes una solicitud pendiente o un plan activo.'),
      findsOneWidget,
    );
    expect(find.text('Solicitud en revisión'), findsOneWidget);
  });

  testWidgets(
    'otro error del servidor da un aviso generico y deja pedir de nuevo',
    (WidgetTester tester) async {
      await abrir(tester);
      api.errorAlSolicitar = ApiException(500, 'boom');

      await tester.tap(find.byKey(const ValueKey<String>('solicitar-plan-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('confirmar-plan')));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo enviar la solicitud. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('solicitar-plan-1')),
        findsOneWidget,
      );
    },
  );

  testWidgets('plan vigente: nombre, fecha, dias que quedan y nada que pedir', (
    WidgetTester tester,
  ) async {
    api.suscripcion = MiSuscripcion(
      id: 4,
      estado: EstadoSuscripcion.activa,
      vigente: true,
      planNombre: 'Plan Mensual',
      venceEn: DateTime(2026, 11, 6, 10),
    );
    await abrir(tester);

    expect(find.byKey(const ValueKey<String>('plan-activo')), findsOneWidget);
    expect(find.text('Plan activo'), findsOneWidget);
    expect(find.textContaining('Plan Mensual · vence el'), findsOneWidget);
    expect(find.text('Quedan 10 días'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('solicitar-plan-1')),
      findsNothing,
    );
    // No pidio la lista de planes: no hace falta.
    expect(api.paisesConsultados, isEmpty);
  });

  testWidgets('rechazada: avisa y deja pedir otra vez', (
    WidgetTester tester,
  ) async {
    api.suscripcion = const MiSuscripcion(
      id: 4,
      estado: EstadoSuscripcion.rechazada,
      vigente: false,
      planNombre: 'Plan Mensual',
    );
    await abrir(tester);

    expect(find.textContaining('no fue aprobada'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('solicitar-plan-1')),
      findsOneWidget,
    );
  });

  testWidgets('activa pero con la fecha vencida cuenta como vencida', (
    WidgetTester tester,
  ) async {
    api.suscripcion = MiSuscripcion(
      id: 4,
      estado: EstadoSuscripcion.activa,
      vigente: false,
      planNombre: 'Plan Mensual',
      venceEn: DateTime(2026, 10, 1),
    );
    await abrir(tester);

    expect(find.textContaining('Tu plan venció'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('solicitar-plan-1')),
      findsOneWidget,
    );
  });

  testWidgets('sin planes disponibles lo dice', (WidgetTester tester) async {
    api.lista = <PlanPatrocinio>[];
    await abrir(tester);
    expect(
      find.text('Por ahora no hay planes disponibles para tu país.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'si no carga muestra el error con Reintentar, y reintentar funciona',
    (WidgetTester tester) async {
      api.errorAlCargar = ApiException(503, 'sin servicio');
      await abrir(tester);
      expect(find.text('No se pudo cargar tu plan.'), findsOneWidget);

      api.errorAlCargar = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Plan Mensual'), findsOneWidget);
    },
  );

  group('MiSuscripcion', () {
    test('diasRestantes cuenta dias enteros y nunca baja de 0', () {
      MiSuscripcion con(DateTime? vence) => MiSuscripcion(
        id: 1,
        estado: EstadoSuscripcion.activa,
        vigente: true,
        planNombre: 'x',
        venceEn: vence,
      );
      expect(con(DateTime(2026, 11, 6, 10)).diasRestantes(_hoy), 10);
      expect(con(DateTime(2026, 10, 27, 12)).diasRestantes(_hoy), 0);
      expect(con(DateTime(2026, 10, 1)).diasRestantes(_hoy), 0);
      expect(con(null).diasRestantes(_hoy), isNull);
    });

    test('el importe del servidor llega como texto decimal', () {
      final PlanPatrocinio p = PlanPatrocinio.fromJson(<String, dynamic>{
        'id': 1,
        'nombre': 'x',
        'duracionDias': 30,
        'moneda': 'USD',
        'importe': '20.00',
      });
      expect(p.importe, 20);
    });
  });
}
