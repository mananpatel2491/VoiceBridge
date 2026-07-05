# Feature Specification: Gujarati Speech-to-Text (Chunk 1)

**Feature Branch**: `retro/003-gujarati-stt` (as-built record — no branch created)

**Created**: 2026-07-05

**Status**: Shipped (v0.0.2)

**Input**: retro-spec conversion of Chunk 1 from v0.0.2 (commit 0add991) — GCP Cloud
Speech-to-Text v1 REST integration (`gu-IN`)

## Why

The bridge's first AI hop: turn the grandparent's recorded Gujarati speech into Gujarati
text. Without accurate Gujarati transcription there is nothing to translate (Chunk 2) or
synthesize (Chunk 3). Chunk 1 adds a Transcribe action that sends the Chunk 0 recording to
Google Cloud Speech-to-Text with the dedicated `gu-IN` acoustic model, plus the secret-
handling scheme (API key in gitignored `local.properties`, injected via `buildConfigField`)
and full error surfacing so a missing key or network failure is always explained, never a
silent failure or crash.

## User Scenarios & Testing

### User Story 1 - Transcribe recorded Gujarati speech (Priority: P1)

After recording Gujarati speech, the user taps "Transcribe (Gujarati)" and sees the Gujarati
transcript appear in the editable text field.

**Why this priority**: The Chunk 1 acceptance test (`README.md:148-153`); core value of the
chunk.

**Independent Test**: With a valid `GCP_STT_API_KEY` in `android/local.properties`, record
Gujarati speech → Transcribe → Gujarati text appears in the transcript field.

**Acceptance Scenarios**:

1. **Given** a recording exists and a key is configured, **When** the user taps
   `Transcribe (Gujarati)`, **Then** the button shows a spinner + "Transcribing...", the WAV
   is sent to GCP STT, and the transcript fills the editable field on success
   (`MainActivity.kt:131-149`; `MainViewModel.kt:80-110`).
2. **Given** the request is in flight, **When** the user looks at the controls, **Then**
   Transcribe and Translate are disabled and the transcript field is read-only
   (`MainActivity.kt:133-136,162`).
3. **Given** GCP returns a valid response with no speech, **When** transcription completes,
   **Then** the field shows `(No speech detected)` rather than being silently empty
   (`SttService.kt:78-81`; `MainViewModel.kt:95`).
4. **Given** GCP returns multiple result segments, **When** the transcript is assembled,
   **Then** the top alternative of each result is joined with spaces
   (`SttService.kt:83-91`).

---

### User Story 2 - Clear errors instead of silent failure (Priority: P1)

Whatever goes wrong — missing key, bad key, no network, empty audio — the user sees a
specific error card and the app keeps running.

**Why this priority**: Stated Chunk 1 requirement "full error surfacing (network, auth,
empty audio, no speech)" (`CHANGELOG.md:54-56`); also what CI asserts without a credential.

**Independent Test**: Leave `GCP_STT_API_KEY` empty, record, tap Transcribe — an error card
naming `GCP_STT_API_KEY` appears (this is smoke-test step 8,
`android/scripts/smoke-test.ps1:278-303`).

**Acceptance Scenarios**:

1. **Given** a blank API key, **When** Transcribe is tapped, **Then** no network call is made
   and the error card reads "GCP_STT_API_KEY is not set. See local.properties.template."
   (`MainViewModel.kt:74-79`).
2. **Given** an HTTP error from GCP, **When** the response arrives, **Then** the GCP error
   message is extracted from the JSON body and shown as
   `GCP STT error <code>: <message>` (`SttService.kt:68-76`).
3. **Given** the recording file is ≤ 44 bytes, **When** Transcribe runs, **Then** it fails
   fast with "Recording is empty or too short to transcribe." (`SttService.kt:40-42`).

### Edge Cases

- **Empty response body** → "Empty response body from GCP STT." (`SttService.kt:65-66`).
- **Unparseable error JSON** → falls back to the raw body text (`SttService.kt:70-75`).
- **Slow network** → OkHttp timeouts: 30 s connect / 60 s read (`SttService.kt:31-34`); a
  timeout surfaces through `runCatching` as an error card.
