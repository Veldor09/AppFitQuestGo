import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/aportes_screen.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/insignias_screen.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/preferencias_screen.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/widgets/actividades_modal.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/widgets/editar_perfil_modal.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/widgets/intereses_modal.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/rutas_screen.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';


class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key, this.api, this.onCerrarSesion});

  final PerfilApi? api;

  final Future<void> Function()? onCerrarSesion;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late final PerfilApi _api = widget.api ?? PerfilApi();
  late Future<Usuario> _futuro = _api.miPerfil();

  void _recargar() {
    setState(() {
      _futuro = _api.miPerfil();
    });
  }

  Future<void> _editarPerfil(Usuario usuario) async {
    final bool? cambiado = await EditarPerfilModal.abrir(
      context,
      usuario: usuario,
      api: _api,
    );
    if (cambiado == true) {
      _recargar();
    }
  }

  Future<void> _gestionarIntereses(Usuario usuario) async {
    final bool? cambiado = await GestionarInteresesModal.abrir(
      context,
      usuario: usuario,
      api: _api,
    );
    if (cambiado == true) {
      _recargar();
    }
  }

  Future<void> _gestionarActividades(Usuario usuario) async {
    final bool? cambiado = await GestionarActividadesModal.abrir(
      context,
      usuario: usuario,
      api: _api,
    );
    if (cambiado == true) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FqColors.paper,
      child: FutureBuilder<Usuario>(
        future: _futuro,
        builder: (BuildContext context, AsyncSnapshot<Usuario> snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _PerfilCargando();
          }
          if (snap.hasError || !snap.hasData) {
            return _PerfilError(
              mensaje: snap.error is ApiException
                  ? (snap.error! as ApiException).message
                  : 'No se pudo cargar tu perfil.',
              onReintentar: _recargar,
            );
          }
          return _PerfilContenido(
            usuario: snap.data!,
            onAjustes: () => _abrirAjustes(snap.data!),
            onEditar: () => _editarPerfil(snap.data!),
            onGestionarIntereses: () => _gestionarIntereses(snap.data!),
            onGestionarActividades: () => _gestionarActividades(snap.data!),
            onRecargar: _recargar,
          );
        },
      ),
    );
  }

  Future<void> _abrirAjustes(Usuario usuario) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FqColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _HojaAjustes(
        usuario: usuario,
        onCerrarSesion: widget.onCerrarSesion,
        onEditar: () => _editarPerfil(usuario),
        onGestionarIntereses: () => _gestionarIntereses(usuario),
        onGestionarActividades: () => _gestionarActividades(usuario),
      ),
    );
  }
}

class _PerfilContenido extends StatelessWidget {
  const _PerfilContenido({
    required this.usuario,
    required this.onAjustes,
    required this.onEditar,
    required this.onGestionarIntereses,
    required this.onGestionarActividades,
    required this.onRecargar,
  });

