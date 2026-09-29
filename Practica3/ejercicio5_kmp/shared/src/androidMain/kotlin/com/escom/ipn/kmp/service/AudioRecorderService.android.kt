package com.escom.ipn.kmp.service

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File

actual class AudioRecorderService(private val context: Context? = null) {

    private var recorder: MediaRecorder? = null
    private var isCurrentlyRecording: Boolean = false
    private var lastRecordedFile: String? = null

    @Suppress("DEPRECATION")
    actual fun startRecording(outputPath: String): Boolean {
        return try {
            val file = File(outputPath)
            file.parentFile?.mkdirs()

            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && context != null) {
                MediaRecorder(context)
            } else {
                MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128000)
                setAudioSamplingRate(44100)
                setOutputFile(outputPath)
                prepare()
                start()
            }
            isCurrentlyRecording = true
            lastRecordedFile = outputPath
            true
        } catch (_: Exception) {
            recorder?.release()
            recorder = null
            isCurrentlyRecording = false
            false
        }
    }

    actual fun stopRecording(): String? {
        if (!isCurrentlyRecording) return null
        return try {
            recorder?.apply {
                stop()
                reset()
                release()
            }
            recorder = null
            isCurrentlyRecording = false
            lastRecordedFile
        } catch (_: Exception) {
            recorder?.release()
            recorder = null
            isCurrentlyRecording = false
            lastRecordedFile
        }
    }

    actual fun isRecording(): Boolean = isCurrentlyRecording

    actual fun getMaxAmplitude(): Int {
        return try {
            if (isCurrentlyRecording) recorder?.maxAmplitude ?: 0 else 0
        } catch (_: Exception) {
            0
        }
    }
}
