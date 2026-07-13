---
name: voicebridge-debugging-playbook
description: >-
  Symptom-to-fix triage playbook for VoiceBridge's real failure modes: Gradle/AGP/JDK
  build failures, smoke-test failures (selector drift, emulator/AVD,
  ANR/permission dialogs, silent Python skip), verify_structure.py
  CRITICAL changelog errors, GCP STT and Translation runtime errors (blank key, 403,
  empty recording, "no speech detected"), silent/corrupt WAV playback, and app-crash
  triage via logcat. Load this skill whenever something in VoiceBridge is FAILING and
  you need to find out why: a red smoke test, a build error, an error card in the app,
  a CRITICAL from verify_structure.py, silent audio, or a crash. Do NOT load it for
  fresh-machine setup (voicebridge-build-and-env), running a release/merge
  (voicebridge-release-gate-runbook), architecture (voicebridge-architecture-contract),
  API/audio format reference (voicebridge-gcp-speech-apis-reference,
  voicebridge-audio-pipeline-reference), change-control policy
  (voicebridge-change-control), or past incidents (voicebridge-failure-archaeology).
---

# VoiceBridge Debugging Playbook

Symptom -> cause -> discriminating check -> fix, for every failure mode this repo has
actually produced or is structurally prone to. Every claim below is grounded in the
code as of 2026-07-13; citations are `path:line`.

**Conventions used throughout:**

- All commands are Windows PowerShell, run from the repo root
  (`C:\Docs\Build\mananUtils\VoiceBridge`) unless stated otherwise.
- `adb` = `C:\Android\platform-tools\adb.exe` (Android Debug Bridge — the CLI that talks
  to the emulator/device).
- **Smoke test** = `android/scripts/smoke-test.ps1`: builds (with `-Build`), installs the
  APK on the emulator, drives the UI via UIAutomator text selectors, screenshots each
  step, and scans logcat for crashes. It is the release gate.
- **UIAutomator dump** = an XML snapshot of the on-screen accessibility tree
  (`adb shell uiautomator dump`); the smoke test finds buttons in it by `@text` /
  `@content-desc`, never by pixel coordinates.
- **AVD** = Android Virtual Device (the emulator image). This repo's AVD is named
  `voicebridge_avd` (smoke-test.ps1:50).
- **ANR** = "Application Not Responding" — the Android system dialog ("isn't responding" /
  "keeps stopping") that can appear on a cold-booted emulator.
- **logcat** = the Android system log stream (`adb logcat`).

**First move for any failure:** identify which of the 7 sections below matches your
symptom, run that section's discriminating check, then apply the fix. Do not guess.

---

## Quick triage index

| You see... | Go to |
|---|---|
| `gradlew.bat assembleDebug` fails before compiling anything | 1. Build failures |
| `[smoke] FAIL: ...` lines / smoke test exits 1 | 2. Smoke-test failures |
| `CRITICAL: The following N files are missing from Project_Structure.md` | 3. verify_structure.py |
| Red error card in app after tapping **Transcribe (Gujarati)** | 4. STT errors |
| Red error card in app after tapping **Translate (English)** | 5. Translation errors |
| Playback silent, `MediaPlayer error`, or `(No speech detected)` on real speech | 6. Audio problems |
| App closes itself / "keeps stopping" / smoke test reports logcat crash | 7. Crash triage |

---

## 1. Build failures

Build command (exactly what the smoke test runs, smoke-test.ps1:178):

```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"
& .\android\gradlew.bat -p android assembleDebug --console=plain
```

### 1a. JDK missing or wrong (JAVA_HOME)

- **Symptom:** build aborts immediately with
  `ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.`
  (gradlew.bat:49) or
  `ERROR: JAVA_HOME is set to an invalid directory: <path>` (gradlew.bat:63).
  A too-old JDK instead fails later with class-file / toolchain version errors
  (the project targets Java 17 — android/app/build.gradle.kts:40-41).
- **Likely causes (ranked):** 1) `JAVA_HOME` not set in this shell (the smoke test sets
  it internally at smoke-test.ps1:68, so manual runs are the ones that forget); 2) it
  points at a JDK other than 17.
