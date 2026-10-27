import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/navegador_app.dart';
import 'package:fit_quest_go/core/push/servicio_push.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/notificaciones_screen.dart';

/// Mientras haya una sesion abierta, deja registrado este telefono para los
/// avisos fuera de la app y lleva al centro de notificaciones cuando se toca uno.
///
/// Se monta una vez iniciada la sesion y desaparece al cerrarla. El idioma de
/// la app viaja con el registro (el aviso se escribe en ese idioma) y se
/// actualiza solo si la persona lo cambia.
class RegistroPush extends StatefulWidget {
  const RegistroPush({
    super.key,
    required this.child,
    this.servicio,
    this.pantallaNotificaciones,
  });

  final Widget child;

  /// Inyectable para pruebas; por defecto [ServicioPush.instancia].
  final ServicioPush? servicio;

  /// La pantalla a la que lleva tocar un aviso; las pruebas ponen otra para no
  /// ir a la red.
  final Widget Function()? pantallaNotificaciones;

  @override
  State<RegistroPush> createState() => _RegistroPushState();
}

class _RegistroPushState extends State<RegistroPush> {
  ServicioPush get _push => widget.servicio ?? ServicioPush.instancia;
  String? _idioma;

  @override
  void initState() {
    super.initState();
    _push.alTocarAviso = _abrirNotificaciones;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String idioma = idiomaDeAviso(Localizations.localeOf(context));
    if (idioma == _idioma) return;
    final bool primera = _idioma == null;
    _idioma = idioma;
    // La primera vez puede pedir el permiso del sistema; los cambios de idioma
    // solo actualizan el registro, nunca preguntan de nuevo.
    _push.registrar(idioma: idioma, pedirPermiso: primera);
  }

  @override
  void didUpdateWidget(RegistroPush anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.servicio != widget.servicio) {
      _push.alTocarAviso = _abrirNotificaciones;
    }
  }

  @override
  void dispose() {
    if (_push.alTocarAviso == _abrirNotificaciones) _push.alTocarAviso = null;
    super.dispose();
  }

  void _abrirNotificaciones() {
    navegadorApp.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            widget.pantallaNotificaciones?.call() ??
            const NotificacionesScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// `es`, `en` o `pt`: los idiomas en que el servidor sabe escribir un aviso.
String idiomaDeAviso(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return 'en';
    case 'pt':
      return 'pt';
    default:
      return 'es';
  }
}
