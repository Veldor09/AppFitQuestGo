/// Lectura de GPS reducida a lo que usa la app (latitud y longitud).
///
/// Mantiene `geolocator` fuera de la logica y de las pruebas, y evita la
/// colision de nombres entre su `Position` y la de `mapbox_maps_flutter`.
typedef PosicionGps = ({double lat, double lng});