- **Discriminating check:**
  ```powershell
  $env:JAVA_HOME
  & "$env:JAVA_HOME\bin\java.exe" -version
  ```
  Expect `openjdk version "17...`. This machine's JDK 17 lives at
  `C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot` (the smoke test's default,
  smoke-test.ps1:51).
- **Fix:** set `$env:JAVA_HOME` to that path (per shell), or just run builds through the
  smoke test, which parameterizes it (`-JavaHome`).

### 1b. `sdk.dir` missing (no local.properties)

- **Symptom:** Gradle configuration fails with an AGP error saying the SDK location was
  not found / `sdk.dir` is not defined (AGP tells you to set `sdk.dir` in
  `local.properties` or `ANDROID_HOME`).
- **Likely cause:** `android/local.properties` does not exist — it is gitignored (the
  smoke test *asserts* it is untracked, smoke-test.ps1:156-158), so every fresh clone
  lacks it.
- **Discriminating check:**
  ```powershell
  Test-Path .\android\local.properties
  Get-Content .\android\local.properties -ErrorAction SilentlyContinue
  ```
- **Fix:** copy the template and keep the backslash escaping exactly as shown
  (android/local.properties.template:6):
  ```powershell
  Copy-Item .\android\local.properties.template .\android\local.properties
  ```
  Then ensure it contains `sdk.dir=C\:\\Android` (this machine's SDK root,
  smoke-test.ps1:52). `GCP_STT_API_KEY` can stay blank for build-only work — the app
  compiles with `""` and surfaces a runtime error card instead (android/app/build.gradle.kts:27-31).

### 1c. Gradle / AGP / Kotlin plugin mismatch — the AGP 9 built-in-Kotlin friction

Background: Gradle 9.3.1 wrapper is COMMITTED (android/gradle/wrapper/gradle-wrapper.properties:
`gradle-9.3.1-bin.zip`), AGP is 9.1.1, Kotlin 2.0.21. AGP 9 ships **built-in Kotlin
support**, which conflicts with also applying the standalone `org.jetbrains.kotlin.android`
plugin.

**VOLATILE (state as of 2026-07-13):** the *committed* config (branch `main`, HEAD
`80b756f`) still applies the standalone plugin — `git show HEAD:android/build.gradle.kts`
shows `id("org.jetbrains.kotlin.android") version "2.0.21" apply false` and
`git show HEAD:android/app/build.gradle.kts` applies it. The *working tree* has
**uncommitted** edits removing that plugin from both files (the AGP 9 built-in-Kotlin
migration). Do not treat either state as final; check before reasoning.

- **Symptom:** build fails during plugin application / configuration with a message
  naming `org.jetbrains.kotlin.android`, built-in Kotlin, or a Kotlin-plugin/AGP
  incompatibility — before any of your code compiles.
- **Likely causes (ranked):** 1) the working tree flipped between the two plugin states
  (e.g. a `git checkout`/`stash` restored the standalone plugin under AGP 9 settings, or
  vice versa); 2) someone bumped AGP or Kotlin versions in `android/build.gradle.kts`
  without checking the built-in-Kotlin story; 3) wrapper drift (someone regenerated the
  wrapper to another Gradle version).
- **Discriminating check:**
  ```powershell
  git -C . diff -- android/build.gradle.kts android/app/build.gradle.kts
  Select-String -Path .\android\build.gradle.kts -Pattern "kotlin"
  Select-String -Path .\android\gradle\wrapper\gradle-wrapper.properties -Pattern "distributionUrl"
  ```
  Uncommitted plugin-line deletions = you are in the mid-migration state described above.
- **Fix:** make the two files internally consistent — either both with the standalone
  plugin (committed state) or both without (migrated state) — and confirm with a clean
  `assembleDebug`. Do NOT commit the migration as a drive-by while debugging something
  else: any commit on a `vX.Y.Z` branch triggers the smoke test via the post-commit hook,
  and version bumps of build tooling are change-controlled
  (see voicebridge-change-control).

### 1d. APK exists but smoke test says it doesn't

- **Symptom:** `[smoke] APK not found at ...app-debug.apk -- run with -Build first.`
  (smoke-test.ps1:184).
- **Cause:** you ran `smoke-test.ps1` without `-Build` and no prior debug build exists at
  `android\app\build\outputs\apk\debug\app-debug.apk` (smoke-test.ps1:65).
