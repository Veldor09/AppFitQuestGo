import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificaciones_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';

// Home pide al abrir los eventos, las rutas y el conteo de notificaciones. Una
// prueba que monte Home y no se ocupe de eso pasa estos falsos: sin ellos las
// peticiones irian a la red de verdad y dejarian temporizadores pendientes.

class EventoApiVacia extends EventoApi {
  @override
  Future<List<Evento>> listar() async => <Evento>[];
}

class RutaApiVacia extends RutaApi {
  @override
  Future<List<Ruta>> explorar() async => <Ruta>[];

  @override
  Future<Set<int>> favoritasIds() async => <int>{};
}

class NotificacionesApiVacia extends NotificacionesApi {
  @override
  Future<int> conteoNoLeidas() async => 0;

  @override
  Future<List<Notificacion>> listar() async => <Notificacion>[];
}
