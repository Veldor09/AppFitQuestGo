import 'package:flutter/material.dart';

import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/widgets/editar_perfil_modal.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Modal para ver y actualizar las actividades/deportes favoritos del usuario.
/// Redirige al editor unificado de perfil en la pestaña de deportes.
class GestionarActividadesModal extends StatelessWidget {
  const GestionarActividadesModal({
    super.key,
    required this.usuario,
    this.api,
  });

  final Usuario usuario;
  final PerfilApi? api;

  static const List<(String, IconData)> opciones = EditarPerfilModal.opcionesActividades;

  static Future<bool?> abrir(
    BuildContext context, {
    required Usuario usuario,
    PerfilApi? api,
  }) {
    return EditarPerfilModal.abrir(
      context,
      usuario: usuario,
      api: api,
      initialTab: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return EditarPerfilModal(
      usuario: usuario,
      api: api,
      initialTab: 1,
    );
  }
}