- **Fix:** rerun with `-Build`.

---

## 2. Smoke-test failures

Run manually (never merges unless `-AutoMerge` is passed AND you are on a `vX.Y.Z`
branch — smoke-test.ps1:378-383):

```powershell
powershell -File android/scripts/smoke-test.ps1 -Build
```

Every failed run prints `FAIL:` lines and leaves per-step screenshots in
`android\app\build\smoke-<timestamp>\` (gitignored) — **open the screenshots first**;
they are the primary diagnostic artifact. The same folder also holds the last
`ui.xml` UIAutomator dump (smoke-test.ps1:81-82).

### 2a. Selector drift — "could not find UI element" / "button not found"

- **Symptom:** `FAIL: could not find UI element: <label> (<predicate>)`
  (smoke-test.ps1:114), `FAIL: button not found: '<text>'` (smoke-test.ps1:133), or
  `FAIL: not found: <label>` (smoke-test.ps1:122) — while the app is visibly running fine.
- **Likely causes (ranked):** 1) someone renamed a button/label in `MainActivity.kt`
  without updating the script — this is the explicit **KEEP IN SYNC** contract
  (smoke-test.ps1:26, :130, :225, :283, :311); 2) an ANR dialog is covering the app (see
  2c); 3) the app never launched (see 7).
- **The sync contract:** the authoritative selector<->source mapping is the
  KEEP-IN-SYNC contract table in voicebridge-release-gate-runbook section 3 —
  consult it there; do not maintain a copy here.

- **Discriminating check:** open the failing step's screenshot, then grep the saved dump:
  ```powershell
  Select-String -Path .\android\app\build\smoke-*\ui.xml -Pattern "Record|Stop|Play|Transcribe|English" | Select-Object -Last 10
  ```
  If the dump shows the app's UI but with different text than the selector -> selector
  drift. If the dump shows a system dialog or launcher -> not drift; see 2c / 7.
- **Fix:** update BOTH sides together (script selector + MainActivity.kt label) in the
  same commit. Never "fix" by loosening a selector to something that matches unrelated
  nodes.

### 2b. Emulator not booted / AVD missing

- **Symptom:** script hangs at `Booting AVD voicebridge_avd ...`, or proceeds after ~3
  minutes and every UI step fails; or the emulator window never appears.
- **How the script behaves:** if `adb devices` shows no `emulator-N  device` line it
  launches the AVD itself (smoke-test.ps1:189-193), then polls
  `sys.boot_completed` up to 60 times x 3 s (:195-199). **It does not fail if boot never
  completes** — it logs "Emulator ready" and marches on, so the *first* real error is
  usually a downstream install/UI failure.
- **Likely causes (ranked):** 1) AVD `voicebridge_avd` does not exist on this machine;
  2) emulator is booting slower than the ~3-minute budget (first cold boot);
  3) a stale offline emulator entry in adb.
- **Discriminating check:**
  ```powershell
  & C:\Android\emulator\emulator.exe -list-avds
  & C:\Android\platform-tools\adb.exe devices
  & C:\Android\platform-tools\adb.exe shell getprop sys.boot_completed
  ```
  Expect `voicebridge_avd` in the list, one `emulator-XXXX  device` line, and `1`.
- **Fix:** missing AVD -> create it (see voicebridge-build-and-env for the recipe) or
  pass an existing one: `powershell -File android/scripts/smoke-test.ps1 -AvdName <name>`.
  Slow boot -> pre-boot the emulator, wait for `sys.boot_completed` = `1`, rerun.
  Stale adb -> `adb kill-server; adb start-server`, rerun.

### 2c. Cold-boot ANR dialog

- **Symptom:** intermittent failures right after launch on a freshly booted emulator;
  screenshot shows an "isn't responding" or "keeps stopping" system dialog.
- **What the script already does:** `Get-Ui` (smoke-test.ps1:84-97) detects any node whose
  text contains `responding` or `keeps stopping`, logs
  `dismissing transient system ANR dialog (cold-boot jank)`, taps the dialog's **Wait**
  button if present, otherwise presses Back (`input keyevent 4`), then re-dumps.
- **When it still fails:** the dialog appeared *between* two dumps (a race), or the dialog
  is a real repeat-crash dialog ("keeps stopping" that returns immediately — that is a
  crash, go to section 7).
- **Discriminating check:** did the yellow "dismissing transient system ANR dialog" line
  appear more than once, and does logcat show `FATAL EXCEPTION`? (Command in section 7.)
  No crash + dialog only on first run after boot = jank; crash present = section 7.
- **Fix (jank case):** rerun the smoke test on the already-warm emulator. The script
  boots with `-no-snapshot-load` (:192), so first runs are always coldest.

### 2d. Permission dialog / `Record` unexpectedly disabled

- **Symptom:** `FAIL: button 'Record': expected enabled=True, got enabled=False`, or a
  screenshot showing the Android mic-permission dialog covering the app.
- **Why it should never happen:** the script grants mic permission programmatically
  before launch — `adb shell pm grant com.mananpatel.voicebridge
  android.permission.RECORD_AUDIO` (smoke-test.ps1:208) — precisely so the runtime dialog
  never blocks UI automation. This works because the debug build is `debuggable`.
  The Record button is gated on `permissionGranted` in MainActivity.kt:114, set by the
  in-app permission launcher (MainActivity.kt:51-60).
- **Likely causes (ranked):** 1) the `pm grant` silently failed (its stderr is discarded —
  the `Adb` wrapper appends `2>$null`, smoke-test.ps1:77) because the app wasn't
  installed yet or a non-debug APK was installed; 2) someone revoked the permission
  mid-run; 3) `AudioRecord` init failed (that surfaces as an error card
  "AudioRecord failed to initialize — verify RECORD_AUDIO permission is granted.",
  AudioRecorder.kt:56).
- **Discriminating check:**
  ```powershell
  & C:\Android\platform-tools\adb.exe shell dumpsys package com.mananpatel.voicebridge | Select-String "RECORD_AUDIO"
  ```
  Expect `android.permission.RECORD_AUDIO: granted=true`.
- **Fix:** reinstall the debug APK, rerun the grant manually, relaunch:
  ```powershell
  & C:\Android\platform-tools\adb.exe install -r .\android\app\build\outputs\apk\debug\app-debug.apk
  & C:\Android\platform-tools\adb.exe shell pm grant com.mananpatel.voicebridge android.permission.RECORD_AUDIO
  ```

### 2e. Python missing — verify_structure silently skipped

- **Symptom:** the smoke run prints a yellow
  `SKIP verify_structure.py (Python not on PATH)` (smoke-test.ps1:171) and PASSES —
  then a later machine/agent with Python fails on structure drift you introduced.
- **Cause:** the script looks for `python` then `python3` on PATH and skips the check if
  neither exists (smoke-test.ps1:164-171). A skip is NOT a pass.
- **Discriminating check:**
  ```powershell
  Get-Command python, python3 -ErrorAction SilentlyContinue
  ```
- **Fix:** put Python on PATH (see voicebridge-build-and-env), then run the check
  directly before trusting any green smoke run:
  ```powershell
  python .\scripts\verify_structure.py
  ```

---

## 3. verify_structure.py CRITICAL failures

`scripts/verify_structure.py` enforces GEMINI.md Lesson 1: every file addition/removal
must be logged in the Changelog table of `Project_Structure.md`.

- **Symptom (the only two failure outputs):**
  1. `CRITICAL: The following N files are missing from Project_Structure.md:` followed by
     ` - <repo-relative/posix/path>` lines, exit code 1 (verify_structure.py:81-84).
  2. `CRITICAL: Could not find Project_Structure.md in any parent directory.`
     (verify_structure.py:44) — you moved/deleted the anchor file or ran the script from
     a copied tree.
- **How to read failure 1:** each listed path is a real file on disk that has NO row in
  the `## Changelog` table naming it. The parser reads the table's 4th column
  (**Files Affected**, split on `|`, column index 3 — verify_structure.py:26-37), splits
  on commas, strips backticks, and compares posix-normalized relative paths.
