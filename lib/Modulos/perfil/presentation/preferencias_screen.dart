import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/biometria/biometria_servicio.dart';
import 'package:fit_quest_go/core/idioma/idioma_app.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/push/registro_push.dart';
import 'package:fit_quest_go/core/push/servicio_push.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// APP-07 / NAV-08 - Preferencias y privacidad.
class PreferenciasScreen extends StatefulWidget {
  const PreferenciasScreen({
    super.key,
    required this.usuario,
    this.api,
    this.idioma,
    this.push,
  });
  final Usuario usuario;
  final PerfilApi? api;

  /// Inyectable para pruebas; por defecto el idioma de toda la app.
  final ControladorIdioma? idioma;

  /// Inyectable para pruebas; por defecto [ServicioPush.instancia].
  final ServicioPush? push;

  @override
  State<PreferenciasScreen> createState() => _PreferenciasScreenState();
}

class _PreferenciasScreenState extends State<PreferenciasScreen> {
  late final PerfilApi _api = widget.api ?? PerfilApi();
  late final ControladorIdioma _idioma =
      widget.idioma ?? ControladorIdioma.instancia;
  late String _unidad;
  late bool _notificaciones;
  late String _visibilidad;
  bool _guardando = false;
  bool _biometriaDisponible = false;
  bool _biometriaActiva = false;

