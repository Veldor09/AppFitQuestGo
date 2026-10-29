import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/widgets/foto_remota.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

class FotoNodo extends StatelessWidget {
  const FotoNodo({
    super.key,
    required this.api,
    required this.nodoId,
    this.altura = 200,
    this.titulo,
    this.alReportar,
  });

  final NodoApi api;
  final int nodoId;
  final double altura;

  final String? titulo;

  final VoidCallback? alReportar;

  @override
  Widget build(BuildContext context) {
    return FotoRemota(
      cargar: () => api.foto(nodoId),
      altura: altura,
      titulo: titulo,
      alReportar: alReportar,
      llave: const ValueKey<String>('foto-nodo'),
    );
  }
}
