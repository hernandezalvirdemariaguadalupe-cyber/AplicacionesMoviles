package com.escom.ipn.kmp.model

import kotlinx.serialization.Serializable

@Serializable
enum class MediaType {
    PHOTO,
    AUDIO
}

@Serializable
enum class MediaCategory {
    INSTITUCIONAL,
    EVIDENCIA,
    PERSONAL
}

@Serializable
data class MediaItem(
    val id: String,
    val title: String,
    val type: MediaType,
    val filePath: String,
    val timestamp: Long,
    val durationMs: Long = 0L,
    val sizeBytes: Long = 0L,
    val category: MediaCategory = MediaCategory.INSTITUCIONAL,
    val notes: String = ""
) {
    val formattedSize: String
        get() {
            if (sizeBytes <= 0) return "0 B"
            val kb = sizeBytes / 1024.0
            val mb = kb / 1024.0
            return when {
                mb >= 1.0 -> "${(mb * 10).toInt() / 10.0} MB"
                kb >= 1.0 -> "${(kb * 10).toInt() / 10.0} KB"
                else -> "$sizeBytes B"
            }
        }

    val formattedDuration: String
        get() {
            val totalSeconds = durationMs / 1000
            val minutes = totalSeconds / 60
            val seconds = totalSeconds % 60
            return "${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}"
        }
}
