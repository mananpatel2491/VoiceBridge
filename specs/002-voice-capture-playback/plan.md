# Implementation Plan: Voice Capture & Playback (Chunk 0)

**Branch**: `retro/002-voice-capture-playback` | **Date**: 2026-07-05 | **Spec**: [spec.md](./spec.md)

**Input**: As-built reconstruction from v0.0.2 (commit 0add991).

## Summary

A single-activity Kotlin + Jetpack Compose app (`MainActivity.kt`) with a `MainViewModel`
StateFlow state machine. `AudioRecorder.kt` wraps `android.media.AudioRecord` to capture PCM
16-bit/16 kHz/mono on a `Dispatchers.IO` coroutine and writes a WAV file (44-byte header
backfilled on stop). `AudioPlayer.kt` wraps `MediaPlayer` for playback. Runtime `RECORD_AUDIO`
permission via `ActivityResultContracts.RequestPermission`. This chunk also established the
Android build baseline (AGP 9.1.1, Gradle 9.3.1, Compose BOM) used by all later chunks.

## Technical Context

**Language/Version**: Kotlin 2.0.21 (`android/build.gradle.kts:3`), JVM target 17
(`android/app/build.gradle.kts` compileOptions)

**Primary Dependencies**: Jetpack Compose (BOM 2024.09.00 + material3,
`android/app/build.gradle.kts:54-57`), activity-compose 1.9.3, lifecycle-viewmodel/
runtime-compose 2.8.7, kotlinx-coroutines-android 1.9.0
(`android/app/build.gradle.kts:58-61`); platform `android.media.AudioRecord`/`MediaPlayer`
(no audio library)

**Storage**: app-private file `filesDir/recording.wav` (`MainActivity.kt:26`) — no DB

**Testing**: `android/scripts/smoke-test.ps1` UIAutomator drive (added v0.0.3; steps 5–7
cover this chunk); no unit tests

**Target Platform**: Android API 24–35 (`android/app/build.gradle.kts:16,20-21`), Gradle 9.3.1
wrapper (`android/gradle/wrapper/gradle-wrapper.properties:3`), AGP 9.1.1
(`android/build.gradle.kts:2`)

**Project Type**: mobile app (single `:app` module, `android/settings.gradle.kts`)

**Performance Goals**: capture loop must not drop frames — buffer sized
`max(getMinBufferSize, 8192)` (`AudioRecorder.kt:45-46`); latency budgets for later streaming
stages tracked per `PATTERNS.md:24`

**Constraints**: offline-capable (Chunk 0 needs no network); $0/mo — on-device only

**Scale/Scope**: 1 screen, 3 controls, 1 recording file; personal app (2 households)

## Constitution Check

Gated against `.specify/memory/constitution.md` (distillation of `GEMINI.md`, supreme).

- **I. Context-First Architecture Map — PASS.** All 19 v0.0.2 files are logged in the
  Changelog table row dated 2026-06-15 (`Project_Structure.md:68`) and mapped in the
  Application Layer table (`Project_Structure.md:27-44`).
- **II. Pattern Reference Integrity — PASS.** The Audio Format Contract this chunk
  establishes is registered (`PATTERNS.md:23`) and reflects the shipped constants
  (`AudioRecorder.kt:29-31`) — actual, not aspirational.
- **III. Voice Pipeline Discipline — PASS with documented deferrals.** PCM 16/16k/mono
  contract: enforced at the capture boundary. Streaming-first and VAD gating: NOT implemented
  in Chunk 0 — batch capture is the explicitly chunked scope (`README.md:69-75`), with
  streaming/VAD deferred to Chunk 4; deferral is visible in the registry ("LLM/TTS → TBD",
  `Project_Structure.md:59-60`). Provider seams for capture/playback are concrete classes,
  not interfaces — carried as open items in tasks.md (see also specs 003/004).
- **IV. Gated Validation — PASS.** No backend API → Bruno N/A; the authoritative gate is the
  smoke test, which asserts this chunk's full UI flow and enabled/disabled matrix
  (`android/scripts/smoke-test.ps1:215-275`).
- **V. Infrastructure-as-Code & Cost Gating — PASS.** No infra: on-device capture/playback,
  no cloud calls in this chunk, $0/mo; terraform untouched by design.

## Project Structure

### Documentation (this feature)

```text
specs/002-voice-capture-playback/
├── spec.md
├── plan.md              # this file
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
└── contracts/
    ├── audio-format-contract.md
    └── app-contract.md
```

### Source Code (repository root)

```text
android/
├── settings.gradle.kts                # project + :app module          (v0.0.2)
├── build.gradle.kts                   # AGP 9.1.1 / Kotlin 2.0.21      (v0.0.2)
├── gradle.properties                  # JVM heap, AndroidX             (v0.0.2)
├── gradle/wrapper/                    # Gradle 9.3.1 pin + jar         (v0.0.2)
├── local.properties.template          # sdk.dir + key placeholders     (v0.0.2)
└── app/
    ├── build.gradle.kts               # compose, minSdk 24, deps       (v0.0.2)
    ├── proguard-rules.pro             # release rules (debug skips)    (v0.0.2)
    └── src/main/
        ├── AndroidManifest.xml        # RECORD_AUDIO, INTERNET, launcher (v0.0.2)
        ├── res/values/{strings,themes}.xml                             # (v0.0.2)
        └── java/com/mananpatel/voicebridge/
            ├── MainActivity.kt        # Compose UI + permission flow   (v0.0.2; extended v0.0.4)
            ├── MainViewModel.kt       # UiState state machine          (v0.0.2; extended v0.0.4)
            ├── AudioRecorder.kt       # AudioRecord → WAV              (v0.0.2)
            └── AudioPlayer.kt         # MediaPlayer wrapper            (v0.0.2)
```

**Structure Decision**: single-module Android app under `android/` beside the repo-root
governance layer; no `src/`+`tests/` split — the smoke test (repo-level PowerShell) is the
test harness of record.

## Complexity Tracking

No violations. Notable simplicity choice: WAV header written by seek-back over 44 reserved
bytes rather than buffering PCM in memory (`AudioRecorder.kt:64-77`) — keeps memory flat for
arbitrarily long recordings.
