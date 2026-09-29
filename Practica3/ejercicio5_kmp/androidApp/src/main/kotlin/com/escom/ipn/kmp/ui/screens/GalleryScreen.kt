package com.escom.ipn.kmp.ui.screens

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Audiotrack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.escom.ipn.kmp.model.MediaItem
import com.escom.ipn.kmp.model.MediaType
import com.escom.ipn.kmp.ui.theme.ColorAudio
import com.escom.ipn.kmp.ui.theme.ColorPhoto
import com.escom.ipn.kmp.viewmodel.MediaViewModel
import com.escom.ipn.kmp.viewmodel.PlaybackStatus
import java.io.File

@Composable
fun GalleryScreen(viewModel: MediaViewModel) {
    val items by viewModel.filteredItems.collectAsState()
    val currentFilter by viewModel.selectedFilter.collectAsState()
    val searchQuery by viewModel.searchQuery.collectAsState()
    val playbackStatus by viewModel.playbackStatus.collectAsState()

    var previewPhotoPath by remember { mutableStateOf<String?>(null) }
    var itemToDelete by remember { mutableStateOf<MediaItem?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        // Barra de búsqueda
        OutlinedTextField(
            value = searchQuery,
            onValueChange = { viewModel.setSearchQuery(it) },
            placeholder = { Text("Buscar fotos o audios...") },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp),
            singleLine = true,
            shape = RoundedCornerShape(12.dp)
        )

        // Chips de filtro
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Default.FilterList, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            FilterChip(
                selected = currentFilter == null,
                onClick = { viewModel.setFilter(null) },
                label = { Text("Todos (${items.size})") }
            )
            FilterChip(
                selected = currentFilter == MediaType.PHOTO,
                onClick = { viewModel.setFilter(MediaType.PHOTO) },
                label = { Text("Fotos") }
            )
            FilterChip(
                selected = currentFilter == MediaType.AUDIO,
                onClick = { viewModel.setFilter(MediaType.AUDIO) },
                label = { Text("Audios") }
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        if (items.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "No hay medios registrados aún.\nUtiliza las pestañas de Cámara o Micrófono para capturar.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(items, key = { it.id }) { item ->
                    MediaItemCard(
                        item = item,
                        playbackStatus = playbackStatus,
                        onPlayClick = { viewModel.playAudio(item) },
                        onPauseClick = { viewModel.pauseAudio() },
                        onResumeClick = { viewModel.resumeAudio() },
                        onPhotoClick = { previewPhotoPath = item.filePath },
                        onDeleteClick = { itemToDelete = item }
                    )
                }
            }
        }
    }

    // Diálogo de confirmación para eliminar
    itemToDelete?.let { item ->
        AlertDialog(
            onDismissRequest = { itemToDelete = null },
            title = { Text("Eliminar elemento") },
            text = { Text("¿Deseas eliminar '${item.title}' del almacenamiento local offline?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deleteItem(item)
                        itemToDelete = null
                    }
                ) {
                    Text("Eliminar", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { itemToDelete = null }) {
                    Text("Cancelar")
                }
            }
        )
    }

    // Modal a pantalla completa para visualizar foto
    previewPhotoPath?.let { path ->
        val file = File(path)
        Dialog(onDismissRequest = { previewPhotoPath = null }) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(8.dp),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = file.name,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.height(12.dp))

                    if (file.exists()) {
                        val bitmap = BitmapFactory.decodeFile(file.absolutePath)
                        if (bitmap != null) {
                            Image(
                                bitmap = bitmap.asImageBitmap(),
                                contentDescription = "Foto capturada",
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(320.dp)
                                    .clip(RoundedCornerShape(8.dp))
                            )
                        } else {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(200.dp)
                                    .background(Color.DarkGray),
                                contentAlignment = Alignment.Center
                            ) {
                                Text("Foto de muestra institucional", color = Color.White)
                            }
                        }
                    } else {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(200.dp)
                                .background(Color.DarkGray),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("Archivo no encontrado en sandbox", color = Color.White)
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))
                    Button(
                        onClick = { previewPhotoPath = null },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Cerrar")
                    }
                }
            }
        }
    }
}

@Composable
fun MediaItemCard(
    item: MediaItem,
    playbackStatus: PlaybackStatus,
    onPlayClick: () -> Unit,
    onPauseClick: () -> Unit,
    onResumeClick: () -> Unit,
    onPhotoClick: () -> Unit,
    onDeleteClick: () -> Unit
) {
    val isPlayingThis = playbackStatus is PlaybackStatus.Playing && playbackStatus.item.id == item.id
    val isPausedThis = playbackStatus is PlaybackStatus.Paused && playbackStatus.item.id == item.id

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = item.type == MediaType.PHOTO) { onPhotoClick() },
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f))
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Badge de tipo
                val badgeColor = if (item.type == MediaType.PHOTO) ColorPhoto else ColorAudio
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(badgeColor.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = if (item.type == MediaType.PHOTO) Icons.Default.Image else Icons.Default.Audiotrack,
                        contentDescription = null,
                        tint = badgeColor,
                        modifier = Modifier.size(24.dp)
                    )
                }

                Spacer(modifier = Modifier.width(12.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = item.title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = "${item.category.name} • ${item.formattedSize}" +
                                if (item.type == MediaType.AUDIO && item.durationMs > 0) " • ${item.formattedDuration}" else "",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 11.sp
                    )
                }

                // Botón de Play/Pause para audio o botón de ver foto
                if (item.type == MediaType.AUDIO) {
                    IconButton(
                        onClick = {
                            when {
                                isPlayingThis -> onPauseClick()
                                isPausedThis -> onResumeClick()
                                else -> onPlayClick()
                            }
                        }
                    ) {
                        Icon(
                            imageVector = if (isPlayingThis) Icons.Default.Pause else Icons.Default.PlayArrow,
                            contentDescription = "Reproducir/Pausar",
                            tint = ColorAudio
                        )
                    }
                }

                IconButton(onClick = onDeleteClick) {
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = "Eliminar",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                    )
                }
            }

            // Barra de progreso interactiva si este audio está reproduciéndose
            if (isPlayingThis || isPausedThis) {
                val currentMs = when (playbackStatus) {
                    is PlaybackStatus.Playing -> playbackStatus.currentPositionMs
                    is PlaybackStatus.Paused -> playbackStatus.currentPositionMs
                    else -> 0L
                }
                val totalMs = when (playbackStatus) {
                    is PlaybackStatus.Playing -> playbackStatus.totalDurationMs
                    is PlaybackStatus.Paused -> playbackStatus.totalDurationMs
                    else -> item.durationMs.coerceAtLeast(1L)
                }
                val progress = (currentMs.toFloat() / totalMs.toFloat().coerceAtLeast(1f)).coerceIn(0f, 1f)

                Spacer(modifier = Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { progress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp)),
                    color = ColorAudio,
                    trackColor = ColorAudio.copy(alpha = 0.2f)
                )
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    val curSec = currentMs / 1000
                    val totSec = totalMs / 1000
                    Text(
                        text = "${curSec / 60}:${(curSec % 60).toString().padStart(2, '0')}",
                        fontSize = 10.sp,
                        color = ColorAudio
                    )
                    Text(
                        text = "${totSec / 60}:${(totSec % 60).toString().padStart(2, '0')}",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            if (item.notes.isNotBlank()) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = item.notes,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 11.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}
