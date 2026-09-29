package com.escom.ipn.kmp.viewmodel

import com.escom.ipn.kmp.model.MediaCategory
import com.escom.ipn.kmp.model.MediaItem
import com.escom.ipn.kmp.model.MediaType
import com.escom.ipn.kmp.model.ThemeColor
import com.escom.ipn.kmp.model.ThemeConfig
import com.escom.ipn.kmp.model.ThemeMode
import com.escom.ipn.kmp.repository.MediaRepository
import com.escom.ipn.kmp.service.AudioPlayerService
import com.escom.ipn.kmp.service.AudioRecorderService
import com.escom.ipn.kmp.service.PlatformStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

sealed class RecordingStatus {
    object Idle : RecordingStatus()
    data class Recording(val durationSeconds: Int, val amplitude: Int, val tempPath: String) : RecordingStatus()
    data class Finished(val recordedPath: String, val durationMs: Long, val sizeBytes: Long) : RecordingStatus()
}

sealed class PlaybackStatus {
    object Idle : PlaybackStatus()
    data class Playing(val item: MediaItem, val currentPositionMs: Long, val totalDurationMs: Long) : PlaybackStatus()
    data class Paused(val item: MediaItem, val currentPositionMs: Long, val totalDurationMs: Long) : PlaybackStatus()
}

