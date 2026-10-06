import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Traduce los valores fijos que vienen del backend (enum `EstadoRuta`) o de
/// los selectores de dificultad/gravedad, siempre en minuscula/valor estable.
/// El valor que viaja por la red y el que se compara en codigo nunca cambia;
/// solo el texto que ve el usuario se traduce.

String estadoRutaLabel(AppLocalizations l10n, String estado) {
  switch (estado) {
    case 'Privada':
      return l10n.estadoRutaPrivada;
    case 'Pendiente':
      return l10n.estadoRutaPendiente;
    case 'Publicada':
      return l10n.estadoRutaPublicada;
    case 'Rechazada':
      return l10n.estadoRutaRechazada;
    default:
      return estado;
  }
}

String dificultadLabel(AppLocalizations l10n, String dificultad) {
  switch (dificultad) {
    case 'facil':
      return l10n.dificultadFacil;
    case 'dificil':
      return l10n.dificultadDificil;
    default:
      return l10n.dificultadModerada;
  }
}

String gravedadLabel(AppLocalizations l10n, String gravedad) {
  switch (gravedad) {
    case 'baja':
      return l10n.gravedadBaja;
    case 'alta':
      return l10n.gravedadAlta;
    default:
      return l10n.gravedadMedia;
  }
}
