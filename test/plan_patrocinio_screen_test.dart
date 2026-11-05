import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/patrocinio/application/region_pago.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/plan_api.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/pago_webview_screen.dart';
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
  );

  /// Si se da, la respuesta depende del pais consultado (como el servidor).
  RespuestaPlanes Function(String pais)? segunPais;
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
    return segunPais?.call(pais) ?? respuesta;
  }

  @override
  Future<PagoIniciado> iniciarPago({
    required int planId,
    required String pais,
  }) async {
    if (errorAlSolicitar != null) throw errorAlSolicitar!;
    pedidos.add((planId: planId, pais: pais));
    // Como el servidor: lo recien pedido queda sin pagar, con su numero.
    suscripcion = const MiSuscripcion(
      id: 9,
      estado: EstadoSuscripcion.solicitada,
      vigente: false,
      planNombre: 'Plan Mensual',
      numeroSolicitud: '482913',
      monto: 10000,
      moneda: 'CRC',
      pagoEnLinea: true,
    );
    return const PagoIniciado(
      suscripcionId: 9,
      numeroSolicitud: '482913',
      url: 'https://checkout.onvopay.com/pay/cs_1',
    );
  }
}

class _AlmacenRegionFalso implements AlmacenRegionPago {
  _AlmacenRegionFalso([this.guardada]);

  RegionPago? guardada;

  @override
  Future<RegionPago?> leer() async => guardada;

  @override
  Future<void> guardar(RegionPago region) async => guardada = region;
}

final DateTime _hoy = DateTime(2026, 10, 27, 10);

