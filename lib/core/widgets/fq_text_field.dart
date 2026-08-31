import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Campo editable con la estetica de `.fq-field`: etiqueta pequena arriba y el
/// valor debajo, dentro de un contenedor con borde de 1px y esquinas de 10px.
///
/// Se usa en las pantallas que SI funcionan (login y registro) para mantener la
/// fidelidad visual sin renunciar a un `TextFormField` real y validable.
class FqTextField extends StatelessWidget {
  const FqTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.autofillHints,
    this.enabled = true,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: FqRadius.allMd,
        border: Border.all(color: FqColors.fieldBorder),
      ),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: FqColors.fieldLabel,
            ),
          ),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            validator: validator,
            autofillHints: autofillHints,
            enabled: enabled,
            onFieldSubmitted: onFieldSubmitted,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: FqColors.ink,
            ),
            cursorColor: FqColors.voltDark,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintText: hintText,
              hintStyle: const TextStyle(
                color: FqColors.muted,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorStyle: const TextStyle(fontSize: 10, height: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}
