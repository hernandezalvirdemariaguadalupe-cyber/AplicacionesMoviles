package com.escom.ipn.kmp.ui.screens

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
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
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.escom.ipn.kmp.model.MediaCategory
import com.escom.ipn.kmp.ui.theme.ColorRecording
import com.escom.ipn.kmp.viewmodel.MediaViewModel
import com.escom.ipn.kmp.viewmodel.RecordingStatus

@Composable
fun AudioRecordScreen(
    viewModel: MediaViewModel,
    hasMicPermission: Boolean,
    onRequestMicPermission: () -> Unit
) {
    val recordingStatus by viewModel.recordingStatus.collectAsState()
    var recordTitle by remember { mutableStateOf("") }
    var recordNotes by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf(MediaCategory.EVIDENCIA) }

    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(800),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse_scale"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // Cabecera descriptiva
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            ),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Grabadora de Audio KMP",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "Captura notas de voz en formato AAC/M4A 100% offline dentro del sandbox local.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // Área central: Temporizador y visualización
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(vertical = 24.dp)
        ) {
            when (val status = recordingStatus) {
                is RecordingStatus.Recording -> {
                    val minutes = status.durationSeconds / 60
                    val seconds = status.durationSeconds % 60
                    val timerStr = "${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}"

                    Text(
                        text = timerStr,
                        fontSize = 54.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = ColorRecording
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = "GRABANDO AUDIO NATIVO",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = ColorRecording
                    )
                    Spacer(modifier = Modifier.height(16.dp))

                    // Indicador de nivel sonoro (amplitud simulada/real)
                    val ampNormalized = (status.amplitude / 32767f).coerceIn(0.1f, 1f)
                    Row(
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(40.dp)
                    ) {
                        for (i in 1..9) {
                            val barHeight = (30 * ampNormalized * (1 - kotlin.math.abs(5 - i) * 0.15f)).coerceAtLeast(6f)
                            Box(
                                modifier = Modifier
                                    .padding(horizontal = 4.dp)
                                    .width(6.dp)
                                    .height(barHeight.dp)
                                    .clip(RoundedCornerShape(3.dp))
                                    .background(ColorRecording)
                            )
                        }
                    }
                }
                is RecordingStatus.Finished -> {
                    Text(
                        text = "Grabación lista para archivar",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Tamaño: ${(status.sizeBytes / 1024)} KB",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                RecordingStatus.Idle -> {
                    Text(
                        text = "00:00",
                        fontSize = 54.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Listo para iniciar grabación",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        // Metadatos y categorías cuando se va a guardar
        if (recordingStatus is RecordingStatus.Finished) {
            Column(modifier = Modifier.fillMaxWidth()) {
                OutlinedTextField(
                    value = recordTitle,
                    onValueChange = { recordTitle = it },
                    label = { Text("Título de la grabación") },
                    placeholder = { Text("Ej. Nota de prueba laboratorio") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = recordNotes,
                    onValueChange = { recordNotes = it },
                    label = { Text("Notas / Observaciones (opcional)") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 2
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
        }

        // Controles de acción
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(bottom = 16.dp)
        ) {
            if (!hasMicPermission) {
                Button(
                    onClick = onRequestMicPermission,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary
                    )
                ) {
                    Icon(Icons.Default.Mic, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Conceder permiso de Micrófono")
                }
            } else {
                when (recordingStatus) {
                    is RecordingStatus.Recording -> {
                        Row(
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            IconButton(
                                onClick = { viewModel.cancelRecording() },
                                modifier = Modifier
                                    .size(56.dp)
                                    .clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.surfaceVariant)
                            ) {
                                Icon(Icons.Default.Close, contentDescription = "Cancelar", tint = Color.Gray)
                            }
                            Spacer(modifier = Modifier.width(32.dp))
                            IconButton(
                                onClick = {
                                    val title = recordTitle.ifBlank { "Grabación ${System.currentTimeMillis() % 10000}" }
                                    viewModel.stopRecording(title, selectedCategory, recordNotes)
                                },
                                modifier = Modifier
                                    .size(80.dp)
                                    .scale(pulseScale)
                                    .clip(CircleShape)
                                    .background(ColorRecording)
                            ) {
                                Icon(Icons.Default.Stop, contentDescription = "Detener", tint = Color.White, modifier = Modifier.size(36.dp))
                            }
                        }
                    }
                    is RecordingStatus.Finished -> {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(16.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Button(
                                onClick = { viewModel.resetRecordingState() },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                                    contentColor = MaterialTheme.colorScheme.onSurfaceVariant
                                ),
                                modifier = Modifier.weight(1f)
                            ) {
                                Text("Descartar")
                            }
                            Button(
                                onClick = {
                                    viewModel.resetRecordingState()
                                    recordTitle = ""
                                    recordNotes = ""
                                },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = MaterialTheme.colorScheme.primary
                                ),
                                modifier = Modifier.weight(1f)
                            ) {
                                Icon(Icons.Default.Check, contentDescription = null)
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Aceptar")
                            }
                        }
                    }
                    RecordingStatus.Idle -> {
                        IconButton(
                            onClick = { viewModel.startRecording() },
                            modifier = Modifier
                                .size(80.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primary)
                        ) {
                            Icon(Icons.Default.Mic, contentDescription = "Iniciar grabación", tint = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.size(38.dp))
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Presiona para grabar",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}
