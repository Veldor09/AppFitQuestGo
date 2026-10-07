import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/editor_evento_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/mapa_trazos_evento.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

/// Construye el mapa de la empresa. En produccion es [MapaTrazosEvento]; las
/// pruebas lo reemplazan por uno falso para ver que se le pasa sin Mapbox.
typedef ConstructorMapaEmpresa =
    Widget Function(
      BuildContext context,
      List<ZonaEvento> areas,
      List<ZonaEvento> recorridos,
      List<ZonaEvento> areasOtras,
      List<ZonaEvento> recorridosOtros,
      List<PuntoGeo> pines,
    );

/// Pantalla principal de una cuenta de empresa: el mapa con todos sus eventos
/// (las areas rellenas y los recorridos como linea) y sus nodos. Con "Ver otras
/// empresas" suma, en gris, los eventos y nodos de las demas empresas (los de
/// los deportistas nunca llegan: el servidor no se los entrega a una empresa).
///
/// Desde aqui tambien se crea un evento nuevo.
class MapaEmpresaScreen extends StatefulWidget {
  const MapaEmpresaScreen({
    super.key,
    this.eventoApi,
    this.nodoApi,
    this.senal,
    this.editorBuilder,
    this.mapaBuilder,
  });

  /// Inyectables para pruebas; en produccion se crean los reales.
  final EventoApi? eventoApi;
  final NodoApi? nodoApi;

  /// Aviso compartido con la pestaña "Eventos": quien guarda o borra un evento
  /// suma uno y todos se recargan.
  final ValueNotifier<int>? senal;

  /// Abre el editor de eventos. Las pruebas lo reemplazan para no montar Mapbox.
  final WidgetBuilder? editorBuilder;

  final ConstructorMapaEmpresa? mapaBuilder;

  @override
  State<MapaEmpresaScreen> createState() => _MapaEmpresaScreenState();
}

class _MapaEmpresaScreenState extends State<MapaEmpresaScreen> {
  late final EventoApi _eventoApi = widget.eventoApi ?? EventoApi();
  late final NodoApi _nodoApi = widget.nodoApi ?? NodoApi();

  List<Evento> _propios = const <Evento>[];
  List<Evento> _otros = const <Evento>[];
  List<Nodo> _nodos = const <Nodo>[];
  bool _cargando = true;
  bool _errorCarga = false;
  bool _verOtras = false;

  // Listas ya listas para el mapa. Cada recarga arma instancias nuevas: asi el
  // mapa sabe que tiene que redibujar.
  List<ZonaEvento> _areas = const <ZonaEvento>[];
  List<ZonaEvento> _recorridos = const <ZonaEvento>[];
  List<ZonaEvento> _areasOtras = const <ZonaEvento>[];
  List<ZonaEvento> _recorridosOtros = const <ZonaEvento>[];
  List<PuntoGeo> _pines = const <PuntoGeo>[];

  int? get _miId =>
      AuthScope.maybeOf(context)?.usuario?.id ??
      (_propios.isEmpty ? null : _propios.first.creadoPorId);

  @override
  void initState() {
    super.initState();
    widget.senal?.addListener(_alSenal);
    unawaited(_cargar());
  }

  @override
  void dispose() {
    widget.senal?.removeListener(_alSenal);
    super.dispose();
  }

