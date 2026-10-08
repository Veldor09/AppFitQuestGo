import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/formato_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/tarjeta_evento.dart';

/// Abre la ficha de un evento desde abajo (al tocar su area, su recorrido o su
/// pin en el mapa): todo lo que hay que saber de el sin salir del mapa.
Future<void> mostrarFichaEvento(
  BuildContext context,
  Evento evento, {
  DateTime Function()? ahora,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext _) => FichaEvento(evento: evento, ahora: ahora),
  );
}

/// Ficha de un evento: su nombre y categoria, si ya empezo, quien lo organiza,
/// cuando es, la descripcion y sus areas y recorridos.
class FichaEvento extends StatelessWidget {
  const FichaEvento({super.key, required this.evento, this.ahora});

  final Evento evento;

  /// Reloj inyectable para pruebas.
  final DateTime Function()? ahora;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final DateTime ahoraActual = (ahora ?? DateTime.now)();
    final String? descripcion = evento.descripcion?.trim();
    final String? empresa = evento.creadoPorNombre;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FqColors.listIconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    iconoCategoriaEvento(evento.categoria),
                    color: FqColors.night,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        evento.nombre,
                        key: const ValueKey<String>('ficha-evento-nombre'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        categoriaEventoLabel(l10n, evento.categoria),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FqColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                EtiquetaEstadoEvento(evento: evento, ahora: ahoraActual),
              ],
            ),
            const SizedBox(height: 14),
            _Dato(
              icono: Icons.schedule,
              texto: rangoFechasLabel(
                context,
                evento.fechaInicio,
                evento.fechaFin,
              ),
            ),
            if (empresa != null)
              _Dato(
                icono: Icons.storefront_outlined,
                texto: l10n.eventoOrganizadoPor(empresa),
              ),
            if (descripcion != null && descripcion.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                descripcion,
                key: const ValueKey<String>('ficha-evento-descripcion'),
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
            ],
            if (evento.areas.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _Titulo(l10n.eventoAreasTitulo),
              _Zonas(
                cantidad: evento.areas.length,
                icono: Icons.flag_rounded,
                color: colorAreaEvento,
                nombres: <String>[
                  for (final ZonaEvento z in evento.areas) z.nombre,
                ],
              ),
            ],
            if (evento.recorridos.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              _Titulo(l10n.eventoRecorridosTitulo),
              _Zonas(
                cantidad: evento.recorridos.length,
                icono: Icons.directions_walk_rounded,
                color: colorRecorridoEvento,
                nombres: <String>[
                  for (final ZonaEvento z in evento.recorridos) z.nombre,
                ],
              ),
            ],
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

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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

/// Los nombres internos de los trazos de un tipo, en una sola linea cada uno.
class _Zonas extends StatelessWidget {
  const _Zonas({
    required this.cantidad,
    required this.icono,
    required this.color,
    required this.nombres,
  });

  final int cantidad;
  final IconData icono;
  final Color color;
  final List<String> nombres;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final String n in nombres)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: <Widget>[
                Icon(icono, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    n,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
