import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/app.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_api.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/bienvenida_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/empresa_shell.dart';

import 'helpers/montar.dart';

UsuarioSesion _usuario(int rol) => UsuarioSesion(
  id: 1,
  nombre: 'Cafe El Roble',
  email: 'contacto@elroble.co',
  rol: rol,
);

/// Abre la pantalla encima de un "inicio", como cuando se llega desde la bienvenida.
Future<AuthFalso> _abrir(WidgetTester tester, {AuthFalso? auth}) async {
  final AuthFalso falso = auth ?? AuthFalso();
  await montarApp(
    tester,
    Builder(
      builder: (BuildContext context) => TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const RegistroEmpresaScreen(),
          ),
        ),
        child: const Text('abrir'),
      ),
    ),
    auth: falso,
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return falso;
}

/// Los campos del formulario, en el orden en que se ven: nombre comercial,
/// correo, telefono y contrasena (`CampoTexto` pinta la etiqueta aparte).
Finder _campo(String etiqueta) {
  const List<String> orden = <String>[
    'Nombre comercial',
    'Correo',
    'Telefono (opcional)',
    'Contrasena',
  ];
  return find.byType(TextField).at(orden.indexOf(etiqueta));
}

Future<void> _llenarValido(WidgetTester tester) async {
  await tester.enterText(_campo('Nombre comercial'), '  Cafe El Roble  ');
  await tester.enterText(_campo('Correo'), 'contacto@elroble.co');
  await tester.enterText(_campo('Telefono (opcional)'), '8888-8888');
  await tester.enterText(_campo('Contrasena'), 'contrasena123');
  await tester.pump();
}

Future<void> _marcarTerminos(WidgetTester tester) async {
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
}

Future<void> _crear(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey<String>('crear-cuenta-empresa')),
  );
  await tester.tap(find.byKey(const ValueKey<String>('crear-cuenta-empresa')));
  await tester.pumpAndSettle();
}

