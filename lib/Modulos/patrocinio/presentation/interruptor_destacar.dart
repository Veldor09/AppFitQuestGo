import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// El mensaje para quien intento encender "Destacar" y el servidor lo rechazo:
/// el codigo viaja en `ApiException.message` (ver `DestacadosService`).
String mensajeErrorDestacar(AppLocalizations l10n, ApiException e) {
  return switch (e.message) {
    'DESTACAR_SIN_PLAN' => l10n.patrocinioSinPlan,
    'DESTACAR_TOPE' => l10n.patrocinioTope,
    'DESTACAR_NO_ELEGIBLE' => l10n.patrocinioNoElegible,
    _ => l10n.patrocinioErrorDestacar,
  };
}

/// El interruptor "Destacar en el mapa" del dueno. [alCambiar] pide el cambio al
/// servidor y devuelve como quedo; si lanza, el interruptor vuelve a como
/// estaba y se avisa por que.
class InterruptorDestacar extends StatefulWidget {
  const InterruptorDestacar({
    super.key,
    required this.activado,
    required this.alCambiar,
    this.compacto = false,
  });

  /// Sin el texto (queda como ayuda del interruptor): para filas angostas.
  final bool compacto;
  final bool activado;
  final Future<bool> Function(bool destacar) alCambiar;

  @override
  State<InterruptorDestacar> createState() => _InterruptorDestacarState();
}

class _InterruptorDestacarState extends State<InterruptorDestacar> {
  late bool _activado = widget.activado;
  bool _esperando = false;

  @override
  void didUpdateWidget(covariant InterruptorDestacar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo si el valor de origen cambio de verdad (la lista se recargo).
    if (oldWidget.activado != widget.activado) _activado = widget.activado;
  }

  Future<void> _cambiar(bool destacar) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() => _esperando = true);
    try {
      final bool resultado = await widget.alCambiar(destacar);
      if (mounted) setState(() => _activado = resultado);
    } on ApiException catch (e) {
      notificarError(mensajeErrorDestacar(l10n, e));
    } catch (_) {
      notificarError(l10n.patrocinioErrorDestacar);
    } finally {
      if (mounted) setState(() => _esperando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.star_rounded, size: 18, color: FqColors.amber),
        const SizedBox(width: 6),
        if (!widget.compacto)
          Flexible(
            child: Text(
              l10n.patrocinioDestacar,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(width: 4),
        Tooltip(
          message: l10n.patrocinioDestacar,
          child: Switch(
            key: const ValueKey<String>('interruptor-destacar'),
            value: _activado,
            onChanged: _esperando ? null : _cambiar,
          ),
        ),
      ],
    );
  }
}