void main() {
  late _PlanApiFalsa api;

  /// Lo que hace la pantalla de pago de mentira: guarda la URL que le abrieron,
  /// deja que el "servidor" reaccione y devuelve como termino.
  late List<String> urlsAbiertas;
  ResultadoPago? terminaCon;
  void Function()? alPagar;

  setUp(() {
    api = _PlanApiFalsa();
    urlsAbiertas = <String>[];
    terminaCon = null;
    alPagar = null;
  });

  Future<ResultadoPago?> abrirPago(BuildContext context, String url) async {
    urlsAbiertas.add(url);
    alPagar?.call();
    return terminaCon;
  }

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
        almacenRegion: _AlmacenRegionFalso(),
        abrirPago: abrirPago,
        ahora: () => _hoy,
        esEmpresa: empresa,
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
      find.textContaining('sin conexión: hasta 15 en vez de 1'),
      findsOneWidget,
    );
    expect(find.textContaining('destacar'), findsNothing);
  });

  const ValueKey<String> claveSolicitar = ValueKey<String>('solicitar-plan-1');
  const ValueKey<String> claveConfirmar = ValueKey<String>('confirmar-plan');

  Future<void> pagar(WidgetTester tester) async {
    await tester.tap(find.byKey(claveSolicitar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(claveConfirmar));
    await tester.pumpAndSettle();
  }

  group('pago en linea', () {
    testWidgets(
      'pagar en Costa Rica: confirma, abre la pantalla de pago con la URL y no cobra antes de confirmar',
      (WidgetTester tester) async {
        await abrir(tester);

        await tester.tap(find.byKey(claveSolicitar));
        await tester.pumpAndSettle();
        expect(find.text('¿Pagar este plan?'), findsOneWidget);
        expect(find.textContaining('₡10.000 por 30 días'), findsOneWidget);
        expect(api.pedidos, isEmpty);
        expect(urlsAbiertas, isEmpty);

        await tester.tap(find.byKey(claveConfirmar));
        await tester.pumpAndSettle();

        expect(api.pedidos, <({int planId, String pais})>[
          (planId: 1, pais: 'CR'),
        ]);
        expect(urlsAbiertas, <String>['https://checkout.onvopay.com/pay/cs_1']);
      },
    );

    testWidgets(
      'si el pago termina bien y el plan ya esta activo, lo muestra y avisa',
      (WidgetTester tester) async {
        terminaCon = ResultadoPago.exito;
        alPagar = () => api.suscripcion = MiSuscripcion(
          id: 9,
          estado: EstadoSuscripcion.activa,
          vigente: true,
          planNombre: 'Plan Mensual',
          venceEn: DateTime(2026, 11, 26),
        );
        await abrir(tester);

        await pagar(tester);

        expect(find.text('Plan activo'), findsOneWidget);
        expect(
          find.text('¡Pago recibido! Tu plan ya está activo.'),
          findsOneWidget,
        );
        expect(find.byKey(claveSolicitar), findsNothing);
      },
    );

    testWidgets(
      'si volvio del pago pero ONVO aun no confirma, no dice que esta activo',
      (WidgetTester tester) async {
        terminaCon = ResultadoPago.exito;
        await abrir(tester);

        await pagar(tester);

        expect(
          find.text('¡Pago recibido! Tu plan ya está activo.'),
          findsNothing,
        );
        expect(find.text('Plan activo'), findsNothing);
      },
    );

    testWidgets('cancelar el pago lo dice y deja pagar de nuevo', (
      WidgetTester tester,
    ) async {
      terminaCon = ResultadoPago.cancelado;
      await abrir(tester);

      await pagar(tester);

      expect(
        find.text('El pago se canceló. No se hizo ningún cobro.'),
        findsOneWidget,
      );
      expect(find.byKey(claveSolicitar), findsOneWidget);
    });

    testWidgets(
      'cerrar la pantalla de pago a mano no avisa nada y vuelve a consultar',
      (WidgetTester tester) async {
        terminaCon = null;
        await abrir(tester);

        await pagar(tester);

        expect(find.textContaining('canceló'), findsNothing);
        expect(find.textContaining('Pago recibido'), findsNothing);
        expect(find.byKey(claveSolicitar), findsOneWidget);
      },
    );

    testWidgets(
      'un pago en linea sin completar muestra los planes con el aviso, no "en revision"',
      (WidgetTester tester) async {
        api.suscripcion = const MiSuscripcion(
          id: 9,
          estado: EstadoSuscripcion.solicitada,
          vigente: false,
          planNombre: 'Plan Mensual',
          numeroSolicitud: '482913',
          pagoEnLinea: true,
        );
        await abrir(tester);

        expect(
          find.text(
            'Tu pago anterior no se completó. Puedes intentarlo de nuevo.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(claveSolicitar), findsOneWidget);
        expect(find.text('Solicitud en revisión'), findsNothing);
      },
    );

    testWidgets(
      'una solicitud manual de antes sigue "en revision" y ya no trae instrucciones de SINPE',
      (WidgetTester tester) async {
        api.suscripcion = const MiSuscripcion(
          id: 9,
          estado: EstadoSuscripcion.solicitada,
          vigente: false,
          planNombre: 'Plan Mensual',
          numeroSolicitud: '482913',
        );
        await abrir(tester);

        expect(find.text('Solicitud en revisión'), findsOneWidget);
        expect(find.byKey(claveSolicitar), findsNothing);
        expect(find.textContaining('SINPE'), findsNothing);
      },
    );
  });

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
      expect(find.text('¿Pagar este plan?'), findsNothing);
      expect(api.pedidos, isEmpty);
    },
  );

  group('region del telefono', () {
    const RespuestaPlanes paypal = RespuestaPlanes(
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
    const RespuestaPlanes onvo = RespuestaPlanes(
      planes: <PlanPatrocinio>[_mensual],
    );

    setUp(() {
      api.segunPais = (String pais) => pais == 'CR' ? onvo : paypal;
    });

    void ponerRegion(WidgetTester tester, Locale locale) {
      tester.platformDispatcher.localeTestValue = locale;
      tester.platformDispatcher.localesTestValue = <Locale>[locale];
    }

    Future<void> abrirSinPais(
      WidgetTester tester,
      Locale region, {
      AlmacenRegionPago? almacen,
    }) async {
      await montarApp(
        tester,
        regionTelefono: region,
        PlanPatrocinioScreen(
          api: api,
          almacenRegion: almacen ?? _AlmacenRegionFalso(),
          ahora: () => _hoy,
          esEmpresa: false,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'si cambia la region con la pantalla abierta, se vuelven a pedir los planes y sale el pago por ONVO',
      (WidgetTester tester) async {
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await abrirSinPais(tester, const Locale('en', 'US'));
        expect(
          find.byKey(const ValueKey<String>('plan-paypal')),
          findsOneWidget,
        );

        ponerRegion(tester, const Locale('es', 'CR'));
        await tester.pumpAndSettle();

        expect(api.paisesConsultados, <String>['US', 'CR']);
        expect(find.byKey(const ValueKey<String>('plan-paypal')), findsNothing);
        expect(find.text('₡10.000'), findsOneWidget);
      },
    );

    testWidgets(
      'al volver a la app despues de cambiar la region en Ajustes tambien se actualiza',
      (WidgetTester tester) async {
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await abrirSinPais(tester, const Locale('en', 'US'));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        ponerRegion(tester, const Locale('es', 'CR'));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(api.paisesConsultados.last, 'CR');
        expect(find.byKey(const ValueKey<String>('plan-paypal')), findsNothing);
      },
    );

    testWidgets(
      'desde un telefono en otra region, elegir Costa Rica da el pago por ONVO y se recuerda',
      (WidgetTester tester) async {
        final _AlmacenRegionFalso almacen = _AlmacenRegionFalso();
        await abrirSinPais(tester, const Locale('en', 'US'), almacen: almacen);
        expect(
          find.byKey(const ValueKey<String>('plan-paypal')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('region-costa-rica')),
        );
        await tester.pumpAndSettle();

        expect(api.paisesConsultados, <String>['US', 'CR']);
        expect(find.byKey(const ValueKey<String>('plan-paypal')), findsNothing);
        expect(find.text('₡10.000'), findsOneWidget);
        expect(almacen.guardada, RegionPago.costaRica);
      },
    );

    testWidgets(
      'lo elegido antes manda sobre lo que dice el telefono, y un cambio de region del telefono no lo pisa',
      (WidgetTester tester) async {
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await abrirSinPais(
          tester,
          const Locale('en', 'US'),
          almacen: _AlmacenRegionFalso(RegionPago.costaRica),
        );
        expect(api.paisesConsultados, <String>['CR']);

        ponerRegion(tester, const Locale('de', 'DE'));
        await tester.pumpAndSettle();

        expect(api.paisesConsultados, <String>['CR']);
        expect(find.byKey(const ValueKey<String>('plan-paypal')), findsNothing);
      },
    );

    testWidgets(
      '"Otro país" desde un telefono que dice Costa Rica muestra PayPal',
      (WidgetTester tester) async {
        await abrirSinPais(tester, const Locale('es', 'CR'));
        expect(find.byKey(const ValueKey<String>('plan-paypal')), findsNothing);

        await tester.tap(find.byKey(const ValueKey<String>('region-otro')));
        await tester.pumpAndSettle();

        expect(api.paisesConsultados.last, isNot('CR'));
        expect(
          find.byKey(const ValueKey<String>('plan-paypal')),
          findsOneWidget,
        );
      },
    );

    testWidgets('si la region no cambia, no vuelve a consultar', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await abrirSinPais(tester, const Locale('es', 'CR'));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(api.paisesConsultados, <String>['CR']);
    });
  });

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
        find.text('No se pudo iniciar el pago. Inténtalo de nuevo.'),
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
        'planes': <dynamic>[],
      });
      expect(r.metodoPago, MetodoPago.paypal);
      expect(r.pagoDisponible, isFalse);
    });

    test('PagoIniciado lee la URL de pago y el numero de solicitud', () {
      final PagoIniciado p = PagoIniciado.fromJson(<String, dynamic>{
        'suscripcionId': 9,
        'numeroSolicitud': '482913',
        'url': 'https://checkout.onvopay.com/pay/cs_1',
      });
      expect(p.suscripcionId, 9);
      expect(p.numeroSolicitud, '482913');
      expect(p.url, 'https://checkout.onvopay.com/pay/cs_1');
    });

    test('una solicitud de antes no es un pago en linea', () {
      final MiSuscripcion s = MiSuscripcion.fromJson(<String, dynamic>{
        'id': 1,
        'estado': 'Solicitada',
        'vigente': false,
        'planNombre': 'P',
      });
      expect(s.pagoEnLinea, isFalse);
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
        'pagoEnLinea': true,
        'audiencia': 'usuario',
      });
      expect(s.numeroSolicitud, '123456');
      expect(s.pagoEnLinea, isTrue);
      expect(s.monto, 2500);
      expect(s.audiencia, 'usuario');
    });
  });
}
