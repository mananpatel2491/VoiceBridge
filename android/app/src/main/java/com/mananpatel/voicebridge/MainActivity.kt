package com.mananpatel.voicebridge

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import java.io.File

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val recordingFile = File(filesDir, "recording.wav")
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    VoiceBridgeScreen(
                        recordingFile = recordingFile,
                        apiKey = BuildConfig.GCP_STT_API_KEY,
                    )
                }
            }
        }
    }
}

@Composable
fun VoiceBridgeScreen(
    recordingFile: File,
    apiKey: String,
    vm: MainViewModel = viewModel(),
) {
    val state by vm.uiState.collectAsStateWithLifecycle()

    var permissionGranted by remember { mutableStateOf(false) }
    var permissionDenied by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        permissionGranted = granted
        permissionDenied = !granted
    }

    // Request mic permission on first composition
    LaunchedEffect(Unit) {
        permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("VoiceBridge", style = MaterialTheme.typography.headlineMedium)

        // Permission denied banner
        if (permissionDenied) {
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer,
                ),
            ) {
                Text(
                    text = "Microphone permission denied.\n" +
                            "Go to Settings → Apps → VoiceBridge → Permissions to enable it.",
                    modifier = Modifier.padding(16.dp),
                    color = MaterialTheme.colorScheme.onErrorContainer,
                )
            }
        }

        // Status line
        Text(
            text = state.statusMessage,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.secondary,
        )

        // Error card
        state.errorMessage?.let { error ->
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer,
                ),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = "Error: $error",
                    modifier = Modifier.padding(12.dp),
                    color = MaterialTheme.colorScheme.onErrorContainer,
                )
            }
        }

        Spacer(Modifier.height(4.dp))

        // ── Chunk 0: Record / Stop / Play ────────────────────────────────
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(
                onClick = { vm.startRecording(recordingFile) },
                enabled = permissionGranted && state.recordingState != RecordingState.RECORDING,
            ) { Text("Record") }

            Button(
                onClick = { vm.stopRecording() },
                enabled = state.recordingState == RecordingState.RECORDING,
            ) { Text("Stop") }
        }

        Button(
            onClick = { vm.playRecording(recordingFile) },
            enabled = state.hasRecording && state.recordingState != RecordingState.RECORDING,
        ) { Text("Play") }

        HorizontalDivider()

        // ── Chunk 1: Transcribe ──────────────────────────────────────────
        Button(
            onClick = { vm.transcribe(recordingFile, apiKey) },
            enabled = state.hasRecording
                    && !state.isTranscribing
                    && state.recordingState != RecordingState.RECORDING,
        ) {
            if (state.isTranscribing) {
                CircularProgressIndicator(
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.dp,
                    color = MaterialTheme.colorScheme.onPrimary,
                )
                Spacer(Modifier.width(8.dp))
                Text("Transcribing…")
            } else {
                Text("Transcribe (Gujarati)")
            }
        }

        // Transcript display
        if (state.transcript.isNotEmpty()) {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Transcript", style = MaterialTheme.typography.labelMedium)
                    Spacer(Modifier.height(6.dp))
                    Text(
                        text = state.transcript,
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
            }
        }
    }
}
