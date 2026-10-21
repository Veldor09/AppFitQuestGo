import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/geo/votacion.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/ficha_lugar.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion_api.dart';
import 'package:fit_quest_go/Modulos/calificaciones/presentation/pulgares.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/foto_nodo.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/destacable.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/etiqueta_destacado.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/interruptor_destacar.dart';

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
  ValueChanged<Nodo>? alDestacar,
  CalificacionApi? calificaciones,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: formaFichaLugar,
    builder: (BuildContext _) => FichaNodo(
      nodo: nodo,
      api: api,
      posicionActual: posicionActual,
      usuarioId: usuarioId,
      alVotar: alVotar,
      alDestacar: alDestacar,
      calificaciones: calificaciones,
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
    this.alDestacar,
    this.calificaciones,
    this.abrirUrl,
  });

  final Nodo nodo;
  final NodoApi api;

  /// Ultima posicion conocida del GPS. Si es null no hay seccion de voto.
  final PosicionGps? Function()? posicionActual;

  /// Quien mira la ficha: quien propuso el punto no lo vota.
  final int? usuarioId;
  final ValueChanged<Nodo>? alVotar;

  /// Recibe el punto tal como quedo tras encender o apagar "Destacar", para que
  /// el mapa lo dibuje al instante.
  final ValueChanged<Nodo>? alDestacar;

  /// Pulgares del punto, inyectable para pruebas.
  final CalificacionApi? calificaciones;

  /// Abre "Como llegar"; por defecto lanza la app de mapas (inyectable para pruebas).
  final Future<bool> Function(Uri uri)? abrirUrl;

  @override
  State<FichaNodo> createState() => _FichaNodoState();
}

class _FichaNodoState extends State<FichaNodo> {
  late Nodo _nodo = widget.nodo;
  bool _votando = false;

  /// El servidor respondio 409: este punto ya no necesita tu voto.
  bool _sinVotoPendiente = false;

  late final CalificacionApi _calificaciones =
      widget.calificaciones ?? CalificacionApi.predeterminada();

  /// Pulgares del punto; null mientras carga (o si no se pudo pedir: la ficha
  /// funciona igual sin ellos).
  ResumenCalificacion? _resumen;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    try {
      final ResumenCalificacion r = await _calificaciones.resumen(
        TipoCalificable.nodo,
        _nodo.id,
      );
      if (mounted) setState(() => _resumen = r);
    } catch (_) {
      // Sin pulgares: no es motivo para romper la ficha.
    }
  }

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

  /// El dueno de un punto que se puede destacar ve el interruptor.
  bool get _puedeDestacar =>
      widget.usuarioId != null &&
      _nodo.creadoPorId == widget.usuarioId &&
      nodoDestacable(_nodo);

  Future<bool> _cambiarDestacado(bool destacar) async {
    final ResultadoDestacar r = await widget.api.destacar(
      _nodo.id,
      destacar: destacar,
    );
    final Nodo nuevo = _nodo.conDestacado(
      destacarActivado: r.destacarActivado,
      destacado: r.destacado,
    );
    if (mounted) setState(() => _nodo = nuevo);
    widget.alDestacar?.call(nuevo);
    return r.destacarActivado;
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
    final String? beneficio = _nodo.beneficio?.trim();
    final Widget? voto = _seccionVoto(l10n);
    final bool esPropio =
        widget.usuarioId != null && _nodo.creadoPorId == widget.usuarioId;
    final ResumenCalificacion? resumen = _resumen;
    // Calificar: solo desde el mapa (con GPS), sobre un punto aprobado y ajeno.
    final bool sePuedeCalificar =
        widget.posicionActual != null &&
        _nodo.estado == 'Aprobado' &&
        !esPropio &&
        resumen != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CabeceraFicha(
            titulo: _nodo.nombre,
            subtitulo: _nodo.creadoPorNombre == null
                ? categoria
                : _nodo.patrocinado
                ? l10n.nodosPatrocinadoPor(categoria, _nodo.creadoPorNombre!)
                : l10n.nodosPropuestoPor(categoria, _nodo.creadoPorNombre!),
            icono: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorCategoriaNodo(_nodo.categoria).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.place_rounded,
                color: colorCategoriaNodo(_nodo.categoria),
              ),
            ),
            etiquetas: <Widget>[if (_nodo.destacado) const EtiquetaDestacado()],
          ),
          if (resumen != null) ...<Widget>[
            const SizedBox(height: 12),
            Pulgares(resumen: resumen, compacto: true),
          ],
          const SizedBox(height: 14),
          FilaAccionesFicha(
            acciones: <Widget>[
              AccionFicha(
                key: const ValueKey<String>('ficha-como-llegar'),
                icono: Icons.directions_rounded,
                etiqueta: l10n.fichaComoLlegar,
                principal: true,
                onTap: () => abrirComoLlegar(
                  context,
                  lat: _nodo.lat,
                  lng: _nodo.lng,
                  abrir: widget.abrirUrl,
                ),
              ),
            ],
          ),
          if (_nodo.conFoto) ...<Widget>[
            const SizedBox(height: 16),
            FotoNodo(api: widget.api, nodoId: _nodo.id, altura: 190),
          ],
          if (beneficio != null && beneficio.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              key: const ValueKey<String>('ficha-beneficio'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FqColors.chipSelectedBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 18,
                    color: FqColors.voltDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.nodosBeneficioTitulo,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: FqColors.chipSelectedInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          beneficio,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (descripcion != null && descripcion.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(descripcion, style: const TextStyle(fontSize: 13.5, height: 1.4)),
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
          if (_puedeDestacar) ...<Widget>[
            const SizedBox(height: 12),
            InterruptorDestacar(
              activado: _nodo.destacarActivado,
              alCambiar: _cambiarDestacado,
            ),
          ],
          if (sePuedeCalificar) ...<Widget>[
            const SizedBox(height: 18),
            SeccionFicha(
              titulo: l10n.calificarPregunta,
              hijo: PulgaresObjeto(
                tipo: TipoCalificable.nodo,
                id: _nodo.id,
                api: _calificaciones,
                resumenInicial: resumen,
                destino: (lat: _nodo.lat, lng: _nodo.lng),
                posicionActual: widget.posicionActual,
                alCambiar: (ResumenCalificacion r) => setState(() => _resumen = r),
              ),
            ),
          ],
          if (voto != null) ...<Widget>[
            const SizedBox(height: 18),
            voto,
          ],
        ],
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
