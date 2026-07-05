# Feature Specification: Voice Capture & Playback (Chunk 0 — App Shell + Audio Contract)

**Feature Branch**: `retro/002-voice-capture-playback` (as-built record — no branch created)

**Created**: 2026-07-05

**Status**: Shipped (v0.0.2)

**Input**: retro-spec conversion of Chunk 0 from v0.0.2 (commit 0add991, "Android app skeleton + GCP STT Gujarati")

## Why

VoiceBridge bridges Gujarati-speaking grandparents and an English-speaking 4-year-old on
video calls. Before any AI stage can exist, the phone must reliably capture the speaker's
voice in the exact PCM format the rest of the pipeline consumes, and prove it by playing the
recording back. Chunk 0 is that foundation: the Android app shell, the runtime microphone
permission flow, Record/Stop/Play, and the repo-wide audio format contract
(PCM 16-bit / 16 kHz / mono WAV) that Chunks 1–4 build on without format migration.

## User Scenarios & Testing

### User Story 1 - Record and hear my own voice (Priority: P1)

A user opens the app, grants microphone access, taps Record, speaks, taps Stop, then taps
Play and hears the recording clearly.

**Why this priority**: This is the Chunk 0 acceptance test verbatim (`README.md:122-127`);
nothing downstream works without trustworthy capture.

**Independent Test**: On a phone/emulator with no API key configured, complete
Record → Stop → Play; playback is audible. (Automated equivalent: smoke test steps 5–7,
`android/scripts/smoke-test.ps1:241-275`.)

**Acceptance Scenarios**:

1. **Given** mic permission granted and app idle, **When** the user taps `Record`, **Then**
   recording starts, status shows "Recording... tap Stop when done.", and `Record` disables
   while `Stop` enables (`MainViewModel.kt:32-47`; `MainActivity.kt:112-120`).
2. **Given** a recording in progress, **When** the user taps `Stop`, **Then** a valid WAV file
   exists at the app-private path and `Play` becomes enabled
   (`MainViewModel.kt:49-58`; `MainActivity.kt:123-126`).
3. **Given** a saved recording, **When** the user taps `Play`, **Then** the WAV plays through
   `MediaPlayer` and status reports "Playback complete." on finish
   (`AudioPlayer.kt:15-33`; `MainViewModel.kt:60-71`).
4. **Given** a new `Record` tap, **When** recording restarts, **Then** stale transcript and
   translation state from previous cycles is cleared (`MainViewModel.kt:38-41`).

---

### User Story 2 - Graceful permission denial (Priority: P2)

A user who denies microphone access sees a clear explanation and a path to fix it, not a
crash or a dead button.

**Why this priority**: First-run UX and a hard Android platform requirement (runtime
permission, API 23+).

**Independent Test**: Deny the permission dialog; a card explains how to re-enable via
Settings, and `Record` stays disabled.

**Acceptance Scenarios**:

1. **Given** first launch, **When** the app opens, **Then** the `RECORD_AUDIO` runtime
   permission is requested immediately (`MainActivity.kt:51-59`; declared in
   `android/app/src/main/AndroidManifest.xml:4`).
2. **Given** the user denies, **When** the main screen renders, **Then** an error-container
   card reads "Microphone permission denied. Go to Settings > Apps > VoiceBridge >
   Permissions to enable it." and `Record` remains disabled
   (`MainActivity.kt:72-85`, enabled-guard `MainActivity.kt:114`).

### Edge Cases

- **AudioRecord fails to initialize** (permission revoked mid-session, mic busy): `start()`
  throws with "AudioRecord failed to initialize — verify RECORD_AUDIO permission is granted."
  and the ViewModel surfaces it as an error card instead of crashing
  (`AudioRecorder.kt:55-57`; `MainViewModel.kt:44-46`).
- **Stop before the writer thread finishes**: `stop()` intentionally does NOT cancel the
  recording coroutine so the WAV header is still written over the 44 reserved bytes
  (`AudioRecorder.kt:80-86`, header backfill `AudioRecorder.kt:75-77,88-95`).
- **AudioRecord read error**: negative read codes break the capture loop cleanly
  (`AudioRecorder.kt:69-72`).
