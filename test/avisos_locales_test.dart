import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/db/daos/notificaciones_cache_dao.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/voz/aviso_voz.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';
import 'package:fit_quest_go/Modulos/clima/data/clima_api.dart';
import 'package:fit_quest_go/Modulos/home/presentation/home_usuario_screen.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/campana_notificaciones.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/perfil/data/avisos_locales.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificaciones_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/notificaciones_screen.dart';

import 'helpers/avisos_locales_falso.dart';
import 'helpers/home_falsos.dart';
import 'helpers/montar.dart';

const PosicionGps _aqui = (lat: 9.9281, lng: -84.0907);

const AlertaClima _calor = AlertaClima(
  tipo: TipoClima.calor,
  nivel: NivelClima.peligro,
  enHoras: 0,
  valor: 41.5,
);

class _NodoApiFalsa extends NodoApi {
  @override
  Future<List<Nodo>> listar() async => <Nodo>[];
}

class _AlertaApiFalsa extends AlertaApi {
  @override
  Future<List<Alerta>> listar() async => <Alerta>[];
}

class _ClimaApiFalsa extends ClimaApi {
  List<AlertaClima> respuesta = <AlertaClima>[];

  @override
  Future<RespuestaClima> alertas({required double lat, required double lng}) async =>
      RespuestaClima(alertas: respuesta, fuente: 'Open-Meteo');
}

class _VozFalsa implements AvisoVoz {
  @override
  Future<void> decir(String texto, {required Locale idioma}) async {}

  @override
  Future<void> detener() async {}
}

class _AuthFalso extends AuthRepositorio {
  @override
  UsuarioSesion? get usuario => const UsuarioSesion(
    id: 1,
    nombre: 'Yo',
    email: 'yo@x.co',
    rol: RolUsuario.userNormal,
  );
}

/// Servidor sin nada, pero que anota si se le pregunto o se le mando algo.
class _NotificacionesApiSinNada extends NotificacionesApi {
  final List<int> marcadas = <int>[];
  final List<int> eliminadas = <int>[];
  bool marcoTodas = false;
  int noLeidas = 0;

  @override
  Future<List<Notificacion>> listar() async => <Notificacion>[];

  @override
  Future<int> conteoNoLeidas() async => noLeidas;

  @override
  Future<void> marcarLeida(int id) async => marcadas.add(id);

  @override
  Future<void> marcarTodasLeidas() async => marcoTodas = true;

  @override
  Future<void> eliminar(int id) async => eliminadas.add(id);
}

class _CacheVacio extends NotificacionesCacheDao {
  @override
  Future<List<Notificacion>> listar({String? categoria}) async => <Notificacion>[];

  @override
  Future<void> guardarTodas(List<Notificacion> notificaciones) async {}
}

Future<AppLocalizations> _textos(WidgetTester tester, Locale locale) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) {
          l10n = AppLocalizations.of(context)!;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return l10n;
}

