import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';

Future<bool> confirmarYEliminarRuta(
  BuildContext context,
  RutaApi api,
  Ruta ruta,
) async {
  final AppLocalizations l10n = AppLocalizations.of(context)!;
  final bool? confirmado = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      key: const ValueKey<String>('confirmar-eliminar-ruta'),
      title: Text(l10n.rutasEliminarTitulo),
      content: Text(l10n.rutasEliminarMensaje(ruta.nombre)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.comunCancelar),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.rutasEliminar),
        ),
      ],
    ),
  );
  if (confirmado != true) return false;
  try {
    await api.eliminar(ruta.id);
    notificarExito(l10n.rutasEliminada);
    return true;
  } catch (_) {
    notificarError(l10n.rutasNoSePudoEliminar);
    return false;
  }
}
