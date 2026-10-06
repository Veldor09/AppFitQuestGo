import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/etiqueta_estado_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/mapa_trazo_ruta.dart';

/// Detalle de una ruta, publica o privada: el trazo dibujado sobre el mapa, su
/// estado (y quien puede verla) y sus datos. Si es una ruta propia todavia
/// privada, desde aqui se envia a revision.
class RutaDetalleScreen extends StatefulWidget {
  const RutaDetalleScreen({
    super.key,
    required this.ruta,
    this.api,
    this.puedeEnviarARevision = false,
    this.onCambio,
  });

  final Ruta ruta;

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final RutaApi? api;

  /// `true` solo en "Mis rutas": la ruta es tuya y se puede enviar a revision
  /// (si ademas esta Privada).
  final bool puedeEnviarARevision;

  /// Se llama tras enviar a revision, para que la lista de rutas se recargue.
  final VoidCallback? onCambio;

  @override
  State<RutaDetalleScreen> createState() => _RutaDetalleScreenState();
}

class _RutaDetalleScreenState extends State<RutaDetalleScreen> {
  late final RutaApi _api = widget.api ?? RutaApi();
  bool _enviando = false;

  bool get _sePuedeEnviar =>
      widget.puedeEnviarARevision && widget.ruta.estado == 'Privada';

  Future<void> _enviarARevision() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() => _enviando = true);
    try {
      await _api.solicitarPublicacion(widget.ruta.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCambio?.call();
      notificarExito(l10n.rutasEnviadaARevision);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      notificarError(l10n.rutasNoSePudoEnviarRuta);
    }
  }

  String _mensajeVisibilidad(AppLocalizations l10n, String estado) {
    switch (estado) {
      case 'Publicada':
        return l10n.detalleRutaVisibilidadPublica;
      case 'Pendiente':
        return l10n.detalleRutaVisibilidadPendiente;
      case 'Rechazada':
        return l10n.detalleRutaVisibilidadRechazada;
      default:
        return l10n.detalleRutaVisibilidadPrivada;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Ruta ruta = widget.ruta;
    return Scaffold(
      backgroundColor: FqColors.paper,
      appBar: AppBar(
        title: Text(
          ruta.nombre,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        backgroundColor: FqColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: 300, child: MapaTrazoRuta(puntos: ruta.puntos)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      EtiquetaEstadoRuta(ruta.estado),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _mensajeVisibilidad(l10n, ruta.estado),
                          style: const TextStyle(fontSize: 11, color: FqColors.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _fila(
                    l10n.rutasActividades,
                    actividadesLabel(l10n, ruta.actividades),
                  ),
                  _fila(l10n.rutasDificultadLabel, dificultadLabel(l10n, ruta.dificultad)),
                  _fila(l10n.rutasDistancia, '${ruta.distanciaKm.toStringAsFixed(1)} km'),
                  _fila(l10n.rutasPuntosDelTrazo, '${ruta.puntos.length}'),
                  if (ruta.creadoPorNombre != null)
                    _fila(l10n.rutasPropuestaPor, ruta.creadoPorNombre!),
                  if (_sePuedeEnviar) ...<Widget>[
                    const SizedBox(height: 16),
                    FqButton.primary(
                      label: _enviando ? l10n.comunEnviando : l10n.rutasEnviarARevision,
                      dense: true,
                      onPressed: _enviando ? null : _enviarARevision,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(etiqueta, style: const TextStyle(fontSize: 11, color: FqColors.muted)),
          Text(
            valor,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