- **What is exempt (never needs a row)**: see the exclusion list in
  voicebridge-docs-and-writing section 2.3, or read it live via
  `Select-String -Path scripts\verify_structure.py -Pattern "startswith|rel_path.parts"`.
- **Fix:** add ONE new row to the `## Changelog` table in `Project_Structure.md`
  (columns: `Date | Action | Files Affected | Summary`), listing every missing path
  backticked and comma-separated, exactly as printed (posix slashes). Example row shape
  (match the existing rows in the table):
  ```
  | 2026-07-13 | ADD | `android/app/src/main/java/com/mananpatel/voicebridge/NewFile.kt` | One-line description of why. |
  ```
  Then re-run `python .\scripts\verify_structure.py` and confirm
  `SUCCESS: All files are accounted for in the changelog.` Do NOT "fix" by deleting the
  file or adding new exclusions to the script — the changelog row is the contract.
  (Also update the architecture map section of `Project_Structure.md`; the script only
  checks the table, but the map is the human contract — see voicebridge-docs-and-writing.)

---

## 4. STT errors (Transcribe button)

Error path: `SttService.transcribe()` returns `Result.failure` ->
`MainViewModel.transcribe()` puts `e.message` into `errorMessage`
(MainViewModel.kt:100-108) -> MainActivity renders it as a red card prefixed `Error: `
(MainActivity.kt:93-106). Status line reads `Transcription failed.`

