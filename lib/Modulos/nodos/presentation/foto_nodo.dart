import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/widgets/foto_remota.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

/// Foto de un nodo (`GET /nodos/:id/foto`): ver [FotoRemota]. Al tocarla se abre
/// a pantalla completa.
class FotoNodo extends StatelessWidget {
  const FotoNodo({
    super.key,
    required this.api,
    required this.nodoId,
    this.altura = 200,
    this.titulo,
  });

  final NodoApi api;
  final int nodoId;
  final double altura;

  /// Se muestra al pie de la imagen a pantalla completa (el nombre del punto).
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    return FotoRemota(
      cargar: () => api.foto(nodoId),
      altura: altura,
      titulo: titulo,
      llave: const ValueKey<String>('foto-nodo'),
    );
  }
}
