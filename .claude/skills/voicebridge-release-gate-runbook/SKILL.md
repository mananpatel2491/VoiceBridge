---
name: voicebridge-release-gate-runbook
description: >
  Operate VoiceBridge's day-to-day run/verify/release machinery: run the smoke test
  (android/scripts/smoke-test.ps1) and read a failed run, know exactly what a release
  commit triggers end-to-end via the post-commit hook (build + emulator UI drive +
  auto-merge to main + push), and keep the smoke-test selectors in sync with
  MainActivity.kt / MainViewModel.kt. Load this skill whenever you are about to: run or
  re-run the smoke test, make ANY commit on a vX.Y.Z branch, ship a version (update
  CHANGELOG.md), rename a button or change UI state logic (KEEP-IN-SYNC table here),
  diagnose a red smoke run, or set up hooks after a fresh clone. Do NOT load it for:
  deciding WHETHER a change is allowed or how to version/document it
  (voicebridge-change-control), root-causing app defects beyond the gate itself
  (voicebridge-debugging-playbook), JDK/SDK/Gradle install problems
  (voicebridge-build-and-env), or STT/translation API semantics
  (voicebridge-gcp-speech-apis-reference).
---

# VoiceBridge Release Gate Runbook

## 0. Orientation — terms used once, then assumed

| Term | Meaning here |
|---|---|
| **Smoke test** | `android/scripts/smoke-test.ps1` — a PowerShell script that builds (optionally), installs the debug APK on an emulator, drives the real UI through Record → Stop → Play → Transcribe → Translate using UIAutomator, screenshots every step, and scans logcat for crashes. It is the single authoritative "done" gate (PATTERNS.md:41). |
| **UIAutomator dump** | `adb shell uiautomator dump` — dumps the live screen's accessibility tree to XML. The script finds buttons by `@text` or `@content-desc` in that XML, never by pixel coordinates (smoke-test.ps1:23–24), so it survives layout changes but breaks on label renames. |
| **AVD** | Android Virtual Device (emulator). This repo's AVD is named `voicebridge_avd` (smoke-test.ps1:50). |
| **Version branch** | Branch named exactly `vX.Y.Z` (regex `^v\d+\.\d+\.\d+$`). All work happens here; **never commit to main directly** — main only receives auto-merges. |
| **Post-commit hook** | `.git/hooks/post-commit`, installed from the tracked template `android/scripts/hooks/post-commit` by `install-hooks.ps1`. Runs the smoke test after every commit on a version branch. |
| **Auto-merge signal** | A commit that touches `CHANGELOG.md` on a version branch. That is the "this version is complete" signal: the hook then adds `-Build -AutoMerge`, and a passing run merges the branch to main and pushes both branches (PATTERNS.md:34). |

**First-time setup after any fresh clone** (`.git/hooks/` is untracked, so hooks vanish on clone):

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge
powershell -File android/scripts/install-hooks.ps1
```

Re-run it whenever `android/scripts/hooks/` templates change.

---

## 1. What a release commit triggers, end to end

```
you: git checkout -b v0.0.8                # new version branch
you: ...code... ; git commit -m "feat: X"  # INTERMEDIATE commit
      └─ hook: smoke-test.ps1 (NO -Build, NO merge)      <- see caveat below
you: edit CHANGELOG.md (+ Project_Structure.md changelog table)
you: git commit -m "chore: v0.0.8"         # RELEASE commit (CHANGELOG.md in the diff)
      └─ hook: smoke-test.ps1 -Build -AutoMerge
           ├─ 0. pre-flight: credential hygiene + verify_structure.py
           ├─ 1. gradlew assembleDebug
           ├─ 2. ensure emulator booted
           ├─ 3. install APK, pm grant RECORD_AUDIO, launch
           ├─ 4-9. UI drive with screenshot per step
           ├─ 10. logcat crash scan + foreground check
           └─ PASS -> checkout main, merge --no-ff, push main, push v0.0.8,
                      return... (you are left ON MAIN after success)
              FAIL -> stays on v0.0.8, exit 1, fix and recommit