| Exact error text in the card | Cause | Fix |
|---|---|---|
| `GCP_STT_API_KEY is not set. See local.properties.template.` | Key blank at build time — this is checked *before* any network call (MainViewModel.kt:74-78) | Set `GCP_STT_API_KEY=<key>` in `android\local.properties`, then **rebuild and reinstall** — the key is baked in via `buildConfigField` (android/app/build.gradle.kts:27-31); editing the file without rebuilding changes nothing |
| `GCP STT error 403: <GCP message>` | Key is set but rejected: Speech-to-Text API not enabled on the GCP project, key restricted, or billing off (SttService.kt:68-76 surfaces the GCP `error.message`) | Read the embedded GCP message — it names the problem. Enable "Cloud Speech-to-Text API" in the key's GCP project; the ONE key covers both STT and Translation (same project, both APIs enabled) |
| `GCP STT error 400: <GCP message>` | Malformed audio/config reaching the API (should not happen with the stock recorder: LINEAR16, 16000 Hz, gu-IN — SttService.kt:48-57) | Verify the WAV per section 6; suspect local modifications to AudioRecorder/SttService |
| `Recording is empty or too short to transcribe.` | WAV file is <= 44 bytes, i.e. header only, no PCM data (SttService.kt:40-42) | Recording stopped instantly or mic produced nothing — see section 6 |
| *(no error; transcript shows `(No speech detected)`)* | API returned HTTP 200 with zero `results` — valid response, no recognized speech (SttService.kt:78-81; the UI substitutes the placeholder at MainViewModel.kt:95) | Not an error. If you DID speak Gujarati: check emulator mic routing (section 6a) and that you spoke during the recording window |

**Discriminating check (key state without touching GCP):** the smoke test's Transcribe
step already discriminates these outcomes (smoke-test.ps1:290-301): error card containing
`GCP_STT_API_KEY` = blank key; transcript card = key works; other error text = network/
auth. To check what key the *installed* APK was built with, check what's in
`local.properties` and whether the APK was rebuilt since:

```powershell
Select-String -Path .\android\local.properties -Pattern "GCP_STT_API_KEY"
Get-Item .\android\app\build\outputs\apk\debug\app-debug.apk | Select-Object LastWriteTime
```

**Network note:** on this corp machine, TLS interception can break emulator HTTPS —
if you get connection/cert errors instead of GCP errors, install the Netskope root CA
into the emulator (see voicebridge-build-and-env / voicebridge-diagnostics-and-tooling).

---

## 5. Translation errors (Translate (English) button)

Error path mirrors STT: `TranslationService.translate()` returns `Result.failure` ->
`MainViewModel.translate()` sets `errorMessage` + status `Translation failed.`
(MainViewModel.kt:141-149) -> same red `Error: ` card (MainActivity.kt:93-106).

