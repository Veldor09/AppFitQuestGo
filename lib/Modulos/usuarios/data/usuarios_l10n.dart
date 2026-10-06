import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Traduce los valores fijos del modelo `Usuario` (rol por `idrol`, estado de
/// cuenta) para mostrar en pantalla. El id/valor estable que viaja por la red
/// y se usa en comparaciones nunca cambia; solo el texto que ve el usuario.

String rolLabel(AppLocalizations l10n, int idrol) {
  switch (idrol) {
    case 2:
      return l10n.rolEmpresa;
    case 3:
      return l10n.rolAdmin;
    default:
      return l10n.rolUsuario;
  }
}

String estadoUsuarioLabel(AppLocalizations l10n, String estado) {
  switch (estado) {
    case 'Desactivado':
      return l10n.estadoUsuarioDesactivado;
    default:
      return l10n.estadoUsuarioActivado;
  }
}
