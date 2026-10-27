import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/push/push_api.dart';

/// Avisos fuera de la app (el telefono suena aunque FitQuest Go este cerrada).
///
/// Solo llegan los resultados importantes de algo que la persona pidio (una
/// ruta aprobada o rechazada, el plan de patrocinio...); el resto vive en la
/// campana de la app. El servidor decide que se manda; aqui solo se registra
/// el telefono.
///
/// Todo es opcional: si el proyecto no tiene Firebase configurado
/// (`android/app/google-services.json`), la app funciona igual y no pasa nada.
abstract class ServicioPush {
  /// El que usa la app. En `flutter test` (que corre en el escritorio) es el
  /// nulo, asi que ninguna prueba toca Firebase.
  static ServicioPush instancia = _porDefecto();

  static ServicioPush _porDefecto() {
    if (kIsWeb) return ServicioPushNulo();
    return (Platform.isAndroid || Platform.isIOS)
        ? ServicioPushFirebase()
        : ServicioPushNulo();
  }

  /// Hay Firebase funcionando en esta instalacion.
  bool get disponible;

  /// Se llama cuando la persona toca un aviso (con la app cerrada o en segundo
  /// plano). La app abre ahi el centro de notificaciones.
  VoidCallback? alTocarAviso;

  /// Registra este telefono para la cuenta actual. [idioma] es `es`, `en` o
  /// `pt`. Con [pedirPermiso] se muestra, una vez, el permiso de notificaciones
  /// del sistema; sin el, solo se registra si ya estaba concedido. Nunca lanza.
  Future<void> registrar({required String idioma, bool pedirPermiso = true});

  /// Quita este telefono de la cuenta (cerrar sesion o apagar el interruptor)
  /// para que deje de recibir avisos. Nunca lanza.
  Future<void> quitar();
}

/// Sin Firebase: no hace nada.
class ServicioPushNulo extends ServicioPush {
  @override
  bool get disponible => false;

  @override
  Future<void> registrar({
    required String idioma,
    bool pedirPermiso = true,
  }) async {}

  @override
  Future<void> quitar() async {}
}

/// Firebase Cloud Messaging. Se prepara solo cuando hace falta (al iniciar
/// sesion), no al abrir la app, y si algo falla se queda en silencio.
class ServicioPushFirebase extends ServicioPush {
  ServicioPushFirebase({PushApi? api, this.espera = const Duration(seconds: 3)})
    : _apiInyectada = api;

  final PushApi? _apiInyectada;
  PushApi get _api => _apiInyectada ?? (_apiCreada ??= PushApi());
  PushApi? _apiCreada;

  /// Pausa antes de preguntar el permiso por primera vez: que la persona vea la
  /// pantalla antes de que le salga el cuadro del sistema.
  final Duration espera;

  bool _intentado = false;
  bool _listo = false;
  bool _yaEspero = false;
  String? _token;
  String _idioma = 'es';
  final List<StreamSubscription<Object?>> _suscripciones =
      <StreamSubscription<Object?>>[];

  @override
  bool get disponible => _listo;

  Future<bool> _preparar() async {
    if (_intentado) return _listo;
    _intentado = true;
    try {
      await Firebase.initializeApp();
      _listo = true;
    } catch (e) {
      // Sin google-services.json no hay proyecto de Firebase: la app sigue.
      debugPrint('Avisos fuera de la app desactivados: $e');
    }
    return _listo;
  }

  @override
  Future<void> registrar({
    required String idioma,
    bool pedirPermiso = true,
  }) async {
    _idioma = idioma;
    try {
      if (!await _preparar()) return;
      final FirebaseMessaging mensajes = FirebaseMessaging.instance;

      NotificationSettings ajustes = await mensajes.getNotificationSettings();
      if (ajustes.authorizationStatus == AuthorizationStatus.notDetermined) {
        if (!pedirPermiso) return;
        if (!_yaEspero) {
          _yaEspero = true;
          await Future<void>.delayed(espera);
        }
        ajustes = await mensajes.requestPermission(badge: false);
      }
      final AuthorizationStatus estado = ajustes.authorizationStatus;
      if (estado != AuthorizationStatus.authorized &&
          estado != AuthorizationStatus.provisional) {
        // Dijo que no: no se insiste.
        return;
      }

      final String? token = await mensajes.getToken();
      if (token == null) return;
      _token = token;
      await _api.registrar(
        token: token,
        plataforma: Platform.isIOS ? 'ios' : 'android',
        idioma: idioma,
      );
      _escuchar(mensajes);
    } catch (e) {
      debugPrint('No se pudo registrar el telefono para avisos: $e');
    }
  }

  void _escuchar(FirebaseMessaging mensajes) {
    if (_suscripciones.isNotEmpty) return;
    _suscripciones.addAll(<StreamSubscription<Object?>>[
      // Firebase cambia el token de vez en cuando: se vuelve a registrar.
      mensajes.onTokenRefresh.listen((String nuevo) async {
        _token = nuevo;
        try {
          await _api.registrar(
            token: nuevo,
            plataforma: Platform.isIOS ? 'ios' : 'android',
            idioma: _idioma,
          );
        } catch (_) {}
      }),
      // Con la app abierta el sistema no muestra el aviso: se ve como un
      // mensaje corto y la campana se pone al dia sola.
      FirebaseMessaging.onMessage.listen((RemoteMessage m) {
        final String? titulo = m.notification?.title;
        if (titulo != null && titulo.isNotEmpty) notificarInfo(titulo);
      }),
      // Tocar el aviso con la app en segundo plano.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage _) {
        alTocarAviso?.call();
      }),
    ]);
    // Tocar el aviso con la app cerrada del todo.
    unawaited(
      mensajes.getInitialMessage().then((RemoteMessage? m) {
        if (m != null) alTocarAviso?.call();
      }),
    );
  }

  @override
  Future<void> quitar() async {
    try {
      if (!_listo) return;
      final FirebaseMessaging mensajes = FirebaseMessaging.instance;
      final String? token = _token ?? await mensajes.getToken();
      for (final StreamSubscription<Object?> s in _suscripciones) {
        await s.cancel();
      }
      _suscripciones.clear();
      if (token != null) await _api.quitar(token);
      // Un token nuevo para la proxima cuenta de este telefono.
      await mensajes.deleteToken();
      _token = null;
    } catch (e) {
      debugPrint('No se pudo quitar el telefono de los avisos: $e');
    }
  }
}
