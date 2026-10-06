import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/catalogos/tipos_alerta.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

const List<Locale> _idiomas = <Locale>[
  Locale('es'),
  Locale('en'),
  Locale('pt', 'BR'),
];

void main() {
  // Las claves son un contrato con el backend (enums TipoAlerta, ActividadRuta
  // y CategoriaNodo): si cambian aqui, tienen que cambiar alla.
  group('claves (contrato con el backend)', () {
    test('actividades de ruta', () {
      expect(
        actividadesRuta.map((OpcionCatalogo o) => o.clave).toList(),
        <String>['running', 'ciclismo', 'mtb', 'hiking', 'caminata', 'otro'],
      );
    });

    test('tipos de alerta', () {
      expect(
        tiposAlerta.map((OpcionCatalogo o) => o.clave).toList(),
        <String>[
          'arbol_caido',
          'bache',
          'derrumbe',
          'inundacion',
          'perro',
          'via_cerrada',
          'accidente',
          'zona_insegura',
          'cable_caido',
          'otro',
        ],
      );
    });

    test('categorias de nodo', () {
      expect(
        categoriasNodo.map((OpcionCatalogo o) => o.clave).toList(),
        <String>[
          'agua',
          'mirador',
          'taller',
          'restaurante',
          'comercio',
          'banos',
          'parqueo',
          'primeros_auxilios',
          'otro',
        ],
      );
    });

    test('"otro" es siempre la ultima opcion', () {
      expect(actividadesRuta.last.clave, 'otro');
      expect(tiposAlerta.last.clave, 'otro');
      expect(categoriasNodo.last.clave, 'otro');
    });
  });

  group('etiquetas traducidas', () {
    for (final Locale idioma in _idiomas) {
      test('cada clave tiene etiqueta en $idioma', () {
        final AppLocalizations l10n = lookupAppLocalizations(idioma);
        for (final OpcionCatalogo o in actividadesRuta) {
          expect(actividadLabel(l10n, o.clave).trim(), isNotEmpty);
          expect(actividadLabel(l10n, o.clave), isNot(o.clave));
        }
        for (final OpcionCatalogo o in tiposAlerta) {
          expect(tipoAlertaLabel(l10n, o.clave).trim(), isNotEmpty);
          expect(tipoAlertaLabel(l10n, o.clave), isNot(o.clave));
        }
        for (final OpcionCatalogo o in categoriasNodo) {
          expect(categoriaNodoLabel(l10n, o.clave).trim(), isNotEmpty);
          expect(categoriaNodoLabel(l10n, o.clave), isNot(o.clave));
        }
      });
    }

    test('ejemplos concretos en cada idioma', () {
      final AppLocalizations es = lookupAppLocalizations(const Locale('es'));
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations pt = lookupAppLocalizations(const Locale('pt', 'BR'));

      expect(tipoAlertaLabel(es, 'arbol_caido'), 'Arbol caido');
      expect(tipoAlertaLabel(en, 'arbol_caido'), 'Fallen tree');
      expect(tipoAlertaLabel(pt, 'arbol_caido'), 'Arvore caida');
      expect(categoriaNodoLabel(en, 'banos'), 'Restrooms');
      expect(actividadLabel(pt, 'caminata'), 'Caminhada');
    });
  });

  group('tipoAlertaLabel / categoriaNodoLabel', () {
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('es'));

    test('con "otro" muestra lo que escribio la persona', () {
      expect(tipoAlertaLabel(l10n, 'otro', otro: 'Poste inclinado'), 'Poste inclinado');
      expect(categoriaNodoLabel(l10n, 'otro', otro: 'Zona de picnic'), 'Zona de picnic');
    });

    test('con "otro" sin texto cae en la etiqueta generica', () {
      expect(tipoAlertaLabel(l10n, 'otro'), 'Otro');
      expect(tipoAlertaLabel(l10n, 'otro', otro: '  '), 'Otro');
    });

    test('el texto "otro" se ignora si la clave es del catalogo', () {
      expect(tipoAlertaLabel(l10n, 'bache', otro: 'ignorame'), 'Bache');
    });

    test('una clave desconocida (dato viejo) se muestra tal cual, sin romper', () {
      expect(tipoAlertaLabel(l10n, 'Arbol caido'), 'Arbol caido');
      expect(categoriaNodoLabel(l10n, 'Agua potable'), 'Agua potable');
      expect(actividadLabel(l10n, 'Kayak'), 'Kayak');
    });
  });

  group('actividadesLabel', () {
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('es'));

    test('une varias con coma, en el orden dado', () {
      expect(
        actividadesLabel(l10n, <String>['running', 'ciclismo']),
        'Running, Ciclismo',
      );
    });

    test('una sola', () {
      expect(actividadesLabel(l10n, <String>['hiking']), 'Hiking');
    });

    test('lista vacia no rompe', () {
      expect(actividadesLabel(l10n, <String>[]), '');
    });
  });

  group('colorCategoriaNodo', () {
    test('conserva los colores que ya tenian los pines', () {
      expect(colorCategoriaNodo('agua'), FqColors.river);
      expect(colorCategoriaNodo('mirador'), FqColors.amber);
      expect(colorCategoriaNodo('restaurante'), FqColors.pink);
      expect(colorCategoriaNodo('comercio'), FqColors.pink);
    });

    test('el resto (y lo desconocido) usa el color por defecto', () {
      expect(colorCategoriaNodo('banos'), FqColors.trail);
      expect(colorCategoriaNodo('lo-que-sea'), FqColors.trail);
    });

    test('ninguna categoria usa el rojo de las alertas', () {
      for (final OpcionCatalogo o in categoriasNodo) {
        expect(colorCategoriaNodo(o.clave), isNot(FqColors.risk));
      }
    });
  });
}
