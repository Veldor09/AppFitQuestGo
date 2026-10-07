import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/formato_evento.dart';

/// Etiqueta de estado de un evento segun la fecha: en curso, proximo o terminado.
class EtiquetaEstadoEvento extends StatelessWidget {
  const EtiquetaEstadoEvento({
    super.key,
    required this.evento,
    required this.ahora,
  });

  final Evento evento;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (evento.haTerminado(ahora)) {
      return FqTag(l10n.eventoEstadoTerminado);
    }
    if (evento.enCurso(ahora)) {
      return FqTag(l10n.eventoEstadoEnCurso, tone: FqTagTone.lime);
    }
    return FqTag(l10n.eventoEstadoProximo, tone: FqTagTone.amber);
  }
}

/// Fila de un evento en una lista: categoria, nombre, fechas y cuantos trazos
/// tiene. Quien la usa decide que pasa al tocarla y que accion lleva a la derecha.
class TarjetaEvento extends StatelessWidget {
  const TarjetaEvento({
    super.key,
    required this.evento,
    required this.ahora,
    required this.onTap,
    this.mostrarEmpresa = false,
    this.trailing,
  });

  final Evento evento;
  final DateTime ahora;
  final VoidCallback onTap;

  /// En la lista del deportista se muestra que empresa lo organiza.
  final bool mostrarEmpresa;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String? empresa = evento.creadoPorNombre;
    final bool terminado = evento.haTerminado(ahora);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: FqRadius.allLg,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FqColors.white,
            borderRadius: FqRadius.allLg,
            border: Border.all(color: FqColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: terminado ? FqColors.cloud : FqColors.listIconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconoCategoriaEvento(evento.categoria),
                  size: 20,
                  color: terminado ? FqColors.muted : FqColors.night,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            evento.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: terminado ? FqColors.muted : FqColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        EtiquetaEstadoEvento(evento: evento, ahora: ahora),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mostrarEmpresa && empresa != null
                          ? '${categoriaEventoLabel(l10n, evento.categoria)} · $empresa'
                          : categoriaEventoLabel(l10n, evento.categoria),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: FqColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: FqColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            rangoFechasLabel(
                              context,
                              evento.fechaInicio,
                              evento.fechaFin,
                            ),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: FqColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.map_outlined,
                          size: 14,
                          color: FqColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.eventoResumenTrazos(
                            evento.areas.length,
                            evento.recorridos.length,
                          ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: FqColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
