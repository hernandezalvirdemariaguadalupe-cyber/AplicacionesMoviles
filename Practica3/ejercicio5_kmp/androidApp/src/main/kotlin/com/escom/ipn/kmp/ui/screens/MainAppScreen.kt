package com.escom.ipn.kmp.ui.screens

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Collections
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.escom.ipn.kmp.model.ThemeColor
import com.escom.ipn.kmp.viewmodel.MediaViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainAppScreen(
    viewModel: MediaViewModel,
    hasCameraPermission: Boolean,
    hasMicPermission: Boolean,
    onRequestCameraPermission: () -> Unit,
    onRequestMicPermission: () -> Unit
) {
    var selectedTab by remember { mutableIntStateOf(2) } // Por defecto Galería
    val themeConfig by viewModel.themeConfig.collectAsState()

    val topBarTitle = when (selectedTab) {
        0 -> "Cámara KMP"
        1 -> "Micrófono & Audio"
        2 -> "Galería de Medios"
        3 -> "Ajustes del Sistema"
        else -> "KMP Multimedia"
    }

    val subtitle = if (themeConfig.color == ThemeColor.GUINDA) "ESCOM - IPN Guinda" else "ESCOM - IPN Azul"

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    androidx.compose.foundation.layout.Column {
                        Text(
                            text = topBarTitle,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            text = subtitle,
                            style = MaterialTheme.typography.bodySmall,
                            fontSize = 11.sp,
                            color = Color.White.copy(alpha = 0.8f)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary
                )
            )
        },
        bottomBar = {
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface
            ) {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Default.CameraAlt, contentDescription = "Cámara") },
                    label = { Text("Cámara") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Default.Mic, contentDescription = "Micrófono") },
                    label = { Text("Audio") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Default.Collections, contentDescription = "Galería") },
                    label = { Text("Galería") }
                )
                NavigationBarItem(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    icon = { Icon(Icons.Default.Settings, contentDescription = "Ajustes") },
                    label = { Text("Ajustes") }
                )
            }
        }
    ) { innerPadding ->
        Box(modifier = Modifier.padding(innerPadding)) {
            when (selectedTab) {
                0 -> CameraCaptureScreen(
                    viewModel = viewModel,
                    hasCameraPermission = hasCameraPermission,
                    onRequestCameraPermission = onRequestCameraPermission
                )
                1 -> AudioRecordScreen(
                    viewModel = viewModel,
                    hasMicPermission = hasMicPermission,
                    onRequestMicPermission = onRequestMicPermission
                )
                2 -> GalleryScreen(viewModel = viewModel)
                3 -> SettingsScreen(viewModel = viewModel)
            }
        }
    }
}
