import 'package:flutter/widgets.dart';

import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';

/// Expone el [AuthRepositorio] al arbol de widgets sin dependencias externas.
///
/// Se apoya en [InheritedNotifier], de modo que los widgets que llamen a
/// [AuthScope.of] se reconstruyen cuando cambia la sesion; los que solo
/// necesitan invocar acciones usan [AuthScope.read] y no se suscriben.
class AuthScope extends InheritedNotifier<AuthRepositorio> {
  const AuthScope({
    super.key,
    required AuthRepositorio auth,
    required super.child,
  }) : super(notifier: auth);

  static AuthRepositorio of(BuildContext context) {
    final AuthScope? scope =
        context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No se encontro AuthScope en el arbol de widgets.');
    return scope!.notifier!;
  }

  static AuthRepositorio read(BuildContext context) {
    final AuthScope? scope =
        context.getInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No se encontro AuthScope en el arbol de widgets.');
    return scope!.notifier!;
  }
}
