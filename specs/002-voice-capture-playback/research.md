# Research: Voice Capture & Playback (Chunk 0)

As-built record — decisions reconstructed 2026-07-05 from v0.0.2, `README.md` Key Decisions,
and `CHANGELOG.md` [0.0.2] Decisions block.

## Decision 1 — Kotlin native + Jetpack Compose (over Flutter / React Native)

**Choice**: native Kotlin with Compose UI (`CHANGELOG.md:58`; `README.md:22-27`).
**Why**: `AudioRecord`/`AudioTrack` give raw PCM byte-buffer access with zero bridge/JNI
latency — a hard requirement for the Chunk 4 real-time pipeline; Compose removes XML layouts.
**Rejected**: Flutter and React Native — both add a platform-channel hop on the audio path,
unacceptable for near-real-time voice.

## Decision 2 — WAV / LINEAR16 at PCM 16-bit, 16 kHz, mono as the repo-wide audio contract

**Choice**: capture at 16 kHz/16-bit/mono and persist as WAV (`AudioRecorder.kt:29-33`;
contract registered `PATTERNS.md:23`; `README.md:37-42`).
**Why**: `AudioRecord` emits raw PCM natively (WAV is just a 44-byte header); GCP STT accepts
it as `LINEAR16` with no conversion (`SttService.kt:50-52`); the identical buffer format
carries into Chunk 4 streaming, so no future migration.
**Rejected**: M4A/AAC — GCP STT would require a decode step (`README.md:42`).

## Decision 3 — Reserved-header WAV writing (seek-back backfill)

**Choice**: write 44 zero bytes first, stream PCM to disk, then `RandomAccessFile` seek(0)
and overwrite with the real RIFF header once sizes are known (`AudioRecorder.kt:64-77,88-95`).
**Why**: WAV headers need final data size; streaming to disk keeps memory flat regardless of
recording length. Corollary: `stop()` must NOT cancel the writer job
(`AudioRecorder.kt:85`) or the file would be left headerless.
**Rejected**: buffering all PCM in memory before writing.

## Decision 4 — MediaPlayer for Chunk 0 playback

**Choice**: thin `MediaPlayer` wrapper (`AudioPlayer.kt:11-44`).
**Why**: file-based WAV playback is exactly MediaPlayer's job; minimal code, callbacks for
completion/error.
**Rejected (deferred)**: `AudioTrack` raw-buffer playback — only needed when Chunk 4 streams
synthesized audio; noted in `README.md:24` as the eventual real-time path.

## Decision 5 — Single StateFlow UiState + explicit RecordingState enum

**Choice**: one immutable `UiState` data class on a `MutableStateFlow`
(`MainViewModel.kt:13-27`) with `RecordingState { IDLE, RECORDING, STOPPED }`.
**Why**: Compose-idiomatic unidirectional data flow; button enablement derives from state
(`MainActivity.kt:111-126`), which the smoke test can assert via accessibility semantics
(`android/scripts/smoke-test.ps1:128-140`).
**Rejected**: multiple LiveData/mutableState fields scattered across the activity.

## Decision 6 — Programmatically grantable runtime permission

**Choice**: standard runtime request on launch (`MainActivity.kt:51-59`) — which also allows
CI to pre-grant via `adb shell pm grant` so the dialog never blocks UI automation
(`android/scripts/smoke-test.ps1:206-208`).
**Why**: platform requirement + testability.
**Rejected**: none (no alternative on API 23+).
