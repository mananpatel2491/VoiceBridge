# Provider Contract: GCP Speech-to-Text seam (Chunk 1)

The de-facto STT provider seam. Today it is a concrete object (`SttService`), not an
interface — the `STTProvider` abstraction named in `Project_Structure.md:57` is a planned
extraction (spec 003 tasks.md T012). This document is the behavioral contract any future
implementation must honor.

## Interface surface

```kotlin
// SttService.kt:36
suspend fun transcribe(audioFile: File, apiKey: String): Result<String>
```

| Guarantee | Detail |
|---|---|
| Threading | runs on `Dispatchers.IO`; safe to call from `viewModelScope` (`SttService.kt:36-37`) |
| Success value | Gujarati transcript; `""` when the service validly detected no speech (`SttService.kt:78-81`) |
| Failure value | `Result.failure` with human-readable message — never throws to the caller (`runCatching`, `SttService.kt:38`) |
| Input precondition | `audioFile` is a spec-002 WAV (PCM 16-bit/16 kHz/mono, 44-byte header) |

## Wire contract (current implementation)

| Aspect | Value | Source |
|---|---|---|
| Endpoint | `POST https://speech.googleapis.com/v1/speech:recognize?key=<apiKey>` | `SttService.kt:28,60` |
| Auth | API key as query param (no OAuth) | `SttService.kt:60` |
| Content-Type | `application/json` | `SttService.kt:61` |
| config | `encoding=LINEAR16`, `sampleRateHertz=16000` (from `AudioRecorder.SAMPLE_RATE`), `languageCode=gu-IN` | `SttService.kt:48-53` |
| audio | `content` = base64(NO_WRAP) of file bytes after offset 44 | `SttService.kt:44-46` |
| Timeouts | 30 s connect / 60 s read | `SttService.kt:31-34` |

## Error mapping

| Condition | Result message |
|---|---|
| file length ≤ 44 bytes | `Recording is empty or too short to transcribe.` (`SttService.kt:40-42`) |
| null response body | `Empty response body from GCP STT.` (`SttService.kt:65-66`) |
| HTTP non-2xx | `GCP STT error <code>: <error.message from body, else raw body>` (`SttService.kt:68-76`) |
| network/TLS exceptions | OkHttp exception message via `runCatching` |
| blank apiKey | **caller-side** guard — `GCP_STT_API_KEY is not set. See local.properties.template.` (`MainViewModel.kt:74-79`) — no network call is made |

## Env / config knobs

| Knob | Source | Effect |
|---|---|---|
| `GCP_STT_API_KEY` | `android/local.properties` → `BuildConfig` (`android/app/build.gradle.kts:27-31`) | blank = offline error-path mode (CI default); set = live calls |

## Known limitations (accepted for Chunk 1)

- Single-shot only; no streaming variant (Chunk 4 scope).
- No retry/backoff — one attempt per tap.
- Fixed `gu-IN`; no language parameter in the seam signature.