```

Hook branch logic (android/scripts/hooks/post-commit:24–35): it counts `CHANGELOG.md` in
`git show --name-only HEAD -- CHANGELOG.md`. Zero → intermediate commit → smoke test only.
Nonzero → release → `-Build -AutoMerge`. On any non-`vX.Y.Z` branch the hook is a no-op
(post-commit:15–17).

**Caveat — intermediate commits test a possibly stale APK.** The hook calls the script
WITHOUT `-Build` on intermediate commits (post-commit:28–29), so it drives the *most
recently built* APK, not necessarily the code you just committed. If your intermediate
commit changed app code, build first or run manually with `-Build` to test what you wrote.

**Commit message convention** (PATTERNS.md:37): `feat:` / `fix:` / `chore:`; the release
commit is `chore: vX.Y.Z`.

---

## 2. smoke-test.ps1 anatomy, stage by stage

Parameters (smoke-test.ps1:47–53): `-Build` (run assembleDebug first), `-AutoMerge`
(merge+push after pass, version branches only), `-AvdName` (default `voicebridge_avd`),
`-JavaHome` (default `C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot` — this
machine's real JDK 17 as of 2026-07-13), `-AndroidHome` (default `C:\Android`).
`$ErrorActionPreference = "Continue"` on purpose: adb writes routine progress to stderr
(smoke-test.ps1:55–57). Failures accumulate in `$script:Failures` via `Fail()`; the run
keeps going so one broken assertion still yields a full screenshot set.

| # | Stage (script lines) | What it does | Why / pass condition |
|---|---|---|---|
| 0a | Credential hygiene (156–162) | `git ls-files android/local.properties` | FAIL if the API-key file is git-tracked. Fix: `git rm --cached android/local.properties`. |
| 0b | Structure integrity (164–172) | Runs `scripts\verify_structure.py` | FAIL if any repo file is missing from the Project_Structure.md changelog table. **Skipped with a yellow warning if Python is not on PATH** — do not mistake skip for pass. |
| 1 | Build, only with `-Build` (176–185) | `gradlew.bat -p android assembleDebug` | Hard `exit 1` on build failure. Without `-Build`, requires an existing APK at `android\app\build\outputs\apk\debug\app-debug.apk` or hard-exits. |
| 2 | Emulator (188–201) | If no `emulator-N   device` in `adb devices`, starts the AVD (`-no-snapshot-load -no-boot-anim`), then polls `sys.boot_completed` up to **60 tries × 3 s = 180 s** | Emulator-serial regex only — see physical-phone recipe §5. |
| 3 | Install + grant + launch (204–212) | `adb install -r`; **`pm grant com.mananpatel.voicebridge android.permission.RECORD_AUDIO`**; `logcat -c`; launch via `monkey -p <appid> -c android.intent.category.LAUNCHER 1`; sleep 5 s | The grant exists because the runtime mic-permission dialog would otherwise sit on top of the app and block every UIAutomator selector. Works because debug builds are debuggable. `logcat -c` clears the buffer so stage 10 only sees this run's crashes. |
| 4 | Initial-state assertions (216–239) | Presence: app title, Record, Stop, Play, Transcribe(…​), (English) button. Enabled-state: **Record=true, Stop=false, Play=false, Translate(English)=false** | Mirrors `UiState` defaults (MainViewModel.kt:13–22): `recordingState=IDLE`, `hasRecording=false`, `transcript=""` — plus the pre-granted permission making Record enabled. Compose Material3 propagates `enabled=false` into the accessibility node, so the dump's `enabled` attribute is trustworthy (smoke-test.ps1:130–131). |
| 5 | Record (242–250) | Tap Record, wait, assert **Stop=true, Record=false**, screenshot, record ~2 s of (silent) audio | Matches `RecordingState.RECORDING` logic in MainActivity.kt:114,119. |
| 6 | Stop (253–269) | Tap Stop, assert **Play=true** and Transcribe enabled | Matches `hasRecording=true` after `stopRecording()` (MainViewModel.kt:49–58). |
| 7 | Play (272–275) | Tap Play, wait 3 s, screenshot | No assertion beyond no-crash; playback is verified by ear/screenshot only. |
| 8 | Transcribe (284–303) | Tap Transcribe, wait 3 s, accept ANY of: (a) node containing `Transcript`, (b) node containing `GCP_STT_API_KEY`, (c) node containing `Error:`/`error` | **Three acceptable outcomes by design**: transcript card (real key + network), key-missing error card (the exact ViewModel message at MainViewModel.kt:76 contains `GCP_STT_API_KEY`), or a network/auth error. Any of the three proves the flow fired and the app did not crash — the point of the gate, per PATTERNS.md:45. Caveat: the empty field's placeholder "Transcription appears here…" (MainActivity.kt:157) itself contains the substring `Transcript`, so when the placeholder is rendered in the dump this step cannot fail on content — treat it strictly as a no-crash gate, not an STT-correctness gate. |
| 9 | Translate (312–343) | If the transcript field (`content-desc='transcript-field'`, MainActivity.kt:160) is empty/placeholder, tap it and `adb shell input text "hello"`; tap the `(English)` button; accept translation card (`Translation (English)`, MainActivity.kt:190) OR error card | Typing "hello" exists so Translate can be driven without a working STT key (the button is disabled while `transcript` is blank, MainActivity.kt:170). The placeholder sentinel string compared at smoke-test.ps1:315 must equal MainActivity.kt:157 exactly. |
| 10 | Crash + foreground (347–359) | `logcat -d` scan for `FATAL EXCEPTION|E AndroidRuntime`; `dumpsys activity activities` must show the app as `topResumedActivity` | Catches crashes that redrew fast enough to fool the UI assertions, and silent finish()/background kicks. |
| — | Summary (362–375) | Green PASS banner, or red banner + the full `$Failures` list + screenshot dir | `exit 1` if any failure accumulated. |
| — | Auto-merge tail (378–407) | Only with `-AutoMerge` and only if branch matches `^v\d+\.\d+\.\d+$` (381); otherwise yellow SKIP + exit 0. Then: `git checkout main` → `git merge --no-ff <branch>` → `git push origin main` → `git push origin <branch>` | On merge conflict it **checks the version branch back out** and exits 1 (394–397) so you fix on the branch. On push failure it exits 1 **while the local merge to main already happened** — recovery: fix the remote issue (auth/network) and push manually; do not re-merge. Note the hook/script pushes to origin **unconditionally** on pass — known open gap, there is no "local-only release" flag. |

Also in the toolbox: `Get-Ui` (79–99) auto-dismisses the transient "isn't responding /
keeps stopping" ANR dialog Android sometimes shows on cold boot — a passing run may
legitimately log a yellow "dismissing transient system ANR dialog" line.

**Exit codes**: `0` = pass (including "auto-merge skipped: not a version branch");
`1` = build failure, APK missing, one or more stage failures, or any checkout/merge/push
failure. The hook exits with the script's code (post-commit:43).

**Screenshot archive — THE primary debugging artifact** (PATTERNS.md:43): every step saves
`NN_name.png` plus the last `ui.xml` dump into
`android\app\build\smoke-<yyyyMMdd-HHmmss>\` — gitignored via `android/.gitignore`
(`app/build/`), so archives never pollute commits and are safe to delete.

**Stage timings** (sleeps are from the script; build/boot vary by machine, 2026-07-13):

| Stage | Time |
|---|---|
| Pre-flight | ~2–5 s |
| Build (`-Build` only) | ~1–5 min (variable; first build after `clean` is worst) |
| Emulator cold boot | up to 180 s (60 × 3 s poll); ~0 s if already running |
| Install + grant + launch | ~10–15 s (includes fixed 5 s post-launch sleep) |
| UI drive (stages 4–9) | ~35–45 s (fixed sleeps: 1+2+1+3+3+~1+3 s, plus 600 ms per tap and a uiautomator dump per assertion) |
| Crash scan + summary | ~5 s |
| **Total** | **~1 min warm/no-build; ~4–8 min cold with build** |

---

## 3. KEEP-IN-SYNC contract table

If you rename a button, change a `contentDescription`, reword an error message, or change
enabled-state logic, you MUST update the matching selector in smoke-test.ps1 in the same
commit — the script says so itself (smoke-test.ps1:26, 130, 225, 283, 311). This table is
the full contract as of 2026-07-13:

| smoke-test.ps1 selector (lines) | MainActivity.kt source (line) | MainViewModel/UiState driver |
|---|---|---|
| `contains(@text,'VoiceBridge')` (218) | `Text("VoiceBridge")` (70) | static title |
| `@text='Record'` (219, 226, 243, 248) | `Text("Record")` (115) | enabled = `permissionGranted && recordingState != RECORDING` (114) |
| `@text='Stop'` (220, 227, 247, 254) | `Text("Stop")` (120) | enabled = `recordingState == RECORDING` (119) |
| `@text='Play'` (221, 228, 258, 273) | `Text("Play")` (126) | enabled = `hasRecording && recordingState != RECORDING` (125) |
| `contains(@text,'Transcribe')` (222, 260, 285) | `Text("Transcribe (Gujarati)")` (147); shows `Transcribing...` while busy (145) — which does NOT contain "Transcribe", so never tap during the busy state | enabled = `hasRecording && !isTranscribing && !isTranslating && recordingState != RECORDING` (133–136) |
| `contains(@text,'(English)')` (223, 230, 328) | `Text("Translate (English)")` (183); busy text `Translating...` (181) | enabled = `transcript.isNotBlank() && !isTranslating && !isTranscribing` (170–172) |
| `@content-desc='transcript-field'` (314, 318) | `semantics { contentDescription = "transcript-field" }` (160) | value = `state.transcript` (154) |
| placeholder sentinel `"Transcription appears here, or type directly to test translation"` (315) | placeholder `Text(...)` (157) — must match **byte for byte** | shown while `transcript` is empty |
| `contains(@text,'GCP_STT_API_KEY')` (290, 333) | error card renders `"Error: $error"` (101) | key-missing message `"GCP_STT_API_KEY is not set. See local.properties.template."` (MainViewModel.kt:76) |
| `contains(@text,'Translation (English)')` (332) | translation card label (190) | shown when `translatedText.isNotEmpty()` (187) |
| Initial enabled expectations (226–237) | — | `UiState` defaults (MainViewModel.kt:13–22): IDLE, `hasRecording=false`, `transcript=""` |

Checklist when touching UI or state:
- [ ] Button label changed? → update every `@text=`/`contains(@text,...)` occurrence.
- [ ] `contentDescription` changed? → update line 314/318 selectors.
- [ ] Placeholder or key-missing error text changed? → update lines 315 / 290 / 333.
- [ ] Enabled-logic changed? → update `Assert-Enabled` expectations in stages 4–6.
- [ ] New screen/button added? → add presence + enabled assertions + a `Save-Shot`.
- [ ] ASCII only in the .ps1 — Windows PowerShell 5.1 reads it as ANSI (smoke-test.ps1:28).

---

## 4. Operating recipes

**Full gate, exactly what a release does (manual dry run, no merge):**
```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge
powershell -File android/scripts/smoke-test.ps1 -Build
```

**Fast re-run (no build — uses the most recent APK; ~1 min warm):**
```powershell
powershell -File android/scripts/smoke-test.ps1
```
Only valid when the last-built APK matches the code you care about.

**Pre-boot the emulator to skip the 180 s boot wait:**
```powershell
& C:\Android\emulator\emulator.exe -avd voicebridge_avd -no-snapshot-load -no-boot-anim
```

**Run against a physical phone** — the script is emulator-centric: its device check at
smoke-test.ps1:189 only matches `emulator-\d+` serials, so with only a phone attached it
will still spawn the AVD. Workable path (2026-07-13):
```powershell
$env:ANDROID_SERIAL = (& C:\Android\platform-tools\adb.exe devices) -match '\tdevice' `
    | Select-Object -First 1 | ForEach-Object { ($_ -split "`t")[0] }
