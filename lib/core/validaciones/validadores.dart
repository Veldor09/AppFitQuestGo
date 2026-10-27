import 'package:flutter/widgets.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Un validador recibe el texto actual y devuelve `null` si es valido o el
/// mensaje de error a mostrar.
typedef Validador = String? Function(String valor);

AppLocalizations? _textos;

/// Los mensajes de los validadores salen en el idioma de la app. Lo fija el
/// `MaterialApp` cada vez que cambia el idioma; mientras no se fije (o en una
/// prueba sin localizaciones) salen en espanol.
void usarTextosDeValidacion(AppLocalizations? l10n) => _textos = l10n;

/// Limite de caracteres del nombre (coincide con el backend).
const int kMaxNombreUsuario = 20;

/// Limite de caracteres del correo (coincide con `varchar(100)` del backend).
const int kMaxCorreoUsuario = 100;

Validador requerido([String? mensaje]) {
  return (String v) => v.trim().isEmpty
      ? (mensaje ?? _textos?.validacionObligatorio ?? 'Este campo es obligatorio')
      : null;
}

Validador maxCaracteres(int n) {
  return (String v) =>
      v.characters.length > n
      ? (_textos?.validacionMaximo(n) ?? 'Maximo $n caracteres')
      : null;
}

Validador minCaracteres(int n, [String? mensaje]) {
  return (String v) => v.characters.length < n
      ? (mensaje ?? _textos?.validacionMinimo(n) ?? 'Minimo $n caracteres')
      : null;
}

/// Igual que [minCaracteres] pero solo aplica si el campo trae algo (util para
/// la contrasena al editar, donde vacio = "no cambiar").
Validador minCaracteresSiPresente(int n, [String? mensaje]) {
  return (String v) {
    if (v.isEmpty) return null;
    return v.characters.length < n
        ? (mensaje ?? _textos?.validacionMinimo(n) ?? 'Minimo $n caracteres')
        : null;
  };
}

String? _sinNumeros(String v) =>
    RegExp(r'[0-9]').hasMatch(v)
        ? (_textos?.validacionSinNumeros ?? 'No se pueden digitar numeros')
        : null;

String? _sinEspeciales(String v) =>
    RegExp(r'[^\p{L}\p{M} ]', unicode: true).hasMatch(v)
        ? (_textos?.validacionSinEspeciales ?? 'No se admiten caracteres especiales')
        : null;

String? _formatoCorreo(String v) {
  final RegExp re =
      RegExp(r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$");
  return re.hasMatch(v.trim())
      ? null
      : (_textos?.validacionCorreoFormato ?? 'El correo no tiene un formato valido');
}

/// Prohibe digitos en el valor.
const Validador sinNumeros = _sinNumeros;

/// Prohibe cualquier cosa que no sea letra o espacio.
const Validador sinEspeciales = _sinEspeciales;

/// Exige un correo con forma `algo@dominio.tld`.
const Validador formatoCorreo = _formatoCorreo;

/// Reglas listas para el campo "Nombre" de un usuario.
List<Validador> reglasNombre() => <Validador>[
      requerido(_textos?.validacionNombreObligatorio ?? 'El nombre es obligatorio'),
      sinNumeros,
      sinEspeciales,
      maxCaracteres(kMaxNombreUsuario),
    ];

/// Reglas listas para el campo "Correo" de un usuario.
List<Validador> reglasCorreo() => <Validador>[
      requerido(_textos?.validacionCorreoObligatorio ?? 'El correo es obligatorio'),
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
