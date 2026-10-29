import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/db/daos/rutas_offline_dao.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/Modulos/patrocinio/application/plan_usuario.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/plan_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/ruta_detalle_screen.dart';

import 'helpers/calificacion_falsa.dart';
import 'helpers/montar.dart';

Ruta _ruta(int id) => Ruta(
  id: id,
  nombre: 'Ruta $id',
  actividades: const <String>['running'],
  dificultad: 'moderada',
  distanciaKm: 5,
  puntos: const <PuntoRuta>[
    PuntoRuta(lat: 9.9281, lng: -84.0907),
    PuntoRuta(lat: 9.9291, lng: -84.0917),
    PuntoRuta(lat: 9.9301, lng: -84.0927),
  ],
  estado: 'Publicada',
);

class _RutaApiFalsa extends RutaApi {
  @override
  Future<Set<int>> favoritasIds() async => <int>{};

  @override
  Future<List<Ruta>> favoritas() async => <Ruta>[];
}

class _OfflineFalso extends RutasOfflineDao {
  _OfflineFalso(int cuantas)
    : guardadas = <Ruta>[for (int i = 1; i <= cuantas; i++) _ruta(100 + i)];

  final List<Ruta> guardadas;
  int intentosDeGuardar = 0;

  @override
  Future<List<Ruta>> listar() async => List<Ruta>.of(guardadas);

  @override
  Future<bool> estaGuardada(int idRemoto) async =>
      guardadas.any((Ruta r) => r.id == idRemoto);

  @override
  Future<bool> guardar(Ruta ruta) async {
    intentosDeGuardar++;
    guardadas.add(ruta);
    return true;
  }
}

class _AlmacenPlan implements AlmacenPlanUsuario {
  DateTime? hasta;

  @override
  Future<DateTime?> leerVigenteHasta() async => hasta;

  @override
  Future<void> guardarVigenteHasta(DateTime? fecha) async => hasta = fecha;
}

class _PlanApiFalsa extends PlanApi {
  MiSuscripcion? respuesta;

  @override
  Future<MiSuscripcion?> miSuscripcion() async => respuesta;
}

void main() {
  late _PlanApiFalsa planApi;
  late PlanUsuario anterior;

  setUp(() {
    planApi = _PlanApiFalsa();
    anterior = PlanUsuario.instancia;
    PlanUsuario.instancia = PlanUsuario(
      api: planApi,
      almacen: _AlmacenPlan(),
      ahora: () => DateTime(2026, 10, 29),
    );
  });
  tearDown(() => PlanUsuario.instancia = anterior);

  Future<_OfflineFalso> abrir(
    WidgetTester tester, {
    required int guardadas,
    AuthFalso? auth,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _OfflineFalso dao = _OfflineFalso(guardadas);
    await montarApp(
      tester,
      RutaDetalleScreen(
        ruta: _ruta(5),
        api: _RutaApiFalsa(),
        calificaciones: CalificacionApiFalsa(),
        offlineDao: dao,
      ),
      auth: auth,
    );
    await tester.pumpAndSettle();
    return dao;
  }

  Future<void> tocarGuardarOffline(
    WidgetTester tester, {
    bool esperarAlFinal = true,
  }) async {
    await tester.scrollUntilVisible(
      find.text('Guardar para uso offline'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar para uso offline'));
    if (esperarAlFinal) {
      await tester.pumpAndSettle();
    } else {
      // Guardar la ruta deja una descarga de mapa en curso (que en pruebas no
      // termina): se avanza un poco en vez de esperar a que todo se quede quieto.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets(
    'sin suscripcion, en la ruta 4 le sale la invitacion a pedir un plan (no un error)',
    (WidgetTester tester) async {
      final _OfflineFalso dao = await abrir(tester, guardadas: 3);

      await tocarGuardarOffline(tester);

      expect(find.text('Necesitas una suscripción'), findsOneWidget);
      expect(
        find.textContaining('límite de 3 rutas guardadas sin conexión'),
        findsOneWidget,
      );
      expect(find.textContaining('hasta 15'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('invitacion-ver-planes')),
        findsOneWidget,
      );
      expect(dao.intentosDeGuardar, 0);
    },
  );

  testWidgets('con una suscripcion vigente guarda la cuarta ruta sin trabas', (
    WidgetTester tester,
  ) async {
    planApi.respuesta = MiSuscripcion(
      id: 1,
      estado: EstadoSuscripcion.activa,
      vigente: true,
      planNombre: 'Plan Explorador',
      venceEn: DateTime(2026, 11, 20),
      audiencia: AudienciaPlan.usuario,
    );
    final _OfflineFalso dao = await abrir(tester, guardadas: 3);

    await tocarGuardarOffline(tester, esperarAlFinal: false);

    expect(find.text('Necesitas una suscripción'), findsNothing);
    expect(dao.intentosDeGuardar, 1);
  });

  testWidgets(
    'con suscripcion el tope sigue existiendo: al llegar a 15 solo se avisa',
    (WidgetTester tester) async {
      planApi.respuesta = MiSuscripcion(
        id: 1,
        estado: EstadoSuscripcion.activa,
        vigente: true,
        planNombre: 'Plan Explorador',
        venceEn: DateTime(2026, 11, 20),
        audiencia: AudienciaPlan.usuario,
      );
      final _OfflineFalso dao = await abrir(tester, guardadas: 15);

      await tocarGuardarOffline(tester);

      expect(find.text('Necesitas una suscripción'), findsNothing);
      expect(
        find.text(
          'Límite de 15 rutas sin conexión alcanzado. Elimina una para descargar otra.',
        ),
        findsOneWidget,
      );
      expect(dao.intentosDeGuardar, 0);
    },
  );

  testWidgets(
    'una cuenta de empresa no recibe la invitacion (su plan es para destacar, no para descargar)',
    (WidgetTester tester) async {
      final AuthFalso empresa = AuthFalso(
        usuario: const UsuarioSesion(
          id: 20,
          nombre: 'Cafe El Roble',
          email: 'c@e.co',
          rol: RolUsuario.empresa,
        ),
      );
      await abrir(tester, guardadas: 3, auth: empresa);

      await tocarGuardarOffline(tester);

      expect(find.text('Necesitas una suscripción'), findsNothing);
      expect(
        find.text(
          'Límite de 3 rutas sin conexión alcanzado. Elimina una para descargar otra.',
        ),
        findsOneWidget,
      );
    },
  );
}
