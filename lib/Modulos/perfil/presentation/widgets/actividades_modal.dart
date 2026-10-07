import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Modal para ver y actualizar exclusivamente las actividades y deportes favoritos del usuario.
class GestionarActividadesModal extends StatefulWidget {
  const GestionarActividadesModal({
    super.key,
    required this.usuario,
    this.api,
  });

  final Usuario usuario;
  final PerfilApi? api;

  static const List<(String, IconData)> opciones = <(String, IconData)>[
    ('Running', Icons.directions_run_rounded),
    ('Ciclismo', Icons.directions_bike_rounded),
    ('MTB', Icons.pedal_bike_rounded),
    ('Hiking', Icons.hiking_rounded),
    ('Caminata', Icons.directions_walk_rounded),
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
      pageBuilder: (_, _, _) => GestionarActividadesModal(
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
  State<GestionarActividadesModal> createState() =>
      _GestionarActividadesModalState();
}

class _GestionarActividadesModalState extends State<GestionarActividadesModal> {
  late final PerfilApi _api = widget.api ?? PerfilApi();
  late final Set<String> _actividades =
      Set<String>.from(widget.usuario.actividades);
  bool _guardando = false;

  void _cerrar([bool cambio = false]) => Navigator.of(context).pop(cambio);

  void _toggleActividad(String act) {
    setState(() {
      if (_actividades.contains(act)) {
        _actividades.remove(act);
      } else {
        _actividades.add(act);
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
        actividades: _actividades.toList(),
      );
      if (!mounted) return;
      notificarExito('Actividades actualizadas correctamente');
      _cerrar(true);
    } on ApiException catch (e) {
      if (mounted) notificarError(e.message);
    } catch (_) {
      if (mounted) {
        notificarError('No se pudo actualizar las actividades. Revisa tu conexión.');
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
                  // Cabecera
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const <Widget>[
                            Text(
                              'Mis actividades favoritas',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: FqColors.ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Deportes y disciplinas que practicas',
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
                    'Selecciona tus actividades para personalizar tus recomendaciones de rutas y retos:',
                    style: TextStyle(fontSize: 12, color: FqColors.ink, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final (String label, IconData icon)
                          in GestionarActividadesModal.opciones)
                        _ChipDeporte(
                          icon: icon,
                          label: label,
                          selected: _actividades.contains(label),
                          onTap: () => _toggleActividad(label),
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

class _ChipDeporte extends StatelessWidget {
  const _ChipDeporte({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE0F2FE) : const Color(0xFFF6F8F5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF0284C7) : const Color(0xFFDCE2DA),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected ? const Color(0xFF0369A1) : FqColors.ink,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? const Color(0xFF0369A1) : FqColors.ink,
                ),
              ),
              if (selected) ...<Widget>[
                const SizedBox(width: 6),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: Color(0xFF0284C7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
