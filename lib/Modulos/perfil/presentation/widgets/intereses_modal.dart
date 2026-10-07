import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/seleccion_widgets.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Modal para ver y actualizar exclusivamente los intereses de personalización del usuario.
class GestionarInteresesModal extends StatefulWidget {
  const GestionarInteresesModal({
    super.key,
    required this.usuario,
    this.api,
  });

  final Usuario usuario;
  final PerfilApi? api;

  static const List<String> opciones = <String>[
    'Rutas nuevas',
    'Eventos',
    'Retos',
    'Naturaleza',
    'Cultura',
    'Comunidad',
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
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => GestionarInteresesModal(
        usuario: usuario,
        api: api,
      ),
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
  State<GestionarInteresesModal> createState() =>
      _GestionarInteresesModalState();
}

class _GestionarInteresesModalState extends State<GestionarInteresesModal> {
  late final PerfilApi _api = widget.api ?? PerfilApi();
  late final Set<String> _intereses =
      Set<String>.from(widget.usuario.intereses);
  bool _guardando = false;

  void _cerrar([bool cambio = false]) => Navigator.of(context).pop(cambio);

  void _toggleInteres(String interes) {
    setState(() {
      if (_intereses.contains(interes)) {
        _intereses.remove(interes);
      } else {
        _intereses.add(interes);
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
        intereses: _intereses.toList(),
      );
      if (!mounted) return;
      notificarExito('Intereses actualizados correctamente');
      _cerrar(true);
    } on ApiException catch (e) {
      if (mounted) notificarError(e.message);
    } catch (_) {
      if (mounted) {
        notificarError('No se pudo actualizar los intereses. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: FqColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            elevation: 14,
            shadowColor: Colors.black45,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Encabezado
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF3EB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.interests_rounded,
                          size: 22,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const <Widget>[
                            Text(
                              'Mis intereses',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: FqColors.ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Elige lo que más te motiva explorar',
                              style: TextStyle(
                                fontSize: 12,
                                color: FqColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
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
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: FqColors.border),
                  const SizedBox(height: 14),
                  const Text(
                    'Selecciona tus temas de interés para descubrir rutas, eventos y contenidos a tu medida:',
                    style: TextStyle(fontSize: 12, color: FqColors.ink, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String opcion
                          in GestionarInteresesModal.opciones)
                        SelectableChip(
                          label: opcion,
                          selected: _intereses.contains(opcion),
                          onTap: () => _toggleInteres(opcion),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: FqColors.border),
                  const SizedBox(height: 14),
                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      FqButton.ghost(
                        label: 'Cancelar',
                        expand: false,
                        onPressed: _guardando ? null : () => _cerrar(),
                      ),
                      const SizedBox(width: 10),
                      FqButton.primary(
                        label: 'Guardar cambios',
                        icon: Icons.check_rounded,
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
