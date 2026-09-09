import 'package:flutter/widgets.dart';

/// Un validador recibe el texto actual y devuelve `null` si es valido o el
/// mensaje de error a mostrar.
typedef Validador = String? Function(String valor);

/// Limite de caracteres del nombre (coincide con el backend).
const int kMaxNombreUsuario = 20;

/// Limite de caracteres del correo (coincide con `varchar(100)` del backend).
const int kMaxCorreoUsuario = 100;

Validador requerido([String mensaje = 'Este campo es obligatorio']) {
  return (String v) => v.trim().isEmpty ? mensaje : null;
}

Validador maxCaracteres(int n) {
  return (String v) =>
      v.characters.length > n ? 'Maximo $n caracteres' : null;
}

Validador minCaracteres(int n, [String? mensaje]) {
  return (String v) => v.characters.length < n
      ? (mensaje ?? 'Minimo $n caracteres')
      : null;
}

/// Igual que [minCaracteres] pero solo aplica si el campo trae algo (util para
/// la contrasena al editar, donde vacio = "no cambiar").
Validador minCaracteresSiPresente(int n, [String? mensaje]) {
  return (String v) {
    if (v.isEmpty) return null;
    return v.characters.length < n
        ? (mensaje ?? 'Minimo $n caracteres')
        : null;
  };
}

String? _sinNumeros(String v) =>
    RegExp(r'[0-9]').hasMatch(v) ? 'No se pueden digitar numeros' : null;

String? _sinEspeciales(String v) =>
    RegExp(r'[^\p{L}\p{M} ]', unicode: true).hasMatch(v)
        ? 'No se admiten caracteres especiales'
        : null;

String? _formatoCorreo(String v) {
  final RegExp re =
      RegExp(r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$");
  return re.hasMatch(v.trim()) ? null : 'El correo no tiene un formato valido';
}

/// Prohibe digitos en el valor.
const Validador sinNumeros = _sinNumeros;

/// Prohibe cualquier cosa que no sea letra o espacio.
const Validador sinEspeciales = _sinEspeciales;

/// Exige un correo con forma `algo@dominio.tld`.
const Validador formatoCorreo = _formatoCorreo;

/// Reglas listas para el campo "Nombre" de un usuario.
List<Validador> reglasNombre() => <Validador>[
      requerido('El nombre es obligatorio'),
      sinNumeros,
      sinEspeciales,
      maxCaracteres(kMaxNombreUsuario),
    ];

/// Reglas listas para el campo "Correo" de un usuario.
List<Validador> reglasCorreo() => <Validador>[
      requerido('El correo es obligatorio'),
      formatoCorreo,
      maxCaracteres(kMaxCorreoUsuario),
    ];

/// Primer mensaje de error que falla, o `null` si [valor] pasa todas las reglas.
String? primeraFalla(String valor, List<Validador> reglas) {
  for (final Validador regla in reglas) {
    final String? error = regla(valor);
    if (error != null) return error;
  }
  return null;
}

/// `true` si cada entrada (texto, reglas) es valida.
bool todoValido(List<(String, List<Validador>)> campos) {
  for (final (String valor, List<Validador> reglas) in campos) {
    if (primeraFalla(valor, reglas) != null) return false;
  }
  return true;
}
