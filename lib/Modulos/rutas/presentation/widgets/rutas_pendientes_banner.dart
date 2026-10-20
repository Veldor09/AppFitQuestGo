import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/Modulos/rutas/application/sync_rutas_service.dart';

/// Aviso "Tienes N rutas pendientes de subir" con boton Sincronizar. Intenta
/// sincronizar solo al abrirse y cada vez que vuelve la conexion. No ocupa
/// espacio si no hay nada pendiente.
class RutasPendientesBanner extends StatefulWidget {
  const RutasPendientesBanner({super.key, this.servicio, this.alSincronizar});

  final SyncRutasService? servicio;

  /// Se llama cuando se subio al menos una ruta (para recargar listas/metricas).
  final VoidCallback? alSincronizar;

  @override
  State<RutasPendientesBanner> createState() => _RutasPendientesBannerState();
}

class _RutasPendientesBannerState extends State<RutasPendientesBanner> {
  late final SyncRutasService _servicio =
      widget.servicio ?? SyncRutasService.instancia;
  StreamSubscription<List<ConnectivityResult>>? _red;
  int _pendientes = 0;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _sincronizar(silencioso: true);
    try {
      _red = Connectivity().onConnectivityChanged.listen(
        (List<ConnectivityResult> r) {
          if (r.any((ConnectivityResult e) => e != ConnectivityResult.none)) {
            _sincronizar(silencioso: true);
          }
        },
        onError: (Object _) {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _red?.cancel();
    super.dispose();
  }

  Future<void> _sincronizar({bool silencioso = false}) async {
    if (_sincronizando) return;
    setState(() => _sincronizando = true);
    int subidas = 0;
    try {
      subidas = await _servicio.sincronizar();
    } catch (_) {}
    final int restantes = await _servicio.pendientes();
    if (!mounted) return;
    setState(() {
      _sincronizando = false;
      _pendientes = restantes;
    });
    if (subidas > 0) {
      notificarExito(
        subidas == 1 ? 'Ruta pendiente subida' : '$subidas rutas pendientes subidas',
      );
      widget.alSincronizar?.call();
    } else if (!silencioso && restantes > 0) {
      notificarError('Aún sin conexión. Se reintentará automáticamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pendientes == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8C766)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_upload_outlined, size: 18, color: FqColors.night),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _pendientes == 1
                  ? 'Tienes 1 ruta pendiente de subir'
                  : 'Tienes $_pendientes rutas pendientes de subir',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: _sincronizando ? null : () => _sincronizar(),
            child: _sincronizando
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sincronizar'),
          ),
        ],
      ),
    );
  }
}
