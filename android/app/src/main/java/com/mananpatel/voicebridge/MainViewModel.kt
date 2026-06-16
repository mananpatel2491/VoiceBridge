package com.mananpatel.voicebridge

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

enum class RecordingState { IDLE, RECORDING, STOPPED }

data class UiState(
    val recordingState: RecordingState = RecordingState.IDLE,
    val hasRecording: Boolean = false,
    val isTranscribing: Boolean = false,
    val transcript: String = "",
    val statusMessage: String = "Tap Record to begin.",
    val errorMessage: String? = null,
)

class MainViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(UiState())
    val uiState = _uiState.asStateFlow()

    private val recorder = AudioRecorder()
    private val player = AudioPlayer()

    fun startRecording(outputFile: File) {
        try {
            recorder.start(outputFile)
            _uiState.update {
                it.copy(
                    recordingState = RecordingState.RECORDING,
                    statusMessage = "Recording… tap Stop when done.",
                    transcript = "",
                    errorMessage = null,
                )
            }
        } catch (e: Exception) {
            _uiState.update { it.copy(errorMessage = e.message ?: "Failed to start recording.") }
        }
    }

    fun stopRecording() {
        recorder.stop()
        _uiState.update {
            it.copy(
                recordingState = RecordingState.STOPPED,
                hasRecording = true,
                statusMessage = "Recording saved. Tap Play or Transcribe.",
            )
        }
    }

    fun playRecording(file: File) {
        player.play(
            file = file,
            onComplete = {
                _uiState.update { it.copy(statusMessage = "Playback complete.") }
            },
            onError = { msg ->
                _uiState.update { it.copy(statusMessage = "Playback error.", errorMessage = msg) }
            },
        )
        _uiState.update { it.copy(statusMessage = "Playing…", errorMessage = null) }
    }

    fun transcribe(file: File, apiKey: String) {
        if (apiKey.isBlank()) {
            _uiState.update {
                it.copy(errorMessage = "GCP_STT_API_KEY is not set. See local.properties.template.")
            }
            return
        }
        _uiState.update {
            it.copy(
                isTranscribing = true,
                transcript = "",
                errorMessage = null,
                statusMessage = "Sending to GCP Speech-to-Text…",
            )
        }
        viewModelScope.launch {
            SttService.transcribe(file, apiKey).fold(
                onSuccess = { text ->
                    _uiState.update {
                        it.copy(
                            isTranscribing = false,
                            transcript = text.ifBlank { "(No speech detected)" },
                            statusMessage = "Transcription complete.",
                        )
                    }
                },
                onFailure = { e ->
                    _uiState.update {
                        it.copy(
                            isTranscribing = false,
                            errorMessage = e.message,
                            statusMessage = "Transcription failed.",
                        )
                    }
                },
            )
        }
    }

    override fun onCleared() {
        super.onCleared()
        recorder.stop()
        player.stop()
    }
}
