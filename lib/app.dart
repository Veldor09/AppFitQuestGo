import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_theme.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/admin_shell.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/bienvenida_screen.dart';
import 'package:fit_quest_go/Modulos/home/presentation/home_usuario_screen.dart';

/// Widget raiz. Publica el [AuthRepositorio] al arbol y monta el `MaterialApp`.
class FitQuestGoApp extends StatelessWidget {
  const FitQuestGoApp({super.key, required this.auth});

  final AuthRepositorio auth;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: auth,
      child: MaterialApp(
        title: 'FitQuest Go',
        debugShowCheckedModeBanner: false,
        theme: buildFqTheme(),
        home: const _RootGate(),
        builder: (BuildContext context, Widget? child) =>
            NotificacionesHost(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Decide la pantalla inicial segun la sesion:
///  - sin sesion        -> Bienvenida (flujo de auth)
///  - sesion + Admin     -> panel de administracion
///  - sesion + otro rol  -> home de usuario
///
/// Al escuchar el [AuthRepositorio] via [AuthScope.of], cualquier login,
/// registro o cierre de sesion recompone esta vista automaticamente.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final AuthRepositorio auth = AuthScope.of(context);

    if (!auth.autenticado) {
      return const BienvenidaScreen();
    }
    final UsuarioSesion usuario = auth.usuario!;
    return usuario.esAdmin ? const AdminShell() : const HomeUsuarioScreen();
  }
}
