import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/formato_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/mapa_trazos_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/tarjeta_evento.dart';

/// Detalle de un evento: el mapa con sus areas y recorridos encuadrados, quien
/// lo organiza, cuando es y la lista de trazos. Solo lectura.
class EventoDetalleScreen extends StatelessWidget {
  const EventoDetalleScreen({
    super.key,
    required this.evento,
    this.ahora,
    this.mapaBuilder,
  });

  final Evento evento;

  /// Reloj inyectable para pruebas.
  final DateTime Function()? ahora;

  /// Reemplazo del mapa para pruebas (Mapbox no corre en un test de widget).
  final WidgetBuilder? mapaBuilder;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final DateTime ahoraActual = (ahora ?? DateTime.now)();
    final String? descripcion = evento.descripcion?.trim();
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
              child: mapaBuilder != null
                  ? mapaBuilder!(context)
                  : MapaTrazosEvento(
                      areas: evento.areas,
                      recorridos: evento.recorridos,
                    ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(FqGap.xl),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      EtiquetaEstadoEvento(evento: evento, ahora: ahoraActual),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _Dato(
                    icono: Icons.schedule,
                    texto: rangoFechasLabel(
                      context,
                      evento.fechaInicio,
                      evento.fechaFin,
                    ),
                  ),
                  if (evento.creadoPorNombre != null)
                    _Dato(
                      icono: Icons.storefront_outlined,
                      texto: l10n.eventoOrganizadoPor(evento.creadoPorNombre!),
                    ),
                  if (descripcion != null &&
                      descripcion.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      descripcion,
                      style: const TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                  ],
                  if (evento.areas.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    _TituloLista(l10n.eventoAreasTitulo),
                    for (final ZonaEvento z in evento.areas)
                      _FilaZona(
                        icono: Icons.crop_free,
                        color: colorAreaEvento,
                        nombre: z.nombre,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icono, size: 16, color: FqColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: FqColors.ink,
              ),
            ),
          ),
        ],
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
  });

  final IconData icono;
  final Color color;
  final String nombre;

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
        ],
      ),
    );
  }
}
