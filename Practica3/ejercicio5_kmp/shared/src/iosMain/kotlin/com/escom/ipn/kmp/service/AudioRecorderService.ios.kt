package com.escom.ipn.kmp.service

actual class AudioRecorderService {
    private var isRecordingAudio: Boolean = false
    private var activePath: String? = null

    actual fun startRecording(outputPath: String): Boolean {
        // En iOS nativo: se instancia AVAudioRecorder configurado en formato m4a/aac
        isRecordingAudio = true
        activePath = outputPath
        return true
    }

    actual fun stopRecording(): String? {
        isRecordingAudio = false
        val path = activePath
        activePath = null
        return path
    }

    actual fun isRecording(): Boolean = isRecordingAudio

    actual fun getMaxAmplitude(): Int = 0
}
