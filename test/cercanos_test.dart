import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/home/application/cercanos.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

import 'helpers/datos_mapa.dart';

/// Una ruta que pasa a `grados` de latitud al norte de [latBase], mas lejos en
/// los demas puntos (su inicio y su final).
Ruta _rutaQuePasaA(double grados, {int id = 1}) {
  return rutaDePrueba(
    id: id,
    puntos: <PuntoRuta>[
      PuntoRuta(lat: latBase + 0.05, lng: lngBase),
      PuntoRuta(lat: latBase + grados, lng: lngBase),
      PuntoRuta(lat: latBase + 0.06, lng: lngBase),
    ],
  );
}

void main() {
  group('rutaMasCercana', () {
    test('sin rutas no hay ninguna cerca', () {
      expect(
        rutaMasCercana(lat: latBase, lng: lngBase, rutas: const <Ruta>[]),
        isNull,
      );
    });

    test('la distancia es al punto mas cercano del trazo, no a su inicio', () {
      final RutaCercana? cerca = rutaMasCercana(
        lat: latBase,
        lng: lngBase,
        rutas: <Ruta>[_rutaQuePasaA(0.002)],
      );

      expect(cerca, isNotNull);
      expect(cerca!.metros, closeTo(222, 3));
    });

    test('elige la ruta cuyo trazo pasa mas cerca', () {
      final Ruta lejana = _rutaQuePasaA(0.005, id: 1);
      final Ruta cercana = _rutaQuePasaA(0.001, id: 2);

      final RutaCercana? cerca = rutaMasCercana(
        lat: latBase,
        lng: lngBase,
        rutas: <Ruta>[lejana, cercana],
      );

      expect(cerca?.ruta.id, 2);
    });

    test('ignora las rutas fuera del radio', () {
      final Ruta enOtraCiudad = rutaDePrueba(
        puntos: const <PuntoRuta>[
          PuntoRuta(lat: latBase + 0.5, lng: lngBase),
          PuntoRuta(lat: latBase + 0.51, lng: lngBase),
        ],
      );

      expect(
        rutaMasCercana(lat: latBase, lng: lngBase, rutas: <Ruta>[enOtraCiudad]),
        isNull,
      );
    });

    test('el radio se puede cambiar', () {
      final Ruta ruta = _rutaQuePasaA(0.002);

      expect(
        rutaMasCercana(
          lat: latBase,
          lng: lngBase,
          rutas: <Ruta>[ruta],
          radioMetros: 100,
        ),
        isNull,
      );
      expect(
        rutaMasCercana(
          lat: latBase,
          lng: lngBase,
          rutas: <Ruta>[ruta],
          radioMetros: 300,
        ),
        isNotNull,
      );
    });

    test('ignora las rutas sin trazo', () {
      final Ruta sinPuntos = rutaDePrueba(puntos: const <PuntoRuta>[]);

      expect(
        rutaMasCercana(lat: latBase, lng: lngBase, rutas: <Ruta>[sinPuntos]),
        isNull,
      );
    });
  });

  group('alertaMasCercana', () {
    test('sin alertas no hay ninguna cerca', () {
      expect(alertaMasCercana(lat: latBase, lng: lngBase, alertas: []), isNull);
    });

    test('elige la mas cercana y dice a cuantos metros esta', () {
      final AlertaCercana? cerca = alertaMasCercana(
        lat: latBase,
        lng: lngBase,
        alertas: [
          alertaDePrueba(id: 1, lat: latBase + 0.01),
          alertaDePrueba(id: 2, lat: latBase + 0.003),
        ],
      );

      expect(cerca?.alerta.id, 2);
      expect(cerca!.metros, closeTo(333, 3));
    });

    test('solo cuentan las alertas activas', () {
      final AlertaCercana? cerca = alertaMasCercana(
        lat: latBase,
        lng: lngBase,
        alertas: [
          alertaDePrueba(id: 1, estado: 'Resuelta'),
          alertaDePrueba(id: 2, estado: 'Expirada'),
          alertaDePrueba(id: 3, lat: latBase + 0.002),
        ],
      );

      expect(cerca?.alerta.id, 3);
    });

    test('ignora las alertas fuera del radio', () {
      expect(
        alertaMasCercana(
          lat: latBase,
          lng: lngBase,
          alertas: [alertaDePrueba(lat: latBase + 0.5)],
        ),
        isNull,
      );
    });
  });
}
