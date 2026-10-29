import 'package:flutter/material.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/plan_patrocinio_screen.dart';

/// Cuando alguien topa con algo que pide una suscripcion (el limite de rutas
/// sin conexion, destacar sin plan) se le dice por que y se le ofrece pedirla:
/// "Ver planes" abre la pantalla del plan. Devuelve `true` si la abrio.
Future<bool> invitarAPlan(
  BuildContext context, {
  required String mensaje,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context)!;
  final bool? ver = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(l10n.planInvitacionTitulo),
      content: Text(mensaje),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.comunCancelar),
        ),
        FilledButton(
          key: const ValueKey<String>('invitacion-ver-planes'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.planInvitacionVer),
        ),
      ],
    ),
  );
  if (ver != true || !context.mounted) return false;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const PlanPatrocinioScreen()),
  );
  return true;
}
