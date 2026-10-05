/// Token publico (pk.) de Mapbox: esta hecho para ir dentro de la app, no es
/// un secreto. Se puede sobreescribir con `--dart-define=ACCESS_TOKEN=pk...`.
const String kMapboxAccessToken = String.fromEnvironment(
  'ACCESS_TOKEN',
  defaultValue: String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue:
        'pk.eyJ1Ijoicm9zaGlpaTk2IiwiYSI6ImNtdGdyamd4bTE4b2syeHBucWRjOTg0a24ifQ.uS6GPL3MIykjoU3sip1n9g',
  ),
);
