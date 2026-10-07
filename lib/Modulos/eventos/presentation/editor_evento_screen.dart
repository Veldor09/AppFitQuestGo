import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_selector_opciones.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/eventos/data/formato_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/mapa_trazos_evento.dart';

/// Construye el mapa del editor. En produccion es [MapaTrazosEvento]; las
/// pruebas lo reemplazan por uno falso para simular un trazo sin Mapbox.
typedef ConstructorMapaEditor =
    Widget Function(
      BuildContext context,
      List<ZonaEvento> areas,
      List<ZonaEvento> recorridos,
      ModoDibujo modo,
      void Function(ModoDibujo modo, List<PuntoGeo> puntos) onTrazoDibujado,
      VoidCallback onTrazoCorto,
    );

/// Crear o editar un evento: pestaña "Datos" (nombre, categoria, descripcion,
/// fechas) y pestaña "Mapa" (trazar con el dedo las areas y los recorridos).
/// Al guardar cierra la pantalla con el [Evento] que dejo el servidor.
class EditorEventoScreen extends StatefulWidget {
  const EditorEventoScreen({
    super.key,
    this.api,
    this.evento,
    this.mapaBuilder,
    this.ahora,
  });

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final EventoApi? api;

  /// El evento a editar; null para crear uno nuevo.
  final Evento? evento;

  final ConstructorMapaEditor? mapaBuilder;

  /// Reloj inyectable para pruebas.
  final DateTime Function()? ahora;

  @override
  State<EditorEventoScreen> createState() => _EditorEventoScreenState();
}

class _EditorEventoScreenState extends State<EditorEventoScreen> {
  late final EventoApi _api = widget.api ?? EventoApi();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre = TextEditingController(
    text: widget.evento?.nombre,
  );
  late final TextEditingController _descripcion = TextEditingController(
    text: widget.evento?.descripcion,
  );

  late String? _categoria = widget.evento?.categoria;
  late DateTime? _inicio = widget.evento?.fechaInicio.toLocal();
  late DateTime? _fin = widget.evento?.fechaFin.toLocal();
  late List<ZonaEvento> _areas = List<ZonaEvento>.of(
    widget.evento?.areas ?? const <ZonaEvento>[],
  );
  late List<ZonaEvento> _recorridos = List<ZonaEvento>.of(
    widget.evento?.recorridos ?? const <ZonaEvento>[],
  );

  int _pestana = 0;
  ModoDibujo _modo = ModoDibujo.ninguno;
  bool _faltaCategoria = false;
  bool _guardando = false;

  bool get _esEdicion => widget.evento != null;

  DateTime get _ahora => (widget.ahora ?? DateTime.now)();

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  // ---- Fechas --------------------------------------------------------------

