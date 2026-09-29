package com.escom.ipn.kmp.repository

import com.escom.ipn.kmp.model.MediaCategory
import com.escom.ipn.kmp.model.MediaItem
import com.escom.ipn.kmp.model.MediaType
import com.escom.ipn.kmp.model.ThemeColor
import com.escom.ipn.kmp.model.ThemeConfig
import com.escom.ipn.kmp.model.ThemeMode
import com.escom.ipn.kmp.service.PlatformStorage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class MediaRepository(private val storage: PlatformStorage) {

    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
    }

    private val catalogFileName = "media_catalog.json"
    private val themeFileName = "theme_config.json"

    private val _items = MutableStateFlow<List<MediaItem>>(emptyList())
    val items: StateFlow<List<MediaItem>> = _items.asStateFlow()

    private val _themeConfig = MutableStateFlow(ThemeConfig())
    val themeConfig: StateFlow<ThemeConfig> = _themeConfig.asStateFlow()

    init {
        loadTheme()
        loadCatalog()
    }

    private fun getCatalogPath(): String =
        "${storage.getAppDataDirectory()}/$catalogFileName"

    private fun getThemePath(): String =
        "${storage.getAppDataDirectory()}/$themeFileName"

    private fun loadCatalog() {
        val path = getCatalogPath()
        val text = storage.readText(path)
        if (text != null && text.isNotBlank()) {
            try {
                val parsed = json.decodeFromString<List<MediaItem>>(text)
                _items.value = parsed.sortedByDescending { it.timestamp }
                return
            } catch (_: Exception) {
                // Si falla lectura, semilla inicial
            }
        }
        seedInitialData()
    }

    private fun seedInitialData() {
        val now = 1774846800000L // 28 Septiembre 2026
        val initialList = listOf(
            MediaItem(
                id = "item_seed_1",
                title = "Bienvenida ESCOM IPN 2027-1",
                type = MediaType.AUDIO,
                filePath = "${storage.getAppDataDirectory()}/audio_bienvenida.m4a",
                timestamp = now - 3600000,
                durationMs = 125000, // 2:05
                sizeBytes = 2048576, // ~2 MB
                category = MediaCategory.INSTITUCIONAL,
                notes = "Audio demostrativo grabado para la Práctica 3 de Desarrollo Móvil."
            ),
            MediaItem(
                id = "item_seed_2",
                title = "Fachada ESCOM Zacatenco",
                type = MediaType.PHOTO,
                filePath = "${storage.getAppDataDirectory()}/foto_escom.jpg",
                timestamp = now - 7200000,
                sizeBytes = 3145728, // ~3 MB
                category = MediaCategory.INSTITUCIONAL,
                notes = "Captura de la entrada principal de la Escuela Superior de Cómputo."
            ),
            MediaItem(
                id = "item_seed_3",
                title = "Nota de Laboratorio Móvil",
                type = MediaType.AUDIO,
                filePath = "${storage.getAppDataDirectory()}/nota_lab.m4a",
                timestamp = now - 1800000,
                durationMs = 45000, // 0:45
                sizeBytes = 720000,
                category = MediaCategory.EVIDENCIA,
                notes = "Prueba de sensibilidad del micrófono en el entorno emulado."
            )
        )
        _items.value = initialList
        saveCatalog()
    }

    fun addItem(item: MediaItem) {
        val updated = listOf(item) + _items.value
        _items.value = updated
        saveCatalog()
    }

    fun deleteItem(item: MediaItem) {
        if (storage.fileExists(item.filePath)) {
            storage.deleteFile(item.filePath)
        }
        val updated = _items.value.filter { it.id != item.id }
        _items.value = updated
        saveCatalog()
    }

    private fun saveCatalog() {
        try {
            val content = json.encodeToString(_items.value)
            storage.writeText(getCatalogPath(), content)
        } catch (_: Exception) {}
    }

    fun updateTheme(color: ThemeColor, mode: ThemeMode) {
        val newConfig = ThemeConfig(color = color, mode = mode)
        _themeConfig.value = newConfig
        try {
            val content = json.encodeToString(newConfig)
            storage.writeText(getThemePath(), content)
        } catch (_: Exception) {}
    }

    private fun loadTheme() {
        val path = getThemePath()
        val text = storage.readText(path)
        if (text != null && text.isNotBlank()) {
            try {
                val parsed = json.decodeFromString<ThemeConfig>(text)
                _themeConfig.value = parsed
            } catch (_: Exception) {}
        }
    }
}
