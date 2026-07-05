# Implementation Plan: Gujarati→English Translation (Chunk 2)

**Branch**: `retro/004-gujarati-english-translation` | **Date**: 2026-07-05 | **Spec**: [spec.md](./spec.md)

**Input**: As-built reconstruction from v0.0.4 (commits b7bef79, c40a0bf).

## Summary

`TranslationService.kt` mirrors the Chunk 1 service shape: a stateless Kotlin `object` on
OkHttp that POSTs `{q, source:"gu", target:"en", format:"text"}` to Cloud Translation v2 and
returns `Result<String>`. `MainViewModel` gained `isTranslating`/`translatedText` state, a
`translate()` action, and `onTranscriptEdited()` for staleness invalidation. The UI replaced
the read-only transcript card with an editable `OutlinedTextField` (semantics
`transcript-field` for testability) plus a Translate button and result card. The smoke test
gained a translate step that works with or without a real key.

## Technical Context

**Language/Version**: Kotlin 2.0.21 / JVM 17 (unchanged baseline)

**Primary Dependencies**: OkHttp 4.12.0 + `org.json` (same as spec 003 — no new dependency
was added for this chunk)

**Storage**: none — in-memory UiState only

**Testing**: smoke-test step 9 (`android/scripts/smoke-test.ps1:306-343`) + initial
Translate-disabled assertion (`android/scripts/smoke-test.ps1:229-237`); manual acceptance
test `README.md:155-161`

**Target Platform**: Android API 24–35; network required for live translation

**Project Type**: mobile app — second service-layer object + UI extension

**Performance Goals**: single-shot text translation; 30 s connect / 30 s read timeouts
(`TranslationService.kt:16-19`)

**Constraints**: same `GCP_STT_API_KEY` credential as STT (hard requirement of the chunk);
500K chars/month free tier

**Scale/Scope**: 1 service object (~65 lines), 2 ViewModel actions, 1 field + 1 button +
1 card in the UI, version bump to 0.0.4 (`android/app/build.gradle.kts:22-23`)

## Constitution Check

Gated against `.specify/memory/constitution.md` (distillation of `GEMINI.md`, supreme).

- **I. Context-First Architecture Map — PASS.** `TranslationService.kt` mapped at
  `Project_Structure.md:33`; Translation row added to the Pipeline Stage Registry
  (`Project_Structure.md:58`); v0.0.4 Changelog rows list every touched file
  (`Project_Structure.md:71-72`).
- **II. Pattern Reference Integrity — PASS.** Reuses the established service-object pattern
  from Chunk 1 (same OkHttp/`Result`/error-mining shape — compare `TranslationService.kt:44-55`
  with `SttService.kt:64-76`); decision rationale recorded in `CHANGELOG.md:30-34` and
  `README.md:9-20` instead of re-litigating.
- **III. Voice Pipeline Discipline — PARTIAL, documented.** Text stage, so the PCM contract
  is untouched. Provider seam: same gap as Chunk 1 — concrete `TranslationService` object,
  `TranslationProvider` (`Project_Structure.md:58`) not yet extracted; carried open in
  tasks.md. Streaming: N/A for short-text translation (buffered call is the appropriate
  shape here).
- **IV. Gated Validation — PASS.** No repo backend → Bruno N/A; smoke test extended in the
  same release with the translate step and the initial-disabled assertion — the gate grew
  with the feature, as required.
- **V. Infrastructure-as-Code & Cost Gating — PASS.** Zero new infra and zero new
  credentials; free tier 500K chars/month; explicitly costed in the decision record
  (`CHANGELOG.md:31-32`). Terraform untouched by design.

## Project Structure

### Documentation (this feature)

```text
specs/004-gujarati-english-translation/
├── spec.md
├── plan.md              # this file
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
└── contracts/
    └── gcp-translation-contract.md
```

### Source Code (repository root)

```text
android/app/src/main/java/com/mananpatel/voicebridge/
├── TranslationService.kt      # Cloud Translation v2 REST client        (v0.0.4)
├── MainViewModel.kt           # isTranslating/translatedText state,
│                              # translate(), onTranscriptEdited()       (v0.0.4)
└── MainActivity.kt            # editable OutlinedTextField, Translate
│                              # button, Translation (English) card      (v0.0.4)
android/app/build.gradle.kts   # versionCode 4 / versionName "0.0.4"     (v0.0.4)
android/scripts/smoke-test.ps1 # translate-flow step + disabled assert   (v0.0.4)
```

**Structure Decision**: one service object per pipeline stage continues; the UI stays a
single screen — Chunk 2 extends it below a divider rather than adding navigation.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| No `TranslationProvider` interface | Same reasoning as spec 003: one implementation exists; the registry records the intended seam | Speculative abstraction before a second provider exists |
| Manual Translate tap instead of auto-translate after STT | User reviews/corrects STT output before it is translated for a child — accuracy over convenience | Auto-chaining rejected: STT errors would propagate silently into the child-facing output |