| Exact error text in the card | Cause | Fix |
|---|---|---|
| `GCP_STT_API_KEY is not set in local.properties. The same key covers Cloud Translation -- enable 'Cloud Translation API' in the same GCP project you used for STT.` | Key blank — checked inside the service, before the network call (TranslationService.kt:24-30). Yes, the variable is named `GCP_STT_API_KEY` even for translation; there is deliberately only one key | Same as STT blank-key fix: set key, rebuild, reinstall |
| `Translation API error 403: <GCP message>` | Key set but **Cloud Translation API** not enabled on the project (STT working proves the key itself is fine — this is the discriminator), or key API-restricted to STT only (TranslationService.kt:48-55) | Enable "Cloud Translation API" in the same GCP project; if the key has API restrictions, add Translation to the allowed list |
| `Empty response body from Cloud Translation API.` | Transport-level anomaly (TranslationService.kt:45-46) | Retry; then check emulator network / corp CA (section 4 network note) |
| *(button does nothing)* | Not a bug: `translate()` returns silently when the transcript is blank (MainViewModel.kt:120-121), and the button is disabled until `state.transcript.isNotBlank()` (MainActivity.kt:170) | Type or transcribe some text first. The transcript field is editable exactly so translation can be tested without STT (MainActivity.kt:153-163) |

**Discriminating check (STT vs Translation API enablement):** run Transcribe first. If
Transcribe returns a transcript but Translate returns `Translation API error 403`, the
key is valid and ONLY the Translation API is missing/disabled — a GCP console fix, not a
code fix.

---

## 6. Audio problems (silent playback, corrupt WAV)

The contract: `AudioRecorder` writes PCM 16-bit, 16 kHz, mono WAV with a 44-byte header
(AudioRecorder.kt:29-33). It reserves 44 zero bytes first (AudioRecorder.kt:66), streams
PCM behind them, and only after the write loop exits and the file closes does it seek
back and overwrite the placeholder with a real RIFF header (AudioRecorder.kt:75-76,
:88-95). The recording lives at the app-private path
`/data/data/com.mananpatel.voicebridge/files/recording.wav` (MainActivity.kt:26).

**Load-bearing subtlety — do not "fix" this:** `AudioRecorder.stop()` deliberately does
NOT cancel `recordingJob` (AudioRecorder.kt:80-86; the comment at :85 says exactly this).
It only flips `isRecording = false` and releases the `AudioRecord`; the coroutine's
`while` loop (AudioRecorder.kt:69) then exits on its own, the `FileOutputStream` closes,
and `writeWavHeader()` runs. If anyone adds `recordingJob?.cancel()` to `stop()` — a
very tempting "cleanup" — the header write can be killed and the file keeps its 44 zero
bytes: unplayable, and any tool reading the header sees garbage.

### 6a. Playback is silent (no error card)

- **Likely causes (ranked):** 1) the recording itself is silence — emulator mic not
  routed to the host mic, or host mic muted (most common on a fresh AVD); 2) emulator
  media volume at zero; 3) recording window too short to catch speech.
- **Discriminating check — is there real signal in the file?** Pull it (works on debug
  builds via `run-as`) and look at the size and bytes. WARNING: never redirect adb
  binary output with `>` in PowerShell 5.1 — it re-encodes native stdout as UTF-16 text
  and corrupts the bytes (see voicebridge-diagnostics-and-tooling section 3); the 6b
  RIFF check is only valid on a file pulled via this byte-safe two-step route:
  ```powershell
  & C:\Android\platform-tools\adb.exe shell "run-as com.mananpatel.voicebridge cat files/recording.wav > /sdcard/recording.wav"
  & C:\Android\platform-tools\adb.exe pull /sdcard/recording.wav $env:TEMP\recording.wav
  & C:\Android\platform-tools\adb.exe shell rm /sdcard/recording.wav
  (Get-Item $env:TEMP\recording.wav).Length
  ```
  Length 44 = no PCM at all (see 4: "empty or too short"). Length large but silent =
  play the pulled file on the host (any media player). Silent on host too -> the mic
  input is the problem, not playback.
- **Fix:** enable host mic in emulator settings (Extended controls > Microphone >
  "Virtual microphone uses host audio input"), unmute host mic, raise emulator media
  volume (`adb shell input keyevent 24` presses volume-up), re-record.

### 6b. `MediaPlayer error (what=..., extra=...)` or exception message on Play

