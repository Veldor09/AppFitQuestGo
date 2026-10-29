import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/core/geo/centroide.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/ficha_lugar.dart';
import 'package:fit_quest_go/core/widgets/foto_remota.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/calificaciones/application/resumen_remoto.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion_api.dart';
import 'package:fit_quest_go/Modulos/calificaciones/presentation/pulgares.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/eventos/data/formato_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/recorrido_evento_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/tarjeta_evento.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/etiqueta_destacado.dart';
import 'package:fit_quest_go/Modulos/reportes/presentation/hoja_reportar.dart';

/// Abre la ficha de un evento desde abajo (al tocar su area, su recorrido o su
/// pin en el mapa): todo lo que hay que saber de el sin salir del mapa.
Future<void> mostrarFichaEvento(
  BuildContext context,
  Evento evento, {
  DateTime Function()? ahora,
  CalificacionApi? calificaciones,
  Future<bool> Function(Uri uri)? abrirUrl,
  EventoApi? api,
  Widget Function(BuildContext context, Evento evento)? recorridoBuilder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: formaFichaLugar,
    builder: (BuildContext _) => FichaEvento(
      evento: evento,
      ahora: ahora,
      calificaciones: calificaciones,
      abrirUrl: abrirUrl,
      api: api,
      recorridoBuilder: recorridoBuilder,
    ),
  );
}

({double lat, double lng})? destinoDeEvento(Evento evento) {
  for (final ZonaEvento area in evento.areas) {
    if (area.puntos.isEmpty) continue;
    final PuntoGeo c = centroideDe(area.puntos);
    return (lat: c.lat, lng: c.lng);
  }
  for (final ZonaEvento recorrido in evento.recorridos) {
    if (recorrido.puntos.isEmpty) continue;
    return (lat: recorrido.puntos.first.lat, lng: recorrido.puntos.first.lng);
  }
  return null;
}

class FichaEvento extends StatefulWidget {
  const FichaEvento({
    super.key,
    required this.evento,
    this.ahora,
    this.calificaciones,
    this.abrirUrl,
    this.api,
    this.recorridoBuilder,
  });

  final Evento evento;

  /// Reloj inyectable para pruebas.
  final DateTime Function()? ahora;

  final CalificacionApi? calificaciones;

  final Future<bool> Function(Uri uri)? abrirUrl;

  final EventoApi? api;

  /// Pantalla de navegación/recorrido inyectable para pruebas.
  final Widget Function(BuildContext context, Evento evento)? recorridoBuilder;

  @override
  State<FichaEvento> createState() => _FichaEventoState();
}

