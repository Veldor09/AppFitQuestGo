import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum OrigenFoto { camara, galeria }

/// Elige una foto del dispositivo. Es una interfaz para poder cambiar el
/// selector real por uno falso en las pruebas (no hay camara ni galeria ahi).
abstract class SelectorFoto {
  /// Los bytes de la foto elegida, o null si la persona cancelo o no se pudo.
  Future<Uint8List?> elegir(OrigenFoto origen);
}

/// [SelectorFoto] sobre `image_picker`. La foto se reduce antes de subirla
/// (lado mayor 1600 px, JPEG al 80 %): son ~0.3-0.8 MB en vez de varios, y el
/// servidor admite hasta 3 MB.
class SelectorFotoImagePicker implements SelectorFoto {
  SelectorFotoImagePicker([ImagePicker? selector])
    : _selector = selector ?? ImagePicker();

  final ImagePicker _selector;

  @override
  Future<Uint8List?> elegir(OrigenFoto origen) async {
    try {
      final XFile? archivo = await _selector.pickImage(
        source: origen == OrigenFoto.camara
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      return archivo == null ? null : await archivo.readAsBytes();
    } catch (_) {
      // Sin permiso o sin camara: la persona simplemente se queda sin foto.
      return null;
    }
  }
}
