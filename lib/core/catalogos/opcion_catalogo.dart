import 'package:flutter/widgets.dart';

/// Una opcion de una lista cerrada (actividad de ruta, tipo de alerta,
/// categoria de nodo). La `clave` es estable y es la que viaja al backend; el
/// texto visible se traduce aparte, segun el idioma de la app.
class OpcionCatalogo {
  const OpcionCatalogo(this.clave, this.icono);

  final String clave;
  final IconData icono;
}

/// Clave de la opcion "ninguna de las anteriores", igual en todos los catalogos.
const String claveOtro = 'otro';
