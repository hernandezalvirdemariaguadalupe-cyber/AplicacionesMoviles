package com.escom.ipn.kmp.service

/**
 * Servicio multiplataforma para reproducción de audio grabado.
 * En Android se implementa mediante MediaPlayer.
 * En iOS se implementa mediante AVAudioPlayer.
 */
expect class AudioPlayerService {
    fun play(filePath: String, onCompletion: () -> Unit): Boolean
    fun pause()
    fun resume()
    fun stop()
    fun isPlaying(): Boolean
    fun currentPositionMs(): Long
    fun durationMs(): Long
    fun seekTo(positionMs: Long)
}
