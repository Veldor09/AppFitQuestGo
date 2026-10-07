import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/formulario_nodo_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

/// Panel de la empresa · "Mis nodos": los Nodos de Abastecimiento que publico,
/// con el beneficio que ofrece cada uno. Crear, editar y dar de baja.
class MisNodosScreen extends StatefulWidget {
  const MisNodosScreen({super.key, this.api, this.formularioBuilder});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final NodoApi? api;

  /// Abre el formulario. Las pruebas lo reemplazan para no montar Mapbox.
  final Widget Function(BuildContext context, Nodo? nodo)? formularioBuilder;

  @override
  State<MisNodosScreen> createState() => _MisNodosScreenState();
}

class _MisNodosScreenState extends State<MisNodosScreen> {
  late final NodoApi _api = widget.api ?? NodoApi();
  late Future<List<Nodo>> _futuro = _api.misNodos();

  Future<void> _recargar() async {
    final Future<List<Nodo>> nuevo = _api.misNodos();
    setState(() {
      _futuro = nuevo;
    });
    try {
      await nuevo;
    } catch (_) {
      // El error se muestra en el propio FutureBuilder.
    }
  }

  Future<void> _abrirFormulario([Nodo? nodo]) async {
    final Nodo? guardado = await Navigator.of(context).push<Nodo>(
      MaterialPageRoute<Nodo>(
        builder: (BuildContext ctx) =>
            widget.formularioBuilder?.call(ctx, nodo) ??
            FormularioNodoEmpresaScreen(api: _api, nodo: nodo),
      ),
    );
    if (guardado != null && mounted) await _recargar();
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
      await _recargar();
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
        label: Text(l10n.nodoEmpresaNuevo),
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
                l10n.nodoEmpresaSubtitulo,
                style: const TextStyle(fontSize: 12, color: FqColors.muted),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Nodo>>(
                future: _futuro,
                builder: (BuildContext context, AsyncSnapshot<List<Nodo>> s) {
                  if (s.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.hasError) {
                    return FqEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: l10n.eventosErrorCarga,
                      action: TextButton(
                        onPressed: _recargar,
                        child: Text(l10n.comunReintentar),
                      ),
                    );
                  }
                  final List<Nodo> nodos = s.data ?? const <Nodo>[];
                  if (nodos.isEmpty) {
                    return FqEmptyState(
                      icon: Icons.storefront_outlined,
                      title: l10n.nodoEmpresaVacioTitulo,
                      message: l10n.nodoEmpresaVacioMensaje,
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
                        nodo: nodos[i],
                        onTap: () => _abrirFormulario(nodos[i]),
                        onEliminar: () => _eliminar(nodos[i]),
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
    required this.nodo,
    required this.onTap,
    required this.onEliminar,
  });

  final Nodo nodo;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

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
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
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
                child: Icon(Icons.storefront_outlined, size: 20, color: color),
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
                    const SizedBox(height: 8),
                    FqTag(l10n.nodoEmpresaPublicado, tone: FqTagTone.green),
                  ],
                ),
              ),
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
}
