
/// Elemento administrable de los catalogos de FitQuest Go.
///
/// Corresponde a un registro de la tabla `catalogo_items` del backend.
class CatalogoItem {
  const CatalogoItem({
    required this.id,
    required this.catalogo,
    required this.clave,
    required this.nombre,
    required this.activo,
  });

  final int id;
  final String catalogo;
  final String clave;
  final String nombre;
  final bool activo;

  factory CatalogoItem.fromJson(Map<String, dynamic> json) {
    return CatalogoItem(
      id: json['id'] as int,
      catalogo: json['catalogo'] as String,
      clave: json['clave'] as String,
      nombre: json['nombre'] as String,
      activo: json['activo'] as bool,
    );
  }
}
