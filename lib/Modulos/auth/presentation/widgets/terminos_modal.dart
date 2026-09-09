import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';

/// Modal de Terminos y condiciones que se muestra desde el registro.
///
/// El texto es un contenido base: debe ser revisado y reemplazado por el
/// equipo legal antes de publicar la app.
class TerminosModal {
  const TerminosModal._();

  static Future<void> mostrar(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (_, _, _) => const _TerminosDialog(),
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
}

class _TerminosDialog extends StatelessWidget {
  const _TerminosDialog();

  static const List<(String, String)> _secciones = <(String, String)>[
    (
      '1. Aceptacion de los terminos',
      'Al crear una cuenta en FitQuest Go confirmas que has leido, entendido '
          'y aceptas estos terminos y condiciones, asi como la politica de '
          'privacidad de la aplicacion. Si no estas de acuerdo, no debes '
          'registrarte ni usar la app.',
    ),
    (
      '2. Uso de la cuenta',
      'Eres responsable de la informacion que registras y de mantener la '
          'confidencialidad de tu contrasena. FitQuest Go puede suspender o '
          'desactivar cuentas que incumplan estos terminos o que se usen de '
          'forma fraudulenta.',
    ),
    (
      '3. Ubicacion y datos de actividad',
      'Algunas funciones (rutas, alertas cercanas, mapa en vivo) requieren '
          'acceso a tu ubicacion y datos de actividad fisica. Estos datos se '
          'usan unicamente para ofrecer esas funciones y para mejorar la '
          'seguridad de la comunidad.',
    ),
    (
      '4. Contenido generado por usuarios',
      'Al publicar rutas, alertas, reportes o comentarios, garantizas que '
          'tienes derecho a compartir ese contenido y aceptas que pueda ser '
          'revisado o moderado por el equipo de FitQuest Go.',
    ),
    (
      '5. Cambios en los terminos',
      'Estos terminos pueden actualizarse. Si el cambio es sustancial, se '
          'notificara dentro de la app antes de que entre en vigor.',
    ),
    (
      '6. Contacto',
      'Para preguntas sobre estos terminos o sobre tus datos, puedes '
          'escribir al equipo de soporte de FitQuest Go.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
          child: Material(
            color: FqColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Terminos y condiciones',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: FqColors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 18),
                        color: FqColors.muted,
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: FqColors.border),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final (String titulo, String texto)
                            in _secciones)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  titulo,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: FqColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  texto,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.5,
                                    color: FqColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: FqColors.border),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FqButton.primary(
                    label: 'Entendido',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