  void _alSenal() => unawaited(_cargar());

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = false;
    });
    try {
      final List<Evento> propios = await _eventoApi.mios();
      if (!mounted) return;
      _propios = propios;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = true;
      });
      return;
    }
    // Lo demas es complemento: si falla, el mapa igual muestra los eventos propios.
    try {
      _nodos = await _nodoApi.listar();
    } catch (_) {
      _nodos = const <Nodo>[];
    }
    if (_verOtras) await _cargarOtros();
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _recalcular();
    });
  }

  Future<void> _cargarOtros() async {
    try {
      final List<Evento> todos = await _eventoApi.listar();
      final Set<int> propios = <int>{for (final Evento e in _propios) e.id};
      _otros = <Evento>[
        for (final Evento e in todos)
          if (!propios.contains(e.id)) e,
      ];
    } catch (_) {
      _otros = const <Evento>[];
    }
  }

  Future<void> _alternarOtras(bool valor) async {
    setState(() => _verOtras = valor);
    if (valor) await _cargarOtros();
    if (!mounted) return;
    setState(_recalcular);
  }

  void _recalcular() {
    _areas = <ZonaEvento>[for (final Evento e in _propios) ...e.areas];
    _recorridos = <ZonaEvento>[
      for (final Evento e in _propios) ...e.recorridos,
    ];
    _areasOtras = _verOtras
        ? <ZonaEvento>[for (final Evento e in _otros) ...e.areas]
        : const <ZonaEvento>[];
    _recorridosOtros = _verOtras
        ? <ZonaEvento>[for (final Evento e in _otros) ...e.recorridos]
        : const <ZonaEvento>[];
    final int? mio = _miId;
    // Los nodos propios siempre; los de otras empresas solo si se piden.
    _pines = <PuntoGeo>[
      for (final Nodo n in _nodos)
        if (_verOtras || (mio != null && n.creadoPorId == mio))
          PuntoGeo(lat: n.lat, lng: n.lng),
    ];
  }

  Future<void> _nuevoEvento() async {
    final Evento? guardado = await Navigator.of(context).push<Evento>(
      MaterialPageRoute<Evento>(
        builder: (BuildContext ctx) =>
            widget.editorBuilder?.call(ctx) ?? const EditorEventoScreen(),
      ),
    );
    if (guardado == null || !mounted) return;
    final ValueNotifier<int>? senal = widget.senal;
    if (senal != null) {
      senal.value++;
    } else {
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool sinEventos = !_cargando && !_errorCarga && _propios.isEmpty;
    return Scaffold(
      backgroundColor: FqColors.paper,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('nuevo-evento-mapa'),
        onPressed: _nuevoEvento,
        backgroundColor: FqColors.volt,
        foregroundColor: FqColors.primaryInk,
        icon: const Icon(Icons.add),
        label: Text(l10n.eventoNuevo),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.mapaBuilder != null
              ? widget.mapaBuilder!(
                  context,
                  _areas,
                  _recorridos,
                  _areasOtras,
                  _recorridosOtros,
                  _pines,
                )
              : MapaTrazosEvento(
                  areas: _areas,
                  recorridos: _recorridos,
                  areasSecundarias: _areasOtras,
                  recorridosSecundarios: _recorridosOtros,
                  pines: _pines,
                  centrarEnUsuario: true,
                ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Align(
                alignment: Alignment.topCenter,
                child: _PanelSuperior(
                  verOtras: _verOtras,
                  onVerOtras: _alternarOtras,
                  cargando: _cargando,
                  error: _errorCarga,
                  eventos: _propios.length,
                  onReintentar: _cargar,
                ),
              ),
            ),
          ),
          if (sinEventos)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90,
              child: _TarjetaVacia(
                titulo: l10n.mapaEmpresaVacioTitulo,
                mensaje: l10n.mapaEmpresaVacioMensaje,
              ),
            ),
        ],
      ),
    );
  }
}

class _PanelSuperior extends StatelessWidget {
  const _PanelSuperior({
    required this.verOtras,
    required this.onVerOtras,
    required this.cargando,
    required this.error,
    required this.eventos,
    required this.onReintentar,
  });

  final bool verOtras;
  final ValueChanged<bool> onVerOtras;
  final bool cargando;
  final bool error;
  final int eventos;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FqColors.white.withValues(alpha: .96),
          borderRadius: FqRadius.allLg,
          boxShadow: FqColors.softShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      error
                          ? l10n.mapaEmpresaErrorCarga
                          : l10n.mapaEmpresaResumen(eventos),
                      key: const ValueKey<String>('resumen-mapa'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: error ? FqColors.risk : FqColors.ink,
                      ),
                    ),
                  ),
                  if (cargando)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (error)
                    TextButton(
                      onPressed: onReintentar,
                      child: Text(l10n.comunReintentar),
                    ),
                ],
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.mapaEmpresaOtrasEmpresas,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FqColors.muted,
                      ),
                    ),
                  ),
                  Switch(
                    key: const ValueKey<String>('ver-otras-empresas'),
                    value: verOtras,
                    onChanged: onVerOtras,
                    activeThumbColor: FqColors.voltDark,
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: <Widget>[
                  _Leyenda(
                    color: colorAreaEvento,
                    texto: l10n.eventoAreasTitulo,
                  ),
                  _Leyenda(
                    color: colorRecorridoEvento,
                    texto: l10n.eventoRecorridosTitulo,
                  ),
                  _Leyenda(color: FqColors.volt, texto: l10n.navNodos),
                  if (verOtras)
                    _Leyenda(
                      color: colorSecundarioEvento,
                      texto: l10n.mapaEmpresaLeyendaOtras,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: const TextStyle(fontSize: 10.5, color: FqColors.muted),
        ),
      ],
    );
  }
}

class _TarjetaVacia extends StatelessWidget {
  const _TarjetaVacia({required this.titulo, required this.mensaje});

  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FqColors.night.withValues(alpha: .92),
        borderRadius: FqRadius.allLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            titulo,
            key: const ValueKey<String>('mapa-vacio'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: FqColors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: FqColors.white),
          ),
        ],
      ),
    );
  }
}
