import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/carga_lista.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/formulario_nodo_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/destacable.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/interruptor_destacar.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/ficha_nodo.dart';

/// Quien usa el panel de nodos. El panel es el mismo; cambia lo que se puede
/// hacer con cada nodo.
enum ModoNodos {
  /// Una empresa: sus Nodos de Abastecimiento salen publicados con su
  /// beneficio, y los puede editar y dar de baja.
  empresa,

  /// Un deportista: sus puntos de interes quedan pendientes hasta que un admin
  /// los revisa; aqui solo los ve y propone nuevos.
  usuario,
}

/// Panel "Mis nodos": los nodos que creo quien esta conectado. Lo usan la
/// empresa (en su panel) y el deportista (en su barra de navegacion).
class MisNodosScreen extends StatefulWidget {
  const MisNodosScreen({
    super.key,
    this.api,
    this.formularioBuilder,
    this.modo = ModoNodos.empresa,
  });

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final NodoApi? api;

  /// Abre el formulario. Las pruebas lo reemplazan para no montar Mapbox.
  final Widget Function(BuildContext context, Nodo? nodo)? formularioBuilder;

  final ModoNodos modo;

  @override
  State<MisNodosScreen> createState() => _MisNodosScreenState();
}

class _MisNodosScreenState extends State<MisNodosScreen> {
  late final NodoApi _api = widget.api ?? NodoApi();
  late final CargaLista<Nodo> _carga = CargaLista<Nodo>(() => _api.misNodos());

  @override
  void initState() {
    super.initState();
    _carga.cargar();
  }

  @override
  void dispose() {
    _carga.dispose();
    super.dispose();
  }

  bool get _esEmpresa => widget.modo == ModoNodos.empresa;

  Future<void> _recargar() => _carga.cargar(silencioso: true);

  Future<void> _abrirFormulario([Nodo? nodo]) async {
    final Nodo? guardado = await Navigator.of(context).push<Nodo>(
      MaterialPageRoute<Nodo>(
        builder: (BuildContext ctx) =>
            widget.formularioBuilder?.call(ctx, nodo) ??
            FormularioNodoEmpresaScreen(
              api: _api,
              nodo: nodo,
              esEmpresa: _esEmpresa,
            ),
      ),
    );
    if (guardado != null && mounted) await _recargar();
  }

  /// Tocar un nodo: la empresa lo edita; el deportista solo ve su ficha (una
  /// vez propuesto, el punto lo gestiona el admin).
  void _abrirNodo(Nodo nodo) {
    if (_esEmpresa) {
      _abrirFormulario(nodo);
    } else {
      mostrarFichaNodo(context, nodo, _api);
    }
  }