- **Where it comes from:** `AudioPlayer` surfaces async errors via `onError`
  (AudioPlayer.kt:21-24) and `prepare()`/`setDataSource` exceptions via the catch
  (AudioPlayer.kt:27-31); MainViewModel shows them in the error card with status
  `Playback error.` (MainViewModel.kt:66-68).
- **Likely causes (ranked):** 1) corrupt/placeholder header (see the stop() subtlety
  above — check first if AudioRecorder was recently modified); 2) Play tapped before the
  header-write coroutine finished (a race: `stopRecording()` flips UI state immediately,
  MainViewModel.kt:49-58, while the header is written on Dispatchers.IO — normally
  finishes in milliseconds, but a tap within that window reads a header-less file);
  3) file missing (first launch, nothing recorded — but the Play button is disabled
  until `hasRecording`, MainActivity.kt:125).
- **Discriminating check — inspect the header magic:** pull the file (command in 6a),
  then:
  ```powershell
  $b = Get-Content $env:TEMP\recording.wav -Encoding Byte -TotalCount 4
  [System.Text.Encoding]::ASCII.GetString($b)
  ```
  Expect `RIFF`. If the header check fails, FIRST re-pull via the byte-safe route in 6a
  — a `>` redirect of `adb exec-out` in PowerShell 5.1 corrupts binary and fakes this
  exact symptom (see voicebridge-diagnostics-and-tooling section 3). Four zero bytes on
  a byte-safe pull = the placeholder was never overwritten -> the header
  write was killed or never ran: diff `AudioRecorder.kt` against `main`
  (`git diff main -- android/app/src/main/java/com/mananpatel/voicebridge/AudioRecorder.kt`)
  and look for a `cancel()` added to `stop()` or the loop.
- **Fix:** restore the no-cancel contract in `stop()`; for the race, re-record and wait
  a beat before Play (a proper fix — awaiting the job before enabling Play — is an OPEN
  improvement, not shipped as of 2026-07-13).

---

## 7. App crash triage (the logcat crash gate)

The smoke test fails ANY run where logcat contains `FATAL EXCEPTION` or
`E AndroidRuntime` (smoke-test.ps1:348-352), and separately fails if the app is not the
foreground (`topResumedActivity`) at the end (smoke-test.ps1:354-358). It clears logcat
right before launching (`adb logcat -c`, smoke-test.ps1:209), so hits are from THIS run.

**Manual reproduction of the gate:**

```powershell
& C:\Android\platform-tools\adb.exe logcat -c
# ... reproduce the action that crashes ...
& C:\Android\platform-tools\adb.exe logcat -d | Select-String -Pattern "FATAL EXCEPTION|E AndroidRuntime" -Context 0,30
& C:\Android\platform-tools\adb.exe shell dumpsys activity activities | Select-String "topResumedActivity"
```

The `-Context 0,30` gives you the stack trace under the FATAL line. Read the FIRST
`Caused by:` frame that mentions `com.mananpatel.voicebridge` — that is your file:line.

**Triage by where the stack points:**

| Stack mentions | Suspect |
|---|---|
| `AudioRecord` / `AudioRecorder.kt` | Permission not actually granted (the init `check` throws with "AudioRecord failed to initialize...", AudioRecorder.kt:55-57 — but note `startRecording()` catches exceptions into the error card, MainViewModel.kt:44-46, so a crash here means a code path outside that try) |
| `MediaPlayer` / `AudioPlayer.kt` | Lifecycle misuse — `stop()`/`release()` ordering; the current code guards `IllegalStateException` (AudioPlayer.kt:37-39) |
| `NetworkOnMainThreadException` | Someone removed a `withContext(Dispatchers.IO)` from SttService.kt:37 or TranslationService.kt:22 |
| `JSONException` | GCP response shape changed or a parse was made non-optional (Translation parsing is strict `getJSONObject`/`getJSONArray`, TranslationService.kt:57-61 — an unexpected 200-response shape throws, but lands in `runCatching` -> error card, not crash) |
| Compose / `Recomposer` frames only | UI-state bug; reproduce with the smoke test and inspect the step screenshots |

**"App keeps stopping" dialog vs cold-boot jank:** if the dialog reappears immediately
on every launch, it is a real crash loop — logcat will have the FATAL. If it appears
once after AVD boot and never again, it is the transient ANR jank that `Get-Ui`
auto-dismisses (section 2c).

