import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/seleccion_widgets.dart';

/// APP-05 · Registro · Actividades. Seleccion multiple de deportes.
/// Presentacion pura: el estado lo mantiene `RegistroFlujoScreen`.
///
/// `seleccion`/`onToggle` viajan por clave estable (las de `actividadesRuta`),
/// no por el texto visible: el texto se traduce, la clave no, para que el valor
/// guardado no cambie segun el idioma del usuario. Es el mismo catalogo que usa
/// el formulario de guardar una ruta; aqui no se ofrece "otro".
class PasoActividades extends StatelessWidget {
  const PasoActividades({
    super.key,
    required this.seleccion,
    required this.onToggle,
  });

  final Set<String> seleccion;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PasoIntro(
          titulo: l10n.registroActividadesTitulo,
          bajada: l10n.registroActividadesBajada,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            const double gap = 8;
            final double itemW = (c.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final OpcionCatalogo opcion in actividadesRuta)
                  if (opcion.clave != claveOtro)
                    SizedBox(
                      width: itemW,
                      child: ChoiceOption(
                        icon: opcion.icono,
                        label: actividadLabel(l10n, opcion.clave),
                        selected: seleccion.contains(opcion.clave),
                        onTap: () => onToggle(opcion.clave),
                      ),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}
