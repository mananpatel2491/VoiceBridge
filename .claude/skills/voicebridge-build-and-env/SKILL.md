---
name: voicebridge-build-and-env
description: >-
  Recreate the VoiceBridge Android development environment from scratch on a fresh
  Windows machine and get to a passing debug build: JDK 17, Android SDK at C:\Android,
  the voicebridge_avd emulator, android/local.properties, git hooks, Python on PATH,
  and build/install the APK — with every known environment trap (silent Python skip,
  local.properties backslash escaping, JAVA_HOME vs PATH, first-boot emulator jank,
  AGP 9 Kotlin-plugin friction, corp-proxy CA). Load this skill when setting up a new
  machine, when a build fails with environment-shaped errors (SDK location not found,
  wrong JDK, missing AVD, gradle wrapper questions), when onboarding a new engineer or
  agent to the repo, or when verifying an environment is complete. Do NOT load it for
  release/merge mechanics (voicebridge-release-gate-runbook), app-code debugging
  (voicebridge-debugging-playbook), audio/GCP API details
  (voicebridge-audio-pipeline-reference, voicebridge-gcp-speech-apis-reference), or
  change-control policy (voicebridge-change-control).
---

# VoiceBridge: Build & Environment Setup (Windows)

Goal: from a bare Windows machine to (1) `.\gradlew assembleDebug` green, (2) the APK
installed on the `voicebridge_avd` emulator, (3) git hooks installed, (4) the full smoke
test able to run. Every command below is copy-pasteable Windows PowerShell.

Facts verified against the repo on 2026-07-13. Line citations are to files in
`C:\Docs\Build\mananUtils\VoiceBridge` (adjust the clone path to your machine; the smoke
test itself is path-independent — it resolves the repo root from its own location,
`android/scripts/smoke-test.ps1:61`).

## Glossary (read once)

| Term | Meaning here |
|---|---|
| **JDK 17** | Java Development Kit, major version 17. Required by the build (`sourceCompatibility = JavaVersion.VERSION_17`, `android/app/build.gradle.kts`). |
| **Android SDK** | Google's Android toolset (platform-tools, emulator, system images). This repo assumes it lives at `C:\Android`. |
| **AGP** | Android Gradle Plugin — the Gradle plugin that builds Android apps. Pinned at **9.1.1** (`android/build.gradle.kts:2`). |
| **Gradle wrapper** | `gradlew`/`gradlew.bat` + `gradle/wrapper/*` — scripts committed to the repo that download and run the exact pinned Gradle (**9.3.1**, `android/gradle/wrapper/gradle-wrapper.properties:3`). You never install Gradle globally. |
| **AVD** | Android Virtual Device — an emulator instance. The smoke test's default AVD name is **`voicebridge_avd`** (`android/scripts/smoke-test.ps1:50`). |
| **adb** | Android Debug Bridge — CLI that talks to a device/emulator (install APKs, shell, logcat). Ships in SDK `platform-tools`. |
| **`local.properties`** | Gitignored per-machine file in `android/` holding the SDK path and the GCP API key. Never committed (`android/.gitignore:2`). |
| **post-commit hook** | Git hook installed into `.git/hooks/` that runs the smoke test (and auto-merge on release commits). `.git/` is untracked, so hooks must be installed **per clone**. |
| **`buildConfigField`** | Gradle mechanism that injects `GCP_STT_API_KEY` from `local.properties` into `BuildConfig` at compile time (`android/app/build.gradle.kts` `defaultConfig`). One key covers BOTH GCP STT and Translation (same GCP project, both APIs enabled). |
| **uiautomator** | Android's UI-dump/automation layer; the smoke test uses it to find buttons by text, not pixels. |

## Known-good environment matrix (2026-07-13)

| Component | Known-good value | Where pinned/defaulted |
|---|---|---|
| OS | Windows 11 | — |
| JDK | Eclipse Adoptium (Temurin) 17, at `C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot` | smoke-test default, `android/scripts/smoke-test.ps1:51` |
| Android SDK | `C:\Android` | smoke-test default, `android/scripts/smoke-test.ps1:52`; README prerequisites |
| Gradle | 9.3.1 via committed wrapper | `android/gradle/wrapper/gradle-wrapper.properties:3` |
| AGP | 9.1.1 | `android/build.gradle.kts:2` |
| Kotlin | 2.0.21 (see AGP 9 trap below) | `android/build.gradle.kts` |
| compileSdk / targetSdk / minSdk | 35 / 35 / 24 | `android/app/build.gradle.kts:16,20-21` |
| App id | `com.mananpatel.voicebridge` | `android/app/build.gradle.kts:19` |
| AVD name | `voicebridge_avd` | `android/scripts/smoke-test.ps1:50` |
| Python | Any Python 3.x on PATH as `python` or `python3` | `android/scripts/smoke-test.ps1:164-165` |

