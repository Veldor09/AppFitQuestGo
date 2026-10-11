import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mapbox pone por defecto una brujula negra y una barra de escala encima de
/// cada mapa. La app las apaga con `ocultarAdornos`, que hay que llamar al
/// crear cada mapa. Esta prueba recorre el codigo y avisa si alguien agrega un
/// `MapWidget` nuevo y se olvida de llamarla.
void main() {
  final List<File> archivos = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  final List<File> conMapa = <File>[
    for (final File f in archivos)
      if (f.readAsStringSync().contains('MapWidget(')) f,
  ];

  test('hay mapas en el codigo (la prueba no esta mirando al vacio)', () {
    expect(conMapa.length, greaterThanOrEqualTo(6));
  });

  for (final File f in conMapa) {
    final String nombre = f.path.replaceAll(r'\', '/');
    test('$nombre apaga la brujula y la escala al crear su mapa', () {
      expect(
        f.readAsStringSync(),
        contains('ocultarAdornos('),
        reason: '$nombre crea un MapWidget pero no llama a ocultarAdornos()',
      );
    });
  }

  test(
    'ocultarAdornos apaga la brujula y la escala, y deja el logo de Mapbox',
    () {
      final String fuente = File(
        'lib/core/mapa/adornos_mapa.dart',
      ).readAsStringSync();
      expect(fuente, contains('CompassSettings(enabled: false)'));
      expect(fuente, contains('ScaleBarSettings(enabled: false)'));
      // El logo y la atribucion los exigen los terminos de uso de Mapbox.
      expect(fuente, isNot(contains('LogoSettings')));
      expect(fuente, isNot(contains('AttributionSettings')));
    },
  );
}
