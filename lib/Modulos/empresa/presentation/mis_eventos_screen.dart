import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/editor_evento_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/tarjeta_evento.dart';

/// Panel de la empresa · "Mis eventos": todos los que publico, los vigentes
/// primero y los terminados al final. Crear uno nuevo, tocar uno para editarlo
/// o borrarlo.
class MisEventosScreen extends StatefulWidget {
  const MisEventosScreen({super.key, this.api, this.ahora, this.editorBuilder});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final EventoApi? api;

  /// Reloj inyectable para pruebas.
  final DateTime Function()? ahora;

  /// Abre el editor. Las pruebas lo reemplazan para no montar Mapbox.
  final Widget Function(BuildContext context, Evento? evento)? editorBuilder;

  @override
  State<MisEventosScreen> createState() => _MisEventosScreenState();
}

class _MisEventosScreenState extends State<MisEventosScreen> {
  late final EventoApi _api = widget.api ?? EventoApi();
  late Future<List<Evento>> _futuro = _api.mios();

  DateTime get _ahora => (widget.ahora ?? DateTime.now)();

  Future<void> _recargar() async {
    final Future<List<Evento>> nuevo = _api.mios();
    setState(() {
      _futuro = nuevo;
    });
    try {
      await nuevo;
    } catch (_) {
      // El error se muestra en el propio FutureBuilder.
    }
  }

  Future<void> _abrirEditor([Evento? evento]) async {
    final Evento? guardado = await Navigator.of(context).push<Evento>(
      MaterialPageRoute<Evento>(
        builder: (BuildContext ctx) =>
            widget.editorBuilder?.call(ctx, evento) ??
            EditorEventoScreen(api: _api, evento: evento, ahora: widget.ahora),
      ),
    );
    if (guardado != null && mounted) await _recargar();
  }

  Future<void> _eliminar(Evento evento) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.eventoEliminarTitulo),
        content: Text(l10n.eventoEliminarMensaje(evento.nombre)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.comunCancelar),
          ),
          FilledButton(
            key: const ValueKey<String>('confirmar-eliminar'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.comunEliminar),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await _api.eliminar(evento.id);
      if (!mounted) return;
      notificarExito(l10n.eventoEliminado);
      await _recargar();
    } on ApiException catch (e) {
      notificarError(e.message);
    } catch (_) {
      notificarError(l10n.eventoErrorEliminar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: FqColors.paper,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('nuevo-evento'),
        onPressed: () => _abrirEditor(),
        backgroundColor: FqColors.volt,
        foregroundColor: FqColors.primaryInk,
        icon: const Icon(Icons.add),
        label: Text(l10n.eventoNuevo),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(FqGap.xl, 16, FqGap.xl, 4),
              child: Text(
                l10n.misEventosTitulo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(FqGap.xl, 0, FqGap.xl, 8),
              child: Text(
                l10n.misEventosSubtitulo,
                style: const TextStyle(fontSize: 12, color: FqColors.muted),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Evento>>(
                future: _futuro,
                builder: (BuildContext context, AsyncSnapshot<List<Evento>> s) {
                  if (s.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.hasError) {
                    return FqEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: l10n.eventosErrorCarga,
                      action: TextButton(
                        onPressed: _recargar,
                        child: Text(l10n.comunReintentar),
                      ),
                    );
                  }
                  final List<Evento> eventos = s.data ?? const <Evento>[];
                  if (eventos.isEmpty) {
                    return FqEmptyState(
                      icon: Icons.event_outlined,
                      title: l10n.misEventosVacioTitulo,
                      message: l10n.misEventosVacioMensaje,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _recargar,
                    child: _lista(eventos),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(List<Evento> todos) {
    final DateTime ahora = _ahora;
    // Vigentes primero (el mas proximo arriba); los terminados, al final.
    final List<Evento> vigentes = <Evento>[
      for (final Evento e in todos)
        if (!e.haTerminado(ahora)) e,
    ]..sort((Evento a, Evento b) => a.fechaInicio.compareTo(b.fechaInicio));
    final List<Evento> terminados = <Evento>[
      for (final Evento e in todos)
        if (e.haTerminado(ahora)) e,
    ]..sort((Evento a, Evento b) => b.fechaFin.compareTo(a.fechaFin));
    final List<Evento> ordenados = <Evento>[...vigentes, ...terminados];
    return ListView.separated(
      key: const ValueKey<String>('lista-mis-eventos'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(FqGap.xl, 4, FqGap.xl, 90),
      itemCount: ordenados.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext _, int i) {
        final Evento evento = ordenados[i];
        return TarjetaEvento(
          evento: evento,
          ahora: ahora,
          onTap: () => _abrirEditor(evento),
          trailing: IconButton(
            key: ValueKey<String>('eliminar-evento-${evento.id}'),
            tooltip: AppLocalizations.of(context)!.comunEliminar,
            onPressed: () => _eliminar(evento),
            icon: const Icon(Icons.delete_outline, color: FqColors.risk),
          ),
        );
      },
    );
  }
}