The exact Adoptium patch version (`17.0.18.8`) WILL drift with installer updates. Any
JDK 17 works; if yours is elsewhere, pass `-JavaHome "<path>"` to the smoke test — the
default is only a convenience.

---

## Step 1 — Install JDK 17 (Eclipse Adoptium)

1. Download Temurin **17 (LTS)** JDK for Windows x64 from adoptium.net and install with
   default options. On this machine it lands at
   `C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot`.
2. Set `JAVA_HOME` for your shell (and ideally your user environment):

```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"   # adjust patch version
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
java -version   # must report 17.x
```

> Trap: the smoke test sets `JAVA_HOME` itself (`android/scripts/smoke-test.ps1:68`), so
> it will pass even when your interactive shell is misconfigured — but your own manual
> `.\gradlew` runs use whatever `JAVA_HOME`/`java` your shell resolves. There is NO
> Gradle `java toolchain {}` block in this project (verified 2026-07-13); nothing
> auto-downloads a JDK for you. If `gradlew` picks up a JDK other than 17+, AGP 9 fails
> fast with a Java-version error. Fix = set `JAVA_HOME` as above; do not add a toolchain
> block just to work around your shell.

## Step 2 — Install the Android SDK at C:\Android

Install the SDK **command-line tools** (from developer.android.com → "command line tools
only"), unzip so the tools sit at `C:\Android\cmdline-tools\latest\`, then install the
packages. The repo does not pin an emulator system image; API 35 matches
`compileSdk`/`targetSdk` and is the recommended choice (minSdk is 24, so any image ≥ 24
technically works):

```powershell
$env:ANDROID_HOME = "C:\Android"
$sdkmanager = "C:\Android\cmdline-tools\latest\bin\sdkmanager.bat"
& $sdkmanager "platform-tools" "emulator" "platforms;android-35" "system-images;android-35;google_apis;x86_64"
& $sdkmanager --licenses    # accept all
```

Verify the two binaries the smoke test hardcodes relative to `AndroidHome`
(`android/scripts/smoke-test.ps1:63-64`):

```powershell
Test-Path C:\Android\platform-tools\adb.exe      # must be True
Test-Path C:\Android\emulator\emulator.exe       # must be True
```

If your SDK must live elsewhere, everything still works — pass
`-AndroidHome "<path>"` to the smoke test and put your real path in `local.properties`
(Step 5).

## Step 3 — Create the AVD named voicebridge_avd

The name matters: it is the smoke test's default (`-AvdName`,
`android/scripts/smoke-test.ps1:50`). Use exactly `voicebridge_avd` unless you want to
pass `-AvdName` forever.

```powershell
$avdmanager = "C:\Android\cmdline-tools\latest\bin\avdmanager.bat"
& $avdmanager create avd --name voicebridge_avd --package "system-images;android-35;google_apis;x86_64" --device "pixel_6"
C:\Android\emulator\emulator.exe -list-avds    # must print: voicebridge_avd
```

(The `--device pixel_6` profile is a reasonable default, not a repo requirement — the
smoke test finds buttons by text via uiautomator, not by pixel coordinates, so screen
size is not load-bearing.)

Boot it once now and let it fully settle (see the first-boot trap below):

```powershell
C:\Android\emulator\emulator.exe -avd voicebridge_avd
```

## Step 4 — Clone the repo; verify (do NOT regenerate) the Gradle wrapper

```powershell
cd C:\Docs\Build\mananUtils    # or wherever you keep repos
git clone <origin-url> VoiceBridge
cd VoiceBridge
```

The Gradle wrapper **is committed** — `android/gradlew`, `android/gradlew.bat`,
`android/gradle/wrapper/gradle-wrapper.jar`, `android/gradle/wrapper/gradle-wrapper.properties`
are all git-tracked (verified with `git ls-files android` on 2026-07-13). It pins
Gradle 9.3.1. **No bootstrap step is needed. Do not run `gradle wrapper` after cloning.**

