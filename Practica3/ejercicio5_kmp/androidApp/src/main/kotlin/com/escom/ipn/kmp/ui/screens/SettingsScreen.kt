package com.escom.ipn.kmp.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BrightnessAuto
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.escom.ipn.kmp.model.ThemeColor
import com.escom.ipn.kmp.model.ThemeMode
import com.escom.ipn.kmp.ui.theme.EscomAzul
import com.escom.ipn.kmp.ui.theme.EscomCeleste
import com.escom.ipn.kmp.ui.theme.IpnGuinda
import com.escom.ipn.kmp.ui.theme.IpnOro
import com.escom.ipn.kmp.viewmodel.MediaViewModel

@Composable
fun SettingsScreen(viewModel: MediaViewModel) {
    val themeConfig by viewModel.themeConfig.collectAsState()
    val items by viewModel.items.collectAsState()
    val scrollState = rememberScrollState()

    val totalBytes = items.sumOf { it.sizeBytes }
    val totalSizeMb = (totalBytes / (1024.0 * 1024.0) * 10).toInt() / 10.0

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Sección de Identidad Gráfica Institucional
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Palette, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Identidad Institucional",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = "Selecciona la paleta de colores oficial:",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(modifier = Modifier.height(12.dp))

                // Selector Guinda IPN
                PaletteOptionCard(
                    title = "Guinda IPN",
                    subtitle = "Pantone 222 C (#6C1D45) y Oro (#D4AF37)",
                    primaryColor = IpnGuinda,
                    secondaryColor = IpnOro,
                    isSelected = themeConfig.color == ThemeColor.GUINDA,
                    onClick = { viewModel.setTheme(ThemeColor.GUINDA, themeConfig.mode) }
                )

                Spacer(modifier = Modifier.height(8.dp))

                // Selector Azul ESCOM
                PaletteOptionCard(
                    title = "Azul ESCOM",
                    subtitle = "Pantone 295 C (#003366) y Celeste (#0099FF)",
                    primaryColor = EscomAzul,
                    secondaryColor = EscomCeleste,
                    isSelected = themeConfig.color == ThemeColor.AZUL,
                    onClick = { viewModel.setTheme(ThemeColor.AZUL, themeConfig.mode) }
                )
            }
        }

        // Modo de iluminación (Claro / Oscuro / Sistema)
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Modo de Iluminación",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FilterChip(
                        selected = themeConfig.mode == ThemeMode.SYSTEM,
                        onClick = { viewModel.setTheme(themeConfig.color, ThemeMode.SYSTEM) },
                        leadingIcon = { Icon(Icons.Default.BrightnessAuto, contentDescription = null) },
                        label = { Text("Sistema") }
                    )
                    FilterChip(
                        selected = themeConfig.mode == ThemeMode.LIGHT,
                        onClick = { viewModel.setTheme(themeConfig.color, ThemeMode.LIGHT) },
                        leadingIcon = { Icon(Icons.Default.LightMode, contentDescription = null) },
                        label = { Text("Claro") }
                    )
                    FilterChip(
                        selected = themeConfig.mode == ThemeMode.DARK,
                        onClick = { viewModel.setTheme(themeConfig.color, ThemeMode.DARK) },
                        leadingIcon = { Icon(Icons.Default.DarkMode, contentDescription = null) },
                        label = { Text("Oscuro") }
                    )
                }
            }
        }

        // Sandbox & Almacenamiento Offline
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Storage, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Sandbox de Almacenamiento Local",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Total de medios almacenados: ${items.size} archivos (~$totalSizeMb MB)",
                    style = MaterialTheme.typography.bodyMedium
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Ruta: ${viewModel.storage.getAppDataDirectory()}",
                    style = MaterialTheme.typography.bodySmall,
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(8.dp))
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color(0xFF2E7D32).copy(alpha = 0.15f))
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Text(
                        text = "• Operatividad 100% Offline verificada",
                        color = Color(0xFF2E7D32),
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp
                    )
                }
            }
        }

        // Información Académica y del Equipo
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Info, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Información del Proyecto",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Materia: Desarrollo de Aplicaciones Móviles Nativas\n" +
                            "Profesor: Gabriel Hurtado Avilés\n" +
                            "Grupo: 7CV4 | Ciclo: 2027-1\n" +
                            "Integrantes:\n" +
                            "• Hernández Alvirde María Guadalupe (Boleta 2022630105)\n" +
                            "• Aragón Martínez Manuel Alejandro",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    lineHeight = 18.sp
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Arquitectura: Kotlin Multiplatform (KMP) con módulo común 'shared' (commonMain, androidMain, iosMain) e interfaces declarativas.",
                    style = MaterialTheme.typography.bodySmall,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}

@Composable
fun PaletteOptionCard(
    title: String,
    subtitle: String,
    primaryColor: Color,
    secondaryColor: Color,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = if (isSelected) MaterialTheme.colorScheme.primary else Color.LightGray.copy(alpha = 0.4f),
                shape = RoundedCornerShape(12.dp)
            )
            .clickable { onClick() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy((-8).dp)) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(primaryColor)
            )
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(secondaryColor)
            )
        }
        Spacer(modifier = Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(text = title, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleSmall)
            Text(text = subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp)
        }
        if (isSelected) {
            Icon(Icons.Default.Check, contentDescription = "Seleccionado", tint = MaterialTheme.colorScheme.primary)
        }
    }
}
