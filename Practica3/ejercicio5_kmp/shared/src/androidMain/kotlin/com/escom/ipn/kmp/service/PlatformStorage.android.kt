package com.escom.ipn.kmp.service

import android.content.Context
import java.io.File

actual class PlatformStorage(private val context: Context) {

    actual fun getAppDataDirectory(): String {
        val dir = File(context.filesDir, "kmp_media_vault")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir.absolutePath
    }

    actual fun fileExists(path: String): Boolean {
        return File(path).exists()
    }

    actual fun deleteFile(path: String): Boolean {
        return File(path).delete()
    }

    actual fun getFileSize(path: String): Long {
        val file = File(path)
        return if (file.exists()) file.length() else 0L
    }

    actual fun writeText(path: String, content: String): Boolean {
        return try {
            val file = File(path)
            file.parentFile?.mkdirs()
            file.writeText(content)
            true
        } catch (_: Exception) {
            false
        }
    }

    actual fun readText(path: String): String? {
        return try {
            val file = File(path)
            if (file.exists()) file.readText() else null
        } catch (_: Exception) {
            null
        }
    }
}
