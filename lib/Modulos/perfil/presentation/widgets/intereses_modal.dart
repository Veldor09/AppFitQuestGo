import 'package:flutter/material.dart';

import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/widgets/editar_perfil_modal.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Modal para ver y actualizar los intereses de personalización del usuario.
/// Redirige al editor unificado de perfil en la pestaña de intereses.
class GestionarInteresesModal extends StatelessWidget {
  const GestionarInteresesModal({
    super.key,
    required this.usuario,
    this.api,
  });

  final Usuario usuario;
  final PerfilApi? api;

  static const List<String> opciones = EditarPerfilModal.opcionesIntereses;

  static Future<bool?> abrir(
    BuildContext context, {
    required Usuario usuario,
    PerfilApi? api,
  }) {
    return EditarPerfilModal.abrir(
      context,
      usuario: usuario,
      api: api,
      initialTab: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return EditarPerfilModal(
      usuario: usuario,
      api: api,
      initialTab: 2,
    );
  }
}
