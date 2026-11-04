import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/Modulos/admin/data/catalogos_api.dart';
import 'package:fit_quest_go/Modulos/rutas/application/metricas_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/planificar_ruta_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/selector_actividades_catalogo.dart';
import 'package:fit_quest_go/core/fotos/selector_foto.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/campo_foto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_icono_dificultad.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Pantalla para editar una ruta propia: permite modificar nombre,
/// actividades deportivas, dificultad, visibilidad, foto de portada y
/// retocar o redibujar el trazo en el mapa.
class EditarRutaScreen extends StatefulWidget {
  const EditarRutaScreen({
    super.key,
    required this.ruta,
    this.api,
    this.catalogosApi,
    this.selectorFoto,
    this.accessToken,
  });

  final Ruta ruta;
  final RutaApi? api;
  final CatalogosApi? catalogosApi;
  final SelectorFoto? selectorFoto;
  final String? accessToken;

  @override
  State<EditarRutaScreen> createState() => _EditarRutaScreenState();
}

class _EditarRutaScreenState extends State<EditarRutaScreen> {
  late final RutaApi _api = widget.api ?? RutaApi();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreController = TextEditingController(
    text: widget.ruta.nombre,
  );
  late Set<String> _actividades = Set<String>.of(widget.ruta.actividades);
  late String _dificultad = widget.ruta.dificultad;
  late String _visibilidad =
      widget.ruta.estado == 'Publicada' ? 'publica' : 'privada';
  late List<PuntoRuta> _puntos = List<PuntoRuta>.of(widget.ruta.puntos);

  Uint8List? _fotoNueva;
  bool _guardando = false;
  bool _catalogoDisponible = true;
  String? _errorActividades;

  double get _distanciaKm => distanciaTrazoKm(_puntos);

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _abrirEditorTrazo() async {
    final List<PuntoRuta>? puntosModificados =
        await Navigator.of(context).push<List<PuntoRuta>>(
          MaterialPageRoute<List<PuntoRuta>>(
            builder: (BuildContext _) => PlanificarRutaScreen(
              puntosIniciales: _puntos,
              modoSeleccionarTrazo: true,
              api: _api,
              catalogosApi: widget.catalogosApi,
              selectorFoto: widget.selectorFoto,
              accessToken: widget.accessToken,
            ),
          ),
        );

    if (puntosModificados != null && mounted) {
      setState(() => _puntos = puntosModificados);
      final AppLocalizations l10n = AppLocalizations.of(context)!;
      notificarInfo(
        l10n.planificarPuntosYDistancia(
          _puntos.length,
          _distanciaKm.toStringAsFixed(2),
        ),
      );
    }
  }

  Future<void> _guardar() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) return;

    if (_actividades.isEmpty) {
      setState(
        () => _errorActividades = l10n.rutasActividades,
      );
      notificarError('Selecciona al menos una actividad.');
      return;
    }

    if (_puntos.length < 2) {
      notificarError('La ruta debe contener al menos 2 puntos en el trazo.');
      return;
    }

    setState(() => _guardando = true);

    try {
      final Ruta actualizada = await _api.actualizar(
        id: widget.ruta.id,
        nombre: _nombreController.text.trim(),
        actividades: _actividades.toList(),
        dificultad: _dificultad,
        distanciaKm: _distanciaKm,
        puntos: _puntos,
        visibilidad: _visibilidad,
      );

      if (_fotoNueva != null) {
        try {
          await _api.subirFoto(widget.ruta.id, _fotoNueva!);
        } catch (_) {
          notificarError(l10n.fotoNoSubida);
        }
      }

      if (!mounted) return;
      notificarExito('Ruta actualizada con éxito');
      Navigator.of(context).pop(actualizada);
    } catch (_) {
      if (mounted) {
        notificarError(l10n.planificarNoSePudoGuardar);
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: FqColors.paper,
      appBar: AppBar(
        backgroundColor: FqColors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Editar ruta',
          style: TextStyle(
            color: FqColors.night,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: FqColors.night),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          children: <Widget>[
            // Foto de la ruta
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FqColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FqColors.border),
              ),
              child: CampoFoto(
                foto: _fotoNueva,
                yaTiene: widget.ruta.conFoto,
                selector: widget.selectorFoto,
                alCambiar: (Uint8List? f) => setState(() => _fotoNueva = f),
              ),
            ),
            const SizedBox(height: 14),

            // Tarjeta de datos principales
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FqColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FqColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: l10n.comunNombre,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (String? v) => (v == null || v.trim().isEmpty)
                        ? l10n.comunObligatorio
                        : null,
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: _dificultad,
                    decoration: InputDecoration(
                      labelText: l10n.rutasDificultadLabel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'facil',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const IconoDificultad(
                              dificultad: 'facil',
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(dificultadLabel(l10n, 'facil')),
                          ],
                        ),
                      ),
                      DropdownMenuItem<String>(
                        value: 'moderada',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const IconoDificultad(
                              dificultad: 'moderada',
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(dificultadLabel(l10n, 'moderada')),
                          ],
                        ),
                      ),
                      DropdownMenuItem<String>(
                        value: 'dificil',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const IconoDificultad(
                              dificultad: 'dificil',
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(dificultadLabel(l10n, 'dificil')),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (String? v) {
                      if (v != null) setState(() => _dificultad = v);
                    },
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: _visibilidad,
                    decoration: InputDecoration(
                      labelText: l10n.rutasVisibilidadLabel,
                      helperText: l10n.rutasVisibilidadHelper,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'privada',
                        child: Text(l10n.rutasVisibilidadPrivada),
                      ),
                      DropdownMenuItem<String>(
                        value: 'publica',
                        child: Text(l10n.rutasVisibilidadPublica),
                      ),
                    ],
                    onChanged: (String? v) {
                      if (v != null) setState(() => _visibilidad = v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Selector de Actividades
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FqColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FqColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.rutasActividades,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FqColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectorActividadesCatalogo(
                    seleccion: _actividades,
                    errorTexto: _errorActividades,
                    catalogosApi: widget.catalogosApi,
                    onEstadoCarga: (bool disponible) {
                      setState(() => _catalogoDisponible = disponible);
                    },
                    onChanged: (Set<String> nuevas) {
                      setState(() {
                        _actividades = nuevas;
                        if (nuevas.isNotEmpty) _errorActividades = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tarjeta de Trazado de Ruta y modificación en mapa
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FqColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FqColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FqColors.volt.withValues(alpha: .25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          color: FqColors.night,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Trazado de la ruta',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: FqColors.night,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Puedes ver o ajustar el recorrido sobre el mapa',
                              style: TextStyle(
                                fontSize: 11,
                                color: FqColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: FqColors.paper,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                l10n.rutasDistancia,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: FqColors.muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_distanciaKm.toStringAsFixed(2)} km',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: FqColors.night,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: FqColors.paper,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Puntos',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: FqColors.muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_puntos.length} puntos',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: FqColors.night,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: FqColors.night, width: 1.5),
                    ),
                    icon: const Icon(
                      Icons.edit_location_alt_rounded,
                      size: 18,
                      color: FqColors.night,
                    ),
                    label: const Text(
                      'Modificar trazo en el mapa',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: FqColors.night,
                      ),
                    ),
                    onPressed: _abrirEditorTrazo,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botón Guardar cambios
            FqButton.primary(
              label: _guardando ? l10n.comunGuardando : 'Guardar cambios',
              onPressed: (!_catalogoDisponible || _guardando) ? null : _guardar,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
