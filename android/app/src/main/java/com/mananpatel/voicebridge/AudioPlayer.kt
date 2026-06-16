package com.mananpatel.voicebridge

import android.media.MediaPlayer
import java.io.File

/**
 * Thin wrapper around MediaPlayer for WAV file playback.
 * Call play() to start; call stop() to release resources at any time.
 * onComplete and onError callbacks are delivered on the MediaPlayer internal thread.
 */
class AudioPlayer {

    private var mediaPlayer: MediaPlayer? = null

    fun play(file: File, onComplete: () -> Unit, onError: (String) -> Unit) {
        stop() // Release any prior player before starting a new one
        mediaPlayer = MediaPlayer().apply {
            try {
                setDataSource(file.absolutePath)
                setOnCompletionListener { onComplete() }
                setOnErrorListener { _, what, extra ->
                    onError("MediaPlayer error (what=$what, extra=$extra)")
                    true
                }
                prepare()
                start()
            } catch (e: Exception) {
                onError(e.message ?: "Unknown playback error")
                release()
                mediaPlayer = null
            }
        }
    }

    fun stop() {
        mediaPlayer?.apply {
            try {
                if (isPlaying) stop()
            } catch (_: IllegalStateException) { /* already stopped */ }
            release()
        }
        mediaPlayer = null
    }
}
