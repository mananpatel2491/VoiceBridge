package com.mananpatel.voicebridge

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Captures audio from the device microphone as raw PCM and writes a WAV file.
 *
 * Format: 16 kHz, 16-bit, mono — accepted natively by GCP STT as LINEAR16
 * (no format conversion needed in SttService).
 *
 * Call start() to begin recording, stop() to end it. stop() triggers the WAV
 * header to be written back over the placeholder bytes at the start of the file,
 * so the resulting file is a valid WAV that MediaPlayer can play back.
 */
class AudioRecorder {

    companion object {
        const val SAMPLE_RATE = 16_000          // Hz
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val BYTES_PER_SAMPLE = 2  // 16-bit = 2 bytes
        private const val WAV_HEADER_SIZE = 44
    }

    private var audioRecord: AudioRecord? = null
    private var recordingJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO)

    @Volatile private var isRecording = false

    fun start(outputFile: File) {
        stop() // Ensure any prior recording is cleanly stopped first

        val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        val bufSize = maxOf(minBuf, 8192)

        val ar = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            CHANNEL_CONFIG,
            AUDIO_FORMAT,
            bufSize
        )
        check(ar.state == AudioRecord.STATE_INITIALIZED) {
            "AudioRecord failed to initialize — verify RECORD_AUDIO permission is granted."
        }

        audioRecord = ar
        isRecording = true
        ar.startRecording()

        recordingJob = scope.launch {
            FileOutputStream(outputFile).use { fos ->
                // Reserve header space — filled in after recording so we know the data size
                fos.write(ByteArray(WAV_HEADER_SIZE))

                val buffer = ByteArray(bufSize)
                while (isRecording && ar.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    val read = ar.read(buffer, 0, buffer.size)
                    if (read < 0) break   // AudioRecord error code — stop loop cleanly
                    if (read > 0) fos.write(buffer, 0, read)
                }
            }
            // File is closed; now overwrite the placeholder header with correct sizes
            writeWavHeader(outputFile)
        }
    }

    fun stop() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        // Do NOT cancel recordingJob here — let it finish writing the WAV header
    }

    private fun writeWavHeader(file: File) {
        val totalFileSize = file.length()
        val pcmDataSize = (totalFileSize - WAV_HEADER_SIZE).coerceAtLeast(0).toInt()
        RandomAccessFile(file, "rw").use { raf ->
            raf.seek(0)
            raf.write(buildWavHeader(pcmDataSize))
        }
    }

    private fun buildWavHeader(pcmDataSize: Int): ByteArray {
        val byteRate = SAMPLE_RATE * 1 * BYTES_PER_SAMPLE   // sampleRate × channels × bytesPerSample
        return ByteBuffer.allocate(WAV_HEADER_SIZE)
            .order(ByteOrder.LITTLE_ENDIAN)
            .apply {
                // RIFF chunk descriptor
                put("RIFF".toByteArray())
                putInt(pcmDataSize + 36)   // total file size minus 8 bytes for RIFF header
                put("WAVE".toByteArray())
                // fmt sub-chunk
                put("fmt ".toByteArray())
                putInt(16)                              // PCM fmt chunk is 16 bytes
                putShort(1)                             // PCM format
                putShort(1)                             // 1 channel (mono)
                putInt(SAMPLE_RATE)
                putInt(byteRate)
                putShort((1 * BYTES_PER_SAMPLE).toShort())      // block align
                putShort((BYTES_PER_SAMPLE * 8).toShort())      // bits per sample (16)
                // data sub-chunk
                put("data".toByteArray())
                putInt(pcmDataSize)
            }
            .array()
    }
}
