---
name: voicebridge-audio-pipeline-reference
description: >-
  Domain reference for VoiceBridge's audio pipeline as actually built: WAV/RIFF
  header anatomy, the placeholder-then-seek header pattern (why
  AudioRecorder.stop() must never cancel the recording coroutine), AudioRecord
  lifecycle, the PCM 16-bit / 16 kHz / mono contract, the 44-byte header strip
  before GCP STT upload, MediaPlayer limits, audio math, and streaming/VAD
  theory for Chunk 4. Load this skill whenever you (a) read or modify
  AudioRecorder.kt, AudioPlayer.kt, or the audio-handling half of SttService.kt,
  (b) debug a corrupt/unplayable/zero-length WAV, a "Recording is empty" error,
  or garbled playback, (c) size buffers, estimate payloads, or
  reason about recording length limits, or (d) design Chunk 4 streaming capture
  or VAD gating. Do NOT load it for GCP request/response or quota questions
  (voicebridge-gcp-speech-apis-reference), build/emulator setup
  (voicebridge-build-and-env), release or smoke-test procedure
  (voicebridge-release-gate-runbook), or general crash debugging
  (voicebridge-debugging-playbook).
---

# VoiceBridge Audio Pipeline Reference

Everything below is verified against the repo on 2026-07-13. This is the audio
*domain theory* as it applies to THIS codebase — not a general audio textbook.
File paths are relative to `C:\Docs\Build\mananUtils\VoiceBridge` unless absolute.

**Jargon defined once:**

- **PCM** (Pulse-Code Modulation): raw uncompressed audio — a stream of signed
  integer samples. "16-bit PCM" = each sample is a signed 2-byte little-endian
  integer.
- **WAV / RIFF**: WAV is a RIFF (Resource Interchange File Format) container. A
  RIFF file = a header + typed "chunks". Our WAV = 44-byte header + one `data`
  chunk of raw PCM. Nothing else.
- **Sample rate**: samples per second per channel. 16 kHz = 16,000 samples/sec.
- **Mono**: 1 channel. Stereo would interleave 2 channels sample-by-sample.
- **LINEAR16**: GCP Speech-to-Text's name for exactly our format — headerless
  16-bit little-endian PCM.
- **VAD** (Voice Activity Detection): classifying short audio frames as
  speech vs. silence, used to gate expensive downstream calls.

## 1. The pipeline at a glance (Chunks 0–2, shipped)

```
Mic → AudioRecord (raw PCM frames)
    → AudioRecorder writes filesDir/recording.wav      (MainActivity.kt:26)
    → SttService strips 44-byte header, base64s PCM → GCP STT v1 (gu-IN)
    → TranslationService (gu→en)                       [text only — no audio]
    → AudioPlayer (MediaPlayer) plays the WAV back
```

The audio format contract is constitutional: PCM 16-bit / 16 kHz / mono between
all pipeline stages unless an exception is documented with rationale
(PATTERNS.md:23, "Audio Format Contract"). All three audio classes obey it.

