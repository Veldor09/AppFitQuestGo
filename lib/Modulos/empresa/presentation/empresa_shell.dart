import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/cuenta_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mapa_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mis_eventos_screen.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mis_nodos_screen.dart';

/// Panel unico de una cuenta de empresa (rol Empresa): el mapa con sus eventos
/// (pantalla principal), la lista de eventos, sus nodos y su cuenta. Es la
/// pantalla raiz cuando quien inicia sesion es un comercio.
class EmpresaShell extends StatefulWidget {
  const EmpresaShell({super.key, this.paginas});

  /// Reemplazo de las cuatro pestañas para pruebas (cada una carga datos de la red).
  final List<Widget>? paginas;

  @override
  State<EmpresaShell> createState() => _EmpresaShellState();
}

class _EmpresaShellState extends State<EmpresaShell> {
  int _tab = 0;

  /// Aviso compartido: cuando se crea, edita o borra un evento (desde el mapa
  /// o desde la lista), las dos pantallas se recargan.
  final ValueNotifier<int> _senalEventos = ValueNotifier<int>(0);

  @override
  void dispose() {
    _senalEventos.dispose();
    super.dispose();
  }

  Future<void> _cerrarSesion() => AuthScope.read(context).cerrarSesion();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<Widget> paginas =
        widget.paginas ??
        <Widget>[
          MapaEmpresaScreen(senal: _senalEventos),
          MisEventosScreen(senal: _senalEventos),
          const MisNodosScreen(),
          CuentaEmpresaScreen(onCerrarSesion: _cerrarSesion),
        ];
    return Scaffold(
      backgroundColor: FqColors.paper,
      body: IndexedStack(index: _tab, children: paginas),
      bottomNavigationBar: NavigationBar(
        key: const ValueKey<String>('nav-empresa'),
        selectedIndex: _tab,
        onDestinationSelected: (int i) => setState(() => _tab = i),
        backgroundColor: FqColors.white,
        indicatorColor: FqColors.chipSelectedBg,
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map, color: FqColors.night),
            label: l10n.navMapa,
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_outlined),
            selectedIcon: const Icon(Icons.event, color: FqColors.night),
            label: l10n.comunEventos,
          ),
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront, color: FqColors.night),
            label: l10n.navNodos,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person, color: FqColors.night),
            label: l10n.cuentaEmpresaTitulo,
          ),
        ],
      ),
    );
  }
}
