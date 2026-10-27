import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/idioma/idioma_app.dart';
import 'package:fit_quest_go/core/navegador_app.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/push/registro_push.dart';
import 'package:fit_quest_go/core/theme/fq_theme.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/admin_shell.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/bienvenida_screen.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/empresa_shell.dart';
import 'package:fit_quest_go/Modulos/home/presentation/user_shell.dart';

/// Widget raiz. Publica el [AuthRepositorio] al arbol y monta el `MaterialApp`.
class FitQuestGoApp extends StatelessWidget {
  const FitQuestGoApp({super.key, required this.auth, this.idioma});

  final AuthRepositorio auth;

  /// El idioma elegido en Preferencias; por defecto el de toda la app.
  final ControladorIdioma? idioma;

  @override
  Widget build(BuildContext context) {
    final ControladorIdioma controlador = idioma ?? ControladorIdioma.instancia;
    return AuthScope(
      auth: auth,
      child: ListenableBuilder(
        listenable: controlador,
        builder: (BuildContext context, Widget? _) => MaterialApp(
          title: 'FitQuest Go',
          debugShowCheckedModeBanner: false,
          navigatorKey: navegadorApp,
          theme: buildFqTheme(),
          // Nulo = el idioma del telefono; si la persona eligio uno, manda ese.
          locale: controlador.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // `es` primero: si el idioma del dispositivo no esta en esta lista,
          // la app cae en espanol (el idioma con el que se construyo y probo
          // el resto de la UI), no en ingles.
          supportedLocales: const <Locale>[
            Locale('es'),
            Locale('en'),
            Locale('pt', 'BR'),
          ],
          home: const _RootGate(),
          builder: (BuildContext context, Widget? child) {
            // Los validadores de formularios no tienen contexto: se les pasa
            // aqui el idioma vigente cada vez que cambia.
            usarTextosDeValidacion(AppLocalizations.of(context));
            return NotificacionesHost(child: child ?? const SizedBox.shrink());
          },
        ),
      ),
    );
  }
}

/// Que panel abre cada rol al iniciar sesion.
enum PantallaRaiz { admin, empresa, usuario }

/// El panel de [usuario]: el admin gestiona la plataforma, la empresa publica
/// sus eventos y nodos, y todos los demas entran como deportistas.
PantallaRaiz pantallaRaizDe(UsuarioSesion usuario) {
  if (usuario.esAdmin) return PantallaRaiz.admin;
  if (usuario.esEmpresa) return PantallaRaiz.empresa;
  return PantallaRaiz.usuario;
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final AuthRepositorio auth = AuthScope.of(context);

    if (!auth.autenticado) {
      return const BienvenidaScreen();
    }
    switch (pantallaRaizDe(auth.usuario!)) {
      case PantallaRaiz.admin:
        return const AdminShell();
      // Avisos fuera de la app: para quien publica y para quien hace deporte.
      // El admin no los recibe (no hay nada que avisarle).
      case PantallaRaiz.empresa:
        return const RegistroPush(child: EmpresaShell());
      case PantallaRaiz.usuario:
        return const RegistroPush(child: UserShell());
    }
  }
}