Sources of truth (all six app files live under
`android\app\src\main\java\com\mananpatel\voicebridge\`):

| File | Audio role |
|---|---|
| `AudioRecorder.kt` | Mic capture → valid WAV file (this skill's core subject) |
| `AudioPlayer.kt` | WAV playback via `MediaPlayer` |
| `SttService.kt` | Consumes the WAV: strips header, uploads raw PCM |
| `MainViewModel.kt:29-30` | Owns one `AudioRecorder` + one `AudioPlayer` instance |
| `MainActivity.kt:26` | Defines the single recording file `File(filesDir, "recording.wav")` — overwritten every recording |

## 2. WAV/RIFF anatomy, byte by byte, as built here

`AudioRecorder.buildWavHeader(pcmDataSize)` (`AudioRecorder.kt:97-120`) emits
exactly 44 bytes via a little-endian `ByteBuffer` (`AudioRecorder.kt:100`).
All multi-byte integers are **little-endian** (RIFF requirement); the four
4-character tags are plain ASCII.

| Offset | Size | Field | Value in THIS app | Code line (AudioRecorder.kt) |
|---:|---:|---|---|---|
| 0 | 4 | ChunkID | ASCII `RIFF` | 103 |
| 4 | 4 | ChunkSize | `pcmDataSize + 36` (= file length − 8) | 104 |
| 8 | 4 | Format | ASCII `WAVE` | 105 |
| 12 | 4 | Subchunk1 ID | ASCII `fmt ` (note the trailing space — 4 chars) | 107 |
| 16 | 4 | Subchunk1 size | `16` (a plain-PCM fmt chunk is always 16 bytes) | 108 |
| 20 | 2 | AudioFormat | `1` = uncompressed PCM | 109 |
| 22 | 2 | NumChannels | `1` (mono) | 110 |
| 24 | 4 | SampleRate | `16000` (`SAMPLE_RATE`, line 29) | 111 |
| 28 | 4 | ByteRate | `32000` = SampleRate × channels × bytesPerSample = 16000 × 1 × 2 | 98, 112 |
| 32 | 2 | BlockAlign | `2` = channels × bytesPerSample (bytes per one multi-channel sample frame) | 113 |
| 34 | 2 | BitsPerSample | `16` (`BYTES_PER_SAMPLE * 8`, line 32) | 114 |
| 36 | 4 | Subchunk2 ID | ASCII `data` | 116 |
| 40 | 4 | Subchunk2 size | `pcmDataSize` (raw PCM byte count) | 117 |
| 44 | … | data | raw signed 16-bit LE PCM samples | (written by the record loop) |

Why the two size fields matter for debugging:

- **ChunkSize (offset 4)** = everything after offset 8 = `pcmDataSize + 36`.
  If a player reports a truncated/invalid file, hexdump offsets 4 and 40 first.
- **Subchunk2 size (offset 40)** = PCM byte count only. `MediaPlayer` uses this
  to know where audio data ends. If it reads `0`, the header backfill (§3)
  never ran — see the stop()/coroutine rule below.

Quick header check from PowerShell (first 44 bytes of the pulled file):

```powershell
& C:\Android\platform-tools\adb.exe shell "run-as com.mananpatel.voicebridge cat files/recording.wav > /sdcard/rec.wav"
& C:\Android\platform-tools\adb.exe pull /sdcard/rec.wav $env:TEMP\rec.wav
& C:\Android\platform-tools\adb.exe shell rm /sdcard/rec.wav
$b = [System.IO.File]::ReadAllBytes("$env:TEMP\rec.wav")[0..43]
[System.Text.Encoding]::ASCII.GetString($b[0..3]) + " / " + [System.Text.Encoding]::ASCII.GetString($b[8..11]) + " / rate=" + [BitConverter]::ToInt32($b,24) + " / dataSize=" + [BitConverter]::ToInt32($b,40)
# Expect: RIFF / WAVE / rate=16000 / dataSize=<file length - 44>
```

Never redirect `adb exec-out` binary output with `>` in PowerShell 5.1 — it
re-encodes native stdout as text and corrupts the bytes, so the Expect line
above becomes unobtainable even for a healthy recording; the two-step `/sdcard`
pull is byte-safe (see voicebridge-diagnostics-and-tooling section 3). For a
more thorough version of this same check, use
`.claude/skills/voicebridge-diagnostics-and-tooling/scripts/inspect_wav.py`.

## 3. The placeholder-then-seek header pattern (and the stop() rule)

A WAV header contains two sizes you cannot know until recording ends. So
`AudioRecorder` does this (the standard pattern for stream-to-disk WAV):

1. **On start**: write 44 zero bytes as a placeholder, then stream PCM after
   them (`AudioRecorder.kt:64-66` — `fos.write(ByteArray(WAV_HEADER_SIZE))`).
2. **Record loop**: `ar.read(buffer, …)` → `fos.write(...)` while recording
   (`AudioRecorder.kt:68-73`). Memory stays flat regardless of duration —
   nothing is buffered in RAM beyond one `bufSize` array.
3. **On loop exit**: the stream is closed, then `writeWavHeader(outputFile)`
   runs (`AudioRecorder.kt:75-76`). It computes
   `pcmDataSize = file.length() - 44` (`AudioRecorder.kt:89-90`), opens the
   file with `RandomAccessFile("rw")`, `seek(0)`, and overwrites the
   placeholder with the real header (`AudioRecorder.kt:91-94`).

**THE RULE — `stop()` must NOT cancel `recordingJob`.**
`stop()` (`AudioRecorder.kt:80-86`) only flips `isRecording = false`, stops and
releases the `AudioRecord`, and returns. The comment at `AudioRecorder.kt:85`
is load-bearing: *"Do NOT cancel recordingJob here — let it finish writing the
WAV header."* The header backfill lives INSIDE the coroutine, after the read
loop exits (`AudioRecorder.kt:75-76`). If anyone "cleans up" by adding
`recordingJob?.cancel()` in `stop()`, the job dies before `writeWavHeader`
runs and every recording ends as 44 zero bytes + PCM = a file that:

- `MediaPlayer` refuses to play (garbage/zeroed header),
- STT still half-works (SttService blindly skips 44 bytes, §5), which makes
  the bug confusingly asymmetric: "transcription works but playback broken"
  → suspect a dead header backfill first.

The loop exits when either `isRecording` goes false OR the `AudioRecord`
leaves `RECORDSTATE_RECORDING` (`AudioRecorder.kt:69`) — releasing the
recorder in `stop()` satisfies the second condition even if a race delays the
first, so the coroutine always reaches the header write.

Related invariant: `start()` calls `stop()` first (`AudioRecorder.kt:43`) so a
double-tap on Record can't leak a live `AudioRecord` or interleave two writers
into `recording.wav`.

## 4. AudioRecord lifecycle (capture side)

`AudioRecorder.start()` (`AudioRecorder.kt:42-78`), step by step:

| Step | Code | What a junior must know |
|---|---|---|
| Buffer sizing | `maxOf(getMinBufferSize(...), 8192)` (`AudioRecorder.kt:45-46`) | `getMinBufferSize` returns the device-specific minimum internal buffer; going below it makes the constructor fail. The 8192-byte floor (= 256 ms at our format, see §7) guards against devices reporting tiny minimums that cause overrun/data loss under scheduling jitter. |
| Construction | `AudioRecord(MediaRecorder.AudioSource.MIC, 16000, CHANNEL_IN_MONO, ENCODING_PCM_16BIT, bufSize)` (`AudioRecorder.kt:48-54`) | Constructor never throws for permission problems — it silently yields an uninitialized object. |
| Init check = permission proxy | `check(ar.state == AudioRecord.STATE_INITIALIZED)` (`AudioRecorder.kt:55-57`) | On Android, a missing/denied `RECORD_AUDIO` permission most commonly surfaces as `state != STATE_INITIALIZED` right here — hence the error text pointing at the permission. The runtime permission is requested in `MainActivity.kt:59`. If this `check` trips, verify the permission grant before suspecting hardware. |
| Read loop | `ar.read(buffer, 0, buffer.size)` (`AudioRecorder.kt:70`) | Blocking read into a byte array. Returns bytes read (≥ 0) or a **negative error code**: `ERROR_INVALID_OPERATION` (−3, e.g. reading after release), `ERROR_BAD_VALUE` (−2), `ERROR_DEAD_OBJECT` (−6), `ERROR` (−1). The loop treats any negative as fatal and breaks cleanly (`AudioRecorder.kt:71`) — the header still gets written, so a mid-recording device error yields a short-but-valid WAV, not a corrupt one. |
| Teardown | `stop()` → `audioRecord.stop(); release(); audioRecord = null` (`AudioRecorder.kt:80-86`) | `release()` frees the native mic resource. Never keep a released `AudioRecord` reference around — hence the null-out. |

Threading: the loop runs on `Dispatchers.IO` in a class-private
`CoroutineScope` (`AudioRecorder.kt:38,63`); `isRecording` is `@Volatile`
(`AudioRecorder.kt:40`) because `stop()` flips it from a different thread.

## 5. Why exactly 16 kHz / 16-bit / mono

This is a deliberate contract, not a default:

1. **GCP STT native**: `LINEAR16` at 16000 Hz is what `SttService` declares
   (`SttService.kt:50-51`, `sampleRateHertz` read from
   `AudioRecorder.SAMPLE_RATE` — single source of truth, no drift possible).
   Recording in this format means **zero resampling / transcoding** anywhere
   in the app. 16 kHz is also the sweet spot for speech models — speech
   energy lives below 8 kHz (Nyquist of 16 kHz), so higher rates add payload
   without accuracy.
2. **One format end-to-end**: PATTERNS.md:23 mandates PCM 16-bit/16 kHz/mono
   between ALL pipeline stages. Capture, upload, and (future) TTS/relay all
   speak the same frames.
3. **Chunk 4 reuse**: the real-time two-phone relay (not started) will stream
   the *same* buffers instead of writing them to a file. Because capture is
   already frame-based `ByteArray` reads at the wire format, Chunk 4 changes
   the *sink*, not the capture code (see §8; deferral recorded in
   `specs/002-voice-capture-playback/tasks.md:52`, T014).
4. **Mono**: one mic, one speaker at a time; stereo would double every payload
   for zero STT benefit.

If you ever need to deviate (e.g. a TTS voice that only ships 24 kHz),
PATTERNS.md:23 requires documenting the exception with rationale in
PATTERNS.md — do that via change control, not ad hoc.

## 6. Header strip on upload (SttService)

GCP STT's `LINEAR16` encoding means **headerless** PCM. `SttService.transcribe`
therefore:

- Guards `allBytes.size <= WAV_HEADER_BYTES` → "Recording is empty or too
  short to transcribe." (`SttService.kt:29,40-42`). A 44-byte file = header
  only = user tapped stop instantly.
- Strips the first 44 bytes: `copyOfRange(WAV_HEADER_BYTES, allBytes.size)`
  (`SttService.kt:45`).
- Base64-encodes with `Base64.NO_WRAP` (`SttService.kt:46`). **NO_WRAP is
  mandatory**: Android's default Base64 inserts `\n` every 76 chars, which
  corrupts the JSON string value and produces baffling GCP 400s.

Note the coupling: `WAV_HEADER_BYTES` (SttService.kt:29) and `WAV_HEADER_SIZE`
(AudioRecorder.kt:33) are two constants that must stay equal at 44. There is
no shared symbol. If anyone ever adds chunks to the WAV header (e.g. a `LIST`
metadata chunk), the blind 44-byte strip breaks silently — STT would receive
leading garbage bytes and return junk or empty transcripts. Keep the header
minimal; that is part of the contract
(`specs/002-voice-capture-playback/contracts/audio-format-contract.md`).

The rest of the wire contract (endpoint, auth, error mapping, quotas) is the
sibling skill `voicebridge-gcp-speech-apis-reference`'s territory; the
behavioral contract is also written down in
`specs/003-gujarati-stt/contracts/gcp-stt-contract.md`.

## 7. Audio math you will actually use

At PCM 16-bit / 16 kHz / mono:

| Quantity | Value | Derivation |
|---|---|---|
| Bytes per sample | 2 | 16-bit |
| Bytes per second | **32,000** | 16,000 samples × 2 bytes × 1 channel (this is the header's ByteRate field) |
| 8192-byte capture buffer | 256 ms of audio | 8192 ÷ 32,000 |
| 2 s recording | ≈ 64,044 bytes on disk | 2 × 32,000 + 44 header |
| 1 min recording | ≈ 1.92 MB PCM | 60 × 32,000 |
| Base64 inflation | × 4⁄3 | 3 raw bytes → 4 chars; 1 min PCM ≈ 2.56 MB of JSON payload |
| Duration of any WAV | `(fileBytes − 44) ÷ 32,000` seconds | invert bytes/sec |
| 20 ms VAD frame (future) | 320 samples = 640 bytes | 0.020 × 16,000 × 2 |

Use these for sanity checks: a "30-second" recording that is 200 KB on disk is
actually ~6 s — something stopped early (look for a negative `read` in §4).

## 8. Playback path and its limits (AudioPlayer)

`AudioPlayer` (`AudioPlayer.kt`) is a thin `MediaPlayer` wrapper:

- `play(file, onComplete, onError)`: `stop()` any prior player, then
  `setDataSource(path)` → `prepare()` → `start()` (`AudioPlayer.kt:15-33`).
  `prepare()` is the **synchronous** variant — fine for a small local WAV,
  would jank on large/remote sources.
- Callbacks fire on **MediaPlayer's internal thread**, not the main thread
  (`AudioPlayer.kt:9`) — callers must post to main before touching UI/state
  (the ViewModel handles this).
- `stop()` tolerates already-stopped state via a caught
  `IllegalStateException` and always `release()`s (`AudioPlayer.kt:35-43`).

Known limits (accepted for Chunks 0–2, relevant to Chunk 3/4 planning):

- **File-only**: `MediaPlayer` needs a complete, valid container file. It
  cannot play a raw PCM stream as it arrives. Chunk 4 real-time output (and
  probably Chunk 3 TTS audio if streamed) needs `AudioTrack`, which accepts
  raw PCM buffers directly — this rejection/deferral is recorded in
  `specs/002-voice-capture-playback/research.md:37`.
- **Header-dependent**: a zeroed header (see §3) fails here first.
- No seek/pause surface is exposed; play-to-completion or stop.

## 9. Chunk 4 (real-time relay): what changes, and VAD theory

Status 2026-07-13: **NOT started.** Everything in this section is design
theory + repo mandates, not shipped behavior. Open task anchors:
`specs/002-voice-capture-playback/tasks.md:49-52` (T013 VAD, T014 streaming
capture), `specs/003-gujarati-stt/tasks.md:49-51` (T013 streaming
recognition, T014 VAD gating).

**What changes structurally.** Today's loop does `read → write-to-file`. The
streaming version keeps the identical `AudioRecord` setup and read loop but
hands each `ByteArray` frame to a live consumer (network stream / VAD /
ring buffer) instead of a `FileOutputStream`. The format stays PCM
16-bit/16 kHz/mono (PATTERNS.md:23), so no capture-side rework. On the STT
side, single-shot `speech:recognize` is replaced by a streaming API
(WebSocket/gRPC) per GEMINI.md's latency guidance (GEMINI.md:42-43) and the
Streaming-First pattern (PATTERNS.md:21). Playback of incoming relay audio
moves from `MediaPlayer` to `AudioTrack` (§8).

**VAD gating — why it is mandatory.** PATTERNS.md:22: *"Voice Activity
Detection must gate STT calls to prevent sending silence to paid APIs. The
VAD threshold, frame size, and silence timeout must be documented in this
file when set."* Today silence IS uploaded (accepted for Chunk 1 because the
user explicitly taps record/transcribe and the free tier absorbs it —
rationale at `specs/003-gujarati-stt/plan.md:103`). In an always-listening
relay, un-gated audio would stream silence to a paid API continuously —
unacceptable.

**The three VAD parameters a junior must understand** (none are set yet; when
you set them, PATTERNS.md §2 REQUIRES writing the chosen values into
PATTERNS.md — go through change control, see
`voicebridge-change-control`):

1. **Frame size** — how much audio you classify at once. Speech VADs use
   10–30 ms frames; at our format 20 ms = 320 samples = 640 bytes (§7).
   Smaller frames = faster speech-onset detection but noisier decisions.
   Frame size must divide evenly into your read-buffer handling.
2. **Energy threshold** — the simplest VAD computes per-frame energy (RMS of
   the 320 signed 16-bit samples) and calls the frame "speech" above a
   threshold. A fixed threshold breaks across rooms/mics; practical designs
   use an adaptive noise floor or a trained VAD (e.g. WebRTC VAD-class
   models). Whatever is chosen, the threshold value/mechanism gets
   documented in PATTERNS.md.
3. **Silence timeout (hangover)** — how many consecutive non-speech frames
   before you declare end-of-utterance and close the STT stream segment. Too
   short chops words mid-sentence (Gujarati pauses between clauses are
   normal speech!); too long wastes paid streaming seconds and adds latency
   before translation fires. Typical starting range: 500–1000 ms
   (25–50 twenty-ms frames) — tune with real grandparent speech, not test
   tones.

Also mandated when Chunk 4 lands: per-hop latency budget rows in
`Project_Structure.md` (PATTERNS.md:24 — none exist today), and any new
STT/TTS implementation goes behind the provider interfaces named in the
Pipeline Stage Registry (`Project_Structure.md:50-58`). Note the registry
names `STTProvider`/`TranslationProvider` but **no such interfaces exist in
code yet** — extraction is open work (`specs/003-gujarati-stt/tasks.md`
T012), not something to assume compiles.

## 10. When NOT to use this skill

| You are trying to… | Use instead |
|---|---|
| Debug GCP request/response bodies, API keys, quotas, error codes | `voicebridge-gcp-speech-apis-reference` |
| Set up JDK/SDK/emulator, fix Gradle/AGP build failures | `voicebridge-build-and-env` |
| Cut a version branch, run/repair the smoke test, release | `voicebridge-release-gate-runbook` |
| Follow the general crash/bug triage procedure | `voicebridge-debugging-playbook` |
| Change governed docs (PATTERNS.md, Project_Structure.md, CHANGELOG.md) | `voicebridge-change-control` |
| Understand module boundaries / provider-seam architecture | `voicebridge-architecture-contract` |
| Learn from past incidents (v0.0.5 manual merge, hook -Build fix) | `voicebridge-failure-archaeology` |
| Flags, local.properties, BuildConfig plumbing | `voicebridge-config-and-flags` |
| Plan or execute Chunk 3 voice-clone TTS work | `voicebridge-chunk3-voice-clone-tts-campaign` |
| adb/logcat/screenshot tooling details | `voicebridge-diagnostics-and-tooling` |
| Write tests / QA an audio change | `voicebridge-validation-and-qa` |
| Update docs/specs prose | `voicebridge-docs-and-writing` |
| Evaluate new/experimental audio tech | `voicebridge-research-frontier` |

## Provenance and maintenance

Authored 2026-07-13 by skill-distill (retiring-fellow handover). All line
numbers cite the committed sources as of that date. Chunk 3/4 status
("NOT started") and the absence of provider interfaces / latency-budget rows
are 2026-07-13 facts — re-verify before relying on them.

Re-verification one-liners (PowerShell, from the repo root):

```powershell
# Header builder + stop() rule still intact (expect lines ~85, 97)
Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\AudioRecorder.kt -Pattern "Do NOT cancel|buildWavHeader"
# Format constants unchanged (expect SAMPLE_RATE 16_000, WAV_HEADER_SIZE 44)
Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\AudioRecorder.kt -Pattern "SAMPLE_RATE|WAV_HEADER_SIZE"
# Header strip + NO_WRAP still in SttService (expect WAV_HEADER_BYTES = 44, Base64.NO_WRAP)
Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\SttService.kt -Pattern "WAV_HEADER_BYTES|NO_WRAP|LINEAR16"
# VAD mandate wording in the pattern registry (expect §2 line about threshold/frame/timeout)
Select-String -Path PATTERNS.md -Pattern "VAD Gating"
# Chunk 4 still unstarted? (open [ ] streaming/VAD tasks should still exist)
Select-String -Path specs\002-voice-capture-playback\tasks.md,specs\003-gujarati-stt\tasks.md -Pattern "^\- \[ \] T01[34]"
# Provider interfaces still unextracted? (expect NO hits in app sources)
Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\*.kt -Pattern "interface STTProvider|interface TranslationProvider"
```