  Future<DateTime?> _elegirFechaHora(DateTime? actual) async {
    final DateTime base = actual ?? _ahora.add(const Duration(days: 1));
    final DateTime? dia = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 3),
    );
    if (dia == null || !mounted) return null;
    final TimeOfDay? hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (hora == null) return null;
    return DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);
  }

  Future<void> _cambiarInicio() async {
    final DateTime? nueva = await _elegirFechaHora(_inicio);
    if (nueva == null || !mounted) return;
    setState(() {
      _inicio = nueva;
      // Si el fin quedo antes del nuevo inicio, se corre una hora despues.
      final DateTime? fin = _fin;
      if (fin != null && !fin.isAfter(nueva)) {
        _fin = nueva.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _cambiarFin() async {
    // Sin fin todavia, el selector sugiere una hora despues del inicio.
    final DateTime? nueva = await _elegirFechaHora(
      _fin ?? _inicio?.add(const Duration(hours: 1)),
    );
    if (nueva == null || !mounted) return;
    setState(() => _fin = nueva);
  }

  // ---- Trazos --------------------------------------------------------------

  Future<void> _alTrazoDibujado(ModoDibujo modo, List<PuntoGeo> puntos) async {
    if (!mounted) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool esArea = modo == ModoDibujo.area;
    final String sugerido = esArea
        ? l10n.eventoNombreAreaDefecto(_areas.length + 1)
        : l10n.eventoNombreRecorridoDefecto(_recorridos.length + 1);
    final String? nombre = await _pedirNombreTrazo(l10n, sugerido);
    if (nombre == null || !mounted) return;
    final ZonaEvento zona = ZonaEvento(nombre: nombre, puntos: puntos);
    setState(() {
      // Listas nuevas, no mutadas: el mapa redibuja cuando cambia la instancia.
      if (esArea) {
        _areas = <ZonaEvento>[..._areas, zona];
      } else {
        _recorridos = <ZonaEvento>[..._recorridos, zona];
      }
      _modo = ModoDibujo.ninguno;
    });
  }

  Future<String?> _pedirNombreTrazo(AppLocalizations l10n, String sugerido) {
    final TextEditingController controlador = TextEditingController(
      text: sugerido,
    );
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.eventoNombreTrazoTitulo),
        content: TextField(
          key: const ValueKey<String>('campo-nombre-trazo'),
          controller: controlador,
          autofocus: true,
          maxLength: 100,
          decoration: InputDecoration(labelText: l10n.comunNombre),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.comunCancelar),
          ),
          FilledButton(
            key: const ValueKey<String>('aceptar-nombre-trazo'),
            onPressed: () {
              final String texto = controlador.text.trim();
              Navigator.of(ctx).pop(texto.isEmpty ? sugerido : texto);
            },
            child: Text(l10n.comunGuardar),
          ),
        ],
      ),
    );
  }

  void _alTrazoCorto() {
    if (!mounted) return;
    notificarInfo(AppLocalizations.of(context)!.eventoTrazoCorto);
  }

  void _quitarArea(ZonaEvento zona) => setState(
    () => _areas = _areas.where((ZonaEvento z) => z != zona).toList(),
  );

  void _quitarRecorrido(ZonaEvento zona) => setState(
    () => _recorridos = _recorridos.where((ZonaEvento z) => z != zona).toList(),
  );

  // ---- Guardar -------------------------------------------------------------

  Future<void> _guardar() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();

    final bool formularioOk = _formKey.currentState?.validate() ?? false;
    if (!formularioOk || _categoria == null) {
      setState(() {
        _faltaCategoria = _categoria == null;
        _pestana = 0;
      });
      notificarError(l10n.comunRevisaCampos);
      return;
    }
    final DateTime? inicio = _inicio;
    final DateTime? fin = _fin;
    if (inicio == null || fin == null) {
      setState(() => _pestana = 0);
      notificarError(l10n.eventoFaltaFechas);
      return;
    }
    if (!fin.isAfter(inicio)) {
      setState(() => _pestana = 0);
      notificarError(l10n.eventoFinAntesDeInicio);
      return;
    }
    if (!_esEdicion && !fin.isAfter(_ahora)) {
      setState(() => _pestana = 0);
      notificarError(l10n.eventoYaTermino);
      return;
    }
    if (_areas.isEmpty && _recorridos.isEmpty) {
      setState(() => _pestana = 1);
      notificarError(l10n.eventoFaltaTrazo);
      return;
    }

    setState(() => _guardando = true);
    try {
      final Evento guardado = _esEdicion
          ? await _api.actualizar(
              widget.evento!.id,
              nombre: _nombre.text,
              descripcion: _descripcion.text,
              categoria: _categoria!,
              fechaInicio: inicio,
              fechaFin: fin,
              areas: _areas,
              recorridos: _recorridos,
            )
          : await _api.crear(
              nombre: _nombre.text,
              descripcion: _descripcion.text,
              categoria: _categoria!,
              fechaInicio: inicio,
              fechaFin: fin,
              areas: _areas,
              recorridos: _recorridos,
            );
      if (!mounted) return;
      notificarExito(l10n.eventoGuardado);
      Navigator.of(context).pop(guardado);
    } on ApiException catch (e) {
      _fallar(e.message);
    } catch (_) {
      _fallar(l10n.eventoErrorGuardar);
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    setState(() => _guardando = false);
    notificarError(mensaje);
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: FqColors.paper,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FqAppHeader(
              title: _esEdicion
                  ? l10n.eventoEditarTitulo
                  : l10n.eventoNuevoTitulo,
              onLeading: _guardando
                  ? null
                  : () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(FqGap.xl, 10, FqGap.xl, 6),
              child: SegmentedButton<int>(
                key: const ValueKey<String>('pestanas-editor-evento'),
                showSelectedIcon: false,
                segments: <ButtonSegment<int>>[
                  ButtonSegment<int>(
                    value: 0,
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: Text(l10n.eventoPestanaDatos),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    icon: const Icon(Icons.draw_outlined, size: 18),
                    label: Text(l10n.eventoPestanaMapa),
                  ),
                ],
                selected: <int>{_pestana},
                onSelectionChanged: (Set<int> v) =>
                    setState(() => _pestana = v.first),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _pestana,
                children: <Widget>[_datos(l10n), _mapa(l10n)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FqGap.xl,
                8,
                FqGap.xl,
                FqGap.xl,
              ),
              child: FqButton.primary(
                key: const ValueKey<String>('guardar-evento'),
                label: l10n.eventoGuardar,
                loading: _guardando,
                onPressed: _guardando ? null : _guardar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datos(AppLocalizations l10n) {
    final DateTime? inicio = _inicio;
    final DateTime? fin = _fin;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(FqGap.xl, 8, FqGap.xl, FqGap.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              key: const ValueKey<String>('campo-nombre-evento'),
              controller: _nombre,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: l10n.eventoNombreLabel,
                hintText: l10n.eventoNombreHint,
              ),
              validator: (String? v) => (v == null || v.trim().isEmpty)
                  ? l10n.comunObligatorio
                  : null,
            ),
            const SizedBox(height: 10),
            _titulo(l10n.eventoCategoriaTitulo),
            const SizedBox(height: 8),
            FqSelectorOpciones(
              opciones: categoriasEvento,
              etiqueta: (String clave) => categoriaEventoLabel(l10n, clave),
              seleccion: _categoria == null
                  ? const <String>{}
                  : <String>{_categoria!},
              onToggle: (String clave) => setState(() {
                _categoria = clave;
                _faltaCategoria = false;
              }),
              errorTexto: _faltaCategoria ? l10n.eventoFaltaCategoria : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey<String>('campo-descripcion-evento'),
              controller: _descripcion,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: l10n.comunDescripcionOpcional,
              ),
            ),
            const SizedBox(height: 6),
            _FilaFecha(
              key: const ValueKey<String>('fecha-inicio'),
              icono: Icons.event_available_outlined,
              etiqueta: l10n.eventoInicioLabel,
              valor: inicio == null ? null : fechaHoraLabel(context, inicio),
              vacio: l10n.eventoElegirFecha,
              onTap: _cambiarInicio,
            ),
            const SizedBox(height: 8),
            _FilaFecha(
              key: const ValueKey<String>('fecha-fin'),
              icono: Icons.event_busy_outlined,
              etiqueta: l10n.eventoFinLabel,
              valor: fin == null ? null : fechaHoraLabel(context, fin),
              vacio: l10n.eventoElegirFecha,
              onTap: _cambiarFin,
            ),
            const SizedBox(height: 12),
            _ResumenTrazos(
              areas: _areas.length,
              recorridos: _recorridos.length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(String texto) => Text(
    texto,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: FqColors.muted,
    ),
  );

  Widget _mapa(AppLocalizations l10n) {
    final ConstructorMapaEditor? constructor = widget.mapaBuilder;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        constructor != null
            ? constructor(
                context,
                _areas,
                _recorridos,
                _modo,
                _alTrazoDibujado,
                _alTrazoCorto,
              )
            : MapaTrazosEvento(
                areas: _areas,
                recorridos: _recorridos,
                modoDibujo: _modo,
                onTrazoDibujado: _alTrazoDibujado,
                onTrazoCorto: _alTrazoCorto,
                centrarEnUsuario: !_esEdicion,
              ),
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _BarraModos(
                modo: _modo,
                alCambiar: (ModoDibujo m) => setState(() => _modo = m),
              ),
              if (_modo != ModoDibujo.ninguno) ...<Widget>[
                const SizedBox(height: 8),
                _Aviso(texto: l10n.eventoAyudaDibujo),
              ],
            ],
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: _PanelTrazos(
            areas: _areas,
            recorridos: _recorridos,
            alQuitarArea: _quitarArea,
            alQuitarRecorrido: _quitarRecorrido,
          ),
        ),
      ],
    );
  }
}

