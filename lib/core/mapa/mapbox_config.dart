/// Token publico (pk.) de Mapbox: esta hecho para ir dentro de la app, no es
/// un secreto. Se puede sobreescribir con `--dart-define=ACCESS_TOKEN=pk...`.
const String kMapboxAccessToken = String.fromEnvironment(
  'ACCESS_TOKEN',
  defaultValue: String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
