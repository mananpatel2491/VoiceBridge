---
name: voicebridge-diagnostics-and-tooling
description: >-
  Measurement and evidence-collection toolkit for the VoiceBridge Android app
  (Kotlin/Compose, repo VoiceBridge). Load this skill whenever you need to
  MEASURE instead of eyeball: inspect a recorded WAV file's header against the
  16 kHz / 16-bit / mono contract, diagnose the "header never written" or
  zero-data-chunk failure modes, collect one-shot ADB evidence (devices, app
  version, logcat, crash scan, screenshot, UI hierarchy), pull the app's
  recording.wav off the device or
  emulator, read a uiautomator dump to debug smoke-test selectors, or time an
  STT/translation round-trip and produce latency numbers (including the future
  Chunk 4 latency-budget rows). Do NOT load this skill for running the release
  gate itself (voicebridge-release-gate-runbook), fixing build/JDK/SDK problems
  (voicebridge-build-and-env), interpreting GCP API errors
  (voicebridge-gcp-speech-apis-reference), or root-causing a specific bug
  end-to-end (voicebridge-debugging-playbook) — this skill supplies the
  instruments those workflows consume.
---

# VoiceBridge Diagnostics and Tooling

Purpose: replace "it looks fine" with numbers and artifacts. Every claim about
audio, app state, or latency in this repo should be backed by one of the tools
below.

Jargon used once, defined once:

| Term | Meaning |
|---|---|
| ADB | Android Debug Bridge, `C:\Android\platform-tools\adb.exe` — CLI to a device/emulator |
| logcat | The Android system-wide log stream, read via `adb logcat` |
| dumpsys | ADB command that dumps live system-service state (packages, activities) |
| uiautomator dump | ADB command that snapshots the current screen's widget tree as XML |
| AVD | Android Virtual Device (emulator image); this repo's is named `voicebridge_avd` |
| PCM / LINEAR16 | Raw uncompressed audio samples; GCP STT's name for 16-bit PCM |
| WAV header | The 44-byte prefix that declares sample rate / channels / bit depth / data size |
| Round-trip | Wall-clock time from user action to result rendered (includes network) |

Repo audio contract (PATTERNS.md, "Audio Format Contract"): PCM 16-bit,
16 kHz, mono. Writer: `android/app/src/main/java/com/mananpatel/voicebridge/AudioRecorder.kt:97`
(`buildWavHeader`). Consumer strips the 44-byte header before GCP upload
(`SttService.kt:45`).

## Which tool for which question

| Question | Tool |
|---|---|
| "Is this WAV actually 16 kHz / 16-bit / mono? How long is it? Is the data chunk empty?" | `.claude/skills/voicebridge-diagnostics-and-tooling/scripts/inspect_wav.py` |
| "What state is the device/app in right now? Did it crash? What's on screen?" | `.claude/skills/voicebridge-diagnostics-and-tooling/scripts/grab_diag.ps1` |
| "Why can't the smoke test find button X?" | uiautomator dump reading (below) |
| "How long does Transcribe/Translate actually take?" | Round-trip timing recipe (below) |
| "What P50/P95 rows do I write for a Chunk 4 pipeline hop?" | Latency-budget recipe (below) |

Both scripts live in this skill's `scripts/` folder and are read-only: they
never mutate the repo, git state, or the device beyond writing their own
output files.

## 1. inspect_wav.py — WAV header inspector

```powershell
python .claude/skills/voicebridge-diagnostics-and-tooling/scripts/inspect_wav.py recording.wav
python .claude/skills/voicebridge-diagnostics-and-tooling/scripts/inspect_wav.py recording.wav --json
```

Pure stdlib (tested on Python 3.13, 2026-07-13). Parses the canonical 44-byte
layout `buildWavHeader` writes (RIFF size, fmt chunk, channels, sample rate,
byte rate, block align, bits per sample, data size) and prints a computed
duration. Exit codes: `0` = valid and contract-clean, `1` = contract or
consistency violations (listed), `2` = not readable as a VoiceBridge WAV.

Failure modes it names explicitly:

- **Header-not-written** (exit 2): first 44 bytes all zero. `AudioRecorder.start`
  reserves 44 zero bytes (`AudioRecorder.kt:66`) and only back-fills the real
  header after the recording coroutine drains (`AudioRecorder.kt:76`,
  `writeWavHeader`). If the app dies mid-recording, the placeholder survives.
  The PCM after byte 44 is usually still salvageable.
