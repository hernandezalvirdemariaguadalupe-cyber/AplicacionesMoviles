package com.escom.ipn.kmp.model

import kotlinx.serialization.Serializable

@Serializable
enum class ThemeColor {
    GUINDA, // IPN (#6C1D45)
    AZUL    // ESCOM (#003366)
}

@Serializable
enum class ThemeMode {
    SYSTEM,
    LIGHT,
    DARK
}

@Serializable
data class ThemeConfig(
    val color: ThemeColor = ThemeColor.GUINDA,
    val mode: ThemeMode = ThemeMode.SYSTEM
)
