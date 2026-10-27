import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Notificación del buzón del usuario (NOT-01), emitida por el backend.
class Notificacion {
  Notificacion({
    required this.id,
    required this.categoria,
    required this.titulo,
    required this.mensaje,
    required this.creadaEn,
    this.leida = false,
    this.referenciaTipo,
    this.referenciaId,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: (json['id'] as num).toInt(),
      categoria: (json['categoria'] as String?) ?? 'eventos',
      titulo: (json['titulo'] as String?) ?? '',
      mensaje: (json['mensaje'] as String?) ?? '',
      leida: (json['leida'] as bool?) ?? false,
      creadaEn:
          DateTime.tryParse((json['creadaEn'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      referenciaTipo: json['referenciaTipo'] as String?,
      referenciaId: (json['referenciaId'] as num?)?.toInt(),
    );
  }

  /// Categorías válidas: rutas, alertas, insignias, eventos, patrocinio y
  /// clima (esta última solo la generan los avisos locales de la app).
  static const List<String> categorias = <String>[
    'rutas',
    'alertas',
    'insignias',
    'eventos',
    'patrocinio',
    'clima',
  ];

  final int id;
  final String categoria;
  final String titulo;
  final String mensaje;
  final DateTime creadaEn;
  bool leida;

  /// Entidad a la que apunta la notificación: 'ruta', 'alerta', 'insignia'...
  final String? referenciaTipo;
  final int? referenciaId;

  /// `true` si la genero la propia app (clima, alerta o destacado cerca) y vive
  /// solo en este telefono: su id es negativo y nunca se pide ni se manda al
  /// servidor.
  bool get esLocal => id < 0;

  /// Texto relativo ("Hace 5 min", "Ayer"...) calculado en el cliente.
  ///
  /// Con [l10n] sale en el idioma de la app; sin el, en español.
  String tiempoRelativo({DateTime? ahora, AppLocalizations? l10n}) {
    final Duration d = (ahora ?? DateTime.now()).difference(creadaEn);
    if (d.inMinutes < 1) return l10n?.notificacionesTiempoAhora ?? 'Justo ahora';
    if (d.inMinutes < 60) {
      return l10n?.notificacionesTiempoMinutos(d.inMinutes) ?? 'Hace ${d.inMinutes} min';
    }
    if (d.inHours < 24) {
      return l10n?.notificacionesTiempoHoras(d.inHours) ??
          'Hace ${d.inHours} ${d.inHours == 1 ? 'hora' : 'horas'}';
    }
    if (d.inDays == 1) return l10n?.notificacionesTiempoAyer ?? 'Ayer';
    if (d.inDays < 30) {
      return l10n?.notificacionesTiempoDias(d.inDays) ?? 'Hace ${d.inDays} días';
    }
    return '${creadaEn.day.toString().padLeft(2, '0')}/'
        '${creadaEn.month.toString().padLeft(2, '0')}/${creadaEn.year}';
  }
}
