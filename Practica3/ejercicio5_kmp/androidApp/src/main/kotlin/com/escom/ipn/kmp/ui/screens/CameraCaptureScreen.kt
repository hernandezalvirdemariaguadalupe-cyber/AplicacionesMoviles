package com.escom.ipn.kmp.ui.screens

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Camera
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Cameraswitch
import androidx.compose.material.icons.filled.FlashAuto
import androidx.compose.material.icons.filled.FlashOff
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.escom.ipn.kmp.model.MediaCategory
import com.escom.ipn.kmp.viewmodel.MediaViewModel
import java.io.File
import java.io.FileOutputStream

@Composable
fun CameraCaptureScreen(
    viewModel: MediaViewModel,
    hasCameraPermission: Boolean,
    onRequestCameraPermission: () -> Unit
) {
    val context = LocalContext.current
    var flashMode by remember { mutableIntStateOf(0) } // 0: Auto, 1: On, 2: Off
    var timerSeconds by remember { mutableIntStateOf(0) } // 0, 3, 5
    var isFrontCamera by remember { mutableStateOf(false) }
    var photoTitle by remember { mutableStateOf("") }
    var photoNotes by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf(MediaCategory.EVIDENCIA) }
    var lastCapturedPath by remember { mutableStateOf<String?>(null) }
    var showSuccessBanner by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // Cabecera superior
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            ),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Módulo de Cámara KMP",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "Captura de fotografías de alta resolución con metadatos y almacenamiento offline en el sandbox.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // Visor central / Vista Previa
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .padding(vertical = 12.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(Color(0xFF1E1E24)),
            contentAlignment = Alignment.Center
        ) {
            if (!hasCameraPermission) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(24.dp)
                ) {
                    Icon(
                        Icons.Default.CameraAlt,
                        contentDescription = null,
                        tint = Color.LightGray,
                        modifier = Modifier.size(64.dp)
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "Permiso de Cámara Requerido",
                        style = MaterialTheme.typography.titleMedium,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "La aplicación requiere acceso a la cámara para tomar fotografías y registrarlas en la galería institucional.",
                        color = Color.LightGray,
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.bodySmall
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(
                        onClick = onRequestCameraPermission,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primary
                        )
                    ) {
                        Text("Conceder Permiso")
                    }
                }
            } else {
                // Interfaz de Visor Activo
                Column(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.SpaceBetween,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // Barra superior del visor con toggles
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color.Black.copy(alpha = 0.5f))
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Flash
                        IconButton(onClick = { flashMode = (flashMode + 1) % 3 }) {
                            val icon = when (flashMode) {
                                1 -> Icons.Default.FlashOn
                                2 -> Icons.Default.FlashOff
                                else -> Icons.Default.FlashAuto
                            }
                            Icon(icon, contentDescription = "Flash", tint = Color.White)
                        }

                        // Temporizador
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .clip(RoundedCornerShape(16.dp))
                                .background(Color.White.copy(alpha = 0.2f))
                                .clickable {
                                    timerSeconds = when (timerSeconds) {
                                        0 -> 3
                                        3 -> 5
                                        else -> 0
                                    }
                                }
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Icon(Icons.Default.Timer, contentDescription = "Timer", tint = Color.White, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = if (timerSeconds == 0) "Off" else "${timerSeconds}s",
                                color = Color.White,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }

                        // Alternar cámara
                        IconButton(onClick = { isFrontCamera = !isFrontCamera }) {
                            Icon(Icons.Default.Cameraswitch, contentDescription = "Alternar cámara", tint = Color.White)
                        }
                    }

                    // Cuadro de enfoque institucional
                    Box(
                        modifier = Modifier
                            .size(240.dp)
                            .border(2.dp, Color.White.copy(alpha = 0.6f), RoundedCornerShape(12.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                Icons.Default.PhotoCamera,
                                contentDescription = null,
                                tint = Color.White.copy(alpha = 0.7f),
                                modifier = Modifier.size(48.dp)
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = if (isFrontCamera) "Cámara Frontal" else "Cámara Trasera",
                                color = Color.White.copy(alpha = 0.8f),
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }

                    // Banner informativo inferior en el visor
                    if (showSuccessBanner) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(Color(0xFF2E7D32).copy(alpha = 0.9f))
                                .padding(8.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "¡Fotografía guardada con éxito en el sandbox!",
                                color = Color.White,
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp
                            )
                        }
                    } else {
                        Spacer(modifier = Modifier.height(32.dp))
                    }
                }
            }
        }

        // Formulario de metadatos de captura
        if (hasCameraPermission) {
            Column(modifier = Modifier.fillMaxWidth()) {
                OutlinedTextField(
                    value = photoTitle,
                    onValueChange = { photoTitle = it },
                    label = { Text("Título de la foto") },
                    placeholder = { Text("Ej. Evidencia Práctica 3 ESCOM") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    MediaCategory.entries.forEach { cat ->
                        FilterChip(
                            selected = selectedCategory == cat,
                            onClick = { selectedCategory = cat },
                            label = { Text(cat.name, fontSize = 12.sp) }
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Botón de Disparo
            IconButton(
                onClick = {
                    val timestamp = System.currentTimeMillis()
                    val title = photoTitle.ifBlank { "Captura ESCOM ${timestamp % 10000}" }
                    val fileName = "foto_${timestamp}.jpg"
                    val file = File(viewModel.storage.getAppDataDirectory(), fileName)

                    // Generar imagen bitmap de alta fidelidad para el sandbox
                    val width = 1080
                    val height = 1440
                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bitmap)

                    // Dibujar fondo institucional simulando foto
                    val paintBg = Paint().apply { color = android.graphics.Color.parseColor("#1A1A24") }
                    canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paintBg)

                    val paintGuinda = Paint().apply { color = android.graphics.Color.parseColor("#6C1D45") }
                    canvas.drawRect(0f, 0f, width.toFloat(), 180f, paintGuinda)

                    val paintText = Paint().apply {
                        color = android.graphics.Color.WHITE
                        textSize = 48f
                        isAntiAlias = true
                        isFakeBoldText = true
                    }
                    canvas.drawText("ESCOM - IPN | PRÁCTICA 3", 60f, 110f, paintText)

                    val paintSubtext = Paint().apply {
                        color = android.graphics.Color.parseColor("#D4AF37")
                        textSize = 36f
                        isAntiAlias = true
                    }
                    canvas.drawText("Título: $title", 60f, 300f, paintSubtext)
                    canvas.drawText("Categoría: ${selectedCategory.name}", 60f, 360f, paintSubtext)
                    canvas.drawText("Cámara: ${if (isFrontCamera) "Frontal" else "Trasera"}", 60f, 420f, paintSubtext)
                    canvas.drawText("Timestamp: $timestamp", 60f, 480f, paintSubtext)

                    FileOutputStream(file).use { out ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                    }

                    viewModel.registerCapturedPhoto(title, file.absolutePath, selectedCategory, photoNotes)
                    lastCapturedPath = file.absolutePath
                    showSuccessBanner = true
                    photoTitle = ""
                    photoNotes = ""
                },
                modifier = Modifier
                    .size(76.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary)
            ) {
                Icon(
                    Icons.Default.Camera,
                    contentDescription = "Tomar foto",
                    tint = MaterialTheme.colorScheme.onPrimary,
                    modifier = Modifier.size(38.dp)
                )
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Presiona para capturar",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
