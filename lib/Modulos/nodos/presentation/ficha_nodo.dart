import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/geo/votacion.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/foto_nodo.dart';

/// Abre la ficha corta de un punto de interes (al tocar su pin en el mapa o su
/// fila en la cola de moderacion del admin).
///
/// Con [posicionActual] la ficha tambien deja votar el punto ("sigue ahi" /
/// "ya no existe") a quien este cerca; sin ella (la cola del admin) es solo de
/// lectura. [alVotar] recibe el punto tal como quedo en el servidor tras un
/// voto, para que el mapa se actualice.
Future<void> mostrarFichaNodo(
  BuildContext context,
  Nodo nodo,
  NodoApi api, {
  PosicionGps? Function()? posicionActual,
  int? usuarioId,
  ValueChanged<Nodo>? alVotar,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext _) => FichaNodo(
      nodo: nodo,
      api: api,
      posicionActual: posicionActual,
      usuarioId: usuarioId,
      alVotar: alVotar,
    ),
  );
}

/// Ficha corta de un nodo: nombre, categoria, quien lo propuso, descripcion,
/// foto (si tiene) y, desde el mapa, el voto de "sigue ahi" / "ya no existe".
class FichaNodo extends StatefulWidget {
  const FichaNodo({
    super.key,
    required this.nodo,
    required this.api,
    this.posicionActual,
    this.usuarioId,
    this.alVotar,
  });

  final Nodo nodo;
  final NodoApi api;

  /// Ultima posicion conocida del GPS. Si es null no hay seccion de voto.
  final PosicionGps? Function()? posicionActual;

  /// Quien mira la ficha: quien propuso el punto no lo vota.
  final int? usuarioId;
  final ValueChanged<Nodo>? alVotar;

  @override
  State<FichaNodo> createState() => _FichaNodoState();
}

class _FichaNodoState extends State<FichaNodo> {
  late Nodo _nodo = widget.nodo;
  bool _votando = false;

  /// El servidor respondio 409: este punto ya no necesita tu voto.
  bool _sinVotoPendiente = false;

  Future<void> _votar({required bool sigueAhi}) async {
    final PosicionGps? posicion = widget.posicionActual?.call();
    if (posicion == null || _votando) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() => _votando = true);
    try {
      final Nodo nuevo = sigueAhi
          ? await widget.api.confirmar(_nodo.id, lat: posicion.lat, lng: posicion.lng)
          : await widget.api.marcarObsoleto(_nodo.id, lat: posicion.lat, lng: posicion.lng);
      // El voto ya esta registrado aunque la ficha se haya cerrado mientras tanto.
      widget.alVotar?.call(nuevo);
      notificarExito(
        sigueAhi ? l10n.nodosGraciasConfirmar : l10n.nodosGraciasObsoleto,
      );
      if (!mounted) return;
      if (nuevo.estado != 'Aprobado') {
        // Con este voto el punto salio del mapa: no hay nada mas que mostrar.
        Navigator.of(context).pop();
        return;
      }
      setState(() => _nodo = nuevo);
    } on ApiException catch (e) {
      notificarError(switch (e.statusCode) {
        400 => l10n.nodosVotoMuyLejos,
        403 => l10n.nodosVotoPropioError,
        409 => l10n.nodosVotoNoNecesario,
        _ => l10n.nodosVotoError,
      });
      // 409 es definitivo (ya votaste o el punto ya no esta): no tiene sentido
      // seguir ofreciendo los botones. Otro codigo puede ser pasajero.
      if (mounted && e.statusCode == 409) setState(() => _sinVotoPendiente = true);
    } catch (_) {
      // Sin red u otro fallo: los botones quedan para reintentar.
      notificarError(l10n.nodosVotoError);
    } finally {
      if (mounted) setState(() => _votando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String categoria = categoriaNodoLabel(
      l10n,
      _nodo.categoria,
      otro: _nodo.categoriaOtro,
    );
    final String? descripcion = _nodo.descripcion?.trim();
    final Widget? voto = _seccionVoto(l10n);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_nodo.conFoto) ...<Widget>[
              FotoNodo(api: widget.api, nodoId: _nodo.id),
              const SizedBox(height: 14),
            ],
            Text(
              _nodo.nombre,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              _nodo.creadoPorNombre == null
                  ? categoria
                  : l10n.nodosPropuestoPor(categoria, _nodo.creadoPorNombre!),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FqColors.muted,
              ),
            ),
            if (descripcion != null && descripcion.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(descripcion, style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
            if (_nodo.confirmaciones + _nodo.obsoletos > 0) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                l10n.nodosVotosResumen(_nodo.confirmaciones, _nodo.obsoletos),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FqColors.muted,
                ),
              ),
            ],
            if (voto != null) ...<Widget>[
              const SizedBox(height: 16),
              voto,
            ],
          ],
        ),
      ),
    );
  }

  /// La parte de "sigue ahi / ya no existe": botones si podes votar, o la
  /// razon por la que no (lejos, sin GPS, ya votaste, es tuyo). Null si la
  /// ficha es de solo lectura.
  Widget? _seccionVoto(AppLocalizations l10n) {
    final PosicionGps? Function()? posicionActual = widget.posicionActual;
    if (posicionActual == null || _nodo.estado != 'Aprobado') return null;

    if (widget.usuarioId != null && _nodo.creadoPorId == widget.usuarioId) {
      return _nota(l10n.nodosVotoPropio);
    }
    final String? miVoto = _nodo.miVoto;
    if (miVoto != null) {
      return _nota(
        miVoto == 'confirmar' ? l10n.nodosYaConfirmaste : l10n.nodosYaMarcasteObsoleto,
      );
    }
    if (_sinVotoPendiente) return _nota(l10n.nodosVotoNoNecesario);

    final PosicionGps? posicion = posicionActual();
    if (posicion == null) return _nota(l10n.nodosVotoSinGps);
    final double metros = distanciaMetros(
      posicion.lat,
      posicion.lng,
      _nodo.lat,
      _nodo.lng,
    );
    if (metros > radioVotoMetros) {
      return _nota(l10n.nodosVotoLejos(radioVotoMetros.round(), metros.round()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.nodosVotarTitulo,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: FqButton.primary(
                label: l10n.nodosVotarConfirmar,
                loading: _votando,
                onPressed: _votando ? null : () => _votar(sigueAhi: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FqButton.secondary(
                label: l10n.nodosVotarObsoleto,
                loading: _votando,
                onPressed: _votando ? null : () => _votar(sigueAhi: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _nota(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: FqColors.muted,
        height: 1.35,
      ),
    );
  }
}
