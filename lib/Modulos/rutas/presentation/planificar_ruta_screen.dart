import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';

/// RTE-05/06/07 · Planificar ruta. Cada toque en el mapa agrega un punto al
/// trazo; "Guardar" abre el formulario y crea la ruta como Privada
/// (`POST /rutas`). La distancia se calcula sola (haversine) a partir de los
/// puntos: no se le pide al usuario que la adivine.
class PlanificarRutaScreen extends StatefulWidget {
  const PlanificarRutaScreen({super.key, this.api});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final RutaApi? api;

  @override
  State<PlanificarRutaScreen> createState() => _PlanificarRutaScreenState();
}

class _PlanificarRutaScreenState extends State<PlanificarRutaScreen> {
  static const String _accessToken = String.fromEnvironment('ACCESS_TOKEN');

  late final RutaApi _api = widget.api ?? RutaApi();
  CircleAnnotationManager? _pines;
  PolylineAnnotationManager? _lineas;

  final List<PuntoRuta> _puntos = <PuntoRuta>[];
  bool _guardando = false;

  Future<void> _onMapCreated(MapboxMap controller) async {
    _pines = await controller.annotations.createCircleAnnotationManager();
    _lineas = await controller.annotations.createPolylineAnnotationManager();
  }

  Future<void> _onTap(MapContentGestureContext contexto) async {
    if (_guardando) return;
    final Position posicion = contexto.point.coordinates;
    setState(() {
      _puntos.add(
        PuntoRuta(lat: posicion[1]!.toDouble(), lng: posicion[0]!.toDouble()),
      );
    });
    await _redibujar();
  }

  Future<void> _deshacer() async {
    if (_puntos.isEmpty) return;
    setState(() => _puntos.removeLast());
    await _redibujar();
  }

  Future<void> _limpiar() async {
    if (_puntos.isEmpty) return;
    setState(() => _puntos.clear());
    await _redibujar();
  }

  Future<void> _redibujar() async {
    await _pines?.deleteAll();
    await _lineas?.deleteAll();
    for (final PuntoRuta p in _puntos) {
      await _pines?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(p.lng, p.lat)),
          circleColor: FqColors.voltDark.toARGB32(),
          circleRadius: 6,
          circleStrokeColor: FqColors.white.toARGB32(),
          circleStrokeWidth: 2,
        ),
      );
    }
    if (_puntos.length >= 2) {
      await _lineas?.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: <Position>[
              for (final PuntoRuta p in _puntos) Position(p.lng, p.lat),
            ],
          ),
          lineColor: FqColors.river.toARGB32(),
          lineWidth: 4,
        ),
      );
    }
  }

  double get _distanciaKm {
    double total = 0;
    for (int i = 0; i < _puntos.length - 1; i++) {
      total += _haversineKm(_puntos[i], _puntos[i + 1]);
    }
    return total;
  }

  double _haversineKm(PuntoRuta a, PuntoRuta b) {
    const double radioTierra = 6371;
    final double dLat = _aRadianes(b.lat - a.lat);
    final double dLng = _aRadianes(b.lng - a.lng);
    final double lat1 = _aRadianes(a.lat);
    final double lat2 = _aRadianes(b.lat);
    final double h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return radioTierra * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _aRadianes(double grados) => grados * math.pi / 180;

  Future<void> _guardar() async {
    if (_puntos.length < 2) return;
    final _DatosRuta? datos = await _mostrarFormulario();
    if (datos == null) return;
    setState(() => _guardando = true);
    try {
      await _api.crear(
        nombre: datos.nombre,
        actividad: datos.actividad,
        dificultad: datos.dificultad,
        distanciaKm: _distanciaKm,
        puntos: _puntos,
      );
      if (!mounted) return;
      notificarExito('Ruta guardada como privada. Podes publicarla desde "Mis rutas".');
      setState(() => _puntos.clear());
      await _redibujar();
    } catch (_) {
      if (mounted) notificarError('No se pudo guardar la ruta');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<_DatosRuta?> _mostrarFormulario() {
    final TextEditingController nombre = TextEditingController();
    final TextEditingController actividad = TextEditingController();
    String dificultad = 'moderada';
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showModalBottomSheet<_DatosRuta>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Guardar ruta',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_puntos.length} puntos · ${_distanciaKm.toStringAsFixed(1)} km aprox.',
                      style: const TextStyle(fontSize: 11, color: FqColors.muted),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nombre,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (String? v) =>
                          (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: actividad,
                      decoration: const InputDecoration(
                        labelText: 'Actividad',
                        hintText: 'Running, Ciclismo, Hiking...',
                      ),
                      validator: (String? v) =>
                          (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: dificultad,
                      decoration: const InputDecoration(labelText: 'Dificultad'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'facil', child: Text('Facil')),
                        DropdownMenuItem<String>(
                          value: 'moderada',
                          child: Text('Moderada'),
                        ),
                        DropdownMenuItem<String>(value: 'dificil', child: Text('Dificil')),
                      ],
                      onChanged: (String? v) =>
                          setSheetState(() => dificultad = v ?? dificultad),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        Navigator.of(ctx).pop(
                          _DatosRuta(
                            nombre: nombre.text.trim(),
                            actividad: actividad.text.trim(),
                            dificultad: dificultad,
                          ),
                        );
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_accessToken.isNotEmpty)
          MapWidget(
            key: const ValueKey<String>('planificar-ruta-map'),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(-84.0907, 9.9281)),
              zoom: 13.5,
            ),
            onMapCreated: _onMapCreated,
            onTapListener: _onTap,
          )
        else
          const ColoredBox(
            color: Color(0xFFE8EEE5),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Mapbox necesita ACCESS_TOKEN.\nInicia con --dart-define=ACCESS_TOKEN=pk…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FqColors.muted, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: FqColors.white.withValues(alpha: .97),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: FqColors.softShadow,
                  ),
                  child: const Text(
                    'Toca el mapa para trazar tu ruta, punto por punto.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FqColors.white.withValues(alpha: .97),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: FqColors.softShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        _puntos.isEmpty
                            ? 'Sin puntos todavia'
                            : '${_puntos.length} puntos · ${_distanciaKm.toStringAsFixed(1)} km aprox.',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: FqButton.secondary(
                              label: 'Deshacer',
                              dense: true,
                              onPressed: _puntos.isEmpty || _guardando ? null : _deshacer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FqButton.secondary(
                              label: 'Limpiar',
                              dense: true,
                              onPressed: _puntos.isEmpty || _guardando ? null : _limpiar,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FqButton.primary(
                              label: _guardando ? 'Guardando...' : 'Guardar',
                              dense: true,
                              onPressed: (_puntos.length < 2 || _guardando)
                                  ? null
                                  : _guardar,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _DatosRuta {
  const _DatosRuta({
    required this.nombre,
    required this.actividad,
    required this.dificultad,
  });

  final String nombre;
  final String actividad;
  final String dificultad;
}
