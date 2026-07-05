# Data Model: Voice Capture & Playback (Chunk 0)

No database. Persistent data is a single WAV file; runtime data is one state object.

## recording.wav (app-private file)

Path: `filesDir/recording.wav` — created in `MainActivity.onCreate`
(`MainActivity.kt:26`), overwritten on every new recording.

Layout (written by `AudioRecorder.buildWavHeader`, `AudioRecorder.kt:97-120`):

| Offset | Bytes | Field | Value |
|---|---|---|---|
| 0 | 4 | ChunkID | `RIFF` |
| 4 | 4 | ChunkSize | pcmDataSize + 36 (LE) |
| 8 | 4 | Format | `WAVE` |
| 12 | 4 | Subchunk1ID | `fmt ` |
| 16 | 4 | Subchunk1Size | 16 (PCM) |
| 20 | 2 | AudioFormat | 1 (PCM) |
| 22 | 2 | NumChannels | 1 (mono) |
| 24 | 4 | SampleRate | 16000 (`AudioRecorder.kt:29`) |
| 28 | 4 | ByteRate | 32000 (16000 × 1 × 2, `AudioRecorder.kt:98`) |
| 32 | 2 | BlockAlign | 2 |
| 34 | 2 | BitsPerSample | 16 |
| 36 | 4 | Subchunk2ID | `data` |
| 40 | 4 | Subchunk2Size | pcmDataSize |
| 44 | n | PCM samples | 16-bit LE mono @ 16 kHz |

Downstream consumers: `AudioPlayer` (plays the whole file), `SttService` (strips the first 44
bytes and sends raw PCM, `SttService.kt:29,44-46`).

## UiState (runtime, `MainViewModel.kt:13-22`)

| Field | Type | Default | Chunk |
|---|---|---|---|
| `recordingState` | `RecordingState` (IDLE/RECORDING/STOPPED, `MainViewModel.kt:11`) | IDLE | 0 |
| `hasRecording` | Boolean | false | 0 |
| `isTranscribing` | Boolean | false | 1 (spec 003) |
| `transcript` | String | "" | 1 (spec 003) |
| `isTranslating` | Boolean | false | 2 (spec 004) |
| `translatedText` | String | "" | 2 (spec 004) |
| `statusMessage` | String | "Tap Record to begin." | 0 |
| `errorMessage` | String? | null | 0 |

## Capture configuration (compile-time constants, `AudioRecorder.kt:28-34`)

| Constant | Value |
|---|---|
| `SAMPLE_RATE` | 16_000 Hz |
| `CHANNEL_CONFIG` | `AudioFormat.CHANNEL_IN_MONO` |
| `AUDIO_FORMAT` | `AudioFormat.ENCODING_PCM_16BIT` |
| `BYTES_PER_SAMPLE` | 2 |
| `WAV_HEADER_SIZE` | 44 |
| capture buffer | `max(AudioRecord.getMinBufferSize(...), 8192)` bytes (`AudioRecorder.kt:45-46`) |

## Config / env keys

None for this chunk — Chunk 0 runs fully offline with no configuration. (`sdk.dir` in
`android/local.properties` is a build-machine concern, `android/local.properties.template`.)
