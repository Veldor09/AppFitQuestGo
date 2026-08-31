import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_brand_mark.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';

/// Destino de una cuenta autenticada que NO es Admin.
///
/// La experiencia principal de la app movil (mapa vivo, rutas, tracking...) esta
/// fuera del alcance de esta entrega; aqui se confirma la sesion y se permite
/// cerrarla. El panel de administracion solo es accesible con rol Admin.
class HomeUsuarioScreen extends StatelessWidget {
  const HomeUsuarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UsuarioSesion? u = AuthScope.of(context).usuario;

    return Scaffold(
      backgroundColor: FqColors.paper,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kAuthContentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const FqBrandMark(size: 60),
                const SizedBox(height: 18),
                Text(
                  u == null ? 'Sesion iniciada' : 'Hola, ${_nombre(u)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: FqColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu cuenta quedo activa. La experiencia movil (mapa, rutas y '
                  'tracking) aun no forma parte de esta entrega.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.55,
                    color: FqColors.muted,
                  ),
                ),
                if (u != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    '${u.email}  ·  rol ${u.etiquetaRol}',
                    style: const TextStyle(fontSize: 10, color: FqColors.muted),
                  ),
                ],
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 200),
                  child: FqButton.secondary(
                    label: 'Cerrar sesion',
                    expand: false,
                    onPressed: () => AuthScope.read(context).cerrarSesion(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _nombre(UsuarioSesion u) =>
      u.nombre.isNotEmpty ? u.nombre.split(' ').first : u.email.split('@').first;
}