- **Zero-size data chunk** (exit 1): valid header, `data_size=0` — the mic
  produced nothing or Stop fired instantly.
- **Contract violations** (exit 1): wrong sample rate / bit depth / channel
  count, plus internal consistency checks (byte_rate math, riff_size vs
  data_size, declared vs actual PCM byte count — catches truncated pulls).

It intentionally does NOT walk arbitrary RIFF chunk orders; a WAV with
LIST/INFO chunks before `data` is reported as "non-canonical layout" because
VoiceBridge's recorder never produces one — if you see that, the file did not
come from this app.

## 2. grab_diag.ps1 — one-shot ADB evidence collector

```powershell
powershell -ExecutionPolicy Bypass -File .claude/skills/voicebridge-diagnostics-and-tooling/scripts/grab_diag.ps1
# non-default SDK path or output folder:
powershell -ExecutionPolicy Bypass -File .claude/skills/voicebridge-diagnostics-and-tooling/scripts/grab_diag.ps1 -AndroidHome C:\Android -OutDir C:\temp\diag1
```

Writes a timestamped folder (default `android/app/build/diag-<timestamp>/`,
gitignored via the `build/` rule in `android/.gitignore`) containing:

| File | Content |
|---|---|
| `devices.txt` | `adb devices -l` output |
| `dumpsys-package.txt` | Full package dump; versionName/versionCode echoed to console |
| `foreground-activity.txt` | `topResumedActivity` line — is the app actually foreground? |
| `logcat-full.txt` | Last 1500 lines (`-LogLines` to change), `-v time` |
| `logcat-app.txt` | Same window filtered to the app's pid (empty note if app not running) |
| `logcat-crashes.txt` | Lines matching `FATAL EXCEPTION|E AndroidRuntime` — the exact crash-gate patterns from `android/scripts/smoke-test.ps1:348` |
| `screenshot.png` | `screencap -p`, pulled |
| `ui.xml` | uiautomator dump for selector debugging |

Exits 2 with a boot hint if no device is online (verified behavior
2026-07-13). Boot the emulator with:

```powershell
& C:\Android\emulator\emulator.exe -avd voicebridge_avd -no-snapshot-load -no-boot-anim
```

Version-number caveat (volatile, 2026-07-13): `dumpsys` reports the Gradle
`versionName`, which is `0.0.4` (`android/app/build.gradle.kts:23`) even
though the repo docs are at v0.0.7 — releases v0.0.5–v0.0.7 changed docs/specs
only and did not bump the app's versionName. Do not treat versionName as the
repo version; check `CHANGELOG.md` for that.

Why PowerShell, when PATTERNS.md says maintenance scripts are Python?
ADB/emulator driving on this Windows machine is the established exception —
`android/scripts/smoke-test.ps1` is the precedent this collector mirrors.
Keep it **ASCII-only**: Windows PowerShell 5.1 reads `.ps1` files as ANSI and
non-ASCII characters break parsing (documented at `smoke-test.ps1:28`; this
script was parser-checked and byte-scanned before shipping).

## 3. Pulling the recorded WAV off the device

The app writes to **internal** app storage, not external:
`MainActivity.kt:26` — `File(filesDir, "recording.wav")`, i.e.
`/data/data/com.mananpatel.voicebridge/files/recording.wav`. There is no
`getExternalFilesDir` usage anywhere in the app (verified 2026-07-13), so a
plain `adb pull` of that path fails with permission denied. Because debug
builds are debuggable, `run-as` works:

```powershell
# Step 1: copy out of the app sandbox to shared storage (inside the device)
adb shell "run-as com.mananpatel.voicebridge cat files/recording.wav > /sdcard/recording.wav"
# Step 2: pull to the PC, then clean up
adb pull /sdcard/recording.wav recording.wav
adb shell rm /sdcard/recording.wav
# Step 3: never trust it by eye
python .claude/skills/voicebridge-diagnostics-and-tooling/scripts/inspect_wav.py recording.wav
```

Trap: do NOT use `adb exec-out run-as ... cat files/recording.wav > recording.wav`
from PowerShell 5.1 — PowerShell's `>` re-encodes native stdout as text and
corrupts binary data. The two-step `/sdcard` route above is byte-safe. (If you
must one-line it, wrap in cmd: `cmd /c "adb exec-out ... > recording.wav"`.)

Note: the repo root `.gitignore` ignores `*.wav`, so a pulled recording inside
the repo cannot be committed by accident.

