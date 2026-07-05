# Feature Specification: Gujarati→English Translation (Chunk 2)

**Feature Branch**: `retro/004-gujarati-english-translation` (as-built record — no branch created)

**Created**: 2026-07-05

**Status**: Shipped (v0.0.4)

**Input**: retro-spec conversion of Chunk 2 from v0.0.4 (commits b7bef79 feature, c40a0bf
release) — GCP Cloud Translation API v2, `gu` → `en`

## Why

The second AI hop of the bridge: the grandparent's Gujarati words must become English text
the 4-year-old's side can use. Chunk 2 adds a Translate action over the transcript —
crucially reworking the transcript into an *editable* field so translation can be exercised
three ways: from real STT output, from corrected STT output, or from typed/pasted Gujarati
(no recording required). It reuses the same GCP project and the same `GCP_STT_API_KEY` as
Chunk 1, so enabling one additional API is the only new setup.

## User Scenarios & Testing

### User Story 1 - Translate the transcript to English (Priority: P1)

With Gujarati text in the transcript field, the user taps "Translate (English)" and reads the
English translation in a card below.

**Why this priority**: The Chunk 2 acceptance test (`README.md:155-161`); the capability's
whole point.

**Independent Test**: Type or transcribe Gujarati text, tap Translate; an English result card
appears.

**Acceptance Scenarios**:

1. **Given** a non-blank transcript, **When** the user taps `Translate (English)`, **Then**
   the button shows a spinner + "Translating...", the text is POSTed to Cloud Translation v2
   with `source=gu`, `target=en`, `format=text`, and the result renders in the
   "Translation (English)" card (`MainActivity.kt:168-198`;
   `TranslationService.kt:32-37,57-61`; `MainViewModel.kt:119-152`).
2. **Given** an empty transcript, **When** the screen renders, **Then** the Translate button
   is disabled (`MainActivity.kt:170`); a whitespace-only transcript additionally no-ops in
   the ViewModel guard (`MainViewModel.kt:120-121`).
3. **Given** a translation is displayed, **When** the user edits the transcript field,
   **Then** the stale translation is cleared immediately
   (`MainViewModel.onTranscriptEdited`, `MainViewModel.kt:113-117`).

---

### User Story 2 - Test translation without recording (Priority: P2)

A user (or CI) types Gujarati text directly into the transcript field and translates it —
no microphone, no STT, no recording needed.

**Why this priority**: Decouples Chunk 2 verification from Chunk 0/1 hardware and
credentials; explicitly listed in the acceptance test (`README.md:160`).

**Independent Test**: Fresh launch → type text into the transcript field → Translate button
enables → tap → result or error card. Automated as smoke-test step 9
(`android/scripts/smoke-test.ps1:306-343`, types "hello" when STT produced nothing).

**Acceptance Scenarios**:

1. **Given** no recording exists, **When** the user types into the transcript field
   (`contentDescription="transcript-field"`, `MainActivity.kt:153-163`), **Then**
   `Translate (English)` enables as soon as the text is non-blank.
2. **Given** CI without a GCP key, **When** the smoke test taps Translate, **Then** an error
   card appears (missing key / API error) instead of a crash — either outcome passes
   (`android/scripts/smoke-test.ps1:330-341`).

### Edge Cases

- **Blank key**: pre-flight error inside the service explains that the *same* key covers
  Translation and that the Cloud Translation API must be enabled in the same project
  (`TranslationService.kt:24-30`).
- **HTTP error**: GCP `error.message` extracted, surfaced as
  `Translation API error <code>: <message>` — e.g. API not enabled on the project
  (`TranslationService.kt:48-55`).
- **Empty response body** → "Empty response body from Cloud Translation API."
  (`TranslationService.kt:45-46`).
- **State collisions**: Transcribe and Translate are mutually exclusive — each button is
  disabled while the other is in flight (`MainActivity.kt:133-136,170-172`); a new recording
  clears `translatedText` (`MainViewModel.kt:38-41`).
- **Explicit non-goals (Chunk 2)**: no auto-translate after STT (user reviews/edits first —
  deliberate for accuracy with a child listener), no language auto-detect (fixed `gu`→`en`),
  no reverse direction (en→gu is future two-way relay scope), no TTS of the result
  (Chunk 3).

## Requirements

### Functional Requirements

- **FR-001**: The app MUST translate via GCP Cloud Translation API v2
  `POST https://translation.googleapis.com/language/translate/v2?key=<API key>`
  (`TranslationService.kt:14,39-42`).
- **FR-002**: The request MUST be `{q, source: "gu", target: "en", format: "text"}` as
  `application/json; charset=utf-8` (`TranslationService.kt:32-41`).
- **FR-003**: The result MUST be read from `data.translations[0].translatedText`
  (`TranslationService.kt:57-61`).
- **FR-004**: Translation MUST reuse `BuildConfig.GCP_STT_API_KEY` — no second credential
  (`MainActivity.kt:32,169`; key-reuse guidance in `TranslationService.kt:26-29` and
  `README.md:131-135`).
- **FR-005**: The transcript MUST be user-editable, with any edit invalidating the shown
  translation (`MainActivity.kt:153-163`; `MainViewModel.kt:113-117`).
- **FR-006**: The trimmed transcript MUST be sent; whitespace-only input never leaves the
  device (`MainViewModel.kt:120-121`).
- **FR-007**: In-flight state (`isTranslating`) MUST disable Translate, Transcribe, and the
  field, with spinner feedback (`MainViewModel.kt:18`; `MainActivity.kt:133-136,162,170-185`).
- **FR-008**: All failures MUST surface via the shared error card with
  `statusMessage="Translation failed."` (`MainViewModel.kt:141-149`).

### Key Entities

- **Translation request/response**: v2 JSON shapes (full detail in data-model.md).
- **UiState.isTranslating / UiState.translatedText**: chunk-owned state fields
  (`MainViewModel.kt:18-19`).
- **Translation result card**: rendered only when `translatedText` is non-empty
  (`MainActivity.kt:187-198`).

## Success Criteria

- **SC-001**: Chunk 2 acceptance test passes end-to-end (STT text → English card) and via
  the type-directly path (`README.md:155-161`). Status: ✅ Built (`README.md:73`).
- **SC-002**: Smoke-test step 9 (translate flow incl. initial-disabled assertion at
  `android/scripts/smoke-test.ps1:229-237`) passes on every version-branch commit since
  v0.0.4.
- **SC-003**: Zero new credentials or infra: same key, same project, one API enablement;
  500K chars/month free tier covers all development (`README.md:20`; `CHANGELOG.md:31-32`).

## Assumptions

- The Cloud Translation API is enabled on the same GCP project as STT (`README.md:135-138`);
  the error card explicitly coaches this when it isn't.
- v2 (API-key capable) is sufficient — v3's OAuth/service-account requirements are
  unnecessary for a personal app.
- Text is short conversational speech; 30 s read timeout is ample
  (`TranslationService.kt:16-19`).
