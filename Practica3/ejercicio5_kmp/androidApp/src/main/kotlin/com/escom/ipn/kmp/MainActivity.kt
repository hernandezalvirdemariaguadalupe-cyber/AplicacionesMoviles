package com.escom.ipn.kmp

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.escom.ipn.kmp.repository.MediaRepository
import com.escom.ipn.kmp.service.AudioPlayerService
import com.escom.ipn.kmp.service.AudioRecorderService
import com.escom.ipn.kmp.service.PlatformStorage
import com.escom.ipn.kmp.ui.screens.MainAppScreen
import com.escom.ipn.kmp.ui.theme.KmpMediaTheme
import com.escom.ipn.kmp.viewmodel.MediaViewModel

class MainActivity : ComponentActivity() {

    private lateinit var viewModel: MediaViewModel

    private var hasCameraPermission by mutableStateOf(false)
    private var hasMicPermission by mutableStateOf(false)

    private val cameraPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        hasCameraPermission = isGranted
    }

    private val micPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        hasMicPermission = isGranted
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Comprobar permisos iniciales
        hasCameraPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        hasMicPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        // Inicializar arquitectura Clean Architecture KMP
        val storage = PlatformStorage(applicationContext)
        val recorder = AudioRecorderService(applicationContext)
        val player = AudioPlayerService()
        val repository = MediaRepository(storage)

        viewModel = MediaViewModel(
            repository = repository,
            recorderService = recorder,
            playerService = player,
            storage = storage,
            scope = lifecycleScope
        )

        setContent {
            val themeConfig by viewModel.themeConfig.collectAsState()

            KmpMediaTheme(themeConfig = themeConfig) {
                MainAppScreen(
                    viewModel = viewModel,
                    hasCameraPermission = hasCameraPermission,
                    hasMicPermission = hasMicPermission,
                    onRequestCameraPermission = {
                        cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                    },
                    onRequestMicPermission = {
                        micPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                    }
                )
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::viewModel.isInitialized) {
            viewModel.stopAudioPlayback()
            viewModel.cancelRecording()
        }
    }
}
