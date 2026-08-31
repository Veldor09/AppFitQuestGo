import 'package:flutter/widgets.dart';

import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_lista_maqueta.dart';

/// Pantallas de lista del panel de administracion que todavia no tienen backend.
///
/// Cada una reproduce la estructura completa de su diseno (buscador, filtros,
/// pestanas de estado y tabla) mediante [AdminListaMaqueta], con la tabla en
/// estado vacio para no inventar datos.

/// ADM-04 · Gestion de rutas.
class RutasScreen extends StatelessWidget {
  const RutasScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminListaMaqueta(
        searchHint: 'Buscar en rutas',
        emptyTitle: 'Sin rutas en la cola',
        emptyMessage:
            'Las rutas enviadas a moderacion apareceran aqui para revisarlas.',
      );
}

/// ADM-06 · Gestion de alertas.
class AlertasScreen extends StatelessWidget {
  const AlertasScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminListaMaqueta(
        searchHint: 'Buscar en alertas activas',
        emptyTitle: 'Sin alertas activas',
        emptyMessage:
            'Los reportes comunitarios en vivo se listaran aqui en tiempo real.',
      );
}

/// ADM-07 · Gestion de nodos / POIs.
class NodosScreen extends StatelessWidget {
  const NodosScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminListaMaqueta(
        searchHint: 'Buscar en nodos / pois',
        emptyTitle: 'Sin puntos propuestos',
        emptyMessage:
            'Los puntos de interes propuestos por la comunidad llegaran aqui.',
      );
}

/// ADM-08 · Gestion de eventos.
class EventosScreen extends StatelessWidget {
  const EventosScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminListaMaqueta(
        searchHint: 'Buscar en eventos',
        emptyTitle: 'Sin eventos por aprobar',
        emptyMessage:
            'Eventos y retos patrocinados pendientes de aprobacion se veran aqui.',
      );
}

/// ADM-09 · Gestion de patrocinadores.
class PatrocinadoresScreen extends StatelessWidget {
  const PatrocinadoresScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminListaMaqueta(
        searchHint: 'Buscar en patrocinadores',
        emptyTitle: 'Sin cuentas comerciales',
        emptyMessage:
            'Las cuentas de patrocinador para verificar o supervisar iran aqui.',
      );
}

/// ADM-10 · Gestion de insignias.
class InsigniasScreen extends StatelessWidget {
  const InsigniasScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminListaMaqueta(
        searchHint: 'Buscar en insignias',
        emptyTitle: 'Sin insignias configuradas',
        emptyMessage:
            'Crea reglas de gamificacion para que aparezcan en este listado.',
        nuevoLabel: 'Nuevo',
      );
}

/// ADM-11 · Catalogos.
class CatalogosScreen extends StatelessWidget {
  const CatalogosScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminListaMaqueta(
        searchHint: 'Buscar en catalogos',
        emptyTitle: 'Sin catalogos',
        emptyMessage:
            'Tipos de alerta, categorias de nodo y actividades se administran aqui.',
        nuevoLabel: 'Nuevo',
      );
}

/// ADM-12 · Reportes de contenido.
class ReportesContenidoScreen extends StatelessWidget {
  const ReportesContenidoScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminListaMaqueta(
        searchHint: 'Buscar en reportes de contenido',
        emptyTitle: 'Sin denuncias',
        emptyMessage:
            'Las denuncias sobre rutas, nodos, alertas o eventos se moderan aqui.',
      );
}

/// ADM-13 · Auditoria.
class AuditoriaScreen extends StatelessWidget {
  const AuditoriaScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminListaMaqueta(
        searchHint: 'Buscar en auditoria',
        emptyTitle: 'Sin registros de auditoria',
        emptyMessage:
            'Cada decision administrativa quedara trazada en esta bitacora.',
      );
}
