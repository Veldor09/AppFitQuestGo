import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:fit_quest_go/core/voz/aviso_voz.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel canal = MethodChannel('flutter_tts');
  late List<MethodCall> llamadas;
  late Object? Function(MethodCall) respuesta;

  setUp(() {
    llamadas = <MethodCall>[];
    respuesta = (MethodCall _) => 1;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (MethodCall llamada) async {
      llamadas.add(llamada);
      return respuesta(llamada);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  group('etiquetaDeVoz', () {
    test('mapea los idiomas de la app a etiquetas del motor de voz', () {
      expect(etiquetaDeVoz(const Locale('es')), 'es-ES');
      expect(etiquetaDeVoz(const Locale('en')), 'en-US');
      expect(etiquetaDeVoz(const Locale('pt', 'BR')), 'pt-BR');
      expect(etiquetaDeVoz(const Locale('pt')), 'pt-BR');
    });

    test('un idioma desconocido cae en espanol', () {
      expect(etiquetaDeVoz(const Locale('fr')), 'es-ES');
    });
  });

  group('AvisoVozTts', () {
    test('fija el idioma y luego habla el texto', () async {
      final AvisoVozTts voz = AvisoVozTts(FlutterTts());

      await voz.decir('Atencion: bache', idioma: const Locale('es'));

      final List<String> metodos = llamadas.map((MethodCall c) => c.method).toList();
      expect(metodos, containsAllInOrder(<String>['setLanguage', 'speak']));
      final MethodCall idioma = llamadas.firstWhere((MethodCall c) => c.method == 'setLanguage');
      expect(idioma.arguments, 'es-ES');
      final MethodCall habla = llamadas.firstWhere((MethodCall c) => c.method == 'speak');
      expect(habla.arguments.toString(), contains('Atencion: bache'));
    });

    test('habla en el idioma de la app', () async {
      final AvisoVozTts voz = AvisoVozTts(FlutterTts());

      await voz.decir('Heads up', idioma: const Locale('en'));

      final MethodCall idioma = llamadas.firstWhere((MethodCall c) => c.method == 'setLanguage');
      expect(idioma.arguments, 'en-US');
    });

    test('sin motor de voz no lanza (el aviso en pantalla sigue)', () async {
      respuesta = (MethodCall _) => throw PlatformException(code: 'sin_motor');
      final AvisoVozTts voz = AvisoVozTts(FlutterTts());

      await expectLater(
        voz.decir('Atencion', idioma: const Locale('es')),
        completes,
      );
      await expectLater(voz.detener(), completes);
    });

    test('detener corta la voz', () async {
      final AvisoVozTts voz = AvisoVozTts(FlutterTts());

      await voz.detener();

      expect(llamadas.map((MethodCall c) => c.method), contains('stop'));
    });
  });
}
