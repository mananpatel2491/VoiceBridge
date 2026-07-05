# Research: Gujarati Speech-to-Text (Chunk 1)

As-built record — decisions reconstructed 2026-07-05 from v0.0.2, `README.md` Key Decisions,
and `CHANGELOG.md` [0.0.2] Decisions block.

## Decision 1 — GCP Cloud Speech-to-Text `gu-IN` (over OpenAI Whisper)

**Choice**: Google Cloud STT v1 with explicit `languageCode=gu-IN` (`SttService.kt:52`;
`README.md:29-35`).
**Why**: dedicated Gujarati acoustic model; Whisper's Gujarati accuracy is undertested in
production; simple REST needs no vendor SDK on Android; 60 min/month free tier covers all
development.
**Rejected**: OpenAI Whisper (accuracy risk on `gu`), on-device models (not evaluated at this
stage).

## Decision 2 — Raw REST + OkHttp, no Google Cloud SDK

**Choice**: hand-rolled `POST speech:recognize` with OkHttp 4.12.0 and `org.json`
(`SttService.kt:28-34,59-62`).
**Why**: one endpoint, one payload; avoids the heavyweight `google-cloud-speech` Android
dependency chain and its gRPC/auth stack; API-key auth via query param is enough for a
personal app.
**Rejected**: official client library (dependency weight, needs service-account plumbing).

## Decision 3 — Strip the WAV header, send raw LINEAR16

**Choice**: drop the first 44 bytes and base64 (NO_WRAP) only the PCM
(`SttService.kt:44-46`).
**Why**: GCP's `LINEAR16` encoding means headerless PCM; sending the WAV container whole
risks the header being interpreted as audio. `sampleRateHertz` is sourced from
`AudioRecorder.SAMPLE_RATE` (`SttService.kt:51`) so capture and upload can't drift apart.
**Rejected**: `encoding=WAV`-style container upload (not a supported v1 REST encoding for
this flow).

## Decision 4 — Compile-time key injection via buildConfigField

**Choice**: `GCP_STT_API_KEY` read from gitignored `android/local.properties` into
`BuildConfig` (`android/app/build.gradle.kts:9-12,27-31`), consumed once at the composition
root (`MainActivity.kt:32`) and passed down as a parameter.
**Why**: keeps the secret out of source control while remaining zero-infrastructure; blank
fallback `""` turns the missing-key case into a testable UX path instead of a build failure.
**Rejected**: committing a key (obviously), remote config/secret manager (infra cost for a
personal app), runtime key entry UI (friction for grandparents).

## Decision 5 — Result-typed service + ViewModel-owned presentation

**Choice**: `SttService.transcribe(): Result<String>`; the ViewModel folds success/failure
into `UiState` (`SttService.kt:36`; `MainViewModel.kt:90-109`).
**Why**: the service stays presentation-free; every failure becomes a human-readable error
card ("full error surfacing" was an explicit Chunk 1 requirement, `CHANGELOG.md:54-56`).
**Superseded detail**: v0.0.2 displayed the transcript in a read-only card; v0.0.4 replaced
it with an editable `OutlinedTextField` so users can correct STT output (or type directly)
before translating (`CHANGELOG.md:19-21`; `MainActivity.kt:151-163`). The Chunk 1 FRs above
describe the current (editable) behavior.

## Decision 6 — Empty-results = "(No speech detected)", not an error

**Choice**: a valid response with no `results` returns `""`, which the ViewModel renders as
`(No speech detected)` (`SttService.kt:78-81`; `MainViewModel.kt:95`).
**Why**: silence is a user outcome, not a system failure; reserving the error card for real
faults keeps it meaningful.