## 4. Reading a uiautomator dump (selector debugging)

The smoke test resolves every tap from a live dump by `@text` or
`@content-desc`, never pixels (`smoke-test.ps1:79-117`). When it reports
"could not find UI element", diagnose with the dump `grab_diag.ps1` already
pulled (`ui.xml`), or manually:

```powershell
adb shell uiautomator dump /sdcard/ui.xml
adb pull /sdcard/ui.xml .
```

What to look for in the XML:

- Every widget is a `<node>` with attributes. Compose `Text("Record")` inside
  a Button surfaces as `text="Record"`; the transcript field is found by
  `content-desc="transcript-field"` (set via semantics at `MainActivity.kt:160`).
- `bounds="[x1,y1][x2,y2]"` — tap target center is `((x1+x2)/2, (y1+y2)/2)`;
  that is exactly how `Get-Center` computes taps (`smoke-test.ps1:101`).
- `enabled="true|false"` — Compose Material3 propagates the `enabled` flag to
  the accessibility node, so button state IS testable from the dump
  (`smoke-test.ps1:130-140`).
- Common failure causes: button label renamed in `MainActivity.kt` without
  updating the selector (the script headers say KEEP IN SYNC); an ANR dialog
  covering the app (the smoke test auto-dismisses "isn't responding" dialogs,
  `smoke-test.ps1:85`); dump taken while a `CircularProgressIndicator` swap
  changed the button text (e.g. "Transcribing..." instead of
  "Transcribe (Gujarati)" — see `MainActivity.kt:138-148`; match with
  `contains(@text,'Transcribe')` like the smoke test does).

Quick grep of a dump for a label:

```powershell
Select-String -Path ui.xml -Pattern 'text="[^"]*Transcribe[^"]*"'
```

## 5. Timing an STT / translation round-trip

Ground truth first (verified by grep 2026-07-13): the app sources contain
**zero `android.util.Log` calls**, so logcat carries no app-emitted timing
lines today. You have two honest options:

**Option A — no code change (coarse, ~1 s resolution).** The ViewModel drives
observable status text: `"Sending to GCP Speech-to-Text..."` ->
`"Transcription complete."` / `"Transcription failed."`
(`MainViewModel.kt:86,96,105`) and `"Sending to GCP Cloud Translation..."` ->
`"Translation complete."` / `"Translation failed."`
(`MainViewModel.kt:127,137,146`). Tap the button via adb, start a stopwatch,
poll dumps until the terminal status appears:

```powershell
$adb = "C:\Android\platform-tools\adb.exe"
# Get the Transcribe button center from a fresh ui.xml first (section 4), then:
& $adb shell input tap <x> <y>
$sw = [System.Diagnostics.Stopwatch]::StartNew()
do {
    & $adb shell uiautomator dump /sdcard/t.xml 2>$null | Out-Null
    & $adb pull /sdcard/t.xml "$env:TEMP\t.xml" 2>$null | Out-Null
    $done = Select-String -Path "$env:TEMP\t.xml" -Pattern "Transcription complete\.|Transcription failed\." -Quiet
} until ($done -or $sw.Elapsed.TotalSeconds -gt 60)
"round-trip <= $([int]$sw.Elapsed.TotalMilliseconds) ms (upper bound; includes ~0.5-1.5s dump overhead per poll)"
```

Report Option A numbers as upper bounds, never as budget rows.

**Option B — instrumented logcat (precise; requires a code change).** Status
as of 2026-07-13: NOT in the code — adding it is a candidate change that must
ride a normal `vX.Y.Z` branch through change control
(voicebridge-change-control). The pattern: emit one tagged line at request
start and one at completion, e.g.
`Log.i("VBTiming", "stt_start ${SystemClock.elapsedRealtime()}")` in
`MainViewModel.transcribe` and the matching `stt_done` in the `fold` callbacks.
Then measure without any UI polling:

```powershell
adb logcat -c
# ... exercise the app ...
adb logcat -d -v epoch -s VBTiming
# -v epoch prints seconds-with-ms timestamps; round-trip = done - start.
```

`-v epoch` timestamps come from the device clock and are subtraction-safe;
`SystemClock.elapsedRealtime()` values embedded in the message are immune to
clock changes — either works, embedded values are cleaner.

## 6. Latency-budget recipe (Chunk 4 prep)

