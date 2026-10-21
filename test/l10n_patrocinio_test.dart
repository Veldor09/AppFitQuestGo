import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations_en.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations_es.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations_pt.dart';

void main() {
  void comprobar(
    AppLocalizations l10n,
    List<String> esperado,
  ) {
    expect(<String>[
      l10n.patrocinioDestacar,
      l10n.patrocinioDestacado,
      l10n.patrocinioSinPlan,
      l10n.patrocinioTope,
      l10n.patrocinioNoElegible,
      l10n.patrocinioErrorDestacar,
      l10n.patrocinioCercaTitulo,
    ], esperado);
  }

  test('textos de patrocinio en espanol', () {
    comprobar(AppLocalizationsEs(), <String>[
      'Destacar en el mapa',
      'Destacado',
      'Necesitas un plan de patrocinio vigente para destacar.',
      'Llegaste al maximo de destacados activos. Apaga alguno para destacar este.',
      'Este contenido no se puede destacar.',
      'No se pudo cambiar el destacado.',
      'Destacado cerca de ti',
    ]);
  });

  test('textos de patrocinio en ingles', () {
    comprobar(AppLocalizationsEn(), <String>[
      'Feature on the map',
      'Featured',
      'You need an active sponsorship plan to feature this.',
      'You reached the maximum of active featured items. Turn one off to feature this one.',
      'This item cannot be featured.',
      'The featured status could not be changed.',
      'Featured near you',
    ]);
  });

  test('textos de patrocinio en portugues (pt y pt_BR)', () {
    final List<String> esperado = <String>[
      'Destacar no mapa',
      'Destaque',
      'Voce precisa de um plano de patrocinio ativo para destacar.',
      'Voce chegou ao maximo de destaques ativos. Desative um para destacar este.',
      'Este conteudo nao pode ser destacado.',
      'Nao foi possivel alterar o destaque.',
      'Destaque perto de voce',
    ];
    comprobar(AppLocalizationsPt(), esperado);
    comprobar(AppLocalizationsPtBr(), esperado);
  });
}
