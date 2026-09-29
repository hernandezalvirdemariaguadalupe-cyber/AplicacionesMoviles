package com.escom.ipn.kmp.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import com.escom.ipn.kmp.model.ThemeColor
import com.escom.ipn.kmp.model.ThemeConfig
import com.escom.ipn.kmp.model.ThemeMode

private val GuindaLightScheme = lightColorScheme(
    primary = IpnGuinda,
    onPrimary = SurfaceLight,
    primaryContainer = IpnGuindaLight,
    onPrimaryContainer = SurfaceLight,
    secondary = IpnOro,
    onSecondary = TextPrimaryLight,
    background = BackgroundLight,
    onBackground = TextPrimaryLight,
    surface = SurfaceLight,
    onSurface = TextPrimaryLight,
    surfaceVariant = SurfaceVariantLight,
    onSurfaceVariant = TextSecondaryLight
)

private val GuindaDarkScheme = darkColorScheme(
    primary = IpnGuindaLight,
    onPrimary = SurfaceLight,
    primaryContainer = IpnGuinda,
    onPrimaryContainer = IpnOro,
    secondary = IpnOro,
    onSecondary = TextPrimaryLight,
    background = BackgroundDark,
    onBackground = TextPrimaryDark,
    surface = SurfaceDark,
    onSurface = TextPrimaryDark,
    surfaceVariant = SurfaceVariantDark,
    onSurfaceVariant = TextSecondaryDark
)

private val AzulLightScheme = lightColorScheme(
    primary = EscomAzul,
    onPrimary = SurfaceLight,
    primaryContainer = EscomAzulLight,
    onPrimaryContainer = SurfaceLight,
    secondary = EscomCeleste,
    onSecondary = SurfaceLight,
    background = BackgroundLight,
    onBackground = TextPrimaryLight,
    surface = SurfaceLight,
    onSurface = TextPrimaryLight,
    surfaceVariant = SurfaceVariantLight,
    onSurfaceVariant = TextSecondaryLight
)

private val AzulDarkScheme = darkColorScheme(
    primary = EscomCeleste,
    onPrimary = BackgroundDark,
    primaryContainer = EscomAzul,
    onPrimaryContainer = EscomCelesteLight,
    secondary = EscomCelesteLight,
    onSecondary = BackgroundDark,
    background = BackgroundDark,
    onBackground = TextPrimaryDark,
    surface = SurfaceDark,
    onSurface = TextPrimaryDark,
    surfaceVariant = SurfaceVariantDark,
    onSurfaceVariant = TextSecondaryDark
)

@Composable
fun KmpMediaTheme(
    themeConfig: ThemeConfig,
    content: @Composable () -> Unit
) {
    val isDark = when (themeConfig.mode) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }

    val colorScheme: ColorScheme = when (themeConfig.color) {
        ThemeColor.GUINDA -> if (isDark) GuindaDarkScheme else GuindaLightScheme
        ThemeColor.AZUL -> if (isDark) AzulDarkScheme else AzulLightScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}
