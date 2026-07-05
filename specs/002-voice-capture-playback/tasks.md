---
description: "As-built task record for Chunk 0 — app shell, capture, playback, audio contract"
---

# Tasks: Voice Capture & Playback (Chunk 0)

As-built record — reconstructed 2026-07-05 from v0.0.2 (commit 0add991). `[X]` = shipped with
release; `[ ]` = genuinely open.

## Phase 1: Android project baseline

- [X] T001 Scaffold Gradle project: `android/settings.gradle.kts`, root
  `android/build.gradle.kts` (AGP 9.1.1, Kotlin 2.0.21), `gradle.properties`, wrapper pinned
  to Gradle 9.3.1 (v0.0.2)
- [X] T002 App module `android/app/build.gradle.kts`: compileSdk 35, minSdk 24, Compose BOM
  2024.09.00, coroutines 1.9.0 (v0.0.2)
- [X] T003 [P] `AndroidManifest.xml`: RECORD_AUDIO + INTERNET permissions, launcher activity,
  `allowBackup=false` (v0.0.2)
- [X] T004 [P] Minimal resources: `strings.xml`, Material Light NoActionBar `themes.xml`;
  `proguard-rules.pro`; `android/.gitignore` excluding `local.properties` and build outputs
  (v0.0.2)
- [X] T005 [P] `local.properties.template` documenting `sdk.dir` + `GCP_STT_API_KEY` (v0.0.2)

## Phase 2: Capture & playback engine (US1)

- [X] T006 [US1] `AudioRecorder.kt`: AudioRecord @ PCM 16-bit/16 kHz/mono, IO-coroutine
  capture loop, reserved-header WAV write with seek-back backfill (v0.0.2)
- [X] T007 [US1] `AudioPlayer.kt`: MediaPlayer wrapper with completion/error callbacks and
  idempotent stop/release (v0.0.2)
- [X] T008 [US1] `MainViewModel.kt`: `RecordingState` enum + `UiState` StateFlow;
  start/stop/play actions with error surfacing; `onCleared` resource release (v0.0.2)

## Phase 3: UI shell & permission flow (US1, US2)

- [X] T009 [US1] `MainActivity.kt`: Compose screen with Record/Stop/Play buttons wired to
  state-derived enablement (v0.0.2)
- [X] T010 [US2] Runtime RECORD_AUDIO request on launch + graceful denial card with Settings
  guidance (v0.0.2)
- [X] T011 [US1] Status line + error card surfaces for recorder/player failures (v0.0.2)

## Phase 4: Documentation of record

- [X] T012 Register the Audio Format Contract in `PATTERNS.md` §2 and README Key Decisions;
  log all 19 files in the `Project_Structure.md` Changelog row; Chunk 0 acceptance test in
  `README.md` (v0.0.2)

## Open follow-ups (genuinely pending)

- [ ] T013 VAD gating (PATTERNS.md §2 "VAD Gating") is not implemented — silence is recorded
  and (in spec 003) sent to the paid STT API; threshold/frame/timeout values were never set
  or documented
- [ ] T014 Streaming capture path (AudioRecord → live frame consumer) — Chunk 4 scope
  (`README.md:75`), needed for the real-time two-phone relay
- [ ] T015 `AudioCapture`/`AudioOutput` provider interfaces named in the Pipeline Stage
  Registry (`Project_Structure.md:56,61`) do not exist as Kotlin abstractions —
  `AudioRecorder`/`AudioPlayer` are concrete classes used directly
- [ ] T016 Latency budget rows for capture/playback hops (PATTERNS.md §2 "Latency Budget
  Tracking") have never been added to `Project_Structure.md`
