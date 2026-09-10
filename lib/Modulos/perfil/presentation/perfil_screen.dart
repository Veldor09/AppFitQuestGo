import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
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
    // Bloque, no expresion: `=> _futuro = x` devuelve el Future asignado,
    // y setState no acepta un callback que devuelva un Future.
    setState(() {
      _futuro = _api.miPerfil();
    });
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
          );
        },
      ),
    );
  }

  Future<void> _abrirAjustes(Usuario usuario) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: FqColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _HojaAjustes(
        usuario: usuario,
        onCerrarSesion: widget.onCerrarSesion,
      ),
    );
  }
}

class _PerfilContenido extends StatelessWidget {
  const _PerfilContenido({required this.usuario, required this.onAjustes});

  final Usuario usuario;
  final VoidCallback onAjustes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Hero(usuario: usuario, onAjustes: onAjustes),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: const <Widget>[
                _MenuFila(icono: Icons.route_outlined, texto: 'Mis rutas'),
                _MenuFila(icono: Icons.send_outlined, texto: 'Mis aportes'),
                _MenuFila(
                  icono: Icons.military_tech_outlined,
                  texto: 'Insignias',
                ),
                _MenuFila(
                  icono: Icons.notifications_none_rounded,
                  texto: 'Notificaciones',
                ),
                _MenuFila(
                  icono: Icons.download_outlined,
                  texto: 'Mapas offline',
                ),
                _MenuFila(
                  icono: Icons.tune_rounded,
                  texto: 'Preferencias y privacidad',
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
  const _Hero({required this.usuario, required this.onAjustes});

  final Usuario usuario;
  final VoidCallback onAjustes;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      color: FqColors.night,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(14, topInset + 20, 14, 12),
            child: Column(
              children: <Widget>[
                _Avatar(iniciales: usuario.iniciales),
                const SizedBox(height: 7),
                Text(
                  usuario.nombreUser,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: FqColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
  const _Avatar({required this.iniciales});

  final String iniciales;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FqColors.volt,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              iniciales,
              style: const TextStyle(
                color: FqColors.night,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF28A36D),
                shape: BoxShape.circle,
                border: Border.all(color: FqColors.night, width: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tira blanca de 3 metricas. Valores de ejemplo: aun no hay endpoint de
/// actividad del usuario.
class _MetricasEjemplo extends StatelessWidget {
  const _MetricasEjemplo();

  @override
  Widget build(BuildContext context) {
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
            const Expanded(child: _Metrica(valor: '312', etiqueta: 'KM')),
            _sep(),
            const Expanded(child: _Metrica(valor: '41', etiqueta: 'RUTAS')),
            _sep(),
            const Expanded(child: _Metrica(valor: '6', etiqueta: 'INSIGNIAS')),
          ],
        ),
      ),
    );
  }

  Widget _sep() => Container(width: 1, color: FqColors.border);
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
  const _MenuFila({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => notificarInfo('$texto: disponible pronto'),
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
  const _HojaAjustes({required this.usuario, this.onCerrarSesion});

  final Usuario usuario;
  final Future<void> Function()? onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
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
              'Datos leidos de la base de datos.',
              style: TextStyle(fontSize: 10, color: FqColors.muted),
            ),
            const SizedBox(height: 14),
            _Dato(label: 'Nombre', valor: usuario.nombreUser),
            _Dato(label: 'Correo', valor: usuario.emailUser),
            _Dato(label: 'Rol', valor: usuario.etiquetaRol),
            _Dato(label: 'Estado', valor: usuario.estado, ultimo: true),
            if (onCerrarSesion != null) ...<Widget>[
              const SizedBox(height: 18),
              FqButton.danger(
                label: 'Cerrar sesion',
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