> History: the README once falsely claimed the wrapper was NOT committed and told you to
> regenerate it; that was fixed in v0.0.7 (docs drift fixes). If you see old advice to
> bootstrap the wrapper, it is stale. The only time to regenerate is if the wrapper files
> are missing/corrupted: `gradle wrapper --gradle-version=9.3.1` from `android/`
> (requires a standalone Gradle on PATH — README.md:93).

Verify:

```powershell
git -C . ls-files android/gradlew.bat android/gradle/wrapper/gradle-wrapper.jar
# → both paths print. Empty output = broken clone, stop and investigate.
```

## Step 5 — Create android/local.properties from the template

```powershell
Copy-Item android\local.properties.template android\local.properties
notepad android\local.properties
```

Set two values:

```
sdk.dir=C\:\\Android
GCP_STT_API_KEY=AIza...
```

> Trap — Windows path escaping: `sdk.dir` is a Java properties value, so `:` and `\`
> must be escaped. `C:\Android` is written **`C\:\\Android`**
> (`android/local.properties.template:6`). Writing `C:\Android` literally makes Gradle
> fail with "SDK location not found" or a mangled path.

About the key (`README.md:124-139`): ONE GCP API key, named `GCP_STT_API_KEY`, covers
BOTH Chunk 1 (Cloud Speech-to-Text) and Chunk 2 (Cloud Translation) — same GCP project
with both APIs enabled. It is injected at build time via
`buildConfigField("String", "GCP_STT_API_KEY", ...)` in `android/app/build.gradle.kts`,
defaulting to `""` if unset. A blank key still builds and runs — the app (and the smoke
test) surface a clear error card instead of crashing, so you can defer the key until you
need real transcription/translation. Never commit `local.properties`; the smoke test's
pre-flight actively fails if it is ever git-tracked (`android/scripts/smoke-test.ps1:156-158`).

## Step 6 — Install the git hooks (MANDATORY, once per clone)

`.git/hooks/` is untracked, so hooks vanish on every fresh clone. Skipping this step
silently disables the entire release gate — commits on version branches will neither
smoke-test nor auto-merge.

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge
powershell -File android\scripts\install-hooks.ps1
# → "Installed: .git/hooks/post-commit"
```

What the installed hook does (`android/scripts/hooks/post-commit`): on version branches
(`vX.Y.Z`) every commit runs the smoke test; a commit that touches `CHANGELOG.md` runs
`smoke-test.ps1 -Build -AutoMerge`, which on pass merges to `main` and **pushes both
branches to origin unconditionally** (known open gap — there is no dry-run flag). On any
other branch the hook is a no-op. Details of the release flow belong to
**voicebridge-release-gate-runbook**; the environment-relevant fact is: install the hook,
and know that committing a CHANGELOG update on a version branch has push side effects.

## Step 7 — Python 3.x on PATH

The repo's hygiene scripts (`scripts/verify_structure.py`, `scripts/optimize_changelog.py`,
`scripts/generate_bootstrap_prompt.py`) are Python 3. Install Python 3.x and make sure
`python` (or `python3`) resolves on PATH.

