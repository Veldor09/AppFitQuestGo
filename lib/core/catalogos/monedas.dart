/// Una moneda en la que se cobra el patrocinio. Es un contrato con el backend
/// (`MONEDAS` en `src/Modules/Patrocinio/monedas.ts`): misma lista, mismo orden.
///
/// [decimales] es solo para MOSTRAR el importe (el colon va sin decimales); la
/// unidad minima que usa cada pasarela de pago es otra cosa.
class Moneda {
  const Moneda(this.codigo, this.simbolo, this.decimales);

  final String codigo;
  final String simbolo;
  final int decimales;
}

const List<Moneda> monedas = <Moneda>[
  Moneda('CRC', '₡', 0),
  Moneda('USD', 'US\$', 2),
  Moneda('EUR', '€', 2),
];

/// La moneda con ese codigo (`CRC`, `USD`, `EUR`), o null si no es una del catalogo.
Moneda? monedaPorCodigo(String codigo) {
  for (final Moneda m in monedas) {
    if (m.codigo == codigo) return m;
  }
  return null;
}
