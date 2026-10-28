import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

enum EstiloMapa {
  calles(MapboxStyles.MAPBOX_STREETS),

  satelite(MapboxStyles.SATELLITE_STREETS);

  const EstiloMapa(this.uri);

  final String uri;
}

class PreferenciaEstiloMapa {
  PreferenciaEstiloMapa._();

  static final PreferenciaEstiloMapa instancia = PreferenciaEstiloMapa._();

  final ValueNotifier<EstiloMapa> estilo = ValueNotifier<EstiloMapa>(
    EstiloMapa.calles,
  );
}

class GestorEstiloMapa {
  GestorEstiloMapa({required this.mapa, required this.alCambiarEstilo});

  final MapboxMap? Function() mapa;

  final Future<void> Function() alCambiarEstilo;

  EstiloMapa _aplicado = PreferenciaEstiloMapa.instancia.estilo.value;
  EstiloMapa? _pendiente;

  EstiloMapa get aplicado => _aplicado;

  void iniciar() =>
      PreferenciaEstiloMapa.instancia.estilo.addListener(_alElegir);

  void liberar() =>
      PreferenciaEstiloMapa.instancia.estilo.removeListener(_alElegir);

  Future<void> _alElegir() async {
    final MapboxMap? m = mapa();
    final EstiloMapa elegido = PreferenciaEstiloMapa.instancia.estilo.value;
    if (m == null || elegido == _aplicado || elegido == _pendiente) return;
    _pendiente = elegido;
    try {
      await m.loadStyleURI(elegido.uri);
    } catch (_) {
      _pendiente = null;
    }
  }

  Future<void> alEstiloCargado([Object? _]) async {
    final EstiloMapa? nuevo = _pendiente;
    if (nuevo == null) return;
    _pendiente = null;
    _aplicado = nuevo;
    await alCambiarEstilo();
  }
}

class BotonTipoMapa extends StatelessWidget {
  const BotonTipoMapa({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Material(
      color: FqColors.white,
      elevation: 3,
      shadowColor: const Color(0x3313233F),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey<String>('boton-tipo-mapa'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => mostrarTipoDeMapa(context),
        child: Tooltip(
          message: l10n.mapaTipoBoton,
          child: const SizedBox(
            width: 46,
            height: 46,
            child: Icon(Icons.layers_rounded, size: 23, color: FqColors.night),
          ),
        ),
      ),
    );
  }
}

Future<void> mostrarTipoDeMapa(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext _) => const _HojaTipoMapa(),
  );
}

class _HojaTipoMapa extends StatelessWidget {
  const _HojaTipoMapa();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<EstiloMapa>(
      valueListenable: PreferenciaEstiloMapa.instancia.estilo,
      builder: (BuildContext context, EstiloMapa actual, Widget? _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: FqColors.stone,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.mapaTipoTitulo,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: FqColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _OpcionEstilo(
                      key: const ValueKey<String>('estilo-calles'),
                      icono: Icons.map_rounded,
                      etiqueta: l10n.mapaTipoCalles,
                      colores: const <Color>[
                        Color(0xFFE6EFE0),
                        Color(0xFFCFE0F3),
                      ],
                      elegido: actual == EstiloMapa.calles,
                      onTap: () => _elegir(context, EstiloMapa.calles),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OpcionEstilo(
                      key: const ValueKey<String>('estilo-satelite'),
                      icono: Icons.satellite_alt_rounded,
                      etiqueta: l10n.mapaTipoSatelite,
                      colores: const <Color>[
                        Color(0xFF2F4A2A),
                        Color(0xFF1B3550),
                      ],
                      claro: false,
                      elegido: actual == EstiloMapa.satelite,
                      onTap: () => _elegir(context, EstiloMapa.satelite),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _elegir(BuildContext context, EstiloMapa estilo) {
    PreferenciaEstiloMapa.instancia.estilo.value = estilo;
    Navigator.of(context).maybePop();
  }
}

class _OpcionEstilo extends StatelessWidget {
  const _OpcionEstilo({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.colores,
    required this.elegido,
    required this.onTap,
    this.claro = true,
  });

  final IconData icono;
  final String etiqueta;
  final List<Color> colores;
  final bool elegido;
  final bool claro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: elegido,
      label: etiqueta,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Container(
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colores,
                ),
                border: Border.all(
                  color: elegido ? FqColors.river : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Center(
                child: Icon(
                  icono,
                  size: 34,
                  color: claro ? FqColors.night : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 13,
                fontWeight: elegido ? FontWeight.w800 : FontWeight.w600,
                color: elegido ? FqColors.river : FqColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