- **Playback errors**: `MediaPlayer` errors surface via `onError("MediaPlayer error
  (what=..., extra=...)")` → error card (`AudioPlayer.kt:21-24`; `MainViewModel.kt:66-68`).
- **Re-entrant start/play**: both `AudioRecorder.start()` and `AudioPlayer.play()` first stop
  and release any prior instance (`AudioRecorder.kt:43`; `AudioPlayer.kt:16`).
- **ViewModel teardown**: `onCleared()` stops recorder and player, releasing the mic and
  audio resources (`MainViewModel.kt:154-158`).
- **Explicit non-goals (Chunk 0)**: no pause/resume, no multiple recordings (single fixed
  file `recording.wav` is overwritten each time, `MainActivity.kt:26`), no VAD, no streaming
  capture (deferred to Chunk 4 per `README.md:69-75`).

## Requirements

### Functional Requirements

- **FR-001**: The app MUST capture microphone audio as PCM 16-bit, 16 kHz, mono — the
  repo-wide audio contract (`AudioRecorder.kt:29-31`; `PATTERNS.md:23`).
- **FR-002**: Recordings MUST be persisted as valid WAV: a 44-byte RIFF/fmt/data header is
  reserved on start and backfilled with real sizes on stop
  (`AudioRecorder.kt:64-77,97-120`).
- **FR-003**: The recording file MUST live in app-private storage
  (`filesDir/recording.wav`, `MainActivity.kt:26`) — no external-storage permission is
  requested (`AndroidManifest.xml:4-5` lists only `RECORD_AUDIO` and `INTERNET`).
- **FR-004**: The UI MUST expose exactly the Chunk 0 controls Record / Stop / Play with
  state-derived enablement: Record disabled while recording; Stop enabled only while
  recording; Play enabled only when a recording exists and not recording
  (`MainActivity.kt:111-126`).
- **FR-005**: The `RECORD_AUDIO` permission MUST be requested at runtime with a graceful
  denial card (`MainActivity.kt:48-59,72-85`).
- **FR-006**: All capture I/O MUST run off the main thread (capture loop on
  `Dispatchers.IO`, `AudioRecorder.kt:38,63`).
- **FR-007**: Recording state MUST be modeled as an explicit state machine
  (`RecordingState { IDLE, RECORDING, STOPPED }`, `MainViewModel.kt:11`) exposed via a single
  immutable `UiState` StateFlow (`MainViewModel.kt:13-27`).
- **FR-008**: `android:allowBackup` MUST be false so recordings are not silently backed up
  off-device (`AndroidManifest.xml:8`).

### Key Entities

- **UiState**: `recordingState`, `hasRecording`, `isTranscribing`, `transcript`,
  `isTranslating`, `translatedText`, `statusMessage`, `errorMessage`
  (`MainViewModel.kt:13-22`) — single source of UI truth (fields beyond Chunk 0 were added by
  specs 003/004).
- **recording.wav**: the single app-private WAV artifact (full shape in data-model.md).
- **AudioRecorder / AudioPlayer**: capture and playback wrappers (Pipeline Stage Registry
  rows "Audio Capture" and "Audio Output", `Project_Structure.md:56,61`).

## Success Criteria

- **SC-001**: Chunk 0 acceptance test (`README.md:122-127`) passes on a physical phone —
  recorded speech is audible on Play. Status: ✅ Built (`README.md:71`).
- **SC-002**: The automated smoke test drives Record → Stop → Play with screenshot evidence
  and zero logcat crashes on every version-branch commit
  (`android/scripts/smoke-test.ps1:241-275,346-359`) — passing since v0.0.3.
- **SC-003**: Downstream stages consume the recording with no format conversion: GCP STT
  accepts the PCM payload as `LINEAR16` directly (`SttService.kt:44-52`), evidencing the
  contract.

## Assumptions

- Single-user, single-recording workflow: each Record overwrites `recording.wav`; history is
  out of scope for the personal-app use case.
- Device runs API 24+ (`minSdk 24`, `android/app/build.gradle.kts:20`).
- `MediaPlayer` (not `AudioTrack`) is sufficient for Chunk 0 playback; raw-buffer playback is
  a Chunk 4 concern (`README.md:24-27`).
