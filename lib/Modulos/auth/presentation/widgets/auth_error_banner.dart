import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Aviso de error en linea para los formularios de autenticacion.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE2DC),
        borderRadius: FqRadius.allMd,
        border: Border.all(color: const Color(0xFFF2C4BA)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, size: 16, color: FqColors.risk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Color(0xFFB83E28),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
