import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/Modulos/admin/data/admin_seccion.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/dashboard_screen.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/pantallas_lista_maqueta.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/revision_ruta_screen.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/usuarios_screen.dart';

/// Registro unico de las pantallas del panel de administracion (ADM-01..ADM-13).
///
/// El sidebar y el shell se construyen a partir de esta lista. Agregar una
/// pantalla es agregar una entrada: no hay `switch` que mantener (OCP).
final List<AdminSeccion> adminSecciones = <AdminSeccion>[
  AdminSeccion(
    code: 'ADM-01',
    navLabel: 'Dashboard',
    headerTitle: 'Dashboard',
    descripcion: 'Estado general y colas del sistema.',
    icono: Icons.dashboard_outlined,
    builder: (_) => const DashboardScreen(),
  ),
  AdminSeccion(
    code: 'ADM-02',
    navLabel: 'Usuarios',
    headerTitle: 'Usuarios',
    descripcion: 'Buscar y gestionar cuentas.',
    icono: Icons.people_outline,
    builder: (_) => const UsuariosScreen(),
  ),
  AdminSeccion(
    code: 'ADM-03',
    navLabel: 'Detalle de usuario',
    headerTitle: 'Detalle de usuario',
    descripcion: 'Revisar historial, aportes y reportes.',
    icono: Icons.badge_outlined,
    builder: (_) => const FqEmptyState(
      icon: Icons.person_search_outlined,
      title: 'Elige un usuario',
      message:
          'Abre la seccion "Usuarios" y pulsa "Ver" en una cuenta para revisar '
          'su detalle.',
    ),
  ),
  AdminSeccion(
    code: 'ADM-04',
    navLabel: 'Gestion de rutas',
    headerTitle: 'Rutas',
    descripcion: 'Administrar la cola de moderacion de rutas.',
    icono: Icons.route_outlined,
    builder: (_) => const RutasScreen(),
  ),
  AdminSeccion(
    code: 'ADM-05',
    navLabel: 'Revision de ruta',
    headerTitle: 'Revision de ruta',
    descripcion: 'Aprobar, pedir correccion o rechazar con motivo.',
    icono: Icons.fact_check_outlined,
    builder: (_) => const RevisionRutaScreen(),
  ),
  AdminSeccion(
    code: 'ADM-06',
    navLabel: 'Gestion de alertas',
    headerTitle: 'Alertas activas',
    descripcion: 'Supervisar reportes comunitarios en vivo.',
    icono: Icons.warning_amber_outlined,
    builder: (_) => const AlertasScreen(),
  ),
  AdminSeccion(
    code: 'ADM-07',
    navLabel: 'Gestion de nodos',
    headerTitle: 'Nodos / POIs',
    descripcion: 'Revisar puntos de interes propuestos.',
    icono: Icons.location_on_outlined,
    builder: (_) => const NodosScreen(),
  ),
  AdminSeccion(
    code: 'ADM-08',
    navLabel: 'Gestion de eventos',
    headerTitle: 'Eventos',
    descripcion: 'Aprobar eventos y retos patrocinados.',
    icono: Icons.event_outlined,
    builder: (_) => const EventosScreen(),
  ),
  AdminSeccion(
    code: 'ADM-09',
    navLabel: 'Gestion de patrocinadores',
    headerTitle: 'Patrocinadores',
    descripcion: 'Verificar y supervisar cuentas comerciales.',
    icono: Icons.storefront_outlined,
    builder: (_) => const PatrocinadoresScreen(),
  ),
  AdminSeccion(
    code: 'ADM-10',
    navLabel: 'Gestion de insignias',
    headerTitle: 'Insignias',
    descripcion: 'Crear y configurar reglas de gamificacion.',
    icono: Icons.military_tech_outlined,
    builder: (_) => const InsigniasScreen(),
  ),
  AdminSeccion(
    code: 'ADM-11',
    navLabel: 'Catalogos',
    headerTitle: 'Catalogos',
    descripcion: 'Mantener tipos de alerta, categorias y actividades.',
    icono: Icons.category_outlined,
    builder: (_) => const CatalogosScreen(),
  ),
  AdminSeccion(
    code: 'ADM-12',
    navLabel: 'Reportes de contenido',
    headerTitle: 'Reportes de contenido',
    descripcion: 'Moderar denuncias sobre cualquier publicacion.',
    icono: Icons.flag_outlined,
    builder: (_) => const ReportesContenidoScreen(),
  ),
  AdminSeccion(
    code: 'ADM-13',
    navLabel: 'Auditoria',
    headerTitle: 'Auditoria',
    descripcion: 'Consultar trazabilidad de decisiones.',
    icono: Icons.history_outlined,
    builder: (_) => const AuditoriaScreen(),
  ),
];