class _FilaFecha extends StatelessWidget {
  const _FilaFecha({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.vacio,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final String? valor;
  final String vacio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: FqRadius.allMd,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: FqColors.white,
          borderRadius: FqRadius.allMd,
          border: Border.all(color: FqColors.fieldBorder),
        ),
        child: Row(
          children: <Widget>[
            Icon(icono, size: 20, color: FqColors.night),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    etiqueta,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: FqColors.fieldLabel,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valor ?? vacio,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: valor == null ? FqColors.muted : FqColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: FqColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ResumenTrazos extends StatelessWidget {
  const _ResumenTrazos({required this.areas, required this.recorridos});

  final int areas;
  final int recorridos;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool vacio = areas == 0 && recorridos == 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vacio ? FqColors.infoNoteBg : FqColors.evidenceBg,
        borderRadius: FqRadius.allMd,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            vacio ? Icons.info_outline : Icons.check_circle_outline,
            size: 18,
            color: vacio ? FqColors.infoNoteInk : FqColors.voltDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              vacio
                  ? l10n.eventoFaltaTrazo
                  : l10n.eventoResumenTrazos(areas, recorridos),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: vacio ? FqColors.infoNoteInk : FqColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraModos extends StatelessWidget {
  const _BarraModos({required this.modo, required this.alCambiar});

  final ModoDibujo modo;
  final ValueChanged<ModoDibujo> alCambiar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: FqRadius.allLg,
        boxShadow: FqColors.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: <Widget>[
            _BotonModo(
              clave: 'modo-mover',
              icono: Icons.pan_tool_alt_outlined,
              texto: l10n.eventoModoMover,
              activo: modo == ModoDibujo.ninguno,
              onTap: () => alCambiar(ModoDibujo.ninguno),
            ),
            _BotonModo(
              clave: 'modo-recorrido',
              icono: Icons.timeline,
              texto: l10n.eventoModoRecorrido,
              activo: modo == ModoDibujo.recorrido,
              onTap: () => alCambiar(ModoDibujo.recorrido),
            ),
            _BotonModo(
              clave: 'modo-area',
              icono: Icons.crop_free,
              texto: l10n.eventoModoArea,
              activo: modo == ModoDibujo.area,
              onTap: () => alCambiar(ModoDibujo.area),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonModo extends StatelessWidget {
  const _BotonModo({
    required this.clave,
    required this.icono,
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  final String clave;
  final IconData icono;
  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        key: ValueKey<String>(clave),
        onTap: onTap,
        borderRadius: FqRadius.allMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: activo ? FqColors.night : Colors.transparent,
            borderRadius: FqRadius.allMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icono,
                size: 18,
                color: activo ? FqColors.volt : FqColors.night,
              ),
              const SizedBox(height: 2),
              Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: activo ? FqColors.white : FqColors.night,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FqColors.night.withValues(alpha: .92),
        borderRadius: FqRadius.allMd,
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: FqColors.white,
          height: 1.3,
        ),
      ),
    );
  }
}

/// Lo ya dibujado, con una X para quitar cada trazo.
class _PanelTrazos extends StatelessWidget {
  const _PanelTrazos({
    required this.areas,
    required this.recorridos,
    required this.alQuitarArea,
    required this.alQuitarRecorrido,
  });

  final List<ZonaEvento> areas;
  final List<ZonaEvento> recorridos;
  final ValueChanged<ZonaEvento> alQuitarArea;
  final ValueChanged<ZonaEvento> alQuitarRecorrido;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (areas.isEmpty && recorridos.isEmpty) {
      return _Aviso(texto: l10n.eventoSinTrazos);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FqColors.white.withValues(alpha: .96),
        borderRadius: FqRadius.allLg,
        boxShadow: FqColors.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 120),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                for (final ZonaEvento z in areas)
                  InputChip(
                    key: ValueKey<String>('trazo-area-${z.nombre}'),
                    avatar: const Icon(
                      Icons.crop_free,
                      size: 16,
                      color: colorAreaEvento,
                    ),
                    label: Text(z.nombre),
                    onDeleted: () => alQuitarArea(z),
                    deleteButtonTooltipMessage: l10n.comunEliminar,
                  ),
                for (final ZonaEvento z in recorridos)
                  InputChip(
                    key: ValueKey<String>('trazo-recorrido-${z.nombre}'),
                    avatar: const Icon(
                      Icons.timeline,
                      size: 16,
                      color: colorRecorridoEvento,
                    ),
                    label: Text(z.nombre),
                    onDeleted: () => alQuitarRecorrido(z),
                    deleteButtonTooltipMessage: l10n.comunEliminar,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
