import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Pantalla principal para una cuenta autenticada que no es administradora.
class HomeUsuarioScreen extends StatelessWidget {
  const HomeUsuarioScreen({super.key});

  static const String _accessToken = String.fromEnvironment('ACCESS_TOKEN');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_accessToken.isNotEmpty)
            MapWidget(
              key: const ValueKey<String>('fitquest-map'),
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(-84.0907, 9.9281)),
                zoom: 13.5,
              ),
            )
          else
            const _MissingTokenBackground(),
          const SafeArea(
            child: Column(
              children: <Widget>[
                _TopControls(),
                SizedBox(height: 8),
                _FilterChips(),
                Spacer(),
                _NearbyPanel(),
                _BottomNavigation(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: _floatingDecoration(radius: 18),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.search_rounded, color: FqColors.muted, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Buscar lugar, ruta o evento',
                    style: TextStyle(color: FqColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Container(
            width: 50,
            height: 50,
            decoration: _floatingDecoration(radius: 17),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                const Icon(Icons.notifications_none_rounded, size: 27),
                Positioned(
                  right: 9,
                  top: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: FqColors.risk,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Row(
          children: <Widget>[
            _chip('Todo', selected: true),
            _chip('Rutas'),
            _chip('Alertas'),
            _chip('POIs'),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {bool selected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? FqColors.night : FqColors.paper.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? FqColors.white : FqColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NearbyPanel extends StatelessWidget {
  const _NearbyPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(9, 0, 9, 10),
      padding: const EdgeInsets.fromLTRB(16, 15, 4, 15),
      decoration: _floatingDecoration(radius: 19),
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Cerca de ti',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                Text(
                  '6 hallazgos activos',
                  style: TextStyle(fontSize: 9, color: FqColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: <Widget>[
              const Expanded(
                child: _ResultTile(
                  icon: Icons.route_rounded,
                  label: 'Ruta · 1,2 km',
                ),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: _ResultTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'Alerta · 300 m',
                ),
              ),
              const SizedBox(width: 7),
              Container(
                width: 57,
                height: 57,
                decoration: BoxDecoration(
                  color: FqColors.volt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.add_rounded, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: FqColors.paper,
        border: Border.all(color: FqColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      color: FqColors.white.withValues(alpha: .96),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _NavItem(icon: Icons.map_outlined, label: 'Mapa', selected: true),
          _NavItem(icon: Icons.route_outlined, label: 'Rutas'),
          _NavItem(icon: Icons.add_rounded, label: 'Crear'),
          _NavItem(icon: Icons.auto_awesome_outlined, label: 'Eventos'),
          _NavItem(icon: Icons.person_outline_rounded, label: 'Perfil'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.selected = false});

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? FqColors.voltDark : FqColors.muted;
    return SizedBox(
      width: 58,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 23, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: selected ? FqColors.night : color,
              fontSize: 9,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingTokenBackground extends StatelessWidget {
  const _MissingTokenBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EEE5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: const Text(
        'Mapbox necesita ACCESS_TOKEN.\nInicia con --dart-define=ACCESS_TOKEN=pk…',
        textAlign: TextAlign.center,
        style: TextStyle(color: FqColors.muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

BoxDecoration _floatingDecoration({required double radius}) {
  return BoxDecoration(
    color: FqColors.white.withValues(alpha: .97),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Color(0x1F13233F), blurRadius: 18, offset: Offset(0, 5)),
    ],
  );
}
