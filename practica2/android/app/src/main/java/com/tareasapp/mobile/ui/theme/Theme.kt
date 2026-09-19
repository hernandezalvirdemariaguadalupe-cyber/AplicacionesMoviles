package com.tareasapp.mobile.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val AzulPrimario = Color(0xFF1565C0)
private val AzulSecundario = Color(0xFF5E92F3)
private val Fondo = Color(0xFFF5F7FA)

private val LightColors = lightColorScheme(
    primary = AzulPrimario,
    secondary = AzulSecundario,
    background = Fondo,
    surface = Color.White
)

private val DarkColors = darkColorScheme(
    primary = AzulSecundario,
    secondary = AzulPrimario
)

@Composable
fun TareasAppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = if (darkTheme) DarkColors else LightColors
    MaterialTheme(
        colorScheme = colors,
        content = content
    )
}
