import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/geo/votacion.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion_api.dart';

const Color _colorArriba = Color(0xFF1FA64F);
const Color _colorAbajo = Color(0xFFE0362C);

/// Los dos pulgares con su conteo. Solo presentacion: quien lo usa decide que
/// pasa al tocar (ver [PulgaresObjeto]).
///
/// En modo [compacto] es solo lectura (el resumen de una ficha: "👍 5 · 👎 8");
/// con [mini] son dos botones chicos en una fila (para listas, como las areas
/// de un evento); si no, son dos botones grandes y el elegido queda relleno.
class Pulgares extends StatelessWidget {
  const Pulgares({
    super.key,
    required this.resumen,
    this.habilitado = true,
    this.enviando = false,
    this.compacto = false,
    this.mini = false,
    this.onElegir,
  });

  final ResumenCalificacion resumen;

  /// Falso: se ven los conteos pero los botones no responden.
  final bool habilitado;
  final bool enviando;
  final bool compacto;
  final bool mini;
  final ValueChanged<ValorCalificacion>? onElegir;

  @override
  Widget build(BuildContext context) {
    if (compacto) return _Resumen(resumen: resumen);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool activo = habilitado && !enviando && onElegir != null;
    if (mini) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _BotonPulgar(
            key: const ValueKey<String>('pulgar-arriba'),
            valor: ValorCalificacion.arriba,
            etiqueta: l10n.calificarArriba,
            cantidad: resumen.arriba,
            elegido: resumen.mia == ValorCalificacion.arriba,
            activo: activo,
            mini: true,
            onTap: () => onElegir?.call(ValorCalificacion.arriba),
          ),
          const SizedBox(width: 6),
          _BotonPulgar(
            key: const ValueKey<String>('pulgar-abajo'),
            valor: ValorCalificacion.abajo,
            etiqueta: l10n.calificarAbajo,
            cantidad: resumen.abajo,
            elegido: resumen.mia == ValorCalificacion.abajo,
            activo: activo,
            mini: true,
            onTap: () => onElegir?.call(ValorCalificacion.abajo),
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: _BotonPulgar(
            key: const ValueKey<String>('pulgar-arriba'),
            valor: ValorCalificacion.arriba,
            etiqueta: l10n.calificarArriba,
            cantidad: resumen.arriba,
            elegido: resumen.mia == ValorCalificacion.arriba,
            activo: activo,
            onTap: () => onElegir?.call(ValorCalificacion.arriba),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BotonPulgar(
            key: const ValueKey<String>('pulgar-abajo'),
            valor: ValorCalificacion.abajo,
            etiqueta: l10n.calificarAbajo,
            cantidad: resumen.abajo,
            elegido: resumen.mia == ValorCalificacion.abajo,
            activo: activo,
            onTap: () => onElegir?.call(ValorCalificacion.abajo),
          ),
        ),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.resumen});

