# Audio Format Contract (repo-wide, established by Chunk 0)

The binding inter-stage audio contract for the whole VoiceBridge pipeline
(`PATTERNS.md:23`; constitution Principle III).

## The contract

| Property | Value | Defined at |
|---|---|---|
| Encoding | PCM 16-bit signed, little-endian | `AudioRecorder.kt:31` (`ENCODING_PCM_16BIT`) |
| Sample rate | 16 000 Hz | `AudioRecorder.kt:29` |
| Channels | 1 (mono) | `AudioRecorder.kt:30` (`CHANNEL_IN_MONO`) |
| Container (at rest) | WAV, 44-byte RIFF header | `AudioRecorder.kt:33,97-120` |
| Container (in transit to STT) | headerless raw PCM, base64 | `SttService.kt:44-46` |

Exceptions require a documented rationale in `PATTERNS.md` (none exist to date).

## Producer obligations (`AudioRecorder`)

- Reserve 44 header bytes before streaming PCM to disk; backfill the header with real sizes
  after capture ends (`AudioRecorder.kt:64-77,88-95`). A crash before backfill leaves an
  invalid WAV — acceptable because the file is overwritten on next Record.
- Buffer ≥ `AudioRecord.getMinBufferSize` (floor 8192 bytes) to avoid frame drops
  (`AudioRecorder.kt:45-46`).
- `stop()` must let the writer coroutine finish (never cancel it) so the header lands
  (`AudioRecorder.kt:80-86`).

## Consumer obligations

- **AudioPlayer**: consumes the WAV as-is via `MediaPlayer.setDataSource(path)`
  (`AudioPlayer.kt:19`).
- **SttService**: must strip exactly `WAV_HEADER_BYTES = 44` (`SttService.kt:29,45`) and
  declare `encoding=LINEAR16`, `sampleRateHertz=AudioRecorder.SAMPLE_RATE` — note the direct
  constant reuse, which keeps the two sides mechanically in sync (`SttService.kt:50-52`).
- **Future stages (Chunk 3/4 TTS + relay)**: must consume/produce the same PCM frame format;
  this is the stated reason no format migration is needed later (`README.md:41`).

## Non-guarantees

- No VAD: the payload may be mostly silence.
- No length cap: file grows unbounded for the duration of recording (personal-app scope).
- Single artifact: `recording.wav` is overwritten per session; no concurrency guarantees
  across simultaneous starts (UI state machine prevents them).
