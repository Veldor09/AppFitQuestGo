import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/detalle_usuario/directorio_usuarios_screen.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuarios_api.dart';

class _UsuariosApiFalsa extends UsuariosApi {
  @override
  Future<List<Usuario>> list() async => const <Usuario>[
    Usuario(
      id: 1,
      nombreUser: 'Nombre de usuario muy largo en una pantalla pequeña',
      emailUser: 'correo.muy.largo@empresa-ejemplo.com',
      idrol: 1,
    ),
  ];
}

void main() {
  testWidgets('directorio y filtros caben en un teléfono', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DirectorioUsuariosScreen(api: _UsuariosApiFalsa()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
