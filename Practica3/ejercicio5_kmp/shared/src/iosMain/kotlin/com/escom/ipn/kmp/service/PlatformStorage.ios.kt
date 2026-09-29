package com.escom.ipn.kmp.service

actual class PlatformStorage {

    actual fun getAppDataDirectory(): String = "/Documents/kmp_media_vault"

    actual fun fileExists(path: String): Boolean = false

    actual fun deleteFile(path: String): Boolean = true

    actual fun getFileSize(path: String): Long = 0L

    actual fun writeText(path: String, content: String): Boolean = true

    actual fun readText(path: String): String? = null
}
