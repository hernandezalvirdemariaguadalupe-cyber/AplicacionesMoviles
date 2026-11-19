package mx.ipn.escom.gestor_archivos

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.Executors

/**
 * Código específico de Android.
 *
 * Expone al código Dart un MethodChannel ("mx.ipn.escom/storage") que encapsula el
 * Storage Access Framework (SAF). La app NUNCA pide permisos de almacenamiento global
 * (READ/WRITE_EXTERNAL_STORAGE ni MANAGE_EXTERNAL_STORAGE): sólo trabaja con
 *  - su almacenamiento privado (filesDir), y
 *  - carpetas/archivos que el usuario elige en el selector del sistema
 *    (ACTION_OPEN_DOCUMENT_TREE / ACTION_OPEN_DOCUMENT), cuyos permisos se
 *    conservan con takePersistableUriPermission.
 *
 * Las referencias SAF que viajan a Dart son URIs de documento construidas sobre el árbol
 * autorizado (content://.../tree/<raiz>/document/<doc>), lo que permite listar hijos,
 * crear, renombrar y borrar respetando lo que el proveedor de documentos admita.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "mx.ipn.escom/storage"
    private val io = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    private val reqPickDir = 4101
    private val reqPickFiles = 4102
    private val reqExport = 4103

    private var pendingResult: MethodChannel.Result? = null
    private var pendingExportSource: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    // ------------------------------------------------------------------ dispatch

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDirectory" -> startPicker(result, reqPickDir) {
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(persistFlags())
                }
            }
            "pickFiles" -> startPicker(result, reqPickFiles) {
                Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    addFlags(persistFlags())
                }
            }
            "exportFile" -> {
                val source = call.argument<String>("ref")!!
                val name = call.argument<String>("name")!!
                val mime = call.argument<String>("mime") ?: "application/octet-stream"
                pendingExportSource = source
                startPicker(result, reqExport) {
                    Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mime
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                }
            }
            "openWith" -> openWith(call.argument<String>("ref")!!, call.argument<String>("mime"), result)
            "persistedRoots" -> result.success(
                contentResolver.persistedUriPermissions.map { it.uri.toString() }
            )
            "release" -> {
                runCatching {
                    contentResolver.releasePersistableUriPermission(
                        Uri.parse(call.argument<String>("uri")!!), persistFlags()
                    )
                }
                result.success(null)
            }
            "freeSpace" -> background(result) {
                val path = call.argument<String>("path") ?: filesDir.absolutePath
                StatFs(path).availableBytes
            }
            "localAttributes" -> background(result) { localAttributes(call.argument<String>("path")!!) }
            "list" -> background(result) { listChildren(Uri.parse(call.argument<String>("uri")!!)) }
            "stat" -> background(result) { stat(Uri.parse(call.argument<String>("uri")!!)) }
            "read" -> background(result) {
                val uri = Uri.parse(call.argument<String>("uri")!!)
                val max = (call.argument<Number>("maxBytes") ?: Long.MAX_VALUE).toLong()
                openInput(uri.toString()).use { readLimited(it, max) }
            }
            "write" -> background(result) {
                val uri = Uri.parse(call.argument<String>("uri")!!)
                val bytes = call.argument<ByteArray>("bytes")!!
                (contentResolver.openOutputStream(uri, "wt")
                    ?: throw IOException("El proveedor no permite escribir")).use { it.write(bytes) }
                null
            }
            "createFile" -> background(result) {
                val parent = Uri.parse(call.argument<String>("parent")!!)
                val name = call.argument<String>("name")!!
                val mime = call.argument<String>("mime") ?: guessMime(name)
                val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                val created = DocumentsContract.createDocument(contentResolver, parent, mime, name)
                    ?: throw IOException("El proveedor no permitió crear el archivo")
                contentResolver.openOutputStream(created, "w")!!.use { it.write(bytes) }
                created.toString()
            }
            "createDirectory" -> background(result) {
                val parent = Uri.parse(call.argument<String>("parent")!!)
                val name = call.argument<String>("name")!!
                (DocumentsContract.createDocument(
                    contentResolver, parent, DocumentsContract.Document.MIME_TYPE_DIR, name
                ) ?: throw IOException("El proveedor no permitió crear la carpeta")).toString()
            }
            "delete" -> background(result) {
                val ok = DocumentsContract.deleteDocument(
                    contentResolver, Uri.parse(call.argument<String>("uri")!!)
                )
                if (!ok) throw IOException("El proveedor rechazó la eliminación")
                null
            }
            "rename" -> background(result) {
                (DocumentsContract.renameDocument(
                    contentResolver,
                    Uri.parse(call.argument<String>("uri")!!),
                    call.argument<String>("name")!!
                ) ?: throw IOException("El proveedor no permitió renombrar")).toString()
            }
            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------------ selectores del sistema

    private fun persistFlags() =
        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

    private fun startPicker(result: MethodChannel.Result, code: Int, build: () -> Intent) {
        if (pendingResult != null) {
            result.error("BUSY", "Ya hay un selector abierto", null)
            return
        }
        pendingResult = result
        try {
            startActivityForResult(build(), code)
        } catch (e: ActivityNotFoundException) {
            pendingResult = null
            result.error("UNSUPPORTED", "Este dispositivo no tiene un selector de documentos", null)
        }
    }

    @Deprecated("API de resultados clásica; suficiente para FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode !in listOf(reqPickDir, reqPickFiles, reqExport)) return
        val result = pendingResult ?: return
        pendingResult = null

        // El usuario canceló: se respeta su decisión y se informa a Dart con null.
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(null)
            return
        }
        when (requestCode) {
            reqPickDir -> background(result) {
                val tree = data.data!!
                takePersist(tree, data.flags)
                val rootDoc = DocumentsContract.buildDocumentUriUsingTree(
                    tree, DocumentsContract.getTreeDocumentId(tree)
                )
                stat(rootDoc) + mapOf("treeUri" to tree.toString())
            }
            reqPickFiles -> background(result) {
                val uris = mutableListOf<Uri>()
                data.clipData?.let { clip -> for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri) }
                data.data?.let { if (uris.isEmpty()) uris.add(it) }
                uris.map { takePersist(it, data.flags); stat(it) }
            }
            reqExport -> background(result) {
                val target = data.data!!
                val source = pendingExportSource!!
                openInput(source).use { input ->
                    (contentResolver.openOutputStream(target, "w")
                        ?: throw IOException("No se pudo escribir en el destino")).use { input.copyTo(it) }
                }
                target.toString()
            }
        }
    }

    private fun takePersist(uri: Uri, flags: Int) {
        val f = flags and persistFlags()
        try {
            contentResolver.takePersistableUriPermission(uri, f)
        } catch (_: SecurityException) {
            // Algunos proveedores sólo conceden lectura; intentamos conservar al menos eso.
            runCatching {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }
    }

    // ------------------------------------------------------------------ SAF: consultas

    private val columns = arrayOf(
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_MIME_TYPE,
        DocumentsContract.Document.COLUMN_SIZE,
        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        DocumentsContract.Document.COLUMN_FLAGS,
    )

    private fun listChildren(docUri: Uri): List<Map<String, Any?>> {
        val treeDocId = DocumentsContract.getDocumentId(docUri)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(docUri, treeDocId)
        val out = mutableListOf<Map<String, Any?>>()
        contentResolver.query(childrenUri, columns, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val id = c.getString(0)
                val uri = DocumentsContract.buildDocumentUriUsingTree(docUri, id)
                out.add(rowToMap(uri, c))
            }
        } ?: throw FileNotFoundException("La carpeta ya no está disponible")
        return out
    }

    private fun stat(uri: Uri): Map<String, Any?> {
        // Las URIs de documento sueltas (ACTION_OPEN_DOCUMENT) también aceptan esta consulta.
        contentResolver.query(uri, columns, null, null, null)?.use { c ->
            if (c.moveToFirst()) return rowToMap(uri, c)
        }
        // Respaldo para proveedores que sólo exponen OpenableColumns.
        contentResolver.query(uri, null, null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                val nameIdx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIdx = c.getColumnIndex(OpenableColumns.SIZE)
                return mapOf(
                    "ref" to uri.toString(),
                    "name" to if (nameIdx >= 0) c.getString(nameIdx) else uri.lastPathSegment,
                    "isDir" to false,
                    "size" to if (sizeIdx >= 0 && !c.isNull(sizeIdx)) c.getLong(sizeIdx) else null,
                    "modified" to null,
                    "mime" to contentResolver.getType(uri),
                    "canWrite" to false, "canDelete" to false, "canRename" to false, "canCreate" to false,
                )
            }
        }
        throw FileNotFoundException("El documento no existe o se revocó el permiso")
    }

    private fun rowToMap(uri: Uri, c: Cursor): Map<String, Any?> {
        val mime = c.getString(2)
        val flags = if (c.isNull(5)) 0 else c.getInt(5)
        val isDir = mime == DocumentsContract.Document.MIME_TYPE_DIR
        return mapOf(
            "ref" to uri.toString(),
            "name" to c.getString(1),
            "isDir" to isDir,
            "size" to if (isDir || c.isNull(3)) null else c.getLong(3),
            "modified" to if (c.isNull(4)) null else c.getLong(4),
            "mime" to if (isDir) null else mime,
            "canWrite" to (flags and DocumentsContract.Document.FLAG_SUPPORTS_WRITE != 0),
            "canDelete" to (flags and DocumentsContract.Document.FLAG_SUPPORTS_DELETE != 0),
            "canRename" to (flags and DocumentsContract.Document.FLAG_SUPPORTS_RENAME != 0),
            "canCreate" to (flags and DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE != 0),
        )
    }

    // ------------------------------------------------------------------ utilidades

    private fun openInput(ref: String): InputStream =
        if (ref.startsWith("content://")) {
            contentResolver.openInputStream(Uri.parse(ref))
                ?: throw FileNotFoundException("No se pudo abrir el documento")
        } else {
            FileInputStream(File(ref))
        }

    private fun readLimited(input: InputStream, max: Long): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buf = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val n = input.read(buf)
            if (n < 0) break
            val take = minOf(n.toLong(), max - total).toInt()
            out.write(buf, 0, take)
            total += take
            if (total >= max) break
        }
        return out.toByteArray()
    }

    private fun localAttributes(path: String): Map<String, Any?> {
        val f = File(path)
        if (!f.exists()) throw FileNotFoundException("El archivo no existe")
        var created: Long? = null
        // La fecha de creación sólo está disponible con java.nio (API 26+).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            created = runCatching {
                java.nio.file.Files.readAttributes(
                    f.toPath(), java.nio.file.attribute.BasicFileAttributes::class.java
                ).creationTime().toMillis()
            }.getOrNull()
        }
        return mapOf(
            "created" to created,
            "modified" to f.lastModified(),
            "size" to if (f.isDirectory) null else f.length(),
            "type" to if (f.isDirectory) null else guessMime(f.name),
        )
    }

    private fun guessMime(name: String): String {
        val ext = name.substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: when (ext) {
            "md" -> "text/markdown"
            "json" -> "application/json"
            "xml" -> "text/xml"
            else -> "application/octet-stream"
        }
    }

    private fun openWith(ref: String, mime: String?, result: MethodChannel.Result) {
        try {
            val uri = if (ref.startsWith("content://")) Uri.parse(ref)
            else FileProvider.getUriForFile(this, "$packageName.files", File(ref))
            val type = mime ?: contentResolver.getType(uri) ?: guessMime(ref)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, type)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Abrir con"))
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.success(false)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    /** Ejecuta en segundo plano y traduce excepciones a códigos que Dart entiende. */
    private fun background(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: SecurityException) {
                main.post { result.error("PERMISSION_DENIED", e.message, null) }
            } catch (e: FileNotFoundException) {
                main.post { result.error("NOT_FOUND", e.message, null) }
            } catch (e: IOException) {
                val code = if (e.message?.contains("ENOSPC") == true ||
                    e.message?.contains("No space", true) == true) "NO_SPACE" else "IO_ERROR"
                main.post { result.error(code, e.message, null) }
            } catch (e: UnsupportedOperationException) {
                main.post { result.error("UNSUPPORTED", e.message, null) }
            } catch (e: IllegalArgumentException) {
                main.post { result.error("NOT_FOUND", e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("IO_ERROR", e.message, null) }
            }
        }
    }
}
