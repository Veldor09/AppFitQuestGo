import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/seleccion_widgets.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Modal para ver y actualizar las actividades/deportes favoritos del usuario (APP-05).
class GestionarActividadesModal extends StatefulWidget {
  const GestionarActividadesModal({
    super.key,
    required this.usuario,
    this.api,
  });

  final Usuario usuario;
  final PerfilApi? api;

  static const List<(String, IconData)> opciones = <(String, IconData)>[
    ('Running', Icons.directions_run),
    ('Ciclismo', Icons.directions_bike),
    ('MTB', Icons.pedal_bike),
    ('Hiking', Icons.hiking),
    ('Caminata', Icons.directions_walk),
  ];

  static Future<bool?> abrir(
    BuildContext context, {
    required Usuario usuario,
    PerfilApi? api,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (_, _, _) => GestionarActividadesModal(usuario: usuario, api: api),
      transitionBuilder: (_, Animation<double> anim, _, Widget child) {
        final double t = Curves.easeOutCubic.transform(anim.value);
        return FadeTransition(
          opacity: anim,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: ColoredBox(
              color: const Color(0x5A0B1220),
              child: Transform.scale(scale: 0.95 + 0.05 * t, child: child),
            ),
          ),
        );
      },
    );
  }

  @override
  State<GestionarActividadesModal> createState() => _GestionarActividadesModalState();
}

class _GestionarActividadesModalState extends State<GestionarActividadesModal> {
  late final PerfilApi _api = widget.api ?? PerfilApi();
  late final Set<String> _seleccion = Set<String>.from(widget.usuario.actividades);
  bool _guardando = false;

  void _cerrar([bool cambio = false]) => Navigator.of(context).pop(cambio);

  void _toggle(String actividad) {
    setState(() {
      if (_seleccion.contains(actividad)) {
        _seleccion.remove(actividad);
      } else {
        _seleccion.add(actividad);
      }
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await _api.actualizarPerfil(
        id: widget.usuario.id,
        nombreUser: widget.usuario.nombreUser,
        emailUser: widget.usuario.emailUser,
        actividades: _seleccion.toList(),
      );
      if (!mounted) return;
      notificarExito('Actividades actualizadas');
      _cerrar(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      notificarError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      notificarError('No se pudo guardar. Revisa tu conexión.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: FqColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            elevation: 12,
            shadowColor: Colors.black45,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          size: 22,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Actividades favoritas',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: FqColors.ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Deportes y disciplinas que practicas',
                              style: TextStyle(fontSize: 11, color: FqColors.muted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _cerrar(),
                        icon: const Icon(Icons.close, size: 20),
                        color: FqColors.muted,
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: FqColors.border),
                  const SizedBox(height: 16),
                  const Text(
                    '¿Qué actividades practicas?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FqColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      const double gap = 8;
                      final double itemW = (c.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: <Widget>[
                          for (final (String label, IconData icon) in GestionarActividadesModal.opciones)
                            SizedBox(
                              width: itemW,
                              child: ChoiceOption(
                                icon: icon,
                                label: label,
                                selected: _seleccion.contains(label),
                                onTap: () => _toggle(label),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      FqButton.ghost(
                        label: 'Cancelar',
                        expand: false,
                        onPressed: _guardando ? null : () => _cerrar(),
                      ),
                      const SizedBox(width: 8),
                      FqButton.primary(
                        label: 'Guardar actividades',
                        expand: false,
                        loading: _guardando,
                        onPressed: _guardando ? null : _guardar,
                      ),
                    ],
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
