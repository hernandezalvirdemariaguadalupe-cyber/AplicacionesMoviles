package mx.ipn.escom.ruta_ajolote

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Código específico de Android para el juego.
 *
 * Las partidas viven en el almacenamiento privado de la app. Para sacarlas o traerlas se
 * usa el Storage Access Framework, así que NO se declara ningún permiso de almacenamiento:
 *  - exportFile → ACTION_CREATE_DOCUMENT (el usuario elige carpeta y nombre)
 *  - pickFile   → ACTION_OPEN_DOCUMENT (el usuario elige el archivo a importar)
 */
class MainActivity : FlutterActivity() {
    private val reqExport = 5101
    private val reqPick = 5102
    private var pending: MethodChannel.Result? = null
    private var exportSource: String? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mx.ipn.escom/archivos")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "exportFile" -> {
                        exportSource = call.argument<String>("path")
                        launch(result, reqExport, Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mime") ?: "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                        })
                    }
                    "pickFile" -> launch(result, reqPick, Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/xml", "application/xml", "text/plain"))
                    })
                    else -> result.notImplemented()
                }
            }
    }

    private fun launch(result: MethodChannel.Result, code: Int, intent: Intent) {
        if (pending != null) {
            result.error("BUSY", "Ya hay un selector abierto", null)
            return
        }
        pending = result
        try {
            startActivityForResult(intent, code)
        } catch (e: ActivityNotFoundException) {
            pending = null
            result.error("UNSUPPORTED", "No hay selector de documentos disponible", null)
        }
    }

    @Deprecated("API clásica de resultados; suficiente para FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != reqExport && requestCode != reqPick) return
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null) // el usuario canceló
            return
        }
        io.execute {
            try {
                val value: Any = if (requestCode == reqExport) {
                    val out = contentResolver.openOutputStream(uri, "w") ?: throw IOException("Destino no disponible")
                    out.use { o -> File(exportSource!!).inputStream().use { it.copyTo(o) } }
                    uri.toString()
                } else {
                    val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        ?: throw IOException("No se pudo leer el archivo")
                    mapOf("name" to displayName(uri), "bytes" to bytes)
                }
                main.post { result.success(value) }
            } catch (e: SecurityException) {
                main.post { result.error("PERMISSION_DENIED", e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("IO_ERROR", e.message, null) }
            }
        }
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst() && !c.isNull(0)) return c.getString(0)
        }
        return uri.lastPathSegment ?: "partida"
    }
}
