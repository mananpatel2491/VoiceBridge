# Implementation Plan: Gujarati Speech-to-Text (Chunk 1)

**Branch**: `retro/003-gujarati-stt` | **Date**: 2026-07-05 | **Spec**: [spec.md](./spec.md)

**Input**: As-built reconstruction from v0.0.2 (commit 0add991); editable-field UX refinement
from v0.0.4 (commit b7bef79).

## Summary

`SttService.kt` — a Kotlin `object` REST client on OkHttp — reads the Chunk 0 WAV, strips the
44-byte header, base64-encodes the raw PCM, and POSTs it to GCP Cloud Speech-to-Text v1
(`speech:recognize`, `languageCode=gu-IN`, `encoding=LINEAR16`). `MainViewModel.transcribe()`
guards the blank-key case, drives `isTranscribing` state, and folds the `Result` into either
the editable transcript field or an error card. The API key is injected at build time from
gitignored `local.properties` via `buildConfigField`.

## Technical Context

**Language/Version**: Kotlin 2.0.21 / JVM 17 (same baseline as spec 002)

**Primary Dependencies**: OkHttp 4.12.0 (`android/app/build.gradle.kts:62`), `org.json`
(platform), kotlinx-coroutines (`Dispatchers.IO` + `viewModelScope`); deliberately **no**
Google Cloud SDK (see research.md Decision 2)

**Storage**: none — reads `filesDir/recording.wav` produced by spec 002; nothing persisted

**Testing**: smoke-test step 8 (error-surfacing without a key,
`android/scripts/smoke-test.ps1:278-303`); manual acceptance test with a real key
(`README.md:148-153`)

**Target Platform**: Android API 24–35; requires network (INTERNET permission,
`AndroidManifest.xml:5`)

**Project Type**: mobile app — service layer addition to the existing single module

**Performance Goals**: single-shot transcription; OkHttp 30 s connect / 60 s read timeouts
bound the worst case (`SttService.kt:31-34`)

**Constraints**: GCP STT free tier 60 min/month; API key must never enter source control

**Scale/Scope**: 1 service object (~95 lines), 1 ViewModel action, 1 button + field in the UI

## Constitution Check

Gated against `.specify/memory/constitution.md` (distillation of `GEMINI.md`, supreme).

- **I. Context-First Architecture Map — PASS.** `SttService.kt` is mapped
  (`Project_Structure.md:32`) and the Pipeline Stage Registry carries the STT row
  (`Project_Structure.md:57`); files logged in the v0.0.2 Changelog row.
- **II. Pattern Reference Integrity — PASS.** Follows the registered Audio Format Contract
  (`PATTERNS.md:23`) by construction — `sampleRateHertz` is read from
  `AudioRecorder.SAMPLE_RATE` (`SttService.kt:51`), not duplicated.
- **III. Voice Pipeline Discipline — PARTIAL, documented.** PCM contract: PASS. Swappable
  provider seam: NOT met — `SttService` is a concrete singleton called directly from
  `MainViewModel.kt:90`; the `STTProvider` interface named in the registry
  (`Project_Structure.md:57`) does not exist in code. Streaming-first and VAD gating: NOT
  met — single-shot REST on the full recording. All three are inherent to the chunked
  delivery plan (Chunk 4 is the streaming milestone, `README.md:75`) and are carried as open
  tasks (tasks.md T012–T014) rather than hidden.
- **IV. Gated Validation — PASS.** No repo backend (calls Google's hosted API) → Bruno N/A;
  the smoke test is the gate and asserts this chunk's happy/error paths plus the
  crash gate (`android/scripts/smoke-test.ps1:278-303,346-359`).
- **V. Infrastructure-as-Code & Cost Gating — PASS.** No repo-managed infra (Google-hosted
  API, key created manually in the GCP console per `README.md:135-144`); cost posture $0/mo
  within the 60 min/month free tier; terraform correctly untouched.

## Project Structure

### Documentation (this feature)

```text
specs/003-gujarati-stt/
├── spec.md
├── plan.md              # this file
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
└── contracts/
    └── gcp-stt-contract.md
```

### Source Code (repository root)

```text
android/app/src/main/java/com/mananpatel/voicebridge/
├── SttService.kt              # GCP STT v1 REST client                (v0.0.2)
├── MainViewModel.kt           # transcribe() action + key guard       (v0.0.2; state extended v0.0.4)
└── MainActivity.kt            # Transcribe button + transcript field  (v0.0.2; editable field v0.0.4)
android/app/build.gradle.kts   # okhttp dep + GCP_STT_API_KEY buildConfigField (v0.0.2)
android/local.properties.template  # documents the key                 (v0.0.2)
```

**Structure Decision**: stateless service `object` per pipeline stage beside the ViewModel —
the smallest shape that keeps vendor I/O out of UI code (full interface extraction deferred,
see Constitution Check III).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| No `STTProvider` interface despite the registry naming one | Chunk 1 ships one provider; an interface with a single implementation adds ceremony before the second provider (Whisper et al.) exists | Extracting now was rejected as speculative; the registry row records the intended seam so the refactor is planned, not forgotten |
| VAD absent on a paid API call | VAD needs frame-level access to live audio (Chunk 4 streaming work); Chunk 1 operates on a finished file the user explicitly chose to transcribe | Free tier (60 min/mo) makes silence upload cost-neutral at personal-app scale |