  final ResumenCalificacion resumen;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey<String>('pulgares-resumen'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.thumb_up_alt_rounded, size: 16, color: _colorArriba),
        const SizedBox(width: 4),
        Text(
          '${resumen.arriba}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.thumb_down_alt_rounded, size: 16, color: _colorAbajo),
        const SizedBox(width: 4),
        Text(
          '${resumen.abajo}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _BotonPulgar extends StatelessWidget {
  const _BotonPulgar({
    super.key,
    required this.valor,
    required this.etiqueta,
    required this.cantidad,
    required this.elegido,
    required this.activo,
    required this.onTap,
    this.mini = false,
  });

  final bool mini;
  final ValorCalificacion valor;
  final String etiqueta;
  final int cantidad;
  final bool elegido;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool arriba = valor == ValorCalificacion.arriba;
    final Color color = arriba ? _colorArriba : _colorAbajo;
    final Color fondo = elegido ? color : color.withValues(alpha: 0.08);
    final Color frente = elegido ? FqColors.white : color;
    return Semantics(
      button: true,
      selected: elegido,
      label: etiqueta,
      child: Opacity(
        opacity: activo || elegido ? 1 : 0.55,
        child: Material(
          color: fondo,
          borderRadius: BorderRadius.circular(mini ? 12 : 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(mini ? 12 : 16),
            onTap: activo ? onTap : null,
            child: Container(
              padding: mini
                  ? const EdgeInsets.symmetric(vertical: 6, horizontal: 10)
                  : const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(mini ? 12 : 16),
                border: Border.all(
                  color: color.withValues(alpha: elegido ? 1 : 0.28),
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisSize: mini ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedScale(
                    scale: elegido ? 1.15 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      arriba
                          ? Icons.thumb_up_alt_rounded
                          : Icons.thumb_down_alt_rounded,
                      size: mini ? 16 : 22,
                      color: frente,
                    ),
                  ),
                  SizedBox(width: mini ? 5 : 8),
                  Text(
                    '$cantidad',
                    style: TextStyle(
                      fontSize: mini ? 13 : 16,
                      fontWeight: FontWeight.w900,
                      color: frente,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulgares de un objeto concreto (una ruta, un nodo, un evento o un area de
/// un evento): pide su resumen al servidor, deja calificar con un toque (tocar
/// el mismo pulgar otra vez retira la calificacion) y explica por que no se
/// puede cuando no se puede.
class PulgaresObjeto extends StatefulWidget {
  const PulgaresObjeto({
    super.key,
    required this.tipo,
    required this.id,
    this.area,
    this.resumenInicial,
    this.api,
    this.destino,
    this.posicionActual,
    this.compacto = false,
    this.mini = false,
    this.mostrarMotivo = true,
    this.alCambiar,
  });

  final TipoCalificable tipo;
  final int id;

  /// Indice del area de un evento que se califica (null: el objeto entero).
  final int? area;

  /// Si ya se tiene el resumen (el de un area viene con el del evento) no se
  /// vuelve a pedir. Con [area], es el resumen de esa area.
  final ResumenCalificacion? resumenInicial;
  final CalificacionApi? api;

  /// Solo nodos: donde esta el punto, para pedir cercania antes de calificar.
  final ({double lat, double lng})? destino;
  final PosicionGps? Function()? posicionActual;
  final bool compacto;

  /// Botones chicos en una fila, para listas (las areas de un evento).
  final bool mini;

  /// Muestra la nota de por que no se puede calificar (se oculta en listas).
  final bool mostrarMotivo;
  final ValueChanged<ResumenCalificacion>? alCambiar;

  @override
  State<PulgaresObjeto> createState() => _PulgaresObjetoState();
}

class _PulgaresObjetoState extends State<PulgaresObjeto> {
  late final CalificacionApi _api = widget.api ?? CalificacionApi.predeterminada();
  ResumenCalificacion? _resumen;
  bool _enviando = false;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    _resumen = widget.resumenInicial;
    if (_resumen == null) _cargar();
  }

  @override
  void didUpdateWidget(PulgaresObjeto viejo) {
    super.didUpdateWidget(viejo);
    if (widget.resumenInicial != null &&
        !identical(widget.resumenInicial, viejo.resumenInicial) &&
        !_enviando) {
      setState(() => _resumen = widget.resumenInicial);
    }
  }

  Future<void> _cargar() async {
    try {
      final ResumenCalificacion r = await _api.resumen(widget.tipo, widget.id);
      if (mounted) setState(() => _resumen = _deEsteObjeto(r));
    } catch (_) {
      if (mounted) setState(() => _fallo = true);
    }
  }

  Future<void> _elegir(ValorCalificacion valor) async {
    final ResumenCalificacion? actual = _resumen;
    if (actual == null || _enviando) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final PosicionGps? posicion = widget.posicionActual?.call();
    final bool retirar = actual.mia == valor;
    setState(() => _enviando = true);
    try {
      final ResumenCalificacion nuevo = await _api.calificar(
        widget.tipo,
        widget.id,
        retirar ? null : valor,
        area: widget.area,
        lat: posicion?.lat,
        lng: posicion?.lng,
      );
      if (!mounted) return;
      final ResumenCalificacion propio = _deEsteObjeto(nuevo);
      setState(() => _resumen = propio);
      widget.alCambiar?.call(propio);
      if (!retirar) notificarExito(l10n.calificarGracias);
    } on ApiException catch (e) {
      if (!mounted) return;
      notificarError(switch (e.statusCode) {
        400 => l10n.calificarMotivoNoDisponible,
        403 => l10n.calificarMotivoSinRecorrido,
        _ => l10n.calificarError,
      });
    } catch (_) {
      if (mounted) notificarError(l10n.calificarError);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// El servidor responde con el resumen del evento (y el de cada area): si
  /// esto califica un area, se queda con el de esa area.
  ResumenCalificacion _deEsteObjeto(ResumenCalificacion r) {
    final int? area = widget.area;
    if (area == null || area >= r.areas.length) return r;
    return r.areas[area];
  }

  /// Por que no se puede calificar ahora, o null si se puede.
  String? _motivo(AppLocalizations l10n, ResumenCalificacion r) {
    if (!r.puedeCalificar) {
      return switch (r.motivo) {
        MotivoSinCalificar.sinRecorrido => l10n.calificarMotivoSinRecorrido,
        MotivoSinCalificar.propio => l10n.calificarMotivoPropio,
        _ => l10n.calificarMotivoNoDisponible,
      };
    }
    final ({double lat, double lng})? destino = widget.destino;
    if (destino == null || widget.posicionActual == null) return null;
    final PosicionGps? posicion = widget.posicionActual!.call();
    if (posicion == null) return l10n.calificarSinGps;
    final double metros = distanciaMetros(
      posicion.lat,
      posicion.lng,
      destino.lat,
      destino.lng,
    );
    if (metros > radioVotoMetros) {
      return l10n.calificarLejos(radioVotoMetros.round(), metros.round());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ResumenCalificacion? r = _resumen;
    if (r == null) {
      if (_fallo) return const SizedBox.shrink();
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (widget.compacto) return Pulgares(resumen: r, compacto: true);
    if (widget.mini) {
      return Pulgares(
        resumen: r,
        mini: true,
        habilitado: _motivo(AppLocalizations.of(context)!, r) == null,
        enviando: _enviando,
        onElegir: _elegir,
      );
    }

    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String? motivo = _motivo(l10n, r);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Pulgares(
          resumen: r,
          habilitado: motivo == null,
          enviando: _enviando,
          onElegir: _elegir,
        ),
        if (motivo != null && widget.mostrarMotivo) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            motivo,
            key: const ValueKey<String>('pulgares-motivo'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FqColors.muted,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
