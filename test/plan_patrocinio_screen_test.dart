import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  RespuestaPlanes respuesta = const RespuestaPlanes(
    planes: <PlanPatrocinio>[_mensual],
    sinpeNumero: '83722969',
  );
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
  Future<RespuestaPlanes> planes(String pais) async {
    paisesConsultados.add(pais);
    return respuesta;
  }

  @override
  Future<SolicitudCreada> solicitar({
    required int planId,
    required String pais,
  }) async {
    if (errorAlSolicitar != null) throw errorAlSolicitar!;
    pedidos.add((planId: planId, pais: pais));
    // Como el servidor: lo recien pedido queda en revision, con su numero.
    suscripcion = const MiSuscripcion(
      id: 9,
      estado: EstadoSuscripcion.solicitada,
      vigente: false,
      planNombre: 'Plan Mensual',
      numeroSolicitud: '482913',
      monto: 10000,
      moneda: 'CRC',
      metodoPago: MetodoPago.sinpe,
      sinpeNumero: '83722969',
    );
    return const SolicitudCreada(
      numeroSolicitud: '482913',
      monto: 10000,
      moneda: 'CRC',
      sinpeNumero: '83722969',
    );
  }
}

final DateTime _hoy = DateTime(2026, 10, 27, 10);

void main() {
  late _PlanApiFalsa api;

  setUp(() => api = _PlanApiFalsa());

  Future<void> abrir(
    WidgetTester tester, {
    bool empresa = true,
    String pais = 'CR',
  }) async {
    await montarApp(
      tester,
      PlanPatrocinioScreen(
        api: api,
        pais: pais,
        ahora: () => _hoy,
        esEmpresa: empresa,
        nombre: 'Ana Mora',
      ),
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

  testWidgets('un usuario normal ve "Mi suscripción" y para que sirve', (
    WidgetTester tester,
  ) async {
    await abrir(tester, empresa: false);

    expect(find.text('Mi suscripción'), findsOneWidget);
    expect(
      find.textContaining('sin conexión: hasta 15 en vez de 3'),
      findsOneWidget,
    );
    expect(find.textContaining('destacar'), findsNothing);
  });

  testWidgets(
    'pedir un plan en Costa Rica: confirma y salen las instrucciones de SINPE con el numero de solicitud',
    (WidgetTester tester) async {
      await abrir(tester);

      await tester.tap(find.byKey(const ValueKey<String>('solicitar-plan-1')));
      await tester.pumpAndSettle();
      expect(find.text('¿Solicitar este plan?'), findsOneWidget);
      expect(find.textContaining('₡10.000 por 30 días'), findsOneWidget);
      expect(api.pedidos, isEmpty);

      await tester.tap(find.byKey(const ValueKey<String>('confirmar-plan')));
      await tester.pumpAndSettle();

      expect(api.pedidos, <({int planId, String pais})>[
        (planId: 1, pais: 'CR'),
      ]);
      expect(find.text('Solicitud en revisión'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('solicitar-plan-1')),
        findsNothing,
      );
      // Las instrucciones del pago.
      expect(
        find.byKey(const ValueKey<String>('instrucciones-sinpe')),
        findsOneWidget,
      );
      expect(find.text('482913'), findsOneWidget);
      expect(
        find.textContaining('SINPE Móvil al 8372-2969 por ₡10.000'),
        findsOneWidget,
      );
      expect(
        find.textContaining('número de solicitud (482913) y tu nombre'),
        findsOneWidget,
      );
      expect(
        find.textContaining('comprobante al mismo número (8372-2969)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '"Copiar detalle" deja en el portapapeles el numero y el nombre',
    (WidgetTester tester) async {
      api.suscripcion = const MiSuscripcion(
        id: 9,
        estado: EstadoSuscripcion.solicitada,
        vigente: false,
        planNombre: 'Plan Mensual',
        numeroSolicitud: '482913',
        monto: 10000,
        moneda: 'CRC',
        metodoPago: MetodoPago.sinpe,
        sinpeNumero: '83722969',
      );
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall llamada) async {
          if (llamada.method == 'Clipboard.setData') {
            copiado =
                (llamada.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await abrir(tester);

      await tester.tap(find.byKey(const ValueKey<String>('copiar-detalle')));
      await tester.pumpAndSettle();

      expect(copiado, '482913 Ana Mora');
      expect(find.text('Detalle copiado. Pégalo en el SINPE.'), findsOneWidget);
    },
  );

  testWidgets(
    'fuera de Costa Rica se ven los planes pero PayPal aun no esta: no se puede pedir',
    (WidgetTester tester) async {
      api.respuesta = const RespuestaPlanes(
        planes: <PlanPatrocinio>[
          PlanPatrocinio(
            id: 1,
            nombre: 'Plan Mensual',
            duracionDias: 30,
            moneda: 'USD',
            importe: 20,
          ),
        ],
        metodoPago: MetodoPago.paypal,
        pagoDisponible: false,
      );
      await abrir(tester, pais: 'US');

      expect(find.text('Plan Mensual'), findsOneWidget);
      expect(find.text('US\$20,00'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('plan-paypal')), findsOneWidget);
      expect(find.text('Pronto disponible'), findsOneWidget);
      // Tocarlo no hace nada: ni confirmacion ni solicitud.
      await tester.tap(find.byKey(const ValueKey<String>('solicitar-plan-1')));
      await tester.pumpAndSettle();
      expect(find.text('¿Solicitar este plan?'), findsNothing);
      expect(api.pedidos, isEmpty);
    },
  );

  testWidgets('si el servidor dice que el pago no esta disponible lo explica', (
    WidgetTester tester,
  ) async {
    await abrir(tester);
    api.errorAlSolicitar = ApiException(400, 'PAGO_NO_DISPONIBLE');

    await tester.tap(find.byKey(const ValueKey<String>('solicitar-plan-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('confirmar-plan')));
    await tester.pumpAndSettle();

    expect(
      find.text('El pago para tu región aún no está disponible.'),
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

  testWidgets(
    'plan vigente de empresa: nombre, fecha, dias que quedan y nada que pedir',
    (WidgetTester tester) async {
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
      expect(find.textContaining('Destacar'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('solicitar-plan-1')),
        findsNothing,
      );
      expect(api.paisesConsultados, isEmpty);
    },
  );

  testWidgets(
    'plan vigente de usuario: dice cuantas rutas offline puede guardar',
    (WidgetTester tester) async {
      api.suscripcion = MiSuscripcion(
        id: 4,
        estado: EstadoSuscripcion.activa,
        vigente: true,
        planNombre: 'Plan Explorador',
        venceEn: DateTime(2026, 11, 6, 10),
        audiencia: AudienciaPlan.usuario,
      );
      await abrir(tester, empresa: false);

      expect(find.text('Plan activo'), findsOneWidget);
      expect(
        find.text('Ya puedes guardar hasta 15 rutas para verlas sin conexión.'),
        findsOneWidget,
      );
    },
  );

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
    api.respuesta = const RespuestaPlanes(planes: <PlanPatrocinio>[]);
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

  group('modelos', () {
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
        'audiencia': 'usuario',
      });
      expect(p.importe, 20);
      expect(p.audiencia, AudienciaPlan.usuario);
    });

    test('RespuestaPlanes lee el metodo de pago y si ya se puede pagar', () {
      final RespuestaPlanes r = RespuestaPlanes.fromJson(<String, dynamic>{
        'metodoPago': 'paypal',
        'pagoDisponible': false,
        'sinpeNumero': null,
        'planes': <dynamic>[],
      });
      expect(r.metodoPago, MetodoPago.paypal);
      expect(r.pagoDisponible, isFalse);
    });

    test('MiSuscripcion lee el numero de solicitud y el monto', () {
      final MiSuscripcion s = MiSuscripcion.fromJson(<String, dynamic>{
        'id': 1,
        'estado': 'Solicitada',
        'vigente': false,
        'planNombre': 'P',
        'numeroSolicitud': '123456',
        'monto': '2500.00',
        'moneda': 'CRC',
        'metodoPago': 'sinpe',
        'sinpeNumero': '83722969',
        'audiencia': 'usuario',
      });
      expect(s.numeroSolicitud, '123456');
      expect(s.monto, 2500);
      expect(s.audiencia, 'usuario');
    });
  });
}
