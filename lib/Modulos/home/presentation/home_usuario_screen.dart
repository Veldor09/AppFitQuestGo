import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/mapa/mapbox_config.dart';
import 'package:fit_quest_go/core/mapa/ubicacion_mapa.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

class HomeUsuarioScreen extends StatefulWidget {
  const HomeUsuarioScreen({super.key});

  @override
  State<HomeUsuarioScreen> createState() => _HomeUsuarioScreenState();
}

class _HomeUsuarioScreenState extends State<HomeUsuarioScreen> {
  static const String _accessToken = kMapboxAccessToken;

  final NodoApi _nodoApi = NodoApi();
  final AlertaApi _alertaApi = AlertaApi();
  CircleAnnotationManager? _pines;
  List<Nodo> _nodos = <Nodo>[];
  List<Alerta> _alertas = <Alerta>[];

  @override
  void initState() {
    super.initState();
    _cargarNodos();
    _cargarAlertas();
  }

  Future<void> _cargarNodos() async {
    try {
      final List<Nodo> nodos = await _nodoApi.listar();
      if (!mounted) return;
      setState(() => _nodos = nodos);
      await _dibujarPines();
    } catch (_) {
      // Sin datos por ahora: el mapa queda vacio, no bloquea la pantalla.
    }
  }

  Future<void> _cargarAlertas() async {
    try {
      final List<Alerta> alertas = await _alertaApi.listar();
      if (!mounted) return;
      setState(() => _alertas = alertas);
      await _dibujarPines();
    } catch (_) {
      // Sin datos por ahora: el mapa queda vacio, no bloquea la pantalla.
    }
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _pines = await controller.annotations.createCircleAnnotationManager();
    await _dibujarPines();
    await centrarEnUbicacionActual(controller);
  }

