package com.escom.ipn.kmp.service

actual class AudioPlayerService {
    private var playing: Boolean = false

    actual fun play(filePath: String, onCompletion: () -> Unit): Boolean {
        // En iOS nativo: se instancia AVAudioPlayer(contentsOf: url)
        playing = true
        return true
    }

    actual fun pause() {
        playing = false
    }

    actual fun resume() {
        playing = true
    }

    actual fun stop() {
        playing = false
    }

    actual fun isPlaying(): Boolean = playing

    actual fun currentPositionMs(): Long = 0L

    actual fun durationMs(): Long = 0L

    actual fun seekTo(positionMs: Long) {}
}