void main() {
  group('avisoDeClima', () {
    testWidgets('lleva titulo y consejo en el idioma de la app, categoria clima', (
      WidgetTester tester,
    ) async {
      final AvisoLocal es = avisoDeClima(await _textos(tester, const Locale('es')), _calor);
      final AvisoLocal en = avisoDeClima(await _textos(tester, const Locale('en')), _calor);

      expect(es.categoria, 'clima');
      expect(es.titulo, 'Calor extremo en tu zona');
      expect(en.titulo, isNot(es.titulo));
      expect(en.mensaje, isNot(es.mensaje));
    });

    testWidgets('el mismo aviso dentro de la ventana comparte clave; pasada la ventana, no', (
      WidgetTester tester,
    ) async {
      final AppLocalizations l10n = await _textos(tester, const Locale('es'));
      final DateTime t0 = DateTime.utc(2026, 10, 27, 12);

      final String a = avisoDeClima(l10n, _calor, ahora: t0).clave;
      final String b = avisoDeClima(l10n, _calor, ahora: t0.add(const Duration(minutes: 30))).clave;
      final String c = avisoDeClima(l10n, _calor, ahora: t0.add(kVentanaAvisoClima)).clave;

      expect(b, a);
      expect(c, isNot(a));
    });
  });

  group('bandeja de avisos locales', () {
    test('la misma clave no se registra dos veces', () async {
      final AvisosLocalesFalso locales = AvisosLocalesFalso();
      final AvisoLocal aviso = AvisoLocal(
        clave: 'alerta:7',
        categoria: 'alertas',
        titulo: 't',
        mensaje: 'm',
        creadaEn: DateTime(2026, 10, 27),
      );

      await locales.registrar(aviso);
      await locales.registrar(aviso);

      expect((await locales.listar()), hasLength(1));
      expect((await locales.listar()).single.esLocal, isTrue);
    });
  });

  group('centro de notificaciones', () {
    Future<(_NotificacionesApiSinNada, AvisosLocalesFalso)> montar(
      WidgetTester tester,
    ) async {
      final _NotificacionesApiSinNada api = _NotificacionesApiSinNada();
      final AvisosLocalesFalso locales = AvisosLocalesFalso();
      await locales.registrar(
        AvisoLocal(
          clave: 'clima:calor:peligro:1',
          categoria: 'clima',
          titulo: 'Calor extremo en tu zona',
          mensaje: 'Ahora · Hidratate',
          creadaEn: DateTime.now(),
        ),
      );
      await montarApp(
        tester,
        NotificacionesScreen(api: api, cacheDao: _CacheVacio(), avisosLocales: locales),
      );
      await tester.pumpAndSettle();
      return (api, locales);
    }

    testWidgets('el aviso del clima que salio en el mapa se encuentra aqui, con su filtro', (
      WidgetTester tester,
    ) async {
      await montar(tester);

      expect(find.text('Calor extremo en tu zona'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_rounded), findsOneWidget);

      await tester.ensureVisible(find.text('Clima'));
      await tester.tap(find.text('Clima'));
      await tester.pumpAndSettle();
      expect(find.text('Calor extremo en tu zona'), findsOneWidget);

      await tester.tap(find.text('Rutas'));
      await tester.pumpAndSettle();
      expect(find.text('Calor extremo en tu zona'), findsNothing);
    });

    testWidgets('abrirlo lo marca leido en el telefono y nunca le pregunta al servidor', (
      WidgetTester tester,
    ) async {
      final (_NotificacionesApiSinNada api, AvisosLocalesFalso locales) = await montar(tester);
      expect(await locales.conteoNoLeidas(), 1);

      await tester.tap(find.text('Calor extremo en tu zona'));
      await tester.pumpAndSettle();

      expect(await locales.conteoNoLeidas(), 0);
      expect(api.marcadas, isEmpty);
    });
  });

  group('Home deja constancia de lo que muestra', () {
    late AvisosLocalesFalso locales;
    late _NotificacionesApiSinNada notificaciones;
    late _ClimaApiFalsa clima;
    late StreamController<PosicionGps> gps;

    Future<void> montar(WidgetTester tester) async {
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
      tester.platformDispatcher.localeTestValue = const Locale('es');
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      locales = AvisosLocalesFalso();
      notificaciones = _NotificacionesApiSinNada();
      clima = _ClimaApiFalsa();
      gps = StreamController<PosicionGps>();
      addTearDown(gps.close);
      await tester.pumpWidget(
        AuthScope(
          auth: _AuthFalso(),
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (BuildContext context, Widget? child) =>
                NotificacionesHost(child: child!),
            home: Scaffold(
              body: HomeUsuarioScreen(
                nodoApi: _NodoApiFalsa(),
                alertaApi: _AlertaApiFalsa(),
                climaApi: clima,
                eventoApi: EventoApiVacia(),
                rutaApi: RutaApiVacia(),
                notificacionesApi: notificaciones,
                avisosLocales: locales,
                voz: _VozFalsa(),
                posiciones: () => gps.stream,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('el aviso del clima se guarda, se va solo del mapa y queda en la bandeja', (
      WidgetTester tester,
    ) async {
      await montar(tester);
      clima.respuesta = <AlertaClima>[_calor];

      gps.add(_aqui);
      await tester.pump();
      await tester.pump();

      expect(find.text('Calor extremo en tu zona'), findsOneWidget);
      expect(locales.registrados.map((AvisoLocal a) => a.categoria), <String>['clima']);

      // Pasan unos segundos: el aviso sale del mapa, pero sigue en la bandeja.
      await tester.pump(const Duration(seconds: 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Calor extremo en tu zona'), findsNothing);
      expect((await locales.listar()).single.titulo, 'Calor extremo en tu zona');
    });

    testWidgets('la campana cuenta los avisos locales sin leer junto con los del servidor', (
      WidgetTester tester,
    ) async {
      await montar(tester);
      notificaciones.noLeidas = 2;
      clima.respuesta = <AlertaClima>[_calor];

      gps.add(_aqui);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.descendant(of: find.byType(CampanaNotificaciones), matching: find.text('3')), findsOneWidget);
    });
  });
}
