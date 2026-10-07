import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/seleccion_widgets.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Modal unificado para editar la información del perfil del usuario
/// (datos personales, deportes favoritos e intereses).
class EditarPerfilModal extends StatefulWidget {
  const EditarPerfilModal({
    super.key,
    required this.usuario,
    this.api,
    this.initialTab = 0,
  });

  final Usuario usuario;
  final PerfilApi? api;
  final int initialTab;

  static const List<(String, IconData)> opcionesActividades = <(String, IconData)>[
    ('Running', Icons.directions_run),
    ('Ciclismo', Icons.directions_bike),
    ('MTB', Icons.pedal_bike),
    ('Hiking', Icons.hiking),
    ('Caminata', Icons.directions_walk),
  ];

  static const List<String> opcionesIntereses = <String>[
    'Rutas nuevas',
    'Eventos',
    'Retos',
    'Naturaleza',
    'Cultura',
    'Comunidad',
  ];

  static Future<bool?> abrir(
    BuildContext context, {
    required Usuario usuario,
    PerfilApi? api,
    int initialTab = 0,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => EditarPerfilModal(
        usuario: usuario,
        api: api,
        initialTab: initialTab,
      ),
      transitionBuilder: (_, Animation<double> anim, _, Widget child) {
        final double t = Curves.easeOutCubic.transform(anim.value);
        return FadeTransition(
          opacity: anim,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: ColoredBox(
              color: const Color(0x5A0B1220),
              child: Transform.scale(scale: 0.95 + 0.05 * t, child: child),
            ),
          ),
        );
      },
    );
  }

  @override
  State<EditarPerfilModal> createState() => _EditarPerfilModalState();
}

class _EditarPerfilModalState extends State<EditarPerfilModal> {
  late final PerfilApi _api = widget.api ?? PerfilApi();

  late int _tabIndex;

  late final TextEditingController _nombre = TextEditingController(
    text: widget.usuario.nombreUser,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.usuario.emailUser,
  );
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  late final Set<String> _actividades = Set<String>.from(widget.usuario.actividades);
  late final Set<String> _intereses = Set<String>.from(widget.usuario.intereses);

  bool _guardando = false;
  bool _forzarError = false;
  bool _cambiarPassword = false;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab.clamp(0, 2);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _cerrar([bool cambio = false]) => Navigator.of(context).pop(cambio);

  void _toggleActividad(String act) {
    setState(() {
      if (_actividades.contains(act)) {
        _actividades.remove(act);
      } else {
        _actividades.add(act);
      }
    });
  }

  void _toggleInteres(String interes) {
    setState(() {
      if (_intereses.contains(interes)) {
        _intereses.remove(interes);
      } else {
        _intereses.add(interes);
      }
    });
  }

  bool _camposValidos() {
    final bool datosBasicos = todoValido(<(String, List<Validador>)>[
      (_nombre.text, reglasNombre()),
      (_email.text, reglasCorreo()),
    ]);

    if (!_cambiarPassword) return datosBasicos;

    final bool passwordValido = todoValido(<(String, List<Validador>)>[
      (_password.text, <Validador>[
        requerido('Ingresa la nueva contraseña'),
        minCaracteres(8),
      ]),
    ]);

    final bool coincide = _password.text == _confirmPassword.text;
    return datosBasicos && passwordValido && coincide;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_camposValidos()) {
      setState(() {
        _forzarError = true;
        _tabIndex = 0; // Cambiar a la pestaña de datos personales si hay error
      });
      if (_cambiarPassword && _password.text != _confirmPassword.text) {
        notificarError('Las contraseñas no coinciden');
      } else {
        notificarError('Revisa los campos de información personal');
      }
      return;
    }

