# Data Model: Gujarati→English Translation (Chunk 2)

Nothing persisted. Transport and state shapes only.

## Translation request (built at `TranslationService.kt:32-37`)

```json
{
  "q": "<trimmed transcript text>",
  "source": "gu",
  "target": "en",
  "format": "text"
}
```

POSTed as `application/json; charset=utf-8` to
`https://translation.googleapis.com/language/translate/v2?key=<GCP_STT_API_KEY>`
(`TranslationService.kt:14,39-42`).

## Translation response (consumed at `TranslationService.kt:57-61`)

```json
{
  "data": {
    "translations": [
      { "translatedText": "…" }
    ]
  }
}
```

Only `data.translations[0].translatedText` is read. Error bodies
(`{"error": {"message": "…"}}`) are mined for the card text
(`TranslationService.kt:48-55`).

## UiState fields owned by this capability (`MainViewModel.kt:18-19`)

| Field | Type | Semantics |
|---|---|---|
| `isTranslating` | Boolean | in-flight flag; disables Translate/Transcribe/field |
| `translatedText` | String | English result; `""` hides the result card (`MainActivity.kt:187`); cleared on transcript edit, new recording, and new transcription |

## Config / build keys

| Key | Value | Note |
|---|---|---|
| `GCP_STT_API_KEY` | same BuildConfig field as spec 003 (`android/app/build.gradle.kts:27-31`) | intentionally NOT renamed when Translation reused it — one key, two Google APIs; blank-key error text explains the reuse (`TranslationService.kt:24-30`) |

## HTTP client tuning (`TranslationService.kt:16-19`)

| Setting | Value |
|---|---|
| connectTimeout | 30 s |
| readTimeout | 30 s (text-only payload; shorter than STT's 60 s) |
