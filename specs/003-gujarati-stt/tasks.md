---
description: "As-built task record for Chunk 1 — GCP Gujarati speech-to-text"
---

# Tasks: Gujarati Speech-to-Text (Chunk 1)

As-built record — reconstructed 2026-07-05 from v0.0.2 (commit 0add991) and the v0.0.4
editable-field refinement (commit b7bef79). `[X]` = shipped with release; `[ ]` = genuinely
open.

## Phase 1: Secret plumbing

- [X] T001 `buildConfigField("String","GCP_STT_API_KEY", <local.properties value, "" fallback>)`
  in `android/app/build.gradle.kts` + `buildConfig=true` feature flag (v0.0.2)
- [X] T002 [P] Document the key in `android/local.properties.template` and README
  "Providing API Credentials" (v0.0.2; README merged STT+Translation guidance v0.0.4)
- [X] T003 [P] Keep `local.properties` gitignored (`android/.gitignore`); later
  machine-enforced by smoke-test credential hygiene (v0.0.2; enforcement v0.0.3)

## Phase 2: STT client (US1, US2)

- [X] T004 [US1] `SttService.kt`: OkHttp client (30 s/60 s timeouts), request builder with
  `LINEAR16`/16000/`gu-IN` config, WAV-header strip + base64 NO_WRAP payload (v0.0.2)
- [X] T005 [US2] Error surfacing: empty/short-file guard, HTTP error → GCP `error.message`
  extraction, empty-body guard, all as `Result.failure` (v0.0.2)
- [X] T006 [US1] Response parsing: join `results[].alternatives[0].transcript`; empty results
  → `""` (v0.0.2)

## Phase 3: ViewModel + UI (US1, US2)

- [X] T007 [US2] `MainViewModel.transcribe()`: blank-key pre-flight guard with actionable
  message (v0.0.2)
- [X] T008 [US1] `isTranscribing` state + spinner-in-button "Transcribing..." UX; controls
  disabled while in flight (v0.0.2)
- [X] T009 [US1] `(No speech detected)` rendering for empty transcripts (v0.0.2)
- [X] T010 [US1] Transcript display upgraded from read-only card to editable
  `OutlinedTextField` with `transcript-field` contentDescription (v0.0.4)

## Phase 4: Verification

- [X] T011 Smoke-test step 8: Transcribe-without-key asserts error card / transcript /
  surfaced network error — proves error UX in CI without a credential (v0.0.3)

## Open follow-ups (genuinely pending)

- [ ] T012 Extract the `STTProvider` interface promised by the Pipeline Stage Registry
  (`Project_Structure.md:57`) so GCP STT becomes one injected implementation
  (PATTERNS.md §2 Provider Interface Pattern)
- [ ] T013 Streaming recognition (WebSocket/gRPC) for the Chunk 4 real-time pipeline —
  current `speech:recognize` is single-shot with a ~1 min audio ceiling
- [ ] T014 VAD gating of paid STT calls (PATTERNS.md §2 "VAD Gating") — silence is currently
  uploaded; threshold/frame-size/timeout still undocumented
- [ ] T015 Latency budget row (P50/P95) for the STT hop in `Project_Structure.md`
  (PATTERNS.md §2 "Latency Budget Tracking")
