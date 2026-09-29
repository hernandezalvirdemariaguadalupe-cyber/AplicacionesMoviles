package com.escom.ipn.kmp.service

/**
 * Servicio multiplataforma para almacenamiento de archivos en el sandbox local.
 * En Android utiliza Context.filesDir.
 * En iOS utiliza FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).
 */
expect class PlatformStorage {
    fun getAppDataDirectory(): String
    fun fileExists(path: String): Boolean
    fun deleteFile(path: String): Boolean
    fun getFileSize(path: String): Long
    fun writeText(path: String, content: String): Boolean
    fun readText(path: String): String?
}
