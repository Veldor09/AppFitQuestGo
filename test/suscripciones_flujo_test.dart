import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/patrocinio/application/plan_usuario.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/plan_api.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/interruptor_destacar.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/invitar_a_plan.dart';

import 'helpers/montar.dart';

class _AlmacenEnMemoria implements AlmacenPlanUsuario {
  DateTime? hasta;

  @override
  Future<DateTime?> leerVigenteHasta() async => hasta;

  @override
  Future<void> guardarVigenteHasta(DateTime? fecha) async => hasta = fecha;
}

class _ApiFalsa extends PlanApi {
  MiSuscripcion? respuesta;
  bool sinRed = false;
  int consultas = 0;

  @override
  Future<MiSuscripcion?> miSuscripcion() async {
    consultas++;
    if (sinRed) throw ApiException(0, 'sin red');
    return respuesta;
  }
}

MiSuscripcion _vigente({
  String audiencia = AudienciaPlan.usuario,
  DateTime? hasta,
}) => MiSuscripcion(
  id: 1,
  estado: EstadoSuscripcion.activa,
  vigente: true,
  planNombre: 'Plan Explorador',
  venceEn: hasta ?? DateTime(2026, 11, 20),
  audiencia: audiencia,
);

void main() {
  group('PlanUsuario (cuantas rutas se pueden guardar sin conexion)', () {
    final DateTime hoy = DateTime(2026, 10, 29);
    late _AlmacenEnMemoria almacen;
    late _ApiFalsa api;
    late PlanUsuario plan;

    setUp(() {
      almacen = _AlmacenEnMemoria();
      api = _ApiFalsa();
      plan = PlanUsuario(api: api, almacen: almacen, ahora: () => hoy);
    });

    test('sin suscripcion el limite es el gratuito', () async {
      api.respuesta = null;
      expect(await plan.limiteRutasOffline(), kLimiteRutasOfflineGratis);
    });

    test(
      'con una suscripcion de usuario vigente el limite sube y se recuerda su vencimiento',
      () async {
        api.respuesta = _vigente();

        expect(await plan.limiteRutasOffline(), kLimiteRutasOfflineSuscrito);
        expect(almacen.hasta, DateTime(2026, 11, 20));
      },
    );

    test(
      'sin red sigue valiendo lo recordado mientras no haya vencido',
      () async {
        almacen.hasta = DateTime(2026, 11, 20);
        api.sinRed = true;

        expect(await plan.limiteRutasOffline(), kLimiteRutasOfflineSuscrito);
      },
    );

    test(
      'sin red y con lo recordado ya vencido vuelve al limite gratuito',
      () async {
        almacen.hasta = DateTime(2026, 10, 1);
        api.sinRed = true;

        expect(await plan.limiteRutasOffline(), kLimiteRutasOfflineGratis);
      },
    );

    test(
      'si el servidor dice que ya no hay plan, se olvida lo recordado',
      () async {
        almacen.hasta = DateTime(2026, 11, 20);
        api.respuesta = const MiSuscripcion(
          id: 1,
          estado: EstadoSuscripcion.suspendida,
          vigente: false,
          planNombre: 'x',
        );

        expect(await plan.limiteRutasOffline(), kLimiteRutasOfflineGratis);
        expect(almacen.hasta, isNull);
      },
    );

    test('un plan de empresa no da descargas extra', () async {
      api.respuesta = _vigente(audiencia: AudienciaPlan.empresa);
      expect(await plan.limiteRutasOffline(), kLimiteRutasOfflineGratis);
    });

    test('olvidar (al cerrar sesion) borra lo recordado', () async {
      almacen.hasta = DateTime(2026, 11, 20);
      await plan.olvidar();
      expect(await plan.vigenteRecordado(), isFalse);
    });
  });

  group('invitar a pedir un plan', () {
    testWidgets('el aviso explica por que y ofrece "Ver planes" o cancelar', (
      WidgetTester tester,
    ) async {
      bool abrio = true;
      await montarApp(
        tester,
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async => abrio = await invitarAPlan(
              context,
              mensaje: 'Llegaste al limite',
            ),
            child: const Text('probar'),
          ),
        ),
      );

      await tester.tap(find.text('probar'));
      await tester.pumpAndSettle();
      expect(find.text('Necesitas una suscripción'), findsOneWidget);
      expect(find.text('Llegaste al limite'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('invitacion-ver-planes')),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(abrio, isFalse);
    });
  });

  group('destacar sin plan', () {
    testWidgets('en vez de un error suelto, ofrece solicitar el plan', (
      WidgetTester tester,
    ) async {
      await montarApp(
        tester,
        Scaffold(
          body: Center(
            child: InterruptorDestacar(
              activado: false,
              alCambiar: (bool _) async =>
                  throw ApiException(403, 'DESTACAR_SIN_PLAN'),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('interruptor-destacar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Necesitas una suscripción'), findsOneWidget);
      expect(find.textContaining('plan de patrocinio activo'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('invitacion-ver-planes')),
        findsOneWidget,
      );
    });

    testWidgets('otros errores siguen siendo un aviso corto', (
      WidgetTester tester,
    ) async {
      await montarApp(
        tester,
        Scaffold(
          body: Center(
            child: InterruptorDestacar(
              activado: false,
              alCambiar: (bool _) async =>
                  throw ApiException(403, 'DESTACAR_TOPE'),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('interruptor-destacar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Necesitas una suscripción'), findsNothing);
    });
  });
}
