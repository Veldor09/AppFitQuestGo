import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/ficha_lugar.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion_api.dart';
import 'package:fit_quest_go/Modulos/calificaciones/presentation/pulgares.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/foto_nodo.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/destacable.dart';
import 'package:fit_quest_go/Modulos/reportes/presentation/hoja_reportar.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/etiqueta_destacado.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/interruptor_destacar.dart';

Future<void> mostrarFichaNodo(
  BuildContext context,
  Nodo nodo,
  NodoApi api, {
  PosicionGps? Function()? posicionActual,
  int? usuarioId,
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

  /// Recibe el punto tal como quedo tras encender o apagar "Destacar", para que
  /// el mapa lo dibuje al instante.
  final ValueChanged<Nodo>? alDestacar;

  final CalificacionApi? calificaciones;

  final Future<bool> Function(Uri uri)? abrirUrl;

  @override
  State<FichaNodo> createState() => _FichaNodoState();
}

class _FichaNodoState extends State<FichaNodo> {
  late Nodo _nodo = widget.nodo;

  late final CalificacionApi _calificaciones =
      widget.calificaciones ?? CalificacionApi.predeterminada();

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
    final bool esPropio =
        widget.usuarioId != null && _nodo.creadoPorId == widget.usuarioId;
    final bool sePuedeReportar =
        widget.usuarioId != null && !esPropio && _nodo.estado == 'Aprobado';
    Future<bool> reportar({bool foto = false}) => mostrarHojaReportar(
      context,
      tipo: TipoReportable.nodo,
      contenidoId: _nodo.id,
      nombre: _nodo.nombre,
      esFoto: foto,
    );
    final ResumenCalificacion? resumen = _resumen;
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
                  nombre: _nodo.nombre,
                  abrir: widget.abrirUrl,
                ),
              ),
              if (sePuedeReportar)
                AccionFicha(
                  key: const ValueKey<String>('ficha-reportar'),
                  icono: Icons.flag_outlined,
                  etiqueta: l10n.reportarBoton,
                  onTap: reportar,
                ),
            ],
          ),
          if (_nodo.conFoto) ...<Widget>[
            const SizedBox(height: 16),
            FotoNodo(
              key: const ValueKey<String>('foto-nodo-widget'),
              api: widget.api,
              nodoId: _nodo.id,
              altura: 190,
              titulo: _nodo.nombre,
              alReportar: sePuedeReportar ? () => reportar(foto: true) : null,
            ),
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
        ],
      ),
    );
  }
}
