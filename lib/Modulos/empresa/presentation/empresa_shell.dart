import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/cuenta_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mis_eventos_screen.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mis_nodos_screen.dart';

/// Panel unico de una cuenta de empresa (rol Empresa): sus eventos, sus nodos
/// y su cuenta. Es la pantalla raiz cuando quien inicia sesion es un comercio.
class EmpresaShell extends StatefulWidget {
  const EmpresaShell({super.key, this.paginas});

  /// Reemplazo de las tres pestañas para pruebas (cada una carga datos de la red).
  final List<Widget>? paginas;

  @override
  State<EmpresaShell> createState() => _EmpresaShellState();
}

class _EmpresaShellState extends State<EmpresaShell> {
  int _tab = 0;

  Future<void> _cerrarSesion() => AuthScope.read(context).cerrarSesion();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<Widget> paginas =
        widget.paginas ??
        <Widget>[
          const MisEventosScreen(),
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