void main() {
  group('RegistroEmpresaScreen', () {
    testWidgets('con todo vacio no envia y marca los campos', (
      WidgetTester tester,
    ) async {
      final AuthFalso auth = await _abrir(tester);
      await _marcarTerminos(tester);
      await _crear(tester);

      expect(auth.empresasRegistradas, isEmpty);
      expect(find.text('Revisa los campos marcados en rojo'), findsOneWidget);
      expect(find.text('El nombre comercial es obligatorio'), findsWidgets);
    });

    testWidgets('sin aceptar los terminos no envia', (
      WidgetTester tester,
    ) async {
      final AuthFalso auth = await _abrir(tester);
      await _llenarValido(tester);
      await _crear(tester);

      expect(auth.empresasRegistradas, isEmpty);
      expect(
        find.text('Debes aceptar los terminos y condiciones para continuar'),
        findsOneWidget,
      );
    });

    testWidgets('un telefono invalido bloquea el envio', (
      WidgetTester tester,
    ) async {
      final AuthFalso auth = await _abrir(tester);
      await _llenarValido(tester);
      await tester.enterText(_campo('Telefono (opcional)'), '123');
      await _marcarTerminos(tester);
      await _crear(tester);

      expect(auth.empresasRegistradas, isEmpty);
      expect(
        find.text('Telefono invalido: usa de 8 a 20 digitos'),
        findsOneWidget,
      );
    });

    testWidgets('el telefono es opcional: vacio se acepta', (
      WidgetTester tester,
    ) async {
      final AuthFalso auth = await _abrir(tester);
      await _llenarValido(tester);
      await tester.enterText(_campo('Telefono (opcional)'), '');
      await _marcarTerminos(tester);
      await _crear(tester);

      expect(auth.empresasRegistradas, hasLength(1));
    });

    testWidgets('una contrasena corta bloquea el envio', (
      WidgetTester tester,
    ) async {
      final AuthFalso auth = await _abrir(tester);
      await _llenarValido(tester);
      await tester.enterText(_campo('Contrasena'), 'corta');
      await _marcarTerminos(tester);
      await _crear(tester);

      expect(auth.empresasRegistradas, isEmpty);
    });

    testWidgets('datos validos: crea la cuenta, avisa y cierra la pantalla', (
      WidgetTester tester,
    ) async {
      final AuthFalso auth = await _abrir(tester);
      await _llenarValido(tester);
      await _marcarTerminos(tester);
      await _crear(tester);

      expect(auth.empresasRegistradas, hasLength(1));
      final Map<String, Object?> enviado = auth.empresasRegistradas.single;
      expect(
        enviado['nombreComercial'],
        'Cafe El Roble',
      ); // sin espacios sobrantes
      expect(enviado['email'], 'contacto@elroble.co');
      expect(enviado['contrasena'], 'contrasena123');
      expect(enviado['telefono'], '8888-8888');
      expect(enviado['aceptaTerminos'], isTrue);
      expect(find.byType(RegistroEmpresaScreen), findsNothing);
      expect(find.text('Cuenta de empresa creada'), findsOneWidget);
      expect(auth.usuario?.esEmpresa, isTrue);
    });

    testWidgets('un correo repetido (409) lo dice y deja corregir', (
      WidgetTester tester,
    ) async {
      final AuthFalso auth = AuthFalso()
        ..errorAlRegistrar = ApiException(409, 'duplicado');
      await _abrir(tester, auth: auth);
      await _llenarValido(tester);
      await _marcarTerminos(tester);
      await _crear(tester);

      expect(find.byType(RegistroEmpresaScreen), findsOneWidget);
      expect(
        find.text('Ese correo ya tiene una cuenta. Inicia sesion.'),
        findsOneWidget,
      );
    });

    testWidgets('un fallo de red muestra el mensaje de conexion', (
      WidgetTester tester,
    ) async {
      final AuthFalso auth = AuthFalso()
        ..errorAlRegistrar = Exception('sin red');
      await _abrir(tester, auth: auth);
      await _llenarValido(tester);
      await _marcarTerminos(tester);
      await _crear(tester);

      expect(find.byType(RegistroEmpresaScreen), findsOneWidget);
      expect(auth.empresasRegistradas, isEmpty);
      expect(
        find.text('No se pudo crear la cuenta. Revisa tu conexion.'),
        findsOneWidget,
      );
    });
  });

  group('AuthApi.registrarEmpresa', () {
    test(
      'envia nombreComercial, telefono y POST /auth/registro-empresa',
      () async {
        final List<Peticion> reg = <Peticion>[];
        final AuthApi api = AuthApi(
          apiFalso(
            reg,
            (Peticion _) => (
              cuerpo: <String, dynamic>{
                'usuario': <String, dynamic>{
                  'id': 9,
                  'nombre': 'Cafe El Roble',
                  'email': 'a@b.co',
                  'rol': 2,
                },
                'accessToken': 'a',
                'refreshToken': 'r',
              },
              estado: 201,
            ),
          ),
        );

        final Sesion sesion = await api.registrarEmpresa(
          nombreComercial: 'Cafe El Roble',
          email: 'a@b.co',
          contrasena: 'contrasena123',
          aceptaTerminos: true,
          telefono: ' 8888-8888 ',
        );

        expect(reg.single.toString(), 'POST /auth/registro-empresa');
        expect(reg.single.cuerpo, <String, dynamic>{
          'nombreComercial': 'Cafe El Roble',
          'email': 'a@b.co',
          'contrasena': 'contrasena123',
          'aceptaTerminos': true,
          'telefono': '8888-8888',
        });
        expect(sesion.usuario.esEmpresa, isTrue);
      },
    );

    test('sin telefono no lo envia', () async {
      final List<Peticion> reg = <Peticion>[];
      final AuthApi api = AuthApi(
        apiFalso(
          reg,
          (Peticion _) => (
            cuerpo: <String, dynamic>{
              'usuario': <String, dynamic>{
                'id': 9,
                'nombre': 'X',
                'email': 'a@b.co',
                'rol': 2,
              },
              'accessToken': 'a',
              'refreshToken': 'r',
            },
            estado: 201,
          ),
        ),
      );
      await api.registrarEmpresa(
        nombreComercial: 'X',
        email: 'a@b.co',
        contrasena: 'contrasena123',
        aceptaTerminos: true,
        telefono: '  ',
      );
      expect(jsonEncode(reg.single.cuerpo), isNot(contains('telefono')));
    });
  });

  group('pantallaRaizDe (que panel abre cada rol)', () {
    test('admin -> panel de administracion', () {
      expect(pantallaRaizDe(_usuario(RolUsuario.admin)), PantallaRaiz.admin);
    });

    test('empresa -> panel de empresa', () {
      expect(
        pantallaRaizDe(_usuario(RolUsuario.empresa)),
        PantallaRaiz.empresa,
      );
    });

    test('usuario normal -> app del deportista', () {
      expect(
        pantallaRaizDe(_usuario(RolUsuario.userNormal)),
        PantallaRaiz.usuario,
      );
    });

    test('un rol desconocido tambien entra como deportista, no como admin', () {
      expect(pantallaRaizDe(_usuario(99)), PantallaRaiz.usuario);
    });

    test('esEmpresa solo es verdadero para el rol 2', () {
      expect(_usuario(2).esEmpresa, isTrue);
      expect(_usuario(1).esEmpresa, isFalse);
      expect(_usuario(3).esEmpresa, isFalse);
    });
  });

  group('Bienvenida', () {
    testWidgets('"Tengo un comercio" abre el registro de empresa', (
      WidgetTester tester,
    ) async {
      await montarApp(tester, const BienvenidaScreen());

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('soy-comercio')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('soy-comercio')));
      await tester.pumpAndSettle();

      expect(find.byType(RegistroEmpresaScreen), findsOneWidget);
    });
  });

  group('EmpresaShell', () {
    Widget pagina(String t) => Text(t);

    testWidgets('tiene cuatro pestañas y abre en el Mapa', (
      WidgetTester tester,
    ) async {
      await montarApp(
        tester,
        EmpresaShell(
          paginas: <Widget>[
            pagina('pag-mapa'),
            pagina('pag-eventos'),
            pagina('pag-nodos'),
            pagina('pag-cuenta'),
          ],
        ),
      );

      // La primera pantalla es el mapa.
      expect(find.text('pag-mapa'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('nav-empresa')),
          matching: find.text('Mapa'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('cambia entre Mapa, Eventos, Nodos y Cuenta', (
      WidgetTester tester,
    ) async {
      await montarApp(
        tester,
        EmpresaShell(
          paginas: <Widget>[
            pagina('pag-mapa'),
            pagina('pag-eventos'),
            pagina('pag-nodos'),
            pagina('pag-cuenta'),
          ],
        ),
      );

      Future<void> ir(String etiqueta, String pagina) async {
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey<String>('nav-empresa')),
            matching: find.text(etiqueta),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(pagina), findsOneWidget);
      }

      await ir('Eventos', 'pag-eventos');
      await ir('Nodos', 'pag-nodos');
      await ir('Cuenta', 'pag-cuenta');
      await ir('Mapa', 'pag-mapa');
    });
  });
}
