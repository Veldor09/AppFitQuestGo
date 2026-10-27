import 'package:flutter/widgets.dart';

/// El `Navigator` raiz de la app, para abrir pantallas desde fuera del arbol de
/// widgets (por ejemplo al tocar un aviso del sistema).
final GlobalKey<NavigatorState> navegadorApp = GlobalKey<NavigatorState>();
