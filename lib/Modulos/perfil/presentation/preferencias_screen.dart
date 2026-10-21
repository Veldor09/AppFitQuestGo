import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// APP-07 / NAV-08 - Preferencias y privacidad.
class PreferenciasScreen extends StatefulWidget {
  const PreferenciasScreen({super.key, required this.usuario, this.api});
  final Usuario usuario;
  final PerfilApi? api;

  @override
  State<PreferenciasScreen> createState() => _PreferenciasScreenState();
}

class _PreferenciasScreenState extends State<PreferenciasScreen> {
  late final PerfilApi _api = widget.api ?? PerfilApi();
  late String _unidad;
  late bool _notificaciones;
  late String _visibilidad;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _unidad = widget.usuario.unidad;
    _notificaciones = widget.usuario.notificaciones;
    _visibilidad = widget.usuario.visibilidad;
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
      notificarExito(l10n?.preferenciasGuardadas ?? 'Preferencias guardadas');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) notificarError(e.message);
    } catch (_) {
      if (mounted) notificarError(l10n?.preferenciasErrorGuardar ?? 'No se pudo guardar. Revisa tu conexion.');
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
          // ── Cabecera ──────────────────────────────────────────────────────
          Container(
            color: FqColors.night,
            padding: EdgeInsets.fromLTRB(4, top + 4, 16, 12),
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: FqColors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    l10n.preferenciasTitulo,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: FqColors.white),
                  ),
                ),
              ],
            ),
          ),
          // ── Cuerpo ────────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _Tarjeta(
                  icono: Icons.straighten_rounded,
                  titulo: l10n.preferenciasUnidadTitulo,
                  bajada: l10n.preferenciasUnidadDesc,
                  child: Wrap(
                    spacing: 8,
                    children: <Widget>[
                      _Chip(label: l10n.preferenciasKm, activo: _unidad == 'km', onTap: () => setState(() => _unidad = 'km')),
                      _Chip(label: l10n.preferenciasMillas, activo: _unidad == 'mi', onTap: () => setState(() => _unidad = 'mi')),
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
                        _notificaciones ? l10n.preferenciasActivadas : l10n.preferenciasDesactivadas,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _notificaciones ? FqColors.trail : FqColors.muted,
                        ),
                      ),
                      Switch(
                        value: _notificaciones,
                        onChanged: (bool v) => setState(() => _notificaciones = v),
                        activeColor: FqColors.voltDark,
                        activeTrackColor: FqColors.volt,
                        inactiveTrackColor: FqColors.toggleOff,
                        inactiveThumbColor: FqColors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Tarjeta(
                  icono: Icons.lock_outline_rounded,
                  titulo: l10n.preferenciasVisibilidadTitulo,
                  bajada: l10n.preferenciasVisibilidadDesc,
                  child: Column(
                    children: <Widget>[
                      _OpcionVisibilidad(icono: Icons.public_rounded, titulo: l10n.preferenciasPublicoTitulo, sub: l10n.preferenciasPublicoDesc, val: 'publico', sel: _visibilidad, onTap: () => setState(() => _visibilidad = 'publico')),
                      _OpcionVisibilidad(icono: Icons.group_outlined, titulo: l10n.preferenciasAmigosTitulo, sub: l10n.preferenciasAmigosDesc, val: 'amigos', sel: _visibilidad, onTap: () => setState(() => _visibilidad = 'amigos')),
                      _OpcionVisibilidad(icono: Icons.lock_rounded, titulo: l10n.preferenciasPrivadoTitulo, sub: l10n.preferenciasPrivadoDesc, val: 'privado', sel: _visibilidad, onTap: () => setState(() => _visibilidad = 'privado'), ultimo: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Tarjeta(
                  icono: Icons.download_outlined,
                  titulo: l10n.mapasOfflineTitulo,
                  bajada: l10n.preferenciasMapasDesc,
                  child: _MapasPanel(l10n: l10n),
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
  const _Tarjeta({required this.icono, required this.titulo, required this.bajada, required this.child});
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
              Container(width: 32, height: 32, alignment: Alignment.center,
                decoration: BoxDecoration(color: FqColors.listIconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icono, size: 17, color: FqColors.night)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: FqColors.ink)),
                  Text(bajada, style: const TextStyle(fontSize: 10, color: FqColors.muted)),
                ],
              )),
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
  const _Chip({required this.label, required this.activo, required this.onTap});
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
          border: Border.all(color: activo ? FqColors.voltDark : FqColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: activo ? FqColors.night : FqColors.muted)),
      ),
    );
  }
}

class _OpcionVisibilidad extends StatelessWidget {
  const _OpcionVisibilidad({required this.icono, required this.titulo, required this.sub, required this.val, required this.sel, required this.onTap, this.ultimo = false});
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
        decoration: BoxDecoration(border: ultimo ? null : const Border(bottom: BorderSide(color: FqColors.border))),
        child: Row(
          children: <Widget>[
            Icon(icono, size: 18, color: activo ? FqColors.trail : FqColors.muted),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: activo ? FqColors.ink : FqColors.muted)),
                Text(sub, style: const TextStyle(fontSize: 10, color: FqColors.muted)),
              ],
            )),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: activo ? FqColors.trail : FqColors.stone, width: activo ? 5 : 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapasPanel extends StatelessWidget {
  const _MapasPanel({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: FqColors.cloud, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: <Widget>[
              const Icon(Icons.info_outline, size: 16, color: FqColors.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.preferenciasSinMapasDescargados, style: const TextStyle(fontSize: 10, color: FqColors.muted))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => notificarInfo(l10n.preferenciasDescargaPronto),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: FqColors.border), borderRadius: BorderRadius.circular(10), color: FqColors.white),
            child: Row(
              children: <Widget>[
                const Icon(Icons.add_circle_outline, size: 18, color: FqColors.river),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.preferenciasDescargarZona, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: FqColors.river))),
                const Icon(Icons.chevron_right, size: 16, color: FqColors.stone),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