  Future<void> _dibujarPines() async {
    final CircleAnnotationManager? pines = _pines;
    if (pines == null) return;
    await pines.deleteAll();
    if (_nodos.isEmpty && _alertas.isEmpty) return;
    await pines.createMulti(<CircleAnnotationOptions>[
      for (final Nodo nodo in _nodos)
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(nodo.lng, nodo.lat)),
          circleColor: _colorPorCategoria(nodo.categoria).toARGB32(),
          circleRadius: 8,
          circleStrokeColor: FqColors.white.toARGB32(),
          circleStrokeWidth: 2,
        ),
      for (final Alerta alerta in _alertas)
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(alerta.lng, alerta.lat)),
          circleColor: FqColors.risk.toARGB32(),
          circleRadius: alerta.gravedad == 'alta' ? 10 : 8,
          circleStrokeColor: FqColors.white.toARGB32(),
          circleStrokeWidth: 2,
        ),
    ]);
  }

  Future<void> _onLongTap(MapContentGestureContext contexto) async {
    final Position posicion = contexto.point.coordinates;
    final double lng = posicion[0]!.toDouble();
    final double lat = posicion[1]!.toDouble();
    final String? tipo = await _elegirQueReportar();
    if (tipo == null || !mounted) return;
    if (tipo == 'nodo') {
      final Nodo? creado = await _mostrarFormularioNodo(lat: lat, lng: lng);
      if (creado == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Punto enviado. Va a aparecer en el mapa cuando se apruebe.',
          ),
        ),
      );
    } else {
      final Alerta? creada = await _mostrarFormularioAlerta(lat: lat, lng: lng);
      if (creada == null || !mounted) return;
      setState(() => _alertas = <Alerta>[..._alertas, creada]);
      await _dibujarPines();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerta publicada en el mapa.')),
      );
    }
  }

  Future<String?> _elegirQueReportar() {
    return showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Que queres reportar?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Punto de interes'),
              subtitle: const Text('Agua, mirador, comercio...'),
              onTap: () => Navigator.of(ctx).pop('nodo'),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: FqColors.risk),
              title: const Text('Alerta'),
              subtitle: const Text('Peligro u obstaculo en la via'),
              onTap: () => Navigator.of(ctx).pop('alerta'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<Nodo?> _mostrarFormularioNodo({
    required double lat,
    required double lng,
  }) {
    final TextEditingController nombre = TextEditingController();
    final TextEditingController categoria = TextEditingController();
    final TextEditingController descripcion = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showModalBottomSheet<Nodo>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        bool enviando = false;
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
                      'Proponer punto de interes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
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
                      controller: categoria,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        hintText: 'Agua, Mirador, Comercio...',
                      ),
                      validator: (String? v) =>
                          (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descripcion,
                      decoration: const InputDecoration(
                        labelText: 'Descripcion (opcional)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: enviando
                          ? null
                          : () async {
                              if (!(formKey.currentState?.validate() ?? false)) {
                                return;
                              }
                              setSheetState(() => enviando = true);
                              try {
                                final Nodo creado = await _nodoApi.proponer(
                                  nombre: nombre.text.trim(),
                                  categoria: categoria.text.trim(),
                                  lat: lat,
                                  lng: lng,
                                  descripcion: descripcion.text,
                                );
                                if (ctx.mounted) Navigator.of(ctx).pop(creado);
                              } catch (e) {
                                setSheetState(() => enviando = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('No se pudo enviar: $e')),
                                  );
                                }
                              }
                            },
                      child: Text(enviando ? 'Enviando...' : 'Enviar'),
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

  Future<Alerta?> _mostrarFormularioAlerta({
    required double lat,
    required double lng,
  }) {
    final TextEditingController tipo = TextEditingController();
    final TextEditingController descripcion = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String gravedad = 'media';

    return showModalBottomSheet<Alerta>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        bool enviando = false;
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
                      'Reportar alerta',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 11, color: FqColors.muted),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        hintText: 'Arbol caido, Bache, Derrumbe...',
                      ),
                      validator: (String? v) =>
                          (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: gravedad,
                      decoration: const InputDecoration(labelText: 'Gravedad'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'baja', child: Text('Baja')),
                        DropdownMenuItem<String>(value: 'media', child: Text('Media')),
                        DropdownMenuItem<String>(value: 'alta', child: Text('Alta')),
                      ],
                      onChanged: (String? v) =>
                          setSheetState(() => gravedad = v ?? gravedad),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descripcion,
                      decoration: const InputDecoration(
                        labelText: 'Descripcion (opcional)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: enviando
                          ? null
                          : () async {
                              if (!(formKey.currentState?.validate() ?? false)) {
                                return;
                              }
                              setSheetState(() => enviando = true);
                              try {
                                final Alerta creada = await _alertaApi.reportar(
                                  tipo: tipo.text.trim(),
                                  gravedad: gravedad,
                                  lat: lat,
                                  lng: lng,
                                  descripcion: descripcion.text,
                                );
                                if (ctx.mounted) Navigator.of(ctx).pop(creada);
                              } catch (e) {
                                setSheetState(() => enviando = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('No se pudo enviar: $e')),
                                  );
                                }
                              }
                            },
                      child: Text(enviando ? 'Enviando...' : 'Publicar alerta'),
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

  Color _colorPorCategoria(String categoria) {
    switch (categoria.trim().toLowerCase()) {
      case 'agua':
        return FqColors.river;
      case 'mirador':
        return FqColors.amber;
      case 'comercio':
      case 'restaurante':
        return FqColors.pink;
      default:
        return FqColors.trail;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_accessToken.isNotEmpty)
          MapWidget(
            key: const ValueKey<String>('fitquest-map'),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(-84.0907, 9.9281)),
              zoom: 13.5,
            ),
            onMapCreated: _onMapCreated,
            onLongTapListener: _onLongTap,
          )
        else
          const _MissingTokenBackground(),
        const SafeArea(
          child: Column(
            children: <Widget>[
              _TopControls(),
              SizedBox(height: 8),
              _FilterChips(),
              Spacer(),
              _NearbyPanel(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: _floatingDecoration(radius: 18),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.search_rounded, color: FqColors.muted, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Buscar lugar, ruta o evento',
                    style: TextStyle(color: FqColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Container(
            width: 50,
            height: 50,
            decoration: _floatingDecoration(radius: 17),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                const Icon(Icons.notifications_none_rounded, size: 27),
                Positioned(
                  right: 9,
                  top: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: FqColors.risk,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Row(
          children: <Widget>[
            _chip('Todo', selected: true),
            _chip('Rutas'),
            _chip('Alertas'),
            _chip('POIs'),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {bool selected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? FqColors.night : FqColors.paper.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? FqColors.white : FqColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NearbyPanel extends StatelessWidget {
  const _NearbyPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(9, 0, 9, 10),
      padding: const EdgeInsets.fromLTRB(16, 15, 4, 15),
      decoration: _floatingDecoration(radius: 19),
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Cerca de ti',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Manten presionado el mapa para reportar',
                  style: TextStyle(fontSize: 9, color: FqColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: <Widget>[
              const Expanded(
                child: _ResultTile(
                  icon: Icons.route_rounded,
                  label: 'Ruta · 1,2 km',
                ),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: _ResultTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'Alerta · 300 m',
                ),
              ),
              const SizedBox(width: 7),
              Container(
                width: 57,
                height: 57,
                decoration: BoxDecoration(
                  color: FqColors.volt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.add_rounded, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: FqColors.paper,
        border: Border.all(color: FqColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingTokenBackground extends StatelessWidget {
  const _MissingTokenBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EEE5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: const Text(
        'Mapbox necesita ACCESS_TOKEN.\nInicia con --dart-define=ACCESS_TOKEN=pk…',
        textAlign: TextAlign.center,
        style: TextStyle(color: FqColors.muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

BoxDecoration _floatingDecoration({required double radius}) {
  return BoxDecoration(
    color: FqColors.white.withValues(alpha: .97),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Color(0x1F13233F), blurRadius: 18, offset: Offset(0, 5)),
    ],
  );
}