    setState(() => _guardando = true);
    try {
      await _api.actualizarPerfil(
        id: widget.usuario.id,
        nombreUser: _nombre.text.trim(),
        emailUser: _email.text.trim(),
        nuevaContrasena: _cambiarPassword ? _password.text : null,
        actividades: _actividades.toList(),
        intereses: _intereses.toList(),
      );

      if (!mounted) return;
      notificarExito('Perfil actualizado correctamente');
      _cerrar(true);
    } on ApiException catch (e) {
      _fallar(e.message);
    } catch (_) {
      _fallar('No se pudo actualizar el perfil. Revisa tu conexión.');
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    setState(() => _guardando = false);
    notificarError(mensaje);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: FqColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            elevation: 14,
            shadowColor: Colors.black45,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _encabezado(),
                  const SizedBox(height: 14),
                  _selectorTabs(),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: KeyedSubtree(
                      key: ValueKey<int>(_tabIndex),
                      child: _tabContenido(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: FqColors.border),
                  const SizedBox(height: 14),
                  _acciones(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FqColors.volt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            widget.usuario.iniciales,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: FqColors.night,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Editar mi perfil',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: FqColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  FqTag(widget.usuario.etiquetaRol, tone: _tonoRol(widget.usuario.idrol)),
                  const SizedBox(width: 6),
                  Text(
                    widget.usuario.estado,
                    style: const TextStyle(
                      fontSize: 11,
                      color: FqColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _cerrar(),
          icon: const Icon(Icons.close, size: 20),
          color: FqColors.muted,
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }

  Widget _selectorTabs() {
    return Container(
      decoration: BoxDecoration(
        color: FqColors.cloud,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: <Widget>[
          _TabPill(
            icono: Icons.person_outline_rounded,
            label: 'Datos',
            activo: _tabIndex == 0,
            onTap: () => setState(() => _tabIndex = 0),
          ),
          _TabPill(
            icono: Icons.fitness_center_rounded,
            label: 'Deportes',
            contador: _actividades.length,
            activo: _tabIndex == 1,
            onTap: () => setState(() => _tabIndex = 1),
          ),
          _TabPill(
            icono: Icons.interests_outlined,
            label: 'Intereses',
            contador: _intereses.length,
            activo: _tabIndex == 2,
            onTap: () => setState(() => _tabIndex = 2),
          ),
        ],
      ),
    );
  }

  Widget _tabContenido() {
    switch (_tabIndex) {
      case 1:
        return _tabActividades();
      case 2:
        return _tabIntereses();
      default:
        return _tabDatosPersonales();
    }
  }

  Widget _tabDatosPersonales() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CampoTexto(
          label: 'Nombre completo',
          controller: _nombre,
          reglas: reglasNombre(),
          maxCaracteres: kMaxNombreUsuario,
          forzarError: _forzarError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: FqGap.md),
        CampoTexto(
          label: 'Correo electrónico',
          controller: _email,
          reglas: reglasCorreo(),
          maxCaracteres: kMaxCorreoUsuario,
          forzarError: _forzarError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: _cambiarPassword ? TextInputAction.next : TextInputAction.done,
        ),
        const SizedBox(height: FqGap.md),
        InkWell(
          onTap: () => setState(() => _cambiarPassword = !_cambiarPassword),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: _cambiarPassword ? FqColors.choiceSelectedBg : const Color(0xFFF6F8F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _cambiarPassword ? FqColors.voltDark : const Color(0xFFE2E8DE),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  _cambiarPassword ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 19,
                  color: _cambiarPassword ? FqColors.voltDark : FqColors.muted,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Cambiar contraseña de acceso',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FqColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_cambiarPassword) ...<Widget>[
          const SizedBox(height: FqGap.sm),
          CampoTexto(
            label: 'Nueva contraseña',
            controller: _password,
            reglas: <Validador>[
              requerido('Ingresa la contraseña'),
              minCaracteres(8),
            ],
            obscureText: true,
            forzarError: _forzarError,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: FqGap.sm),
          CampoTexto(
            label: 'Confirmar nueva contraseña',
            controller: _confirmPassword,
            reglas: <Validador>[
              requerido('Confirma la contraseña'),
              minCaracteres(8),
            ],
            obscureText: true,
            forzarError: _forzarError,
            textInputAction: TextInputAction.done,
          ),
        ],
      ],
    );
  }

  Widget _tabActividades() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Tus deportes y disciplinas favoritas',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: FqColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Personaliza tus rutas recomendadas y estadísticas.',
          style: TextStyle(fontSize: 11, color: FqColors.muted),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            const double gap = 8;
            final double itemW = (c.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final (String label, IconData icon) in EditarPerfilModal.opcionesActividades)
                  SizedBox(
                    width: itemW,
                    child: ChoiceOption(
                      icon: icon,
                      label: label,
                      selected: _actividades.contains(label),
                      onTap: () => _toggleActividad(label),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _tabIntereses() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Temáticas y metas de interés',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: FqColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Elige lo que más te motiva para descubrir contenidos a tu medida.',
          style: TextStyle(fontSize: 11, color: FqColors.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String opcion in EditarPerfilModal.opcionesIntereses)
              SelectableChip(
                label: opcion,
                selected: _intereses.contains(opcion),
                onTap: () => _toggleInteres(opcion),
              ),
          ],
        ),
      ],
    );
  }

  Widget _acciones() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        FqButton.ghost(
          label: 'Cancelar',
          expand: false,
          onPressed: _guardando ? null : () => _cerrar(),
        ),
        const SizedBox(width: 10),
        FqButton.primary(
          label: 'Guardar cambios',
          icon: Icons.check_rounded,
          expand: false,
          loading: _guardando,
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }

  FqTagTone _tonoRol(int idrol) {
    switch (idrol) {
      case 3:
        return FqTagTone.dark;
      case 2:
        return FqTagTone.amber;
      default:
        return FqTagTone.green;
    }
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.icono,
    required this.label,
    this.contador,
    required this.activo,
    required this.onTap,
  });

  final IconData icono;
  final String label;
  final int? contador;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: activo ? FqColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: activo
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icono,
                size: 15,
                color: activo ? FqColors.night : FqColors.muted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                    color: activo ? FqColors.ink : FqColors.muted,
                  ),
                ),
              ),
              if (contador != null && contador! > 0) ...<Widget>[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: activo ? FqColors.volt : const Color(0xFFD6DFD3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$contador',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: activo ? FqColors.night : FqColors.ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
