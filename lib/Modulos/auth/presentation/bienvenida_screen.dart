import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_brand_mark.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/login_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/registro_flujo.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/auth_layout.dart';

/// APP-02 · Bienvenida.
/// Punto de entrada sin sesion: elegir entre crear cuenta o iniciar sesion.
class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 26),
            child: AuthHero(
              leading: FqBrandMark(),
              tagLabel: 'Muevete con tu ciudad',
              title: 'Tu proxima aventura comienza cerca.',
              subtitle:
                  'Descubre rutas, comparte alertas y activa a tu comunidad.',
            ),
          ),
          const SizedBox(height: 40),
          const Spacer(),
          FqButton.primary(
            label: 'Crear cuenta',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const RegistroFlujoScreen(),
              ),
            ),
          ),
          const SizedBox(height: FqGap.md),
          FqButton.secondary(
            label: 'Iniciar sesion',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            ),
          ),
          const SizedBox(height: FqGap.md),
          const Center(
            child: Text(
              'Al continuar aceptas los Terminos y la Politica de privacidad.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Color(0xFF67726D)),
            ),
          ),
        ],
      ),
    );
  }
}
