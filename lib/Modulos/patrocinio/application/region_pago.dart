import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Desde donde se paga una suscripcion. Costa Rica paga por SINPE Movil; el resto
/// del mundo, por PayPal.
enum RegionPago { costaRica, otro }

/// Donde se recuerda lo que la persona eligio: la region del telefono no siempre
/// dice donde esta (un telefono en "English (US)" puede estar en Costa Rica).
abstract class AlmacenRegionPago {
  Future<RegionPago?> leer();
  Future<void> guardar(RegionPago region);
}

class AlmacenRegionPagoSeguro implements AlmacenRegionPago {
  const AlmacenRegionPagoSeguro([
    this._almacen = const FlutterSecureStorage(aOptions: AndroidOptions()),
  ]);

  final FlutterSecureStorage _almacen;
  static const String _clave = 'region_pago';

  @override
  Future<RegionPago?> leer() async {
    try {
      // Sin tope, un almacen que no responde dejaria la pantalla cargando.
      final String? texto = await _almacen
          .read(key: _clave)
          .timeout(const Duration(seconds: 2));
      for (final RegionPago r in RegionPago.values) {
        if (r.name == texto) return r;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> guardar(RegionPago region) async {
    try {
      await _almacen.write(key: _clave, value: region.name);
    } catch (_) {}
  }
}
