# Provider Contract: GCP Cloud Translation seam (Chunk 2)

The de-facto Translation provider seam. Concrete object today; the `TranslationProvider`
abstraction named in `Project_Structure.md:58` is a planned extraction (tasks.md T012).
Behavioral contract for any future implementation:

## Interface surface

```kotlin
// TranslationService.kt:21
suspend fun translate(text: String, apiKey: String): Result<String>
```

| Guarantee | Detail |
|---|---|
| Threading | `Dispatchers.IO` (`TranslationService.kt:22`) |
| Success value | English translation of `text` |
| Failure value | `Result.failure` with human-readable message — never throws (`runCatching`, `TranslationService.kt:23`) |
| Input precondition | caller sends trimmed, non-empty text (`MainViewModel.kt:120-121`) |
| Key precondition | blank `apiKey` fails fast INSIDE the seam with reuse/enable-API coaching (`TranslationService.kt:24-30`) — note the asymmetry with the STT seam, where the blank-key guard lives in the ViewModel |

## Wire contract (current implementation)

| Aspect | Value | Source |
|---|---|---|
| Endpoint | `POST https://translation.googleapis.com/language/translate/v2?key=<apiKey>` | `TranslationService.kt:14,40` |
| Auth | API key query param (v2; the reason v3 was not used) | `TranslationService.kt:40` |
| Content-Type | `application/json; charset=utf-8` | `TranslationService.kt:41` |
| Body | `{"q": text, "source": "gu", "target": "en", "format": "text"}` | `TranslationService.kt:32-37` |
| Response path | `data.translations[0].translatedText` | `TranslationService.kt:57-61` |
| Timeouts | 30 s connect / 30 s read | `TranslationService.kt:16-19` |

## Error mapping

| Condition | Result message |
|---|---|
| blank apiKey | `GCP_STT_API_KEY is not set in local.properties. The same key covers Cloud Translation -- enable 'Cloud Translation API' in the same GCP project you used for STT.` (`TranslationService.kt:24-30`) |
| null response body | `Empty response body from Cloud Translation API.` (`TranslationService.kt:45-46`) |
| HTTP non-2xx | `Translation API error <code>: <error.message, else raw body>` (`TranslationService.kt:48-55`) |
| network/TLS exceptions | OkHttp exception message via `runCatching` |

## Env / config knobs

| Knob | Source | Effect |
|---|---|---|
| `GCP_STT_API_KEY` | shared BuildConfig field (see spec 003 contract) | blank = coached error path; set + API enabled = live translation |

## Known limitations (accepted for Chunk 2)

- Fixed `gu`→`en`; direction/languages are not parameters of the seam.
- No batching (single `q` per call), no retry/backoff.
- No HTML mode — `format=text` always.
