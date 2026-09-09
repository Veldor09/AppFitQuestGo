import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';

/// Campo de texto con validacion en vivo.
///
/// - Debajo del campo, en rojo, muestra el primer error de [reglas] **en cuanto
///   el usuario escribe** algo incorrecto (o siempre, si [forzarError] es true,
///   p. ej. tras intentar guardar).
/// - En la esquina inferior derecha, fuera del recuadro, muestra el contador
///   `n/[maxCaracteres]` cuando se define un limite.
/// - El limite se aplica de forma dura: no deja escribir mas alla de
///   [maxCaracteres].
class CampoTexto extends StatefulWidget {
  const CampoTexto({
    super.key,
    required this.label,
    required this.controller,
    this.reglas = const <Validador>[],
    this.maxCaracteres,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.forzarError = false,
    this.habilitado = true,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final List<Validador> reglas;
  final int? maxCaracteres;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool forzarError;
  final bool habilitado;
  final String? hintText;

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  bool _tocado = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_alCambiar);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (!mounted) return;
    setState(() => _tocado = true);
  }

  String? get _error => primeraFalla(widget.controller.text, widget.reglas);

  bool get _mostrarError =>
      (_tocado || widget.forzarError) && _error != null;

  @override
  Widget build(BuildContext context) {
    final int largo = widget.controller.text.characters.length;
    final bool conError = _mostrarError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: FqColors.white,
            borderRadius: FqRadius.allMd,
            border: Border.all(
              color: conError ? FqColors.risk : FqColors.fieldBorder,
              width: conError ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: FqColors.fieldLabel,
                ),
              ),
              TextField(
                controller: widget.controller,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                autofillHints: widget.autofillHints,
                enabled: widget.habilitado,
                onSubmitted: widget.onSubmitted,
                inputFormatters: widget.maxCaracteres == null
                    ? null
                    : <TextInputFormatter>[
                        LengthLimitingTextInputFormatter(widget.maxCaracteres),
                      ],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FqColors.ink,
                ),
                cursorColor: FqColors.voltDark,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(
                    color: FqColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: conError
                    ? Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          color: FqColors.risk,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (widget.maxCaracteres != null)
                Text(
                  '$largo/${widget.maxCaracteres}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: largo >= widget.maxCaracteres!
                        ? FqColors.risk
                        : FqColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
