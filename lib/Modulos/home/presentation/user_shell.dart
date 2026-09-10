import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/home/presentation/home_usuario_screen.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/user_nav_bar.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/perfil_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/planificar_ruta_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/rutas_screen.dart';


class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _tab = 0;

  Future<void> _cerrarSesion() => AuthScope.read(context).cerrarSesion();

  @override
  Widget build(BuildContext context) {
    final List<Widget> pestanas = <Widget>[
      const HomeUsuarioScreen(),
      const RutasScreen(),
      const PlanificarRutaScreen(),
      const _Pendiente(titulo: 'Eventos', icono: Icons.auto_awesome_outlined),
      PerfilScreen(onCerrarSesion: _cerrarSesion),
    ];

    return Scaffold(
      backgroundColor: FqColors.paper,
      body: _LazyIndexedStack(index: _tab, children: pestanas),
      bottomNavigationBar: UserNavBar(
        currentIndex: _tab,
        onSelect: (int i) => setState(() => _tab = i),
      ),
    );
  }
}

/// Pestana sin backend todavia: estado vacio honesto, sin datos inventados.
class _Pendiente extends StatelessWidget {
  const _Pendiente({required this.titulo, required this.icono});

  final String titulo;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FqColors.paper,
      child: FqEmptyState(
        icon: icono,
        title: titulo,
        message: 'Esta seccion estara disponible pronto.',
      ),
    );
  }
}

class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  final Set<int> _visitadas = <int>{};

  @override
  void initState() {
    super.initState();
    _visitadas.add(widget.index);
  }

  @override
  void didUpdateWidget(covariant _LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visitadas.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: <Widget>[
        for (int i = 0; i < widget.children.length; i++)
          if (_visitadas.contains(i))
            widget.children[i]
          else
            const SizedBox.shrink(),
      ],
    );
  }
}