PATTERNS.md ("Latency Budget Tracking") requires expected P50/P95 per pipeline
hop in `Project_Structure.md` when a stage is added. As of 2026-07-13 no such
rows exist — this is a known open gap, and Chunk 4 (real-time two-phone relay)
cannot be tuned without them. When that work starts:

1. Instrument each hop boundary with Option B tagged logs (one tag per hop:
   record->stt, stt->translate, translate->tts, tts->playout).
2. Collect **N >= 20 trials per hop** on the real network path (emulator +
   home Wi-Fi at minimum; a corp proxy like Netskope adds latency that must be
   excluded from budgets).
3. Compute P50/P95 = 50th/95th percentile of the N samples (sort ascending;
   P95 with N=20 is the 19th value). Do not report means — tail latency is
   what the user feels on a live call.
4. Add the rows to `Project_Structure.md` via change control, citing the
   measurement date, N, device, and network in the row.
5. Re-measure whenever a provider, region, or codec changes; budgets are
   measurements, not aspirations.

Reference point for intuition (measure, don't assume): a Chunk 1 STT
round-trip is bounded by OkHttp timeouts of 30 s connect / 60 s read
(`SttService.kt:32-33`); translation uses 30 s / 30 s
(`TranslationService.kt:17-18`). Anything approaching those numbers is a
failure, not latency.

## When NOT to use this skill

| You actually want to... | Use instead |
|---|---|
| Run/repair the smoke test, hook, auto-merge release flow | voicebridge-release-gate-runbook |
| Fix Gradle/JDK/SDK/emulator install or build breakage | voicebridge-build-and-env |
| Root-cause a specific bug end-to-end (this skill only supplies the instruments) | voicebridge-debugging-playbook |
| Understand GCP STT/Translation request shapes, errors, quotas | voicebridge-gcp-speech-apis-reference |
| Understand the WAV/PCM pipeline design itself (recorder/player/services) | voicebridge-audio-pipeline-reference |
| API keys, local.properties, BuildConfig flags | voicebridge-config-and-flags |
| Branching, CHANGELOG signal, what may/may not be committed | voicebridge-change-control |
| Architecture map, module contracts, changelog table rules | voicebridge-architecture-contract |
| Past incidents and their lessons (e.g. the v0.0.5 manual merge) | voicebridge-failure-archaeology |
| Add tests/QA coverage beyond the smoke test | voicebridge-validation-and-qa |
| Write docs, specs, changelog entries | voicebridge-docs-and-writing |
| Build Chunk 3 voice-clone TTS | voicebridge-chunk3-voice-clone-tts-campaign |
| Evaluate new/unproven tech directions | voicebridge-research-frontier |

Never use these tools to route around change control: `grab_diag.ps1` and
`inspect_wav.py` observe; they must never be extended to mutate git state,
merge, or push. The only sanctioned commit-gate exception in this repo is the
exact Bruno acknowledgment string in PATTERNS.md.

## Provenance and maintenance

Authored 2026-07-13 by skill-distill. Both scripts were tested before
shipping: `inspect_wav.py` against four generated fixtures (valid contract
WAV, all-zero header, 44.1 kHz stereo, zero-size data chunk — exit codes
0/2/1/1 confirmed on Python 3.13.2); `grab_diag.ps1` passed
`[System.Management.Automation.Language.Parser]::ParseFile` with zero errors,
a zero-non-ASCII byte scan, and a live no-device run (clean exit 2 + hint).

Re-verify volatile facts before trusting them:

| Claim | One-line re-check |
|---|---|
| Recording path is internal `filesDir/recording.wav` | `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\MainActivity.kt -Pattern "recording.wav"` |
| App still has no Log calls (Option A vs B in section 5) | `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\*.kt -Pattern "android.util.Log", "Log\.i", "Log\.d"` |
| Crash-gate patterns unchanged | `Select-String -Path android\scripts\smoke-test.ps1 -Pattern "FATAL EXCEPTION"` |
| Status-message strings unchanged (section 5 selectors) | `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\MainViewModel.kt -Pattern "Sending to GCP|complete\."` |
| versionName still lags repo version | `Select-String -Path android\app\build.gradle.kts -Pattern "versionName"` |
| Audio contract constants (16000/16-bit/mono) | `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\AudioRecorder.kt -Pattern "SAMPLE_RATE|ENCODING_PCM|CHANNEL_IN"` |
| Latency-budget rows still missing from Project_Structure.md | `Select-String -Path Project_Structure.md -Pattern "P50|P95|latency"` |
