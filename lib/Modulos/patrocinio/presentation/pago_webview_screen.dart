import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Como termino la pantalla de pago.
enum ResultadoPago { exito, cancelado }

/// A donde vuelve ONVO al terminar: paginas de nuestro backend. La de retorno es
/// la que confirma el pago con ONVO y activa el plan.
const String _rutaRetorno = '/patrocinio/pagos/retorno';
const String _rutaCancelado = '/patrocinio/pagos/cancelado';

/// Mira una direccion que termino de cargar: si es el retorno del backend el pago
/// termino bien, si es la de cancelado se cancelo; cualquier otra (la de ONVO, el
/// banco, 3D Secure) no es el final.
ResultadoPago? interpretarNavegacion(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.path == _rutaRetorno) return ResultadoPago.exito;
  if (uri.path == _rutaCancelado) return ResultadoPago.cancelado;
  return null;
}

/// La pantalla de pago de ONVO, dentro de la app. Se cierra sola al llegar a la
/// pagina de retorno o de cancelado del backend y devuelve el [ResultadoPago];
/// si la persona la cierra a mano devuelve null (no se sabe si pago: quien la
/// abrio debe volver a consultar su plan).
///
/// No se pide el numero de tarjeta en pantallas propias: lo hace la pagina
/// hospedada de ONVO.
class PagoWebViewScreen extends StatefulWidget {
  const PagoWebViewScreen({super.key, required this.url, this.construirVista});

  final String url;

  /// Inyectable para pruebas (en pruebas no hay WebView de verdad). Recibe la
  /// URL y debe llamar `alTerminarCarga(url)` cada vez que una pagina termina de
  /// cargar.
  final Widget Function(
    BuildContext context,
    String url,
    ValueChanged<String> alTerminarCarga,
  )?
  construirVista;

  @override
  State<PagoWebViewScreen> createState() => _PagoWebViewScreenState();
}

class _PagoWebViewScreenState extends State<PagoWebViewScreen> {
  WebViewController? _controller;
  bool _cerrada = false;

  @override
  void initState() {
    super.initState();
    if (widget.construirVista == null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(onPageFinished: _alTerminarCarga),
        )
        ..loadRequest(Uri.parse(widget.url));
    }
  }

  void _alTerminarCarga(String url) {
    if (_cerrada || !mounted) return;
    final ResultadoPago? resultado = interpretarNavegacion(url);
    if (resultado == null) return;
    _cerrada = true;
    Navigator.of(context).pop(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Widget Function(BuildContext, String, ValueChanged<String>)?
    construir = widget.construirVista;
    return Scaffold(
      backgroundColor: FqColors.paper,
      appBar: AppBar(
        backgroundColor: FqColors.night,
        foregroundColor: FqColors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.planPagoCerrar,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.planPagoTitulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: construir != null
          ? construir(context, widget.url, _alTerminarCarga)
          : WebViewWidget(controller: _controller!),
    );
  }
}
