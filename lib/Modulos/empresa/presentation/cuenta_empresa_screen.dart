import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';

/// Panel de la empresa · "Cuenta": quien esta conectado y como cerrar sesion.
class CuentaEmpresaScreen extends StatelessWidget {
  const CuentaEmpresaScreen({super.key, required this.onCerrarSesion});

  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final UsuarioSesion? usuario = AuthScope.maybeOf(context)?.usuario;
    return ColoredBox(
      color: FqColors.paper,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(FqGap.xl),
          children: <Widget>[
            Text(
              l10n.cuentaEmpresaTitulo,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FqColors.white,
                borderRadius: FqRadius.allLg,
                border: Border.all(color: FqColors.border),
              ),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: FqColors.night,
                    child: Text(
                      usuario?.iniciales ?? '?',
                      style: const TextStyle(
                        color: FqColors.volt,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          usuario?.nombre.isNotEmpty == true
                              ? usuario!.nombre
                              : l10n.cuentaEmpresaSinNombre,
                          key: const ValueKey<String>('cuenta-nombre'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (usuario != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            usuario.email,
                            key: const ValueKey<String>('cuenta-email'),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: FqColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FqButton.secondary(
              key: const ValueKey<String>('cerrar-sesion-empresa'),
              label: l10n.perfilCerrarSesion,
              icon: Icons.logout,
              onPressed: onCerrarSesion,
            ),
          ],
        ),
      ),
    );
  }
}
