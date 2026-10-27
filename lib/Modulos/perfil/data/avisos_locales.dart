import 'package:fit_quest_go/core/catalogos/tipos_alerta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';
import 'package:fit_quest_go/Modulos/patrocinio/application/proximidad_destacados.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';

/// Un aviso que la app genera sola mientras caminas (una alerta cerca, un
/// cambio de clima, un destacado cerca). En el mapa aparece unos segundos y
/// desaparece; este registro es lo que deja en el centro de notificaciones.
///
/// El texto se guarda ya traducido, en el idioma que tenia la app al mostrarlo.
class AvisoLocal {
  const AvisoLocal({
    required this.clave,
    required this.categoria,
    required this.titulo,
    required this.mensaje,
    required this.creadaEn,
  });

  /// Identifica el aviso para no registrarlo dos veces.
  final String clave;

  /// Una de [Notificacion.categorias].
  final String categoria;
  final String titulo;
  final String mensaje;
  final DateTime creadaEn;
}

/// Donde viven los avisos locales. En el centro de notificaciones salen como
/// [Notificacion] con id negativo (ver [Notificacion.esLocal]).
abstract class AvisosLocales {
  /// Guarda el aviso; si ya estaba (misma clave) no hace nada.
  Future<void> registrar(AvisoLocal aviso);

  /// Del mas nuevo al mas viejo.
  Future<List<Notificacion>> listar();

  Future<int> conteoNoLeidas();

  /// [id] es el de la [Notificacion] (negativo).
  Future<void> marcarLeida(int id);
  Future<void> marcarTodasLeidas();
  Future<void> eliminar(int id);
}

/// Cuanto dura sin repetirse un aviso de clima que sigue vigente: el mismo
/// aviso no vuelve a llenar la bandeja cada vez que se consulta el clima.
const Duration kVentanaAvisoClima = Duration(hours: 6);

/// "Alerta cerca de ti": una por alerta, una sola vez.
AvisoLocal avisoDeAlertaCercana(
  AppLocalizations l10n,
  Alerta alerta,
  int metros, {
  DateTime? ahora,
}) {
  return AvisoLocal(
    clave: 'alerta:${alerta.id}',
    categoria: 'alertas',
    titulo: l10n.alertasCercaTitulo,
    mensaje:
        '${tipoAlertaLabel(l10n, alerta.tipo, otro: alerta.tipoOtro)} · ${l10n.alertasCercaDistancia(metros)}',
    creadaEn: ahora ?? DateTime.now(),
  );
}

/// Aviso del clima: el mismo tipo y nivel se registra una vez por ventana
/// ([kVentanaAvisoClima]).
AvisoLocal avisoDeClima(
  AppLocalizations l10n,
  AlertaClima aviso, {
  DateTime? ahora,
}) {
  final DateTime momento = ahora ?? DateTime.now();
  final (String titulo, String consejo) = switch (aviso.tipo) {
    TipoClima.lluvia => (l10n.climaLluviaTitulo, l10n.climaConsejoLluvia),
    TipoClima.tormenta => (l10n.climaTormentaTitulo, l10n.climaConsejoTormenta),
    TipoClima.calor => (l10n.climaCalorTitulo, l10n.climaConsejoCalor),
  };
  final String cuando = aviso.enHoras == 0
      ? l10n.climaAhora
      : l10n.climaEnHoras(aviso.enHoras);
  final int ventana =
      momento.millisecondsSinceEpoch ~/ kVentanaAvisoClima.inMilliseconds;
  return AvisoLocal(
    clave: 'clima:${aviso.clave}:$ventana',
    categoria: 'clima',
    titulo: titulo,
    mensaje: '$cuando · $consejo',
    creadaEn: momento,
  );
}

/// "Destacado cerca de ti": una vez al dia por punto o evento.
AvisoLocal avisoDeDestacado(
  AppLocalizations l10n,
  DestacadoCercano destacado, {
  DateTime? ahora,
}) {
  final DateTime momento = ahora ?? DateTime.now();
  final int dia = momento.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  return AvisoLocal(
    clave: 'destacado:${destacado.clave}:$dia',
    categoria: 'patrocinio',
    titulo: l10n.patrocinioCercaTitulo,
    mensaje: destacado.nombre,
    creadaEn: momento,
  );
}
