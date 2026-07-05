---
description: "As-built task record for Chunk 2 — Gujarati→English translation"
---

# Tasks: Gujarati→English Translation (Chunk 2)

As-built record — reconstructed 2026-07-05 from v0.0.4 (feature commit b7bef79, release
commit c40a0bf). `[X]` = shipped with release; `[ ]` = genuinely open.

## Phase 1: Translation client (US1)

- [X] T001 [US1] `TranslationService.kt`: OkHttp client (30 s/30 s), v2 request
  `{q, source:"gu", target:"en", format:"text"}`, `?key=` auth,
  `data.translations[0].translatedText` parsing (v0.0.4)
- [X] T002 [US1] Error surfacing: blank-key message with same-key/enable-API coaching,
  HTTP `error.message` mining, empty-body guard — all `Result.failure` (v0.0.4)

## Phase 2: State & actions (US1, US2)

- [X] T003 [US1] `UiState` gains `isTranslating` + `translatedText`; `translate()` action
  with trim/empty guard (v0.0.4)
- [X] T004 [US2] `onTranscriptEdited()` — direct-typing support with immediate stale-
  translation invalidation (v0.0.4)
- [X] T005 [US1] `startRecording()` and `transcribe()` also clear `translatedText` so no
  stale pair can render (v0.0.4)

## Phase 3: UI (US1, US2)

- [X] T006 [US2] Transcript card → editable `OutlinedTextField` with
  `contentDescription="transcript-field"`, placeholder inviting direct typing, disabled
  while busy (v0.0.4)
- [X] T007 [US1] `Translate (English)` button: enabled iff transcript non-blank and idle;
  spinner + "Translating..." while in flight (v0.0.4)
- [X] T008 [US1] "Translation (English)" result card rendered when `translatedText`
  non-empty (v0.0.4)

## Phase 4: Verification & release

- [X] T009 Smoke test: initial Translate-disabled assertion + full translate flow (type
  "hello" fallback in CI, result-or-error card check) (v0.0.4)
- [X] T010 Version bump to versionCode 4 / versionName "0.0.4"; CHANGELOG [0.0.4] entry with
  Decisions block; Project_Structure rows + Pipeline Stage Registry Translation row (v0.0.4)
- [X] T011 Hook fix shipped alongside: post-commit now passes `-Build` on release commits so
  auto-merge tests a fresh APK (commit 88ac97a, v0.0.4 cycle)

## Open follow-ups (genuinely pending)

- [ ] T012 Extract `TranslationProvider` interface named in the registry
  (`Project_Structure.md:58`) — same seam debt as spec 003 T012
- [ ] T013 Chunk 3: feed `translatedText` into voice-clone TTS (`README.md:74` — Not
  started); the result card is currently a terminal output
- [ ] T014 Reverse direction (en→gu) for the two-way relay — Chunk 4 scope
- [ ] T015 Latency budget row for the Translation hop in `Project_Structure.md`
  (PATTERNS.md §2)