  final Usuario usuario;
  final VoidCallback onAjustes;
  final VoidCallback onEditar;
  final VoidCallback onGestionarIntereses;
  final VoidCallback onGestionarActividades;
  final VoidCallback onRecargar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Hero(
          usuario: usuario,
          onAjustes: onAjustes,
          onEditar: onEditar,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: <Widget>[
                _SeccionActividades(
                  actividades: usuario.actividades,
                  onGestionar: onGestionarActividades,
                ),
                const SizedBox(height: 6),
                _SeccionIntereses(
                  intereses: usuario.intereses,
                  onGestionar: onGestionarIntereses,
                ),
                const SizedBox(height: 10),
                _MenuFila(
                  icono: Icons.route_outlined,
                  texto: 'Mis rutas',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          body: RutasScreen(initialTab: 1),
                        ),
                      ),
                    );
                  },
                ),
                _MenuFila(
                  icono: Icons.send_outlined,
                  texto: 'Mis aportes',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AportesScreen()),
                  ),
                ),
                _MenuFila(
                  icono: Icons.military_tech_outlined,
                  texto: 'Insignias',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const InsigniasScreen()),
                  ),
                ),
                _MenuFila(
                  icono: Icons.notifications_none_rounded,
                  texto: 'Notificaciones',
                  onTap: () async {
                    final bool? ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(builder: (_) => PreferenciasScreen(usuario: usuario)),
                    );
                    if (ok == true) onRecargar();
                  },
                ),
                _MenuFila(
                  icono: Icons.download_outlined,
                  texto: 'Mapas offline',
                  onTap: () async {
                    final bool? ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(builder: (_) => PreferenciasScreen(usuario: usuario)),
                    );
                    if (ok == true) onRecargar();
                  },
                ),
                _MenuFila(
                  icono: Icons.tune_rounded,
                  texto: 'Preferencias y privacidad',
                  onTap: () async {
                    final bool? ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(builder: (_) => PreferenciasScreen(usuario: usuario)),
                    );
                    if (ok == true) onRecargar();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


/// Cabecera azul: avatar + nombre + subtitulo + tira de metricas.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.usuario,
    required this.onAjustes,
    required this.onEditar,
  });

  final Usuario usuario;
  final VoidCallback onAjustes;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      color: FqColors.night,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(14, topInset + 16, 14, 12),
            child: Column(
              children: <Widget>[
                GestureDetector(
                  onTap: onEditar,
                  child: _Avatar(
                    iniciales: usuario.iniciales,
                    mostrarBotonEditar: true,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: onEditar,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            usuario.nombreUser,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              color: FqColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: FqColors.stone,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${usuario.etiquetaRol} · ${usuario.estado}',
                  style: const TextStyle(
                    color: Color(0xFFB7C3D1),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                const _MetricasEjemplo(),
              ],
            ),
          ),
          Positioned(
            top: topInset + 4,
            left: 6,
            child: IconButton(
              onPressed: onEditar,
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: FqColors.white,
              tooltip: 'Editar perfil',
              splashRadius: 18,
            ),
          ),
          Positioned(
            top: topInset + 4,
            right: 6,
            child: IconButton(
              onPressed: onAjustes,
              icon: const Icon(Icons.tune_rounded, size: 18),
              color: FqColors.white,
              tooltip: 'Ajustes de la cuenta',
              splashRadius: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.iniciales,
    this.mostrarBotonEditar = false,
  });

  final String iniciales;
  final bool mostrarBotonEditar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FqColors.volt,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Text(
              iniciales,
              style: const TextStyle(
                color: FqColors.night,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: const Color(0xFF28A36D),
                shape: BoxShape.circle,
                border: Border.all(color: FqColors.night, width: 3),
              ),
            ),
          ),
          if (mostrarBotonEditar)
            Positioned(
              left: -4,
              bottom: -4,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FqColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: FqColors.night, width: 2),
                ),
                child: const Icon(
                  Icons.edit,
                  size: 11,
                  color: FqColors.night,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tira blanca de 3 metricas reales (PRF-01 / NAV-07).
class _MetricasEjemplo extends StatefulWidget {
  const _MetricasEjemplo();

  @override
  State<_MetricasEjemplo> createState() => _MetricasEjemploState();
}

class _MetricasEjemploState extends State<_MetricasEjemplo> {
  final Future<Map<String, dynamic>> _stats = PerfilApi().estadisticasPropias();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _stats,
      builder: (BuildContext ctx, AsyncSnapshot<Map<String, dynamic>> snap) {
        final String km = snap.hasData
            ? '${(snap.data!['kmRecorridos'] as num? ?? 0).toStringAsFixed(0)}'
            : '—';
        final String rutas = snap.hasData
            ? '${(snap.data!['rutasCompletadas'] as int?) ?? 0}'
            : '—';
        final String insignias = snap.hasData
            ? '${(snap.data!['insignias'] as int?) ?? 0}'
            : '—';
        return Container(
          decoration: BoxDecoration(
            color: FqColors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: FqColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: <Widget>[
                Expanded(child: _Metrica(valor: km, etiqueta: 'KM')),
                Container(width: 1, color: FqColors.border),
                Expanded(child: _Metrica(valor: rutas, etiqueta: 'RUTAS')),
                Container(width: 1, color: FqColors.border),
                Expanded(child: _Metrica(valor: insignias, etiqueta: 'INSIGNIAS')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            valor,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: FqColors.ink,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: FqColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuFila extends StatelessWidget {
  const _MenuFila({
    required this.icono,
    required this.texto,
    this.onTap,
  });

  final IconData icono;
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => notificarInfo('$texto: disponible pronto'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE7EBE5)),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 31,
              height: 31,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FqColors.listIconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icono, size: 17, color: FqColors.night),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FqColors.ink,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: FqColors.stone,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Estados de carga / error
// ---------------------------------------------------------------------------

class _PerfilCargando extends StatelessWidget {
  const _PerfilCargando();

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          color: FqColors.night,
          padding: EdgeInsets.fromLTRB(14, topInset + 24, 14, 24),
          child: Column(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: FqColors.night2,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              const SizedBox(height: 12),
              Container(width: 120, height: 12, color: FqColors.night2),
              const SizedBox(height: 8),
              Container(width: 80, height: 8, color: FqColors.night2),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _PerfilError extends StatelessWidget {
  const _PerfilError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return FqEmptyState(
      icon: Icons.person_off_outlined,
      title: 'No se pudo cargar tu perfil',
      message: mensaje,
      action: TextButton(
        onPressed: onReintentar,
        child: const Text('Reintentar'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hoja de ajustes de la cuenta (datos reales de la BD + cerrar sesion)
// ---------------------------------------------------------------------------

class _HojaAjustes extends StatelessWidget {
  const _HojaAjustes({
    required this.usuario,
    this.onCerrarSesion,
    required this.onEditar,
    required this.onGestionarIntereses,
    required this.onGestionarActividades,
  });

  final Usuario usuario;
  final Future<void> Function()? onCerrarSesion;
  final VoidCallback onEditar;
  final VoidCallback onGestionarIntereses;
  final VoidCallback onGestionarActividades;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: FqColors.stone,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Ajustes de la cuenta',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: FqColors.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Información personal y estado de tu cuenta.',
              style: TextStyle(fontSize: 10, color: FqColors.muted),
            ),
            const SizedBox(height: 14),
            _Dato(label: 'Nombre', valor: usuario.nombreUser),
            _Dato(label: 'Correo', valor: usuario.emailUser),
            _Dato(label: 'Rol', valor: usuario.etiquetaRol),
            _Dato(label: 'Estado', valor: usuario.estado, ultimo: true),
            const SizedBox(height: 16),
            FqButton.primary(
              label: 'Editar perfil',
              icon: Icons.edit_outlined,
              onPressed: () {
                Navigator.of(context).pop();
                onEditar();
              },
            ),
            const SizedBox(height: 8),
            FqButton.secondary(
              label: 'Gestionar actividades / deportes',
              icon: Icons.fitness_center_rounded,
              onPressed: () {
                Navigator.of(context).pop();
                onGestionarActividades();
              },
            ),
            const SizedBox(height: 8),
            FqButton.secondary(
              label: 'Gestionar intereses',
              icon: Icons.interests_outlined,
              onPressed: () {
                Navigator.of(context).pop();
                onGestionarIntereses();
              },
            ),
            if (onCerrarSesion != null) ...<Widget>[
              const SizedBox(height: 10),
              FqButton.danger(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onPressed: () async {
                  Navigator.of(context).pop();
                  await onCerrarSesion!();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.label, required this.valor, this.ultimo = false});

  final String label;
  final String valor;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: ultimo
            ? null
            : const Border(bottom: BorderSide(color: FqColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 74,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: FqColors.fieldLabel,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FqColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta para mostrar los intereses seleccionados del usuario.
class _SeccionIntereses extends StatelessWidget {
  const _SeccionIntereses({
    required this.intereses,
    required this.onGestionar,
  });

  final List<String> intereses;
  final VoidCallback onGestionar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FqColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.interests_rounded,
                size: 16,
                color: Color(0xFF0F766E),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'MIS INTERESES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: FqColors.muted,
                  ),
                ),
              ),
              InkWell(
                onTap: onGestionar,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Gestionar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (intereses.isEmpty)
            InkWell(
              onTap: onGestionar,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8DE)),
                ),
                child: Row(
                  children: const <Widget>[
                    Icon(Icons.add_circle_outline_rounded, size: 16, color: FqColors.muted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selecciona tus intereses',
                        style: TextStyle(fontSize: 11, color: FqColors.muted, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String item in intereses)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF3EB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD6E0D3)),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: FqColors.ink,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Tarjeta para mostrar las actividades/deportes favoritos seleccionados del usuario.
class _SeccionActividades extends StatelessWidget {
  const _SeccionActividades({
    required this.actividades,
    required this.onGestionar,
  });

  final List<String> actividades;
  final VoidCallback onGestionar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FqColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.fitness_center_rounded,
                size: 16,
                color: Color(0xFF0369A1),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'MIS ACTIVIDADES FAVORITAS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: FqColors.muted,
                  ),
                ),
              ),
              InkWell(
                onTap: onGestionar,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Gestionar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (actividades.isEmpty)
            InkWell(
              onTap: onGestionar,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: const <Widget>[
                    Icon(Icons.add_circle_outline_rounded, size: 16, color: FqColors.muted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selecciona tus deportes favoritos',
                        style: TextStyle(fontSize: 11, color: FqColors.muted, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String item in actividades)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