---

## When NOT to use this skill

| Your task | Use instead |
|---|---|
| Fresh-machine setup: install JDK/SDK, create the AVD, write local.properties, corp-CA into emulator | **voicebridge-build-and-env** |
| Running a release: version branch, CHANGELOG signal, auto-merge, hook mechanics | **voicebridge-release-gate-runbook** |
| What am I ALLOWED to change, commit-message rules, the Bruno exception string | **voicebridge-change-control** |
| Why the code is shaped this way; module boundaries; Pipeline Stage Registry | **voicebridge-architecture-contract** |
| WAV/PCM format details, header layout rationale, audio contract reference | **voicebridge-audio-pipeline-reference** |
| GCP STT/Translation request/response reference, quotas, language codes | **voicebridge-gcp-speech-apis-reference** |
| Where config/keys/flags live and how they flow | **voicebridge-config-and-flags** |
| adb/uiautomator/screenshot tooling how-tos beyond triage | **voicebridge-diagnostics-and-tooling** |
| Designing NEW tests / QA coverage | **voicebridge-validation-and-qa** |
| Past incidents and their post-mortems (v0.0.5 manual-merge incident, 88ac97a hook fix) | **voicebridge-failure-archaeology** |
| Writing docs / changelog rows / Project_Structure map prose | **voicebridge-docs-and-writing** |
| Building Chunk 3 (voice-clone TTS) | **voicebridge-chunk3-voice-clone-tts-campaign** |
| Evaluating new/experimental approaches | **voicebridge-research-frontier** |

Nothing in this playbook overrides GEMINI.md (the constitution of record) or PATTERNS.md.
No fix here may bypass change control; the only sanctioned commit-gate exception is the
exact Bruno acknowledgment string recorded in PATTERNS.md.

---

## Provenance and maintenance

Authored 2026-07-13 by skill-distill, grounded against branch `main` at commit
`80b756f` plus the then-current working tree.

**Volatile facts stamped 2026-07-13:** the uncommitted AGP 9 built-in-Kotlin migration
edits (section 1c); `versionName = "0.0.4"` in android/app/build.gradle.kts:23 (repo
history is at v0.0.7 — versionName has not tracked docs-only releases); the OPEN
Play-vs-header-write race note (6b).

Re-verification one-liners (run from repo root) for anything likely to drift:

| Claim | Re-verify with |
|---|---|
| Plugin/migration state (1c) | `git status --short; git diff --stat -- android/` |
| Button labels still match table 2a | `Select-String -Path .\android\app\src\main\java\com\mananpatel\voicebridge\MainActivity.kt -Pattern 'Text\("' ` |
| Smoke-test selectors still match table 2a | `Select-String -Path .\android\scripts\smoke-test.ps1 -Pattern "KEEP IN SYNC|@text=|content-desc"` |
| STT blank-key error string (4) | `Select-String -Path .\android\app\src\main\java\com\mananpatel\voicebridge\MainViewModel.kt -Pattern "GCP_STT_API_KEY"` |
| Translation error strings (5) | `Select-String -Path .\android\app\src\main\java\com\mananpatel\voicebridge\TranslationService.kt -Pattern "error\("` |
| stop() no-cancel contract (6) | `Select-String -Path .\android\app\src\main\java\com\mananpatel\voicebridge\AudioRecorder.kt -Pattern "cancel|Do NOT"` |
| verify_structure exclusion list (3) | `Select-String -Path .\scripts\verify_structure.py -Pattern "startswith|rel_path.parts"` |
| Crash-gate patterns (7) | `Select-String -Path .\android\scripts\smoke-test.ps1 -Pattern "FATAL EXCEPTION"` |
| Gradle/AGP/Kotlin versions (1) | `Get-Content .\android\gradle\wrapper\gradle-wrapper.properties; Get-Content .\android\build.gradle.kts` |
| Default JDK/SDK/AVD params | `Select-String -Path .\android\scripts\smoke-test.ps1 -Pattern '^\s+\[string\]'` |

If any re-verification contradicts this file, the repo wins — update this playbook in
the same change (and log the edit per change control).
