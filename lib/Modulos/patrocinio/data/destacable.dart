import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';

/// Lo que responde el servidor al encender o apagar "Destacar": el interruptor
/// del dueno y si, con su plan, el contenido sale destacado en el mapa.
typedef ResultadoDestacar = ({bool destacarActivado, bool destacado});

/// Categorias de punto de interes que un usuario normal puede destacar. Es un
/// contrato con el backend (`CATEGORIAS_COMERCIO`).
const Set<String> categoriasComercio = <String>{
  'comercio',
  'restaurante',
  'taller',
};

/// Si el [nodo] puede llegar a destacarse: un local de empresa (patrocinado) o
/// un comercio de un usuario. La ultima palabra la tiene el servidor.
bool nodoDestacable(Nodo nodo) =>
    nodo.patrocinado || categoriasComercio.contains(nodo.categoria);

/// De estos [nodos], los que salen destacados en el mapa, en su orden.
List<Nodo> soloDestacados(Iterable<Nodo> nodos) => <Nodo>[
  for (final Nodo n in nodos)
    if (n.destacado) n,
];

/// Un evento se destaca mientras no haya terminado.
bool eventoDestacable(Evento evento, DateTime ahora) =>
    !evento.haTerminado(ahora);