  Future<void> _eliminar(Nodo nodo) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.nodoEmpresaEliminarTitulo),
        content: Text(l10n.nodoEmpresaEliminarMensaje(nodo.nombre)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.comunCancelar),
          ),
          FilledButton(
            key: const ValueKey<String>('confirmar-eliminar'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.comunEliminar),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await _api.eliminar(nodo.id);
      if (!mounted) return;
      notificarExito(l10n.nodoEmpresaEliminado);
      _carga.quitar((Nodo n) => n.id == nodo.id);
    } on ApiException catch (e) {
      notificarError(e.message);
    } catch (_) {
      notificarError(l10n.nodoEmpresaErrorEliminar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: FqColors.paper,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('nuevo-nodo'),
        onPressed: () => _abrirFormulario(),
        backgroundColor: FqColors.volt,
        foregroundColor: FqColors.primaryInk,
        icon: const Icon(Icons.add),
        label: Text(_esEmpresa ? l10n.nodoEmpresaNuevo : l10n.nodoUsuarioNuevo),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(FqGap.xl, 16, FqGap.xl, 4),
              child: Text(
                l10n.nodoEmpresaTitulo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(FqGap.xl, 0, FqGap.xl, 8),
              child: Text(
                _esEmpresa
                    ? l10n.nodoEmpresaSubtitulo
                    : l10n.nodoUsuarioSubtitulo,
                style: const TextStyle(fontSize: 12, color: FqColors.muted),
              ),
            ),
            Expanded(
              child: CargaListaVista<Nodo>(
                carga: _carga,
                error: (BuildContext context, Object _) => FqEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: l10n.eventosErrorCarga,
                  action: TextButton(
                    onPressed: _carga.cargar,
                    child: Text(l10n.comunReintentar),
                  ),
                ),
                datos: (BuildContext context, List<Nodo> nodos) {
                  if (nodos.isEmpty) {
                    return FqEmptyState(
                      icon: _esEmpresa
                          ? Icons.storefront_outlined
                          : Icons.place_outlined,
                      title: _esEmpresa
                          ? l10n.nodoEmpresaVacioTitulo
                          : l10n.nodoUsuarioVacioTitulo,
                      message: _esEmpresa
                          ? l10n.nodoEmpresaVacioMensaje
                          : l10n.nodoUsuarioVacioMensaje,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _recargar,
                    child: ListView.separated(
                      key: const ValueKey<String>('lista-mis-nodos'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        FqGap.xl,
                        4,
                        FqGap.xl,
                        90,
                      ),
                      itemCount: nodos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext _, int i) => _TarjetaNodo(
                        key: ValueKey<int>(nodos[i].id),
                        nodo: nodos[i],
                        esEmpresa: _esEmpresa,
                        onTap: () => _abrirNodo(nodos[i]),
                        interruptor: nodoDestacable(nodos[i])
                            ? InterruptorDestacar(
                                activado: nodos[i].destacarActivado,
                                alCambiar: (bool destacar) async =>
                                    (await _api.destacar(
                                      nodos[i].id,
                                      destacar: destacar,
                                    )).destacarActivado,
                              )
                            : null,
                        onEliminar: _esEmpresa
                            ? () => _eliminar(nodos[i])
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaNodo extends StatelessWidget {
  const _TarjetaNodo({
    super.key,
    required this.nodo,
    required this.esEmpresa,
    required this.onTap,
    required this.onEliminar,
    this.interruptor,
  });

  final Nodo nodo;
  final bool esEmpresa;
  final VoidCallback onTap;

  /// Null cuando quien mira no puede dar de baja el nodo.
  final VoidCallback? onEliminar;

  /// El interruptor "Destacar" (null si el punto no se puede destacar).
  final Widget? interruptor;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String? beneficio = nodo.beneficio?.trim();
    final Color color = colorCategoriaNodo(nodo.categoria);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: FqRadius.allLg,
        child: Ink(
          padding: EdgeInsets.fromLTRB(12, 12, onEliminar == null ? 12 : 4, 12),
          decoration: BoxDecoration(
            color: FqColors.white,
            borderRadius: FqRadius.allLg,
            border: Border.all(color: FqColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  esEmpresa ? Icons.storefront_outlined : Icons.place_outlined,
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      nodo.nombre,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      categoriaNodoLabel(
                        l10n,
                        nodo.categoria,
                        otro: nodo.categoriaOtro,
                      ),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: FqColors.muted,
                      ),
                    ),
                    if (esEmpresa) ...<Widget>[
                      const SizedBox(height: 6),
                      if (beneficio != null && beneficio.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.local_offer_outlined,
                              size: 14,
                              color: FqColors.voltDark,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                beneficio,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          l10n.nodoEmpresaSinBeneficio,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: FqColors.muted,
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    _etiquetaEstado(l10n),
                    if (interruptor != null) ...<Widget>[
                      const SizedBox(height: 6),
                      interruptor!,
                    ],
                  ],
                ),
              ),
              if (onEliminar != null)
                IconButton(
                  key: ValueKey<String>('eliminar-nodo-${nodo.id}'),
                  tooltip: l10n.comunEliminar,
                  onPressed: onEliminar,
                  icon: const Icon(Icons.delete_outline, color: FqColors.risk),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// La empresa publica sin revision. El deportista ve en que va su punto.
  Widget _etiquetaEstado(AppLocalizations l10n) {
    if (esEmpresa) {
      return FqTag(l10n.nodoEmpresaPublicado, tone: FqTagTone.green);
    }
    switch (nodo.estado) {
      case 'Aprobado':
        return FqTag(l10n.nodoEstadoAprobado, tone: FqTagTone.green);
      case 'Rechazado':
        return FqTag(l10n.nodoEstadoRechazado, tone: FqTagTone.red);
      case 'Obsoleto':
        return FqTag(l10n.nodoEstadoObsoleto);
      default:
        return FqTag(l10n.nodoEstadoPendiente, tone: FqTagTone.amber);
    }
  }
}
