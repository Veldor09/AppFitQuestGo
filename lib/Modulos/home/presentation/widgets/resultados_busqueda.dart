import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/core/geo/formato_distancia.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/home/application/busqueda_mapa.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/decoracion_flotante.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';

/// La lista que se abre bajo la barra de busqueda con lo que coincide con lo
/// escrito: cada fila con el icono de lo que es, su nombre, su detalle y, si se
/// conoce la posicion, a cuantos metros esta. Tocar una fila avisa con
/// [onElegir]. Si no hay nada, lo dice.
class ResultadosBusqueda extends StatelessWidget {
  const ResultadosBusqueda({
    super.key,
    required this.consulta,
    required this.resultados,
    required this.onElegir,
  });

  final String consulta;
  final List<ResultadoBusqueda> resultados;
  final ValueChanged<ResultadoBusqueda> onElegir;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String idioma = Localizations.localeOf(context).toString();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: decoracionFlotante(radius: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: resultados.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.homeBuscarSinResultados(consulta.trim()),
                  style: const TextStyle(fontSize: 12.5, color: FqColors.muted),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: resultados.length,
                itemBuilder: (BuildContext context, int i) => _Fila(
                  resultado: resultados[i],
                  idioma: idioma,
                  onTap: () => onElegir(resultados[i]),
                ),
              ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.resultado,
    required this.idioma,
    required this.onTap,
  });

  final ResultadoBusqueda resultado;
  final String idioma;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double? metros = resultado.metros;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: <Widget>[
            _Icono(resultado: resultado),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    resultado.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (resultado.detalle.isNotEmpty)
                    Text(
                      resultado.detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: FqColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            if (metros != null) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                formatearDistancia(metros, locale: idioma),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: FqColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// El circulo con el icono de lo que es el resultado, con los mismos colores
/// que tiene en el mapa.
class _Icono extends StatelessWidget {
  const _Icono({required this.resultado});

  final ResultadoBusqueda resultado;

  @override
  Widget build(BuildContext context) {
    final Object origen = resultado.origen;
    final (IconData, Color, Color) estilo = switch (resultado.tipo) {
      TipoResultado.ruta => (
        Icons.route_rounded,
        FqColors.trail,
        FqColors.white,
      ),
      TipoResultado.alerta => (
        Icons.warning_amber_rounded,
        FqColors.risk,
        FqColors.white,
      ),
      TipoResultado.evento => (
        origen is Evento
            ? iconoCategoriaEvento(origen.categoria)
            : Icons.event_rounded,
        colorAreaEvento,
        FqColors.white,
      ),
      TipoResultado.poi => () {
        final EstiloPin pin = estiloPinNodo(origen is Nodo ? origen.categoria : '');
        return (pin.icono, pin.fondo, pin.colorIcono);
      }(),
    };
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: estilo.$2, shape: BoxShape.circle),
      child: Icon(estilo.$1, size: 18, color: estilo.$3),
    );
  }
}