> **Trap — the gate weakens silently without Python.** The smoke test looks for
> `python`/`python3` and, if neither exists, prints
> `SKIP verify_structure.py (Python not on PATH)` in yellow and **continues without
> failing** (`android/scripts/smoke-test.ps1:164-172`). The structure gate (every file
> must be logged in `Project_Structure.md`'s changelog table) simply stops being
> enforced, and nothing turns red. On a fresh machine, always confirm the smoke-test
> output shows `verify_structure.py passed`, not `SKIP`.

`requirements.txt` (`google-genai`, `python-dotenv`) is only needed for
`scripts/generate_bootstrap_prompt.py`; `verify_structure.py` uses stdlib only, so a bare
Python install is enough for the gate.

```powershell
python --version                       # 3.x
python scripts\verify_structure.py     # → SUCCESS: All files are accounted for...
```

## Step 8 — Build and install

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge\android
.\gradlew assembleDebug
adb install -r app\build\outputs\apk\debug\app-debug.apk
```

First build downloads Gradle 9.3.1 + all dependencies; expect several minutes. `adb`
here assumes `C:\Android\platform-tools` is on PATH; otherwise use the full path
`C:\Android\platform-tools\adb.exe`. Works against the running emulator or a physical
phone (API 24+, USB debugging on).

Manual acceptance check (Chunk 0, `README.md:115-121`): launch the app, grant mic
permission, Record → speak → Stop → Play, hear playback.

---

## Traps (all of them)

1. **`sdk.dir` escaping** — must be `C\:\\Android`, not `C:\Android`. See Step 5.
2. **JAVA_HOME vs what gradlew actually uses** — no toolchain block exists; manual
   builds use your shell's `JAVA_HOME`/`java`. The smoke test overrides `JAVA_HOME`
   itself, so "smoke test passes but my gradlew fails" almost always means your shell
   JDK is wrong. See Step 1.
3. **Silent Python skip** — missing Python turns the structure gate into a yellow SKIP,
   not a failure. See Step 7.
4. **Hooks are per-clone** — forgetting `install-hooks.ps1` disables the release gate
   with zero warning. See Step 6.
5. **First-boot emulator jank (ANR dialogs)** — on a cold-booted AVD, the system may pop
   "app isn't responding" / "keeps stopping" dialogs that steal focus and break UI
   automation. The smoke test has dismiss logic for exactly this: every uiautomator dump
   is scanned for those dialogs and the `Wait` button is tapped (or BACK is sent)
   before proceeding (`android/scripts/smoke-test.ps1:84-97`). If you drive the emulator
   manually, expect the same jank on first boot; let the AVD settle once (Step 3) before
   trusting timing-sensitive runs. The smoke test also boots with `-no-snapshot-load
   -no-boot-anim` and polls `sys.boot_completed` for up to ~3 minutes
   (`android/scripts/smoke-test.ps1:192-199`).
6. **AGP 9 / Kotlin plugin friction (VOLATILE, 2026-07-13)** — the **committed** build
   config applies the standalone Kotlin Android plugin
   (`id("org.jetbrains.kotlin.android") version "2.0.21"` in `android/build.gradle.kts`,
   plus a `kotlinOptions { jvmTarget = "17" }` block in `android/app/build.gradle.kts`).
   As of 2026-07-13 the working tree carries **uncommitted** edits removing both, per
   AGP 9's built-in-Kotlin migration. Do NOT state either form as the settled config:
   check `git status`/`git diff -- android/build.gradle.kts android/app/build.gradle.kts`
   before reasoning about the plugins block. If a fresh clone (which has only the
   committed form) throws Kotlin-plugin/AGP compatibility warnings or errors under
   AGP 9.1.1, this migration is the live context — read the current diff and CHANGELOG
   before "fixing" anything.
7. **Run gradlew from `android/`** — the Gradle project root is `android/`
   (`settings.gradle.kts` lives there). From the repo root, use
   `.\android\gradlew.bat -p android assembleDebug` (the `-p` form is what the smoke
   test does, `android/scripts/smoke-test.ps1:178`).
8. **App versionName lags the repo version — intentional** — `versionName = "0.0.4"`
   in `android/app/build.gradle.kts` while the repo CHANGELOG is at 0.0.7: versions
   0.0.5–0.0.7 were docs/tooling-only releases with no app-code change. Do not "fix"
   the mismatch as part of environment setup.
9. **ASCII-only PowerShell scripts** — Windows PowerShell 5.1 reads `.ps1` files as
   ANSI; non-ASCII characters break parsing (`android/scripts/smoke-test.ps1:28`). If
   you ever edit the scripts, keep them pure ASCII (and keep the sh hook LF-only,
   `android/scripts/hooks/post-commit:4`).
10. **Corp-proxy CA for GCP calls (SPECULATIVE — not reproduced in VoiceBridge)** — on a
    corporate machine where a TLS-intercepting proxy (e.g. Netskope) re-signs HTTPS, the
    emulator does not trust the corp root CA, so real GCP STT/Translation calls from the
    app can fail with `CertPathValidatorException` even though the key is valid. If you
    hit TLS errors on Transcribe/Translate from the emulator, the candidate fix is
    installing the corp root CA into the emulator's user credential store (Settings →
    Security → Install a certificate). This has been observed on this machine in a
    sibling Android project's emulator setup, but has NOT been verified against
    VoiceBridge — treat as a lead, not a fact. The smoke test is unaffected either way:
    it accepts an error card as a passing outcome for the Transcribe/Translate steps.

---

## From-zero verification block

Run all of these; every one must succeed. Together they prove the environment is
complete.

```powershell
# 1. JDK
java -version                                              # reports 17.x
$env:JAVA_HOME                                             # points at a JDK 17

# 2. Android SDK + AVD
Test-Path C:\Android\platform-tools\adb.exe                # True
Test-Path C:\Android\emulator\emulator.exe                 # True
C:\Android\emulator\emulator.exe -list-avds                # includes voicebridge_avd

# 3. Python (gate dependency)
python --version                                           # Python 3.x

# 4. Repo + wrapper + hooks + local config
cd C:\Docs\Build\mananUtils\VoiceBridge
git ls-files android/gradle/wrapper/gradle-wrapper.jar     # prints the path (wrapper committed)
Test-Path .git\hooks\post-commit                           # True (hooks installed)
Test-Path android\local.properties                         # True
git ls-files android/local.properties                      # prints NOTHING (never tracked)

# 5. Gradle resolves the pinned version under JDK 17
cd android
.\gradlew --version                                        # Gradle 9.3.1, JVM 17.x

# 6. Structure gate actually runs (not skipped)
python ..\scripts\verify_structure.py                      # SUCCESS: All files are accounted for...

# 7. Build
.\gradlew assembleDebug                                    # BUILD SUCCESSFUL
Test-Path app\build\outputs\apk\debug\app-debug.apk        # True

# 8. Full end-to-end proof: build + emulator + UI drive + crash scan (no merge)
cd ..
powershell -File android\scripts\smoke-test.ps1 -Build
# PASS criteria: "SMOKE TEST PASSED" AND the pre-flight shows
# "verify_structure.py passed" (NOT "SKIP ... Python not on PATH").
```

Step 8 is the single strongest signal: it exercises JDK, SDK, AVD, adb, Python,
credential hygiene, and the app itself in one run, and it never merges/pushes without
`-AutoMerge`.

## When NOT to use this skill

- **Committing, versioning, CHANGELOG signals, auto-merge, hook routing** →
  `voicebridge-release-gate-runbook` (and policy: `voicebridge-change-control`).
- **App crashes, wrong transcripts, UI-state bugs** → `voicebridge-debugging-playbook`.
- **Why past builds/releases broke** → `voicebridge-failure-archaeology`.
- **What the modules are and their contracts** → `voicebridge-architecture-contract`.
- **WAV format, PCM details, header stripping** → `voicebridge-audio-pipeline-reference`.
- **GCP STT/Translation request/response shapes, quotas** →
  `voicebridge-gcp-speech-apis-reference`.
- **Which flags/keys exist and what they gate** → `voicebridge-config-and-flags`.
- **Smoke-test internals, screenshots, uiautomator selectors** →
  `voicebridge-diagnostics-and-tooling` / `voicebridge-validation-and-qa`.
- **Editing GEMINI.md / PATTERNS.md / Project_Structure.md** →
  `voicebridge-docs-and-writing`.
- **Chunk 3 TTS work** → `voicebridge-chunk3-voice-clone-tts-campaign`;
  open research questions → `voicebridge-research-frontier`.

## Provenance and maintenance

Authored 2026-07-13 by skill-distill (retiring-fellow distillation). All paths, line
numbers, and defaults verified against the working tree on that date. Re-verify anything
that may have drifted:

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge
# Smoke-test defaults (AVD name, JDK path, SDK path):
Select-String -Path android\scripts\smoke-test.ps1 -Pattern 'AvdName|JavaHome|AndroidHome' | Select-Object -First 6
# Pinned Gradle:
Get-Content android\gradle\wrapper\gradle-wrapper.properties | Select-String distributionUrl
# AGP / Kotlin plugin state (trap 6 — check COMMITTED vs WORKING TREE):
git diff -- android/build.gradle.kts android/app/build.gradle.kts; Get-Content android\build.gradle.kts
# SDK levels, app id, versionName, key injection:
Select-String -Path android\app\build.gradle.kts -Pattern 'compileSdk|minSdk|targetSdk|applicationId|versionName|GCP_STT_API_KEY'
# Wrapper still committed:
git ls-files android/gradlew.bat android/gradle/wrapper/
# Python-skip behavior still present:
Select-String -Path android\scripts\smoke-test.ps1 -Pattern 'SKIP verify_structure'
# local.properties escaping example:
Get-Content android\local.properties.template
```

If any re-verification output contradicts this document, trust the repo and update this
skill. Nothing here overrides GEMINI.md (constitution of record) or PATTERNS.md.