powershell -File android/scripts/smoke-test.ps1 -Build
```
`adb` honors `ANDROID_SERIAL`, so every install/tap/dump targets the phone (already booted,
so the boot poll exits immediately); the pointlessly-launched AVD is a known cosmetic gap —
close it when convenient. Phone must run a debug build for `pm grant` to work (API 23+).

**Trigger a real release:** do nothing special — commit on `vX.Y.Z` with `CHANGELOG.md` in
the diff (plus the mandatory Project_Structure.md changelog rows, or pre-flight stage 0b
fails). The hook does the rest. After success you are sitting on `main`; start the next
version with `git checkout -b vX.Y.(Z+1)`.

**Never** release by merging manually — that bypasses the gate. It happened once (v0.0.5
shipped without a CHANGELOG entry, patched retroactively in v0.0.7); treat it as the
cautionary tale, not a technique. Rules for what may ship live in
voicebridge-change-control.

---

## 5. Reading a failed run — in this order

1. **Screenshots first**: open the newest `android\app\build\smoke-*\` folder. The last
   `NN_*.png` shows the screen at (or just before) the failure; `ui.xml` in the same folder
   is the final accessibility dump — grep it for the label the script couldn't find.
2. **The failure list**: the red summary enumerates every `Fail()` in order. Map each line
   to a stage using the §2 table. Common signatures:
   | Failure text | Likely cause |
   |---|---|
   | `could not find UI element: ...` / `not found: ...` | Label renamed in MainActivity.kt without updating the selector (§3), or the app never reached that screen — check the previous screenshot. |
   | `button 'X': expected enabled=... got ...` | Enabled-state logic changed in MainActivity/MainViewModel, or a prior tap silently missed. Note (fixed v0.0.8, INC-6 in voicebridge-failure-archaeology): Compose buttons dump as a clickable parent View holding the REAL enabled state over an always-enabled TextView child; `Assert-Enabled` resolves the nearest clickable self-or-ancestor via `Get-EffectiveButtonNode`. If this signature reappears systematically (all-true or all-false), re-check the dump's node structure before blaming app logic. |
   | `verify_structure.py failed` | You added/removed a file without a Project_Structure.md changelog row. Run `python scripts\verify_structure.py` to list offenders. |
   | `android/local.properties is tracked by git` | `git rm --cached android/local.properties`. |
   | `logcat shows crash(es)` | Real app crash — stack trace is printed in the failure; full context: `adb logcat -d`. Hand off to voicebridge-debugging-playbook. |
   | `app is not the foreground activity` | App crashed-and-relaunched, finished, or a system dialog stole focus after the last screenshot. |
3. **Logcat last**: `adb logcat -d | Select-String "FATAL EXCEPTION" -Context 0,30` — the
   buffer was cleared at launch (stage 3), so everything in it is from this run.
4. After a failed **release** commit you are still on the version branch (the hook never
   merges on red). Fix, recommit (the fix commit must also touch CHANGELOG.md if you want
   the merge to fire — or just amend nothing and make a trivial CHANGELOG-touching
   `chore:` commit once green... simplest: include CHANGELOG.md in the fix commit).

Known gaps to keep expectations honest (open as of 2026-07-13, do not "fix" silently —
route through change control): smoke test is happy-path only (no VAD/deny-permission/
rotation cases); steps 8–9 are no-crash gates with loose content matching; auto-merge
pushes to origin unconditionally; device detection is emulator-only.

---

## 6. When NOT to use this skill

- Deciding **whether/how** a change may ship, versioning policy, doc-update obligations,
  the Bruno commit-gate exception → **voicebridge-change-control**.
- Root-causing an app bug the gate exposed (crashes, wrong transcript, audio glitches) →
  **voicebridge-debugging-playbook**; past incidents → **voicebridge-failure-archaeology**.
- JDK/SDK/AVD/Gradle installation or `assembleDebug` environment failures →
  **voicebridge-build-and-env**.
- WAV/PCM contract details → **voicebridge-audio-pipeline-reference**; STT/Translation API
  behavior → **voicebridge-gcp-speech-apis-reference**; API-key/buildConfig wiring →
  **voicebridge-config-and-flags**.
- Module boundaries / where code lives → **voicebridge-architecture-contract**.
- Extending the smoke test's coverage or adding new QA layers →
  **voicebridge-validation-and-qa**; adb/emulator tooling beyond this runbook →
  **voicebridge-diagnostics-and-tooling**.
- Writing CHANGELOG/docs prose → **voicebridge-docs-and-writing**. New feature campaigns →
  **voicebridge-chunk3-voice-clone-tts-campaign** / **voicebridge-research-frontier**.

---

## 7. Provenance and maintenance

Authored 2026-07-13 by skill-distill, grounded in smoke-test.ps1, hooks/post-commit,
install-hooks.ps1, MainActivity.kt, MainViewModel.kt, PATTERNS.md, verify_structure.py at
repo state v0.0.7 (main @ 80b756f). Re-verify drift-prone facts before trusting:

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge
# Script defaults (AVD name, JDK/SDK paths) and branch regex
Select-String android\scripts\smoke-test.ps1 -Pattern 'AvdName|JavaHome|AndroidHome|notmatch'
# Current selectors and enabled-state assertions
Select-String android\scripts\smoke-test.ps1 -Pattern 'Assert-Node|Assert-Enabled|content-desc|Transcription appears'
# Current UI labels and contentDescription
Select-String android\app\src\main\java\com\mananpatel\voicebridge\MainActivity.kt -Pattern 'Text\("|contentDescription'
# UiState defaults
Select-String android\app\src\main\java\com\mananpatel\voicebridge\MainViewModel.kt -Pattern 'data class UiState' -Context 0,10
# Hook behavior (intermediate vs release commit)
Get-Content android\scripts\hooks\post-commit
# Hook actually installed?
Test-Path .git\hooks\post-commit
```
