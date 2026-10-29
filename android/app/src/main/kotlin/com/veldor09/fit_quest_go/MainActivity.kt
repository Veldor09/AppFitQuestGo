package com.veldor09.fit_quest_go

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Ademas de lo estandar de Flutter, maneja la ventana flotante
/// (Picture-in-Picture) que se usa mientras se sigue una ruta o un evento.
/// Flutter la controla por el canal "fitquest/pip" (ver lib/core/pip/modo_pip.dart).
/// Hereda de FlutterFragmentActivity para dar soporte a autenticacion biometrica (local_auth).
class MainActivity : FlutterFragmentActivity() {
    private var canalPip: MethodChannel? = null

    /// true mientras haya una pantalla de seguimiento abierta.
    private var pipHabilitado = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        canalPip = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitquest/pip").also { canal ->
            canal.setMethodCallHandler { call, result ->
                when (call.method) {
                    "soportado" -> result.success(pipSoportado())
                    "habilitar" -> {
                        pipHabilitado = call.arguments == true && pipSoportado()
                        aplicarParametros()
                        result.success(pipHabilitado)
                    }
                    "entrar" -> result.success(entrarPip())
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun pipSoportado(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    /// Ventana vertical (9:16), como la navegacion de Google Maps.
    private fun parametros(): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val builder = PictureInPictureParams.Builder().setAspectRatio(Rational(9, 16))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: entra solo al salir de la app (boton Home / gesto).
            builder.setAutoEnterEnabled(pipHabilitado)
            // Es un mapa, no un video: evita el redimensionado "suave" que lo deforma.
            builder.setSeamlessResizeEnabled(false)
        }
        return builder.build()
    }

    private fun aplicarParametros() {
        if (!pipSoportado()) return
        parametros()?.let { setPictureInPictureParams(it) }
    }

    private fun entrarPip(): Boolean {
        if (!pipSoportado()) return false
        val params = parametros() ?: return false
        return try {
            enterPictureInPictureMode(params)
        } catch (e: IllegalStateException) {
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Android 8 a 11 no tienen auto-enter: se entra a mano al salir de la app.
        if (pipHabilitado &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S
        ) {
            entrarPip()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        canalPip?.invokeMethod("cambio", isInPictureInPictureMode)
    }
}
