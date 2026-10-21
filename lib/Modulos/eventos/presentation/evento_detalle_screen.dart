import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/ficha_lugar.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';
import 'package:fit_quest_go/Modulos/calificaciones/application/resumen_remoto.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion_api.dart';
import 'package:fit_quest_go/Modulos/calificaciones/presentation/pulgares.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/formato_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/ficha_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/mapa_trazos_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/tarjeta_evento.dart';

/// Detalle de un evento: el mapa con sus areas y recorridos encuadrados, quien
/// lo organiza, cuando es, los pulgares, la lista de trazos (cada area se
/// califica) y "Como llegar".
class EventoDetalleScreen extends StatefulWidget {
  const EventoDetalleScreen({
    super.key,
    required this.evento,
    this.ahora,
    this.mapaBuilder,
    this.calificaciones,
    this.abrirUrl,
  });

  final Evento evento;

  /// Reloj inyectable para pruebas.
  final DateTime Function()? ahora;

  /// Reemplazo del mapa para pruebas (Mapbox no corre en un test de widget).
  final WidgetBuilder? mapaBuilder;

  /// Pulgares del evento, inyectable para pruebas.
  final CalificacionApi? calificaciones;

  /// Abre "Como llegar"; por defecto lanza la app de mapas.
  final Future<bool> Function(Uri uri)? abrirUrl;

  @override
  State<EventoDetalleScreen> createState() => _EventoDetalleScreenState();
}

class _EventoDetalleScreenState extends State<EventoDetalleScreen> {
  late final ResumenRemoto _pulgares = ResumenRemoto(
    tipo: TipoCalificable.evento,
    id: widget.evento.id,
    api: widget.calificaciones,
  );

  @override
  void initState() {
    super.initState();
    _pulgares.cargar();
  }

  @override
  void dispose() {
    _pulgares.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Evento evento = widget.evento;
    final DateTime ahoraActual = (widget.ahora ?? DateTime.now)();
    final String? descripcion = evento.descripcion?.trim();
    final ({double lat, double lng})? destino = destinoDeEvento(evento);
    return Scaffold(
      backgroundColor: FqColors.paper,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FqAppHeader(
              title: evento.nombre,
              subtitle: categoriaEventoLabel(l10n, evento.categoria),
              onLeading: () => Navigator.of(context).maybePop(),
            ),
            SizedBox(
              height: 260,
              child: widget.mapaBuilder != null
                  ? widget.mapaBuilder!(context)
                  : MapaTrazosEvento(
                      areas: evento.areasRotuladas,
                      recorridos: evento.recorridosRotulados,
                    ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _pulgares,
                builder: (BuildContext context, Widget? _) {
                  final ResumenCalificacion? resumen = _pulgares.resumen;
                  final bool propio =
                      resumen?.motivo == MotivoSinCalificar.propio;
                  return ListView(
                    padding: const EdgeInsets.all(FqGap.xl),
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          EtiquetaEstadoEvento(
                            evento: evento,
                            ahora: ahoraActual,
                          ),
                          const Spacer(),
                          if (resumen != null)
                            Pulgares(resumen: resumen, compacto: true),
                        ],
                      ),
                      if (destino != null) ...<Widget>[
                        const SizedBox(height: 12),
                        FilaAccionesFicha(
                          acciones: <Widget>[
                            AccionFicha(
                              key: const ValueKey<String>('ficha-como-llegar'),
                              icono: Icons.directions_rounded,
                              etiqueta: l10n.fichaComoLlegar,
                              principal: true,
                              onTap: () => abrirComoLlegar(
                                context,
                                lat: destino.lat,
                                lng: destino.lng,
                                abrir: widget.abrirUrl,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      DatoFicha(
                        icono: Icons.schedule,
                        texto: rangoFechasLabel(
                          context,
                          evento.fechaInicio,
                          evento.fechaFin,
                        ),
                      ),
                      if (evento.creadoPorNombre != null)
                        DatoFicha(
                          icono: Icons.storefront_outlined,
                          texto: l10n.eventoOrganizadoPor(
                            evento.creadoPorNombre!,
                          ),
                        ),
                      if (descripcion != null &&
                          descripcion.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          descripcion,
                          style: const TextStyle(fontSize: 13.5, height: 1.4),
                        ),
                      ],
                      if (resumen != null && !propio) ...<Widget>[
                        const SizedBox(height: 18),
                        SeccionFicha(
                          titulo: l10n.calificarPregunta,
                          hijo: PulgaresObjeto(
                            tipo: TipoCalificable.evento,
                            id: evento.id,
                            api: widget.calificaciones,
                            resumenInicial: resumen,
                            alCambiar: _pulgares.actualizar,
                          ),
                        ),
                      ],
                      if (evento.areas.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        _TituloLista(l10n.eventoAreasTitulo),
                        for (int i = 0; i < evento.areas.length; i++)
                          _FilaZona(
                            icono: Icons.crop_free,
                            color: colorAreaEvento,
                            nombre: evento.areas[i].nombre,
                            pulgares: resumen != null && i < resumen.areas.length
                                ? PulgaresObjeto(
                                    key: ValueKey<String>('pulgares-area-$i'),
                                    tipo: TipoCalificable.evento,
                                    id: evento.id,
                                    area: i,
                                    api: widget.calificaciones,
                                    resumenInicial: resumen.areas[i],
                                    mini: true,
                                    mostrarMotivo: false,
                                  )
                                : null,
                          ),
                      ],
                      if (evento.recorridos.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        _TituloLista(l10n.eventoRecorridosTitulo),
                        for (final ZonaEvento z in evento.recorridos)
                          _FilaZona(
                            icono: Icons.timeline,
                            color: colorRecorridoEvento,
                            nombre: z.nombre,
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TituloLista extends StatelessWidget {
  const _TituloLista(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: FqColors.muted,
        ),
      ),
    );
  }
}

class _FilaZona extends StatelessWidget {
  const _FilaZona({
    required this.icono,
    required this.color,
    required this.nombre,
    this.pulgares,
  });

  final IconData icono;
  final Color color;
  final String nombre;

  /// Los pulgares de la zona (solo las areas se califican).
  final Widget? pulgares;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          ?pulgares,
        ],
      ),
    );
  }
}
