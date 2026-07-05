# Data Model: Gujarati Speech-to-Text (Chunk 1)

Nothing persisted by this capability (input file owned by spec 002). Shapes below are
transport and config.

## STT request (built at `SttService.kt:48-57`)

```json
{
  "config": {
    "encoding": "LINEAR16",
    "sampleRateHertz": 16000,
    "languageCode": "gu-IN"
  },
  "audio": {
    "content": "<base64 NO_WRAP of WAV bytes [44..end]>"
  }
}
```

POSTed as `application/json` to
`https://speech.googleapis.com/v1/speech:recognize?key=<GCP_STT_API_KEY>`
(`SttService.kt:28,59-62`).

## STT response (consumed at `SttService.kt:78-91`)

```json
{
  "results": [
    { "alternatives": [ { "transcript": "…", "confidence": 0.9 } ] }
  ]
}
```

- Missing/empty `results` → `""` (rendered as `(No speech detected)`,
  `MainViewModel.kt:95`).
- Multiple results → `alternatives[0].transcript` of each, joined by a single space.
- Error body → `{"error": {"message": "…"}}` mined for the card text
  (`SttService.kt:70-75`).

## UiState fields owned by this capability (`MainViewModel.kt:16-17`)

| Field | Type | Semantics |
|---|---|---|
| `isTranscribing` | Boolean | in-flight flag; disables Transcribe/Translate/field |
| `transcript` | String | editable Gujarati text; cleared on new recording/transcription start |

## Config / build keys

| Key | Where | Default | Behavior when blank |
|---|---|---|---|
| `GCP_STT_API_KEY` | `android/local.properties` → `buildConfigField` (`android/app/build.gradle.kts:27-31`) → `BuildConfig.GCP_STT_API_KEY` → `MainActivity.kt:32` | `""` | pre-flight error card, no network call (`MainViewModel.kt:74-79`) |

Documented for humans in `android/local.properties.template:10-13` and `README.md:131-146`.

## HTTP client tuning (`SttService.kt:31-34`)

| Setting | Value |
|---|---|
| connectTimeout | 30 s |
| readTimeout | 60 s (audio upload + recognition latency) |
