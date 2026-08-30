import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_field_display.dart';
import 'package:fit_quest_go/core/widgets/fq_panel.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_note.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuarios_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/widgets/usuario_form_dialog.dart';

/// ADM-03 · Detalle de usuario. Pantalla **funcional**: carga la cuenta real
/// con `GET /usuarios/:id` y permite editarla o eliminarla.
///
/// El diseno muestra un bloque de "Actividad" (km, rutas, alertas); como el
/// backend aun no expone esas metricas, ese panel se sustituye por los datos
/// reales de la cuenta y una nota de lo que llegara despues.
class UsuarioDetalleScreen extends StatefulWidget {
  const UsuarioDetalleScreen({
    super.key,
    required this.usuarioId,
    this.api,
  });

  final int usuarioId;

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final UsuariosApi? api;

  @override
  State<UsuarioDetalleScreen> createState() => _UsuarioDetalleScreenState();
}

class _UsuarioDetalleScreenState extends State<UsuarioDetalleScreen> {
  late final UsuariosApi _api = widget.api ?? UsuariosApi();
  late Future<Usuario> _futuro;
  bool _huboCambios = false;

  @override
  void initState() {
    super.initState();
    _futuro = _api.getById(widget.usuarioId);
  }

  void _recargar() {
    setState(() => _futuro = _api.getById(widget.usuarioId));
  }

  Future<void> _editar(Usuario u) async {
    final bool? ok =
        await UsuarioFormDialog.mostrar(context, usuario: u, api: _api);
    if (!mounted) return;
    if (ok == true) {
      _huboCambios = true;
      _recargar();
    }
  }

  Future<void> _eliminar(Usuario u) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('Se eliminara la cuenta de ${u.nombreUser}.'),
        actions: <Widget>[
          FqButton.ghost(
            label: 'Cancelar',
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          FqButton.danger(
            label: 'Eliminar',
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _api.remove(u.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _avisar(e.message);
    } catch (_) {
      _avisar('No se pudo eliminar.');
    }
  }

  void _avisar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) Navigator.of(context).pop(_huboCambios);
      },
      child: Scaffold(
        backgroundColor: FqColors.adminBg,
        body: Column(
          children: <Widget>[
            _Header(onBack: () => Navigator.of(context).pop(_huboCambios)),
            Expanded(
              child: FutureBuilder<Usuario>(
                future: _futuro,
                builder: (BuildContext context, AsyncSnapshot<Usuario> snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              snap.error is ApiException
                                  ? (snap.error! as ApiException).message
                                  : 'No se pudo cargar el usuario.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FqButton.secondary(
                              label: 'Reintentar',
                              expand: false,
                              onPressed: _recargar,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return _Contenido(
                    usuario: snap.data!,
                    onEditar: _editar,
                    onEliminar: _eliminar,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      color: FqColors.night,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            color: FqColors.white,
            splashRadius: 18,
          ),
          const SizedBox(width: 4),
          const Text(
            'Detalle de usuario',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: FqColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.usuario,
    required this.onEditar,
    required this.onEliminar,
  });

  final Usuario usuario;
  final void Function(Usuario) onEditar;
  final void Function(Usuario) onEliminar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final Widget resumen = _ResumenPanel(
            usuario: usuario,
            onEditar: () => onEditar(usuario),
            onEliminar: () => onEliminar(usuario),
          );
          final Widget datos = _DatosPanel(usuario: usuario);

          if (c.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                resumen,
                const SizedBox(height: FqGap.lg),
                datos,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 7, child: resumen),
              const SizedBox(width: FqGap.lg),
              Expanded(flex: 13, child: datos),
            ],
          );
        },
      ),
    );
  }
}

class _ResumenPanel extends StatelessWidget {
  const _ResumenPanel({
    required this.usuario,
    required this.onEditar,
    required this.onEliminar,
  });

  final Usuario usuario;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return FqPanel(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
              usuario.iniciales,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: FqColors.night,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            usuario.nombreUser,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: FqColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            usuario.emailUser,
            style: const TextStyle(fontSize: 9, color: FqColors.muted),
          ),
          const SizedBox(height: 8),
          FqTag(
            usuario.nombreRol,
            tone: usuario.idrol == 3 ? FqTagTone.dark : FqTagTone.green,
          ),
          const SizedBox(height: FqGap.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: FqButton.secondary(
                  label: 'Editar',
                  dense: true,
                  onPressed: onEditar,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FqButton.danger(
                  label: 'Eliminar',
                  dense: true,
                  onPressed: onEliminar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatosPanel extends StatelessWidget {
  const _DatosPanel({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return FqPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'Datos de la cuenta',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          FqFieldDisplay(label: 'ID', value: usuario.id.toString()),
          const SizedBox(height: FqGap.md),
          FqFieldDisplay(label: 'Nombre', value: usuario.nombreUser),
          const SizedBox(height: FqGap.md),
          FqFieldDisplay(label: 'Correo', value: usuario.emailUser),
          const SizedBox(height: FqGap.md),
          FqFieldDisplay(
            label: 'Rol',
            value: '${usuario.nombreRol} (id ${usuario.idrol})',
          ),
          const SizedBox(height: FqGap.lg),
          const AdminNote(
            title: 'Historial, aportes y reportes',
            detail:
                'El resumen de actividad (km, rutas, alertas y denuncias) se '
                'mostrara aqui cuando el backend exponga esas metricas.',
            icon: Icons.insights_outlined,
            tone: AdminNoteTone.info,
          ),
        ],
      ),
    );
  }
}
