package com.escom.ipn.kmp.service

/**
 * Servicio multiplataforma para grabación de audio.
 * En Android se implementa mediante MediaRecorder.
 * En iOS se implementa mediante AVAudioRecorder (AVFAudio).
 */
expect class AudioRecorderService {
    fun startRecording(outputPath: String): Boolean
    fun stopRecording(): String?
    fun isRecording(): Boolean
    fun getMaxAmplitude(): Int
}
