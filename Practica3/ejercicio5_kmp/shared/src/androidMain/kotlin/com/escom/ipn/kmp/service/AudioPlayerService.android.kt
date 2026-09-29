package com.escom.ipn.kmp.service

import android.media.MediaPlayer
import java.io.File

actual class AudioPlayerService {

    private var mediaPlayer: MediaPlayer? = null
    private var isCurrentlyPlaying: Boolean = false

    actual fun play(filePath: String, onCompletion: () -> Unit): Boolean {
        stop()
        val file = File(filePath)
        if (!file.exists()) return false

        return try {
            mediaPlayer = MediaPlayer().apply {
                setDataSource(filePath)
                prepare()
                setOnCompletionListener {
                    isCurrentlyPlaying = false
                    onCompletion()
                }
                start()
            }
            isCurrentlyPlaying = true
            true
        } catch (_: Exception) {
            mediaPlayer?.release()
            mediaPlayer = null
            isCurrentlyPlaying = false
            false
        }
    }

    actual fun pause() {
        if (isCurrentlyPlaying && mediaPlayer != null) {
            try {
                mediaPlayer?.pause()
                isCurrentlyPlaying = false
            } catch (_: Exception) {}
        }
    }

    actual fun resume() {
        if (!isCurrentlyPlaying && mediaPlayer != null) {
            try {
                mediaPlayer?.start()
                isCurrentlyPlaying = true
            } catch (_: Exception) {}
        }
    }

    actual fun stop() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                reset()
                release()
            }
        } catch (_: Exception) {}
        mediaPlayer = null
        isCurrentlyPlaying = false
    }

    actual fun isPlaying(): Boolean = isCurrentlyPlaying && (mediaPlayer?.isPlaying == true)

    actual fun currentPositionMs(): Long {
        return try {
            mediaPlayer?.currentPosition?.toLong() ?: 0L
        } catch (_: Exception) {
            0L
        }
    }

    actual fun durationMs(): Long {
        return try {
            mediaPlayer?.duration?.toLong() ?: 0L
        } catch (_: Exception) {
            0L
        }
    }

    actual fun seekTo(positionMs: Long) {
        try {
            mediaPlayer?.seekTo(positionMs.toInt())
        } catch (_: Exception) {}
    }
}