class MediaViewModel(
    val repository: MediaRepository,
    val recorderService: AudioRecorderService,
    val playerService: AudioPlayerService,
    val storage: PlatformStorage,
    private val scope: CoroutineScope
) {
    val items: StateFlow<List<MediaItem>> = repository.items
    val themeConfig: StateFlow<ThemeConfig> = repository.themeConfig

    private val _selectedFilter = MutableStateFlow<MediaType?>(null)
    val selectedFilter: StateFlow<MediaType?> = _selectedFilter.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    val filteredItems: StateFlow<List<MediaItem>> = combine(
        items,
        _selectedFilter,
        _searchQuery
    ) { allItems, filter, query ->
        allItems.filter { item ->
            val matchesFilter = filter == null || item.type == filter
            val matchesQuery = query.isBlank() ||
                    item.title.contains(query, ignoreCase = true) ||
                    item.notes.contains(query, ignoreCase = true)
            matchesFilter && matchesQuery
        }
    }.stateIn(scope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _recordingStatus = MutableStateFlow<RecordingStatus>(RecordingStatus.Idle)
    val recordingStatus: StateFlow<RecordingStatus> = _recordingStatus.asStateFlow()

    private val _playbackStatus = MutableStateFlow<PlaybackStatus>(PlaybackStatus.Idle)
    val playbackStatus: StateFlow<PlaybackStatus> = _playbackStatus.asStateFlow()

    private var recordingTimerJob: Job? = null
    private var playbackTimerJob: Job? = null
    private var currentRecordingStart = 0L
    private var currentRecordingPath: String = ""

    fun setFilter(type: MediaType?) {
        _selectedFilter.value = type
    }

    fun setSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun startRecording(targetFileName: String? = null): Boolean {
        if (recorderService.isRecording()) return false
        stopAudioPlayback()

        val timestamp = 1774846800000L + (items.value.size * 1000)
        val fileName = targetFileName ?: "audio_rec_${timestamp}.m4a"
        val outPath = "${storage.getAppDataDirectory()}/$fileName"
        currentRecordingPath = outPath

        val started = recorderService.startRecording(outPath)
        if (started) {
            currentRecordingStart = timestamp
            _recordingStatus.value = RecordingStatus.Recording(0, 0, outPath)
            recordingTimerJob?.cancel()
            recordingTimerJob = scope.launch(Dispatchers.Default) {
                var sec = 0
                while (isActive && recorderService.isRecording()) {
                    delay(1000)
                    sec++
                    val amp = recorderService.getMaxAmplitude()
                    _recordingStatus.value = RecordingStatus.Recording(sec, amp, outPath)
                }
            }
        }
        return started
    }

    fun stopRecording(saveAsTitle: String, category: MediaCategory = MediaCategory.EVIDENCIA, notes: String = "") {
        recordingTimerJob?.cancel()
        val path = recorderService.stopRecording() ?: currentRecordingPath
        val size = storage.getFileSize(path)
        val durationMs = playerService.durationMs().coerceAtLeast(3000L)

        val newItem = MediaItem(
            id = "media_audio_${path.hashCode()}",
            title = if (saveAsTitle.isNotBlank()) saveAsTitle else "Grabación ${items.value.size + 1}",
            type = MediaType.AUDIO,
            filePath = path,
            timestamp = 1774846800000L + items.value.size,
            durationMs = durationMs,
            sizeBytes = size,
            category = category,
            notes = notes
        )
        repository.addItem(newItem)
        _recordingStatus.value = RecordingStatus.Finished(path, durationMs, size)
    }

    fun cancelRecording() {
        recordingTimerJob?.cancel()
        recorderService.stopRecording()
        if (storage.fileExists(currentRecordingPath)) {
            storage.deleteFile(currentRecordingPath)
        }
        _recordingStatus.value = RecordingStatus.Idle
    }

    fun resetRecordingState() {
        _recordingStatus.value = RecordingStatus.Idle
    }

    fun registerCapturedPhoto(title: String, imagePath: String, category: MediaCategory = MediaCategory.EVIDENCIA, notes: String = "") {
        val size = storage.getFileSize(imagePath)
        val newItem = MediaItem(
            id = "media_photo_${imagePath.hashCode()}",
            title = if (title.isNotBlank()) title else "Foto Capturada ${items.value.size + 1}",
            type = MediaType.PHOTO,
            filePath = imagePath,
            timestamp = 1774846800000L + items.value.size,
            sizeBytes = size,
            category = category,
            notes = notes
        )
        repository.addItem(newItem)
    }

    fun playAudio(item: MediaItem) {
        if (item.type != MediaType.AUDIO) return
        stopAudioPlayback()

        val success = playerService.play(item.filePath) {
            _playbackStatus.value = PlaybackStatus.Idle
            playbackTimerJob?.cancel()
        }

        if (success) {
            _playbackStatus.value = PlaybackStatus.Playing(item, 0L, item.durationMs)
            playbackTimerJob?.cancel()
            playbackTimerJob = scope.launch(Dispatchers.Default) {
                while (isActive && playerService.isPlaying()) {
                    delay(250)
                    val current = playerService.currentPositionMs()
                    val total = playerService.durationMs().coerceAtLeast(item.durationMs)
                    _playbackStatus.value = PlaybackStatus.Playing(item, current, total)
                }
            }
        }
    }

    fun pauseAudio() {
        val current = _playbackStatus.value
        if (current is PlaybackStatus.Playing) {
            playerService.pause()
            playbackTimerJob?.cancel()
            _playbackStatus.value = PlaybackStatus.Paused(current.item, current.currentPositionMs, current.totalDurationMs)
        }
    }

    fun resumeAudio() {
        val current = _playbackStatus.value
        if (current is PlaybackStatus.Paused) {
            playerService.resume()
            _playbackStatus.value = PlaybackStatus.Playing(current.item, current.currentPositionMs, current.totalDurationMs)
            playbackTimerJob?.cancel()
            playbackTimerJob = scope.launch(Dispatchers.Default) {
                while (isActive && playerService.isPlaying()) {
                    delay(250)
                    val pos = playerService.currentPositionMs()
                    _playbackStatus.value = PlaybackStatus.Playing(current.item, pos, current.totalDurationMs)
                }
            }
        }
    }

    fun stopAudioPlayback() {
        playbackTimerJob?.cancel()
        playerService.stop()
        _playbackStatus.value = PlaybackStatus.Idle
    }

    fun deleteItem(item: MediaItem) {
        if (_playbackStatus.value is PlaybackStatus.Playing && (_playbackStatus.value as PlaybackStatus.Playing).item.id == item.id) {
            stopAudioPlayback()
        }
        repository.deleteItem(item)
    }

    fun setTheme(color: ThemeColor, mode: ThemeMode) {
        repository.updateTheme(color, mode)
    }
}
