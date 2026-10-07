import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/fotos/selector_foto.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/empresa/data/empresa_api.dart';

/// Panel de la empresa · "Cuenta": la foto de perfil, el nombre comercial y el
/// telefono (editables), el correo (solo se muestra) y cerrar sesion.
class CuentaEmpresaScreen extends StatefulWidget {
  const CuentaEmpresaScreen({
    super.key,
    required this.onCerrarSesion,
    this.api,
    this.selectorFoto,
  });

  final VoidCallback onCerrarSesion;

  /// Inyectables para pruebas; en produccion se crean los reales.
  final EmpresaApi? api;
  final SelectorFoto? selectorFoto;

  @override
  State<CuentaEmpresaScreen> createState() => _CuentaEmpresaScreenState();
}

class _CuentaEmpresaScreenState extends State<CuentaEmpresaScreen> {
  late final EmpresaApi _api = widget.api ?? EmpresaApi();
  late final SelectorFoto _selector =
      widget.selectorFoto ?? SelectorFotoImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _telefono = TextEditingController();

  PerfilEmpresa? _perfil;
  Uint8List? _foto;
  bool _cargando = true;
  bool _errorCarga = false;
  bool _guardando = false;
  bool _subiendoFoto = false;

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = false;
    });
    try {
      final PerfilEmpresa perfil = await _api.miPerfil();
      if (!mounted) return;
      _nombre.text = perfil.nombre;
      _telefono.text = perfil.telefono ?? '';
      setState(() {
        _perfil = perfil;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = true;
      });
      return;
    }
    // La foto es un complemento: si falla se muestran las iniciales.
    try {
      final Uint8List? foto = await _api.foto();
      if (mounted) setState(() => _foto = foto);
    } catch (_) {}
  }

  // ---- Foto ----------------------------------------------------------------

  Future<void> _elegirOrigenFoto() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String? eleccion = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              key: const ValueKey<String>('foto-camara'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.nodosFotoCamara),
              onTap: () => Navigator.of(ctx).pop('camara'),
            ),
            ListTile(
              key: const ValueKey<String>('foto-galeria'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.nodosFotoGaleria),
              onTap: () => Navigator.of(ctx).pop('galeria'),
            ),
            if (_foto != null)
              ListTile(
                key: const ValueKey<String>('foto-quitar'),
                leading: const Icon(Icons.delete_outline, color: FqColors.risk),
                title: Text(l10n.nodosFotoQuitar),
                onTap: () => Navigator.of(ctx).pop('quitar'),
              ),
          ],
        ),
      ),
    );
    if (eleccion == null || !mounted) return;
    switch (eleccion) {
      case 'camara':
        await _subirFoto(OrigenFoto.camara);
      case 'galeria':
        await _subirFoto(OrigenFoto.galeria);
      case 'quitar':
        await _quitarFoto();
    }
  }

  Future<void> _subirFoto(OrigenFoto origen) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Uint8List? bytes = await _selector.elegir(origen);
    if (bytes == null || !mounted) return;
    setState(() => _subiendoFoto = true);
    try {
      await _api.subirFoto(bytes);
      if (!mounted) return;
      setState(() => _foto = bytes);
      notificarExito(l10n.cuentaEmpresaFotoActualizada);
    } on ApiException catch (e) {
      notificarError(e.message);
    } catch (_) {
      notificarError(l10n.cuentaEmpresaFotoError);
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _quitarFoto() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() => _subiendoFoto = true);
    try {
      await _api.quitarFoto();
      if (!mounted) return;
      setState(() => _foto = null);
      notificarExito(l10n.cuentaEmpresaFotoQuitada);
    } on ApiException catch (e) {
      notificarError(e.message);
    } catch (_) {
      notificarError(l10n.cuentaEmpresaFotoError);
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  // ---- Datos ---------------------------------------------------------------

  Future<void> _guardar() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      notificarError(l10n.comunRevisaCampos);
      return;
    }
    setState(() => _guardando = true);
    try {
      final PerfilEmpresa nuevo = await _api.actualizar(
        nombreComercial: _nombre.text,
        telefono: _telefono.text,
      );
      if (!mounted) return;
      // La sesion ya no tiene el nombre viejo: el resto de la app lo ve cambiado.
      AuthScope.maybeOf(context)?.actualizarNombre(nuevo.nombre);
      _nombre.text = nuevo.nombre;
      _telefono.text = nuevo.telefono ?? '';
      setState(() {
        _perfil = nuevo;
        _guardando = false;
      });
      notificarExito(l10n.cuentaEmpresaGuardada);
    } on ApiException catch (e) {
      _fallar(e.message);
    } catch (_) {
      _fallar(l10n.cuentaEmpresaErrorGuardar);
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    setState(() => _guardando = false);
    notificarError(mensaje);
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // `Material` propio: los campos de texto lo necesitan aunque la pantalla
    // se use sin un Scaffold por encima.
    return Material(
      color: FqColors.paper,
      child: SafeArea(bottom: false, child: _cuerpo(l10n)),
    );
  }

  Widget _cuerpo(AppLocalizations l10n) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_errorCarga) {
      return FqEmptyState(
        icon: Icons.cloud_off_outlined,
        title: l10n.cuentaEmpresaErrorCarga,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(onPressed: _cargar, child: Text(l10n.comunReintentar)),
            // Aunque no cargue la cuenta, cerrar sesion tiene que seguir a mano.
            TextButton(
              key: const ValueKey<String>('cerrar-sesion-empresa'),
              onPressed: widget.onCerrarSesion,
              child: Text(l10n.perfilCerrarSesion),
            ),
          ],
        ),
      );
    }
    final PerfilEmpresa perfil = _perfil!;
    return ListView(
      padding: const EdgeInsets.all(FqGap.xl),
      children: <Widget>[
        Text(
          l10n.cuentaEmpresaTitulo,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        Center(
          child: _Avatar(
            foto: _foto,
            iniciales: _iniciales(perfil.nombre),
            subiendo: _subiendoFoto,
            onTap: _subiendoFoto ? null : _elegirOrigenFoto,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _subiendoFoto ? null : _elegirOrigenFoto,
            child: Text(l10n.cuentaEmpresaCambiarFoto),
          ),
        ),
        const SizedBox(height: 10),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                key: const ValueKey<String>('campo-nombre-cuenta'),
                controller: _nombre,
                maxLength: kMaxNombreComercial,
                decoration: InputDecoration(
                  labelText: l10n.registroEmpresaNombreComercial,
                ),
                validator: (String? v) => primeraFalla(v ?? '', <Validador>[
                  requerido(l10n.registroEmpresaValidacionNombre),
                  minCaracteres(2, l10n.registroEmpresaValidacionNombre),
                ]),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const ValueKey<String>('campo-telefono-cuenta'),
                controller: _telefono,
                maxLength: 20,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.registroEmpresaTelefono,
                  hintText: l10n.registroEmpresaTelefonoHint,
                ),
                validator: (String? v) => telefonoOpcional(
                  l10n.registroEmpresaValidacionTelefono,
                )(v ?? ''),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const ValueKey<String>('campo-correo-cuenta'),
                initialValue: perfil.email,
                enabled: false,
                decoration: InputDecoration(
                  labelText: l10n.comunCorreo,
                  helperText: l10n.cuentaEmpresaCorreoNota,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FqButton.primary(
          key: const ValueKey<String>('guardar-cuenta'),
          label: l10n.cuentaEmpresaGuardar,
          loading: _guardando,
          onPressed: _guardando ? null : _guardar,
        ),
        const SizedBox(height: 12),
        FqButton.secondary(
          key: const ValueKey<String>('cerrar-sesion-empresa'),
          label: l10n.perfilCerrarSesion,
          icon: Icons.logout,
          onPressed: widget.onCerrarSesion,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Hasta dos iniciales del nombre comercial ("Cafe El Roble" -> "CE").
  String _iniciales(String nombre) {
    final List<String> partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    final String primera = partes.first.characters.first;
    final String segunda = partes.length > 1 ? partes[1].characters.first : '';
    return (primera + segunda).toUpperCase();
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.foto,
    required this.iniciales,
    required this.subiendo,
    required this.onTap,
  });

  final Uint8List? foto;
  final String iniciales;
  final bool subiendo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('avatar-cuenta'),
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CircleAvatar(
            radius: 52,
            backgroundColor: FqColors.night,
            backgroundImage: foto == null ? null : MemoryImage(foto!),
            child: foto == null
                ? Text(
                    iniciales,
                    key: const ValueKey<String>('avatar-iniciales'),
                    style: const TextStyle(
                      color: FqColors.volt,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  )
                : null,
          ),
          if (subiendo)
            const SizedBox(
              width: 104,
              height: 104,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: FqColors.volt,
                shape: BoxShape.circle,
                border: Border.all(color: FqColors.white, width: 2),
              ),
              child: const Icon(
                Icons.photo_camera,
                size: 16,
                color: FqColors.primaryInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
