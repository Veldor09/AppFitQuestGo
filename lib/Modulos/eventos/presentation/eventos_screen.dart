import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/evento_detalle_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/tarjeta_evento.dart';

/// Pestaña "Eventos" del deportista: lo que las empresas organizan, los que ya
/// empezaron primero y luego los proximos. Tocar uno abre su mapa.
class EventosScreen extends StatefulWidget {
  const EventosScreen({super.key, this.api, this.ahora});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final EventoApi? api;

  /// Reloj inyectable para pruebas.
  final DateTime Function()? ahora;

  @override
  State<EventosScreen> createState() => _EventosScreenState();
}

class _EventosScreenState extends State<EventosScreen> {
  late final EventoApi _api = widget.api ?? EventoApi();
  late Future<List<Evento>> _futuro = _api.listar();

  DateTime get _ahora => (widget.ahora ?? DateTime.now)();

  Future<void> _recargar() async {
    final Future<List<Evento>> nuevo = _api.listar();
    setState(() {
      _futuro = nuevo;
    });
    try {
      await nuevo;
    } catch (_) {
      // El error se muestra en el propio FutureBuilder.
    }
  }

  void _abrir(Evento evento) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            EventoDetalleScreen(evento: evento, ahora: widget.ahora),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: FqColors.paper,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(FqGap.xl, 16, FqGap.xl, 4),
              child: Text(
                l10n.comunEventos,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(FqGap.xl, 0, FqGap.xl, 8),
              child: Text(
                l10n.eventosSubtitulo,
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
                      title: l10n.eventosVacioTitulo,
                      message: l10n.eventosVacioMensaje,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _recargar,
                    child: _lista(l10n, eventos),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(AppLocalizations l10n, List<Evento> eventos) {
    final DateTime ahora = _ahora;
    final List<Evento> enCurso = <Evento>[
      for (final Evento e in eventos)
        if (e.enCurso(ahora)) e,
    ];
    final List<Evento> proximos = <Evento>[
      for (final Evento e in eventos)
        if (!e.haComenzado(ahora)) e,
    ];
    return ListView(
      key: const ValueKey<String>('lista-eventos'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(FqGap.xl, 4, FqGap.xl, FqGap.xxl),
      children: <Widget>[
        if (enCurso.isNotEmpty) ...<Widget>[
          _Seccion(l10n.eventosSeccionEnCurso),
          for (final Evento e in enCurso) _fila(e, ahora),
        ],
        if (proximos.isNotEmpty) ...<Widget>[
          _Seccion(l10n.eventosSeccionProximos),
          for (final Evento e in proximos) _fila(e, ahora),
        ],
      ],
    );
  }

  Widget _fila(Evento evento, DateTime ahora) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TarjetaEvento(
        evento: evento,
        ahora: ahora,
        mostrarEmpresa: true,
        onTap: () => _abrir(evento),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
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