  @override
  void initState() {
    super.initState();
    _unidad = widget.usuario.unidad;
    _notificaciones = widget.usuario.notificaciones;
    _visibilidad = widget.usuario.visibilidad;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarEstadoBiometria();
    });
  }

  Future<void> _cargarEstadoBiometria() async {
    final bool disponible =
        await BiometriaServicio.instancia.dispositivoSoportado;
    if (!mounted) return;
    final bool activa = await AuthScope.read(
      context,
    ).tieneCredencialBiometrica();
    if (mounted) {
      setState(() {
        _biometriaDisponible = disponible;
        _biometriaActiva = activa;
      });
    }
  }

  Future<void> _cambiarBiometria(bool valor) async {
    if (!valor) {
      await AuthScope.read(context).borrarCredencialBiometrica();
      if (!mounted) return;
      setState(() => _biometriaActiva = false);
      notificarInfo(AppLocalizations.of(context)!.bioInicioDesactivado);
      return;
    }

    final String? pass = await _pedirContrasenaParaBiometria();
    if (pass == null || pass.isEmpty) return;

    final bool ok = await BiometriaServicio.instancia.autenticar(
      motivo: AppLocalizations.of(context)!.bioVerificaAsociar,
    );
    if (!ok) {
      if (mounted) {
        notificarError(AppLocalizations.of(context)!.bioErrorVerificar);
      }
      return;
    }

    if (!mounted) return;
    await AuthScope.read(context).guardarCredencialBiometrica(
      email: widget.usuario.emailUser,
      contrasena: pass,
      nombre: widget.usuario.nombreUser,
    );
    if (!mounted) return;
    setState(() => _biometriaActiva = true);
    notificarExito(AppLocalizations.of(context)!.bioInicioActivado);
  }

  Future<String?> _pedirContrasenaParaBiometria() async {
    final TextEditingController passCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: FqColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.of(context)!.bioActivarTitulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: FqColors.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppLocalizations.of(context)!.bioActivarMensaje,
              style: const TextStyle(fontSize: 13, color: FqColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passCtrl,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.bioTuContrasena,
                filled: true,
                fillColor: FqColors.cloud,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: FqColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(
              AppLocalizations.of(context)!.comunCancelar,
              style: const TextStyle(color: FqColors.muted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(passCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: FqColors.night,
              foregroundColor: FqColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(AppLocalizations.of(context)!.admConfirmar),
          ),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    setState(() => _guardando = true);
    try {
      await _api.actualizarPerfil(
        id: widget.usuario.id,
        nombreUser: widget.usuario.nombreUser,
        emailUser: widget.usuario.emailUser,
        unidad: _unidad,
        notificaciones: _notificaciones,
        visibilidad: _visibilidad,
      );
      if (!mounted) return;
      // El interruptor de "Notificaciones push" tambien prende o apaga los
      // avisos fuera de la app en ESTE telefono.
      if (_notificaciones != widget.usuario.notificaciones) {
        final ServicioPush push = widget.push ?? ServicioPush.instancia;
        if (_notificaciones) {
          unawaited(
            push.registrar(
              idioma: idiomaDeAviso(Localizations.localeOf(context)),
            ),
          );
        } else {
          unawaited(push.quitar());
        }
      }
      notificarExito(l10n?.preferenciasGuardadas ?? 'Preferencias guardadas');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) notificarError(e.message);
    } catch (_) {
      if (mounted) {
        notificarError(
          l10n?.preferenciasErrorGuardar ??
              'No se pudo guardar. Revisa tu conexion.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final double top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: FqColors.paper,
      body: Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.only(
              top: top + 12,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: FqColors.white,
              border: Border(bottom: BorderSide(color: FqColors.border)),
            ),
            child: Row(
              children: <Widget>[
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: FqColors.cloud,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FqColors.border),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: FqColors.night,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.perfilPreferencias,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FqColors.ink,
                        ),
                      ),
                      Text(
                        l10n.prefAjustesPrivacidad,
                        style: const TextStyle(
                          fontSize: 11,
                          color: FqColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _Tarjeta(
                  icono: Icons.language_rounded,
                  titulo: l10n.preferenciasIdiomaTitulo,
                  bajada: l10n.preferenciasIdiomaDesc,
                  child: ListenableBuilder(
                    listenable: _idioma,
                    builder: (BuildContext context, Widget? _) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _Chip(
                          label: l10n.preferenciasIdiomaAuto,
                          activo: _idioma.idioma == null,
                          onTap: () => _idioma.elegir(null),
                        ),
                        for (final IdiomaApp i in IdiomaApp.values)
                          _Chip(
                            key: ValueKey<String>('idioma-${i.codigo}'),
                            label: i.nombre,
                            activo: _idioma.idioma == i,
                            onTap: () => _idioma.elegir(i),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Tarjeta(
                  icono: Icons.straighten_rounded,
                  titulo: l10n.preferenciasUnidadTitulo,
                  bajada: l10n.preferenciasUnidadDesc,
                  child: Wrap(
                    spacing: 8,
                    children: <Widget>[
                      _Chip(
                        label: l10n.preferenciasKm,
                        activo: _unidad == 'km',
                        onTap: () => setState(() => _unidad = 'km'),
                      ),
                      _Chip(
                        label: l10n.preferenciasMillas,
                        activo: _unidad == 'mi',
                        onTap: () => setState(() => _unidad = 'mi'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Tarjeta(
                  icono: Icons.notifications_outlined,
                  titulo: l10n.preferenciasPushTitulo,
                  bajada: l10n.preferenciasPushDesc,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        _notificaciones
                            ? l10n.preferenciasActivadas
                            : l10n.preferenciasDesactivadas,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _notificaciones
                              ? FqColors.trail
                              : FqColors.muted,
                        ),
                      ),
                      Switch(
                        value: _notificaciones,
                        onChanged: (bool v) =>
                            setState(() => _notificaciones = v),
                        activeThumbColor: FqColors.voltDark,
                        activeTrackColor: FqColors.volt,
                        inactiveTrackColor: FqColors.toggleOff,
                        inactiveThumbColor: FqColors.white,
                      ),
                    ],
                  ),
                ),
                if (_biometriaDisponible) ...<Widget>[
                  const SizedBox(height: 12),
                  _Tarjeta(
                    icono: Icons.fingerprint_rounded,
                    titulo: l10n.bioTarjetaTitulo,
                    bajada: l10n.bioTarjetaDesc,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          _biometriaActiva
                              ? l10n.preferenciasActivadas
                              : l10n.preferenciasDesactivadas,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _biometriaActiva
                                ? FqColors.trail
                                : FqColors.muted,
                          ),
                        ),
                        Switch(
                          value: _biometriaActiva,
                          onChanged: _cambiarBiometria,
                          activeThumbColor: FqColors.voltDark,
                          activeTrackColor: FqColors.volt,
                          inactiveTrackColor: FqColors.toggleOff,
                          inactiveThumbColor: FqColors.white,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _Tarjeta(
                  icono: Icons.lock_outline_rounded,
                  titulo: l10n.preferenciasVisibilidadTitulo,
                  bajada: l10n.preferenciasVisibilidadDesc,
                  child: Column(
                    children: <Widget>[
                      _OpcionVisibilidad(
                        icono: Icons.public_rounded,
                        titulo: l10n.preferenciasPublicoTitulo,
                        sub: l10n.preferenciasPublicoDesc,
                        val: 'publico',
                        sel: _visibilidad,
                        onTap: () => setState(() => _visibilidad = 'publico'),
                      ),
                      _OpcionVisibilidad(
                        icono: Icons.group_outlined,
                        titulo: l10n.preferenciasAmigosTitulo,
                        sub: l10n.preferenciasAmigosDesc,
                        val: 'amigos',
                        sel: _visibilidad,
                        onTap: () => setState(() => _visibilidad = 'amigos'),
                      ),
                      _OpcionVisibilidad(
                        icono: Icons.lock_rounded,
                        titulo: l10n.preferenciasPrivadoTitulo,
                        sub: l10n.preferenciasPrivadoDesc,
                        val: 'privado',
                        sel: _visibilidad,
                        onTap: () => setState(() => _visibilidad = 'privado'),
                        ultimo: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FqButton.primary(
                  label: l10n.preferenciasGuardarBtn,
                  icon: Icons.save_outlined,
                  loading: _guardando,
                  onPressed: _guardando ? null : _guardar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.bajada,
    required this.child,
  });
  final IconData icono;
  final String titulo;
  final String bajada;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FqColors.listIconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, size: 17, color: FqColors.night),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: FqColors.ink,
                      ),
                    ),
                    Text(
                      bajada,
                      style: const TextStyle(
                        fontSize: 10,
                        color: FqColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: FqColors.border),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.activo,
    required this.onTap,
  });
  final String label;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? FqColors.volt : FqColors.cloud,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo ? FqColors.voltDark : FqColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: activo ? FqColors.night : FqColors.muted,
          ),
        ),
      ),
    );
  }
}

class _OpcionVisibilidad extends StatelessWidget {
  const _OpcionVisibilidad({
    required this.icono,
    required this.titulo,
    required this.sub,
    required this.val,
    required this.sel,
    required this.onTap,
    this.ultimo = false,
  });
  final IconData icono;
  final String titulo, sub, val, sel;
  final VoidCallback onTap;
  final bool ultimo;

  bool get activo => sel == val;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: ultimo
              ? null
              : const Border(bottom: BorderSide(color: FqColors.border)),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icono,
              size: 18,
              color: activo ? FqColors.trail : FqColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: activo ? FqColors.ink : FqColors.muted,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 10, color: FqColors.muted),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: activo ? FqColors.trail : FqColors.stone,
                  width: activo ? 5 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
