import 'package:flutter/widgets.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_lista_maqueta.dart';

/// Pantallas de lista del panel de administracion que todavia no tienen backend.
///
/// Cada una reproduce la estructura completa de su diseno (buscador, filtros,
/// pestanas de estado y tabla) mediante [AdminListaMaqueta], con la tabla en
/// estado vacio para no inventar datos.

/// ADM-08 · Gestion de eventos.
class EventosScreen extends StatelessWidget {
  const EventosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return AdminListaMaqueta(
      searchHint: l10n.admEventosSearchHint,
      emptyTitle: l10n.admEventosVacioTitulo,
      emptyMessage: l10n.admEventosVacioMensaje,
    );
  }
}

/// ADM-09 · Gestion de patrocinadores.
class PatrocinadoresScreen extends StatelessWidget {
  const PatrocinadoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return AdminListaMaqueta(
      searchHint: l10n.admPatrocinadoresSearchHint,
      emptyTitle: l10n.admPatrocinadoresVacioTitulo,
      emptyMessage: l10n.admPatrocinadoresVacioMensaje,
    );
  }
}

/// ADM-10 · Gestion de insignias.
class InsigniasScreen extends StatelessWidget {
  const InsigniasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return AdminListaMaqueta(
      searchHint: l10n.admInsigniasSearchHint,
      emptyTitle: l10n.admInsigniasVacioTitulo,
      emptyMessage: l10n.admInsigniasVacioMensaje,
      nuevoLabel: l10n.comunNuevo,
    );
  }
}

/// ADM-11 · Catalogos.
class CatalogosScreen extends StatelessWidget {
  const CatalogosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return AdminListaMaqueta(
      searchHint: l10n.admCatalogosSearchHint,
      emptyTitle: l10n.admCatalogosVacioTitulo,
      emptyMessage: l10n.admCatalogosVacioMensaje,
      nuevoLabel: l10n.comunNuevo,
    );
  }
}

/// ADM-12 · Reportes de contenido.
class ReportesContenidoScreen extends StatelessWidget {
  const ReportesContenidoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return AdminListaMaqueta(
      searchHint: l10n.admReportesSearchHint,
      emptyTitle: l10n.admReportesVacioTitulo,
      emptyMessage: l10n.admReportesVacioMensaje,
    );
  }
}

/// ADM-13 · Auditoria.
class AuditoriaScreen extends StatelessWidget {
  const AuditoriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return AdminListaMaqueta(
      searchHint: l10n.admAuditoriaSearchHint,
      emptyTitle: l10n.admAuditoriaVacioTitulo,
      emptyMessage: l10n.admAuditoriaVacioMensaje,
    );
  }
}
