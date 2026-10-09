import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/admin_seccion.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/dashboard_screen.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/pantallas_lista_maqueta.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/reportes_contenido_screen.dart'
    as reportes;
import 'package:fit_quest_go/Modulos/admin/presentation/screens/revision_ruta_screen.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/alertas_admin_screen.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/nodos_admin_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/rutas_admin_screen.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/usuarios_screen.dart';

/// Registro unico de las pantallas del panel de administracion (ADM-01..ADM-13).
///
/// El sidebar y el shell se construyen a partir de esta lista. Agregar una
/// pantalla es agregar una entrada: no hay `switch` que mantener (OCP).
///
/// Es una funcion (no una lista `const`/`final` a nivel de modulo) porque el
/// texto de cada seccion esta traducido: necesita `AppLocalizations`, que solo
/// existe con un `BuildContext` a mano, asi que se arma dentro de `build()`.
List<AdminSeccion> buildAdminSecciones(AppLocalizations l10n) {
  return <AdminSeccion>[
    AdminSeccion(
      code: 'ADM-01',
      navLabel: l10n.admNavDashboard,
      headerTitle: l10n.admNavDashboard,
      descripcion: l10n.admDescDashboard,
      icono: Icons.dashboard_outlined,
      builder: (_) => const DashboardScreen(),
    ),
    AdminSeccion(
      code: 'ADM-02',
      navLabel: l10n.admNavUsuarios,
      headerTitle: l10n.admNavUsuarios,
      descripcion: l10n.admDescUsuarios,
      icono: Icons.people_outline,
      builder: (_) => const UsuariosScreen(),
    ),
    AdminSeccion(
      code: 'ADM-03',
      navLabel: l10n.admDetalleUsuarioNav,
      headerTitle: l10n.admDetalleUsuarioNav,
      descripcion: l10n.admDetalleUsuarioDesc,
      icono: Icons.badge_outlined,
      builder: (_) => FqEmptyState(
        icon: Icons.person_search_outlined,
        title: l10n.admDetalleUsuarioVacioTitulo,
        message: l10n.admDetalleUsuarioVacioMensaje(
          l10n.admNavUsuarios,
          l10n.comunVer,
        ),
      ),
    ),
    AdminSeccion(
      code: 'ADM-04',
      navLabel: l10n.admNavGestionRutas,
      headerTitle: l10n.rutasTitulo,
      descripcion: l10n.admDescGestionRutas,
      icono: Icons.route_outlined,
      builder: (_) => const RutasAdminScreen(),
    ),
    AdminSeccion(
      code: 'ADM-05',
      navLabel: l10n.admNavRevisionRuta,
      headerTitle: l10n.admNavRevisionRuta,
      descripcion: l10n.admDescRevisionRuta,
      icono: Icons.fact_check_outlined,
      builder: (_) => const RevisionRutaScreen(),
    ),
    AdminSeccion(
      code: 'ADM-06',
      navLabel: l10n.admNavGestionAlertas,
      headerTitle: l10n.admHeaderAlertasActivas,
      descripcion: l10n.admDescGestionAlertas,
      icono: Icons.warning_amber_outlined,
      builder: (_) => const AlertasAdminScreen(),
    ),
    AdminSeccion(
      code: 'ADM-07',
      navLabel: l10n.admNavGestionNodos,
      headerTitle: l10n.admHeaderNodosPois,
      descripcion: l10n.admDescGestionNodos,
      icono: Icons.location_on_outlined,
      builder: (_) => const NodosAdminScreen(),
    ),
    AdminSeccion(
      code: 'ADM-08',
      navLabel: l10n.admNavGestionEventos,
      headerTitle: l10n.comunEventos,
      descripcion: l10n.admDescGestionEventos,
      icono: Icons.event_outlined,
      builder: (_) => const EventosScreen(),
    ),
    AdminSeccion(
      code: 'ADM-09',
      navLabel: l10n.admNavGestionPatrocinadores,
      headerTitle: l10n.admHeaderPatrocinadores,
      descripcion: l10n.admDescGestionPatrocinadores,
      icono: Icons.storefront_outlined,
      builder: (_) => const PatrocinadoresScreen(),
    ),
    AdminSeccion(
      code: 'ADM-10',
      navLabel: l10n.admNavGestionInsignias,
      headerTitle: l10n.perfilInsignias,
      descripcion: l10n.admDescGestionInsignias,
      icono: Icons.military_tech_outlined,
      builder: (_) => const InsigniasScreen(),
    ),
    AdminSeccion(
      code: 'ADM-11',
      navLabel: l10n.admNavCatalogos,
      headerTitle: l10n.admNavCatalogos,
      descripcion: l10n.admDescCatalogos,
      icono: Icons.category_outlined,
      builder: (_) => const CatalogosScreen(),
    ),
    AdminSeccion(
      code: 'ADM-12',
      navLabel: l10n.admNavReportesContenido,
      headerTitle: l10n.admNavReportesContenido,
      descripcion: l10n.admDescReportesContenido,
      icono: Icons.flag_outlined,
      builder: (_) => const reportes.ReportesContenidoScreen(),
    ),
    AdminSeccion(
      code: 'ADM-13',
      navLabel: l10n.admNavAuditoria,
      headerTitle: l10n.admNavAuditoria,
      descripcion: l10n.admDescAuditoria,
      icono: Icons.history_outlined,
      builder: (_) => const AuditoriaScreen(),
    ),
  ];
}