class _FichaEventoState extends State<FichaEvento> {
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
    final String? empresa = evento.creadoPorNombre;
    final ({double lat, double lng})? destino = destinoDeEvento(evento);
    return ListenableBuilder(
      listenable: _pulgares,
      builder: (BuildContext context, Widget? _) {
        final ResumenCalificacion? resumen = _pulgares.resumen;
        final bool propio = resumen?.motivo == MotivoSinCalificar.propio;
        final bool reportable = puedeReportar(context, evento.creadoPorId);
        Future<bool> reportar({bool foto = false}) => mostrarHojaReportar(
          context,
          tipo: TipoReportable.evento,
          contenidoId: evento.id,
          nombre: evento.nombre,
          esFoto: foto,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CabeceraFicha(
                titulo: evento.nombre,
                keyTitulo: const ValueKey<String>('ficha-evento-nombre'),
                subtitulo: categoriaEventoLabel(l10n, evento.categoria),
                icono: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FqColors.listIconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    iconoCategoriaEvento(evento.categoria),
                    color: FqColors.night,
                  ),
                ),
                etiquetas: <Widget>[
                  EtiquetaEstadoEvento(evento: evento, ahora: ahoraActual),
                  if (evento.destacado) const EtiquetaDestacado(),
                ],
              ),
              if (resumen != null) ...<Widget>[
                const SizedBox(height: 12),
                Pulgares(resumen: resumen, compacto: true),
              ],
              if (destino != null || reportable) ...<Widget>[
                const SizedBox(height: 14),
                FilaAccionesFicha(
                  acciones: <Widget>[
                    if (destino != null)
                    AccionFicha(
                      key: const ValueKey<String>('ficha-como-llegar'),
                      icono: Icons.directions_rounded,
                      etiqueta: l10n.fichaComoLlegar,
                      principal: true,
                      onTap: () async {
                        if (widget.abrirUrl != null) {
                          await abrirComoLlegar(
                            context,
                            lat: destino.lat,
                            lng: destino.lng,
                            nombre: evento.nombre,
                            abrir: widget.abrirUrl,
                          );
                          return;
                        }
                        final NavigatorState nav = Navigator.of(context);
                        nav.pop();
                        await nav.push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext ctx) =>
                                widget.recorridoBuilder?.call(ctx, evento) ??
                                RecorridoEventoScreen(evento: evento),
                          ),
                        );
                      },
                    ),
                    if (reportable)
                      AccionFicha(
                        key: const ValueKey<String>('ficha-reportar'),
                        icono: Icons.flag_outlined,
                        etiqueta: l10n.reportarBoton,
                        onTap: reportar,
                      ),
                  ],
                ),
              ],
              if (evento.conFoto) ...<Widget>[
                const SizedBox(height: 16),
                FotoRemota(
                  key: const ValueKey<String>('foto-evento-widget'),
                  llave: const ValueKey<String>('foto-evento'),
                  cargar: () => (widget.api ?? EventoApi()).foto(evento.id),
                  altura: 190,
                  titulo: evento.nombre,
                  alReportar: reportable ? () => reportar(foto: true) : null,
                ),
              ],
              const SizedBox(height: 16),
              DatoFicha(
                icono: Icons.schedule,
                texto: rangoFechasLabel(
                  context,
                  evento.fechaInicio,
                  evento.fechaFin,
                ),
              ),
              if (empresa != null)
                DatoFicha(
                  icono: Icons.storefront_outlined,
                  texto: l10n.eventoOrganizadoPor(empresa),
                ),
              if (descripcion != null && descripcion.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  key: const ValueKey<String>('ficha-evento-descripcion'),
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
                _Titulo(l10n.eventoAreasTitulo),
                for (int i = 0; i < evento.areas.length; i++)
                  _FilaArea(
                    zona: evento.areas[i],
                    indice: i,
                    eventoId: evento.id,
                    resumen: resumen != null && i < resumen.areas.length
                        ? resumen.areas[i]
                        : null,
                    api: widget.calificaciones,
                  ),
              ],
              if (evento.recorridos.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _Titulo(l10n.eventoRecorridosTitulo),
                for (final ZonaEvento z in evento.recorridos)
                  _FilaRecorrido(nombre: z.nombre),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: FqColors.muted,
        ),
      ),
    );
  }
}

class _FilaArea extends StatelessWidget {
  const _FilaArea({
    required this.zona,
    required this.indice,
    required this.eventoId,
    required this.resumen,
    required this.api,
  });

  final ZonaEvento zona;
  final int indice;
  final int eventoId;

  final ResumenCalificacion? resumen;
  final CalificacionApi? api;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          const Icon(Icons.flag_rounded, size: 18, color: colorAreaEvento),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              zona.nombre,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (resumen != null)
            PulgaresObjeto(
              key: ValueKey<String>('pulgares-area-$indice'),
              tipo: TipoCalificable.evento,
              id: eventoId,
              area: indice,
              api: api,
              resumenInicial: resumen,
              mini: true,
              mostrarMotivo: false,
            ),
        ],
      ),
    );
  }
}

class _FilaRecorrido extends StatelessWidget {
  const _FilaRecorrido({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.directions_walk_rounded,
            size: 18,
            color: colorRecorridoEvento,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