- **State hygiene** → starting a new transcription clears prior transcript, translation, and
  error (`MainViewModel.kt:80-88`); starting a new recording does the same
  (`MainViewModel.kt:38-41`).
- **Explicit non-goals (Chunk 1)**: no streaming recognition (single-shot
  `speech:recognize`), no VAD gating of the paid call (whole recording is uploaded, silence
  included), no on-device fallback, no language auto-detect (`gu-IN` fixed).

## Requirements

### Functional Requirements

- **FR-001**: The app MUST transcribe via GCP Cloud Speech-to-Text v1 REST
  `POST https://speech.googleapis.com/v1/speech:recognize?key=<API key>`
  (`SttService.kt:28,59-62`).
- **FR-002**: The request MUST declare `encoding=LINEAR16`,
  `sampleRateHertz=16000` (reused from `AudioRecorder.SAMPLE_RATE`), and
  `languageCode=gu-IN` (`SttService.kt:48-53`).
- **FR-003**: The 44-byte WAV header MUST be stripped and the raw PCM base64-encoded
  (NO_WRAP) as `audio.content` (`SttService.kt:44-46,54-56`).
- **FR-004**: The API key MUST come from gitignored `android/local.properties` via
  `buildConfigField("String","GCP_STT_API_KEY",...)` with `""` fallback — never from source
  control (`android/app/build.gradle.kts:27-31`; consumed at `MainActivity.kt:32`).
- **FR-005**: A blank key MUST short-circuit before any network call with an actionable
  message (`MainViewModel.kt:74-79`).
- **FR-006**: All failures MUST surface as `Result.failure` with a human-readable message
  rendered in the error card; the caller (ViewModel) owns presentation
  (`SttService.kt:22-24,36-38`; `MainViewModel.kt:100-108`).
- **FR-007**: Network I/O MUST run on `Dispatchers.IO` off the main thread
  (`SttService.kt:36-37`).
- **FR-008**: The transcription result MUST land in an editable field the user can correct
  before translating (shipped in v0.0.4's UI rework, `MainActivity.kt:151-163`; original
  v0.0.2 UI used a read-only card — superseded, see research.md Decision 5).

### Key Entities

- **STT request**: `{config: {encoding, sampleRateHertz, languageCode}, audio: {content}}`
  (`SttService.kt:48-57`) — full shape in data-model.md.
- **STT response**: `results[].alternatives[0].transcript` (`SttService.kt:78-91`).
- **BuildConfig.GCP_STT_API_KEY**: compile-time injected secret (shared with spec 004).

## Success Criteria

- **SC-001**: Chunk 1 acceptance test passes: Gujarati speech → Gujarati text in the field;
  missing/invalid key → clear error card, no silent failure (`README.md:148-153`). Status:
  ✅ Built (`README.md:72`).
- **SC-002**: CI-without-credential proof: smoke-test step 8 taps Transcribe with a blank key
  and requires either a transcript, the `GCP_STT_API_KEY` error card, or a surfaced
  network/auth error — any crash or missing card fails the run
  (`android/scripts/smoke-test.ps1:287-303`; passing since v0.0.3).
- **SC-003**: Secret hygiene is machine-checked: the smoke test fails if
  `android/local.properties` is ever tracked by git
  (`android/scripts/smoke-test.ps1:155-161`).

## Assumptions

- Development usage fits the GCP STT free tier (60 min/month, `README.md:35`;
  `.specify/memory/constitution.md:22`).
- The Cloud Speech-to-Text API is enabled on the user's GCP project and the API key is valid
  for it (`README.md:131-144`).
- Recordings are short (single utterances) — the synchronous `speech:recognize` endpoint has
  a ~1-minute audio limit, which the conversational use case respects; long-audio
  `longrunningrecognize` is out of scope.
- Same key/project serves Translation (spec 004) — a deliberate credential-reuse decision.
