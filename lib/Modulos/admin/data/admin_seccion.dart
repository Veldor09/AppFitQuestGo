import 'package:flutter/widgets.dart';

/// Descriptor de una seccion del panel de administracion.
///
/// El panel se arma a partir de una lista de estos descriptores
/// ([adminSecciones]); agregar o quitar pantallas no obliga a tocar el shell ni
/// el sidebar (principio abierto/cerrado).
@immutable
class AdminSeccion {
  const AdminSeccion({
    required this.code,
    required this.navLabel,
    required this.headerTitle,
    required this.descripcion,
    required this.icono,
    required this.builder,
  });

  /// Codigo del sistema de diseno (p. ej. `ADM-02`).
  final String code;

  /// Texto que aparece en el sidebar.
  final String navLabel;

  /// Titulo corto que muestra la barra superior.
  final String headerTitle;

  /// Descripcion breve (tooltip / subtitulo).
  final String descripcion;

  final IconData icono;

  /// Construye el contenido de la seccion.
  final WidgetBuilder builder;
}
