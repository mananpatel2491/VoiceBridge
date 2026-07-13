---
name: voicebridge-config-and-flags
description: >
  Load this skill when working with ANY configuration axis of the VoiceBridge repo: adding, reading,
  or changing keys in android/local.properties (sdk.dir, GCP_STT_API_KEY); BuildConfig injection via
  buildConfigField in android/app/build.gradle.kts; smoke-test.ps1 parameters;
  gradle.properties knobs; pinned tool versions (Gradle, AGP, Kotlin); lint
  configuration; git hook installation state; or the argparse
  --dry-run/--model flag conventions for scripts/*.py. Also load it when a build fails with a
  missing-key symptom, when the app shows the "GCP_STT_API_KEY is not set" error card, when the smoke
  test fails its credential-hygiene pre-flight, or when you need the add-a-config checklist before
  introducing a new setting. Do NOT load it for release/merge mechanics (voicebridge-release-gate-runbook),
  environment/toolchain install (voicebridge-build-and-env), GCP API request shapes
  (voicebridge-gcp-speech-apis-reference), or debugging app behavior (voicebridge-debugging-playbook).
---

# VoiceBridge Configuration and Flags Reference

Every configuration axis in the VoiceBridge repo: what it is, where it lives, its default, whether
it is production or experimental, and what guards it. Ends with the mandatory add-a-config
checklist. All paths are repo-relative to `C:\Docs\Build\mananUtils\VoiceBridge` unless absolute.

**Jargon defined once:**
- **BuildConfig** — a Java class Gradle generates at build time (`com.mananpatel.voicebridge.BuildConfig`); `buildConfigField` adds a constant to it, which is how secrets get from `local.properties` into Kotlin code without being committed.
- **AVD** — Android Virtual Device, the emulator image. This repo's is named `voicebridge_avd`.
- **AGP** — Android Gradle Plugin (`com.android.application`), the Gradle plugin that builds Android apps.
- **Smoke test** — `android/scripts/smoke-test.ps1`, the UIAutomator-driven release gate (build, install, drive the UI, screenshot each step, scan logcat for crashes).
- **Post-commit hook** — a git-managed script (`.git/hooks/post-commit`) that runs automatically after every `git commit`; here it triggers the smoke test on version branches.

## Configuration map (one-page overview)

| Axis | File | Guard |
|---|---|---|
| Machine secrets + SDK path | `android/local.properties` | gitignored (`android/.gitignore:2`) + smoke-test credential-hygiene check |
| Secret template | `android/local.properties.template` | committed; the documented contract for required keys |
| Secret → app injection | `android/app/build.gradle.kts` (`buildConfigField`) | blank key degrades to an in-app error card, never a crash |
| Gradle daemon knobs | `android/gradle.properties` | committed, rarely changed |
| Gradle version pin | `android/gradle/wrapper/gradle-wrapper.properties` | wrapper is COMMITTED — never regenerate casually |
| AGP + Kotlin version pins | `android/build.gradle.kts` (root) | see VOLATILE note below |
| Lint behavior | `android/app/build.gradle.kts` (`lint {}` block) | intentionally non-blocking; smoke test is the gate |
| Smoke test parameters | `android/scripts/smoke-test.ps1:47-53` | defaults match this machine; all overridable per-invocation |
| Hook install state | `.git/hooks/post-commit` (untracked) | must be re-installed per clone via `install-hooks.ps1` |
| Python script flags | `scripts/*.py` argparse | PATTERNS.md "Automation-First CLI" pattern |

---

## 1. android/local.properties — machine-local secrets and paths

**Never committed.** Contains exactly two keys today (2026-07-13):

| Key | Purpose | Example |
|---|---|---|
| `sdk.dir` | Android SDK path for Gradle | `sdk.dir=C\:\\Android` (note escaped backslashes) |
| `GCP_STT_API_KEY` | Google Cloud API key. ONE key covers BOTH Speech-to-Text AND Cloud Translation — same GCP project, both APIs enabled on it. The name says "STT" for historical reasons (added in Chunk 1); do not create a second key variable for Translation. | `GCP_STT_API_KEY=AIza...` |

**Setup on a fresh clone:**

```powershell
Copy-Item android\local.properties.template android\local.properties
# then edit android\local.properties: set sdk.dir and paste the real GCP API key
```

**Three layered guards keep it out of git:**

1. **gitignore** — `android/.gitignore` line 2 ignores `local.properties`. Verify:
   ```powershell
   git check-ignore -v android/local.properties   # expect: android/.gitignore:2:local.properties
   ```
2. **Smoke-test credential-hygiene pre-flight** — `android/scripts/smoke-test.ps1:156-161` runs
   `git ls-files android/local.properties`; if the file is EVER tracked, the smoke test records a
   failure ("android/local.properties is tracked by git") and tells you the fix:
   `git rm --cached android/local.properties`. Because the smoke test gates every commit on version
   branches (via the post-commit hook), a tracked secrets file blocks releases automatically.
3. **verify_structure.py exclusion** — `scripts/verify_structure.py` explicitly skips
   `android/local.properties` (along with `android/.gradle/` and `android/app/build/`) so the
   changelog-completeness gate never asks you to document it.

**Template discipline:** any new key added to `local.properties` MUST also be added to
`android/local.properties.template` with a comment explaining how to obtain the value. The template
is the only committed record of what a fresh machine needs.

## 2. BuildConfig injection — how the key reaches Kotlin

Mechanics in `android/app/build.gradle.kts` (line numbers = working tree, 2026-07-13):

1. Lines 9–12: a `Properties` object loads `rootProject.file("local.properties")` if it exists (missing file is fine — empty props).
2. Lines 27–31 (inside `defaultConfig`):
   ```kotlin
   buildConfigField(
       "String",
       "GCP_STT_API_KEY",
       "\"${localProps.getProperty("GCP_STT_API_KEY", "")}\""
   )
   ```
   The default `""` means a machine without the key still builds — the key becomes an empty string constant.
3. `buildFeatures { buildConfig = true }` (lines 34–37) is REQUIRED — AGP does not generate BuildConfig by default anymore. If you add a `buildConfigField` and get "unresolved reference: BuildConfig", check this flag first.
4. Consumption: `MainActivity.kt:32` passes `BuildConfig.GCP_STT_API_KEY` into the Compose screen as a plain `apiKey: String` parameter (services never read BuildConfig directly — keep it that way; it keeps services unit-testable).

**Blank-key degradation (by design, verified in code):** a blank key NEVER crashes; each pipeline
stage checks `apiKey.isBlank()` and surfaces an in-app error card:

- STT: `MainViewModel.kt:74-79` — error text `"GCP_STT_API_KEY is not set. See local.properties.template."`
- Translation: `TranslationService.kt:24-30` — error text starting `"GCP_STT_API_KEY is not set in local.properties."`

The smoke test EXPLOITS this: step 8 (`smoke-test.ps1:278-303`) passes on EITHER a transcript card
(real key) OR the `GCP_STT_API_KEY` error card (blank key), so the gate runs green on machines
without credentials. If you change either error string, update the smoke test's node predicates in
the same commit ("KEEP IN SYNC" comments mark the spots).

## 3. smoke-test.ps1 parameters

Declared at `android/scripts/smoke-test.ps1:47-53`:

| Parameter | Type | Default | When to override |
|---|---|---|---|
| `-Build` | switch | off | Pass on first run, after any source change, and always for release verification. Omit to reuse the most recent APK (`android/app/build/outputs/apk/debug/app-debug.apk`) — faster re-runs while iterating on the test script itself. Script exits 1 with "APK not found" if you omit it with no prior build. |
| `-AutoMerge` | switch | off | Almost never pass manually — the post-commit hook passes it on CHANGELOG-updating commits (the release signal). It is internally guarded: it only fires on a branch matching `^v\d+\.\d+\.\d+$` (`smoke-test.ps1:380-384`), otherwise it logs SKIP and exits 0. Manual use = re-driving a release the hook could not complete: either the failure happened after a green smoke run (push/merge issue), or you fixed a red release run and the CHANGELOG edit is already in HEAD so a new commit will not re-signal (see voicebridge-change-control section 2). Either way the merge still only fires on a fresh green run. WARNING: on success it merges to main and pushes BOTH branches to origin unconditionally (known open gap). |
| `-AvdName` | string | `voicebridge_avd` | Only if testing on a different emulator image. The script boots the AVD only when no emulator is already attached (`adb devices` check), so an already-running different emulator is used as-is regardless of this value. |
| `-JavaHome` | string | `C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot` | On a machine where JDK 17 lives elsewhere. Must be a JDK 17 (project compiles with `JavaVersion.VERSION_17`). Sets `$env:JAVA_HOME` for the Gradle invocation. |
| `-AndroidHome` | string | `C:\Android` | On a machine with a different SDK root. The script derives `platform-tools\adb.exe` and `emulator\emulator.exe` from it and sets `$env:ANDROID_HOME`. Keep consistent with `sdk.dir` in local.properties. |

Canonical invocations (from the script's own examples):

```powershell
# Full build + smoke test (no merge)
powershell -File android/scripts/smoke-test.ps1 -Build

# Fast re-run against the existing APK
powershell -File android/scripts/smoke-test.ps1

# Full release flow — normally only the post-commit hook calls this
powershell -File android/scripts/smoke-test.ps1 -Build -AutoMerge
```

Note: intermediate commits on a version branch trigger the hook to run the smoke test with NO
parameters (no `-Build`) — it reuses the last APK. This was the subject of the 88ac97a fix
(release commits originally also ran without `-Build`); do not "simplify" the hook back to a
single invocation.

## 4. gradle.properties knobs

`android/gradle.properties` (all four lines, committed, production):

| Line | Knob | Value | Notes |
|---|---|---|---|
| 1 | `org.gradle.jvmargs` | `-Xmx2048m -Dfile.encoding=UTF-8` | 2 GB Gradle daemon heap. Raise only if you see `OutOfMemoryError` during builds; keep encoding flag. |
| 2 | `android.useAndroidX` | `true` | MANDATORY — the app uses AndroidX artifacts exclusively; builds fail without it. Never remove. |
| 3 | `kotlin.code.style` | `official` | IDE formatting hint. Harmless. |
| 4 | `android.nonTransitiveRClass` | `true` | Each module only sees its own R class. Keep — modern default, faster builds. |

There are NO experimental Gradle flags in this file (no configuration cache, no parallel flag).
Anything you add here is a project-wide change — treat it as config, run the add-a-config checklist.

## 5. Pinned versions — the single source for each pin

| Tool | Pinned version | Where the pin lives |
|---|---|---|
| Gradle | **9.3.1** | `android/gradle/wrapper/gradle-wrapper.properties` (`distributionUrl=...gradle-9.3.1-bin.zip`). The wrapper (jar + scripts) is COMMITTED — a fresh clone builds with zero Gradle install. Changing this line changes the build for everyone; never regenerate the wrapper as a side effect. |
| AGP | **9.1.1** | root `android/build.gradle.kts` — `id("com.android.application") version "9.1.1" apply false` |
| Kotlin | **2.0.21** | root `android/build.gradle.kts` — Compose plugin `org.jetbrains.kotlin.plugin.compose version "2.0.21"`; see VOLATILE note for the Kotlin Android plugin itself |
| JDK | **17** | `compileOptions` in `android/app/build.gradle.kts` (source/target `VERSION_17`) + smoke-test `-JavaHome` default |
| compileSdk / targetSdk / minSdk | 35 / 35 / 24 | `android/app/build.gradle.kts` `defaultConfig` |
| Compose BOM | 2024.09.00 | `android/app/build.gradle.kts` dependencies block |

**VOLATILE (2026-07-13 — verify before relying on it):** the working tree has UNCOMMITTED edits to
both `android/build.gradle.kts` and `android/app/build.gradle.kts` that remove the standalone
`org.jetbrains.kotlin.android` plugin (AGP 9's built-in-Kotlin migration). The COMMITTED config
(HEAD) still declares and applies `org.jetbrains.kotlin.android` version `2.0.21`. Do not describe
the migration as shipped until it lands on main with a CHANGELOG entry. Check current state:

```powershell
git -C C:\Docs\Build\mananUtils\VoiceBridge status --short android/
git -C C:\Docs\Build\mananUtils\VoiceBridge diff android/build.gradle.kts android/app/build.gradle.kts
```

**Version-name gotcha:** `versionCode = 4` / `versionName = "0.0.4"` in `defaultConfig` have NOT
tracked repo releases v0.0.5–v0.0.7 (those were tooling/docs-only, no app change). If your change
ships app code, decide deliberately whether to bump these — do not assume they match the branch name.

## 6. Lint configuration — intentionally non-blocking

`android/app/build.gradle.kts`, `lint {}` block (lines 44–50, working tree 2026-07-13):

```kotlin
lint {
    abortOnError = false
    checkReleaseBuilds = false
    htmlReport = true
}
```

- **The smoke test is the quality gate, not lint.** Lint warns; it never fails a build. Do not
  flip `abortOnError = true` "to be safe" — that changes the release gate semantics and is a
  change-control matter.
- HTML report lands at `android/app/build/reports/lint-results-debug.html` (gitignored build
  output). Read it after builds when touching UI code; treat findings as advisory.

## 7. Hook installation state — per-clone, untracked

- Template (tracked): `android/scripts/hooks/post-commit` (POSIX sh, ASCII-only, LF-only — Git for
  Windows runs it as `sh`, not bash).
- Installed copy (UNTRACKED): `.git/hooks/post-commit`. Git never clones `.git/hooks/`, so **every
  fresh clone must run**:

```powershell
powershell -File android/scripts/install-hooks.ps1
```

Re-run it whenever the template changes (it force-copies everything in `android/scripts/hooks/`).
A clone without the hook silently loses the entire release gate — commits on version branches run
no smoke test and never auto-merge. Check installation:

```powershell
Test-Path C:\Docs\Build\mananUtils\VoiceBridge\.git\hooks\post-commit   # expect True
```

Installed and verified True on this machine as of 2026-07-13.

Hook behavior recap (configuration-relevant only): acts ONLY on branches matching
`^v[0-9]+\.[0-9]+\.[0-9]+$`; CHANGELOG.md touched in the commit → `smoke-test.ps1 -Build -AutoMerge`;
otherwise → `smoke-test.ps1` (no flags). Full release mechanics: see
voicebridge-release-gate-runbook.

## 8. Python script flag conventions (PATTERNS.md-mandated)

PATTERNS.md codifies two rules (verified at PATTERNS.md:9 and :28):

- **Automation-First CLI**: every interactive script must support CLI arguments that bypass user
  input (`--model`) and allow safe previewing (`--dry-run`) — CRON/CI compatibility.
- **argparse**: standard library `argparse` for all scripts, consistent flags and `--help`.

Current state (all four scripts in `scripts/`, verified 2026-07-13):

| Script | `--model` | `--dry-run` | Notes |
|---|---|---|---|
| `generate_bootstrap_prompt.py` | yes (Gemini model ID) | yes (preview, no save) | also positional `intent` arg |
| `optimize_changelog.py` | yes | yes | rewrites Project_Structure.md changelog via Gemini |
| `update_getting_started.py` | yes | yes | onboarding docs via Gemini |
| `verify_structure.py` | yes (no-op, "fleet consistency") | yes (no-op, script is read-only) | the changelog-completeness gate; called by smoke-test.ps1 pre-flight |

**When you add a script:** it MUST take `--model` and `--dry-run` via argparse even if one is a
documented no-op — `verify_structure.py:91-92` is the precedent for no-op flags kept for interface
consistency.

## 9. Add-a-config checklist (run every time you introduce a setting)

Work through ALL rows; each has a verification command.

| # | Step | How / verify |
|---|---|---|
| 1 | **Pick where it lives.** Secret or machine path → `android/local.properties` + `buildConfigField`. Build behavior → `android/gradle.properties` or the relevant `build.gradle.kts`. Script behavior → argparse flag with a safe default. Test-harness behavior → a `param()` entry in `smoke-test.ps1` with a working default. | n/a — decision |
| 2 | **Never hardcode a secret.** Secrets go ONLY in `local.properties`, reach code ONLY via `buildConfigField`, and default to `""` so key-less machines still build (blank must degrade to an error card, not a crash — follow `MainViewModel.kt:74-79`). | `git grep -n "AIza" -- "*.kt" "*.kts"` returns nothing |
| 3 | **Template updated.** New `local.properties` key → add to `android/local.properties.template` with a how-to-obtain comment. | `Select-String -Path android\local.properties.template -Pattern "<YOUR_KEY>"` |
| 4 | **gitignore checked.** Any new machine-local/generated file must be matched by `.gitignore` or `android/.gitignore`. | `git check-ignore -v <path>` prints a rule; `git status --short` shows no untracked secret |
| 5 | **BuildConfig wiring (if applicable).** `buildConfigField` added inside `defaultConfig`; `buildFeatures { buildConfig = true }` still present; value consumed via a plain parameter, not `BuildConfig.` inside services. | `gradlew.bat -p android assembleDebug` then check generated `BuildConfig.java` under `android/app/build/generated/` |
| 6 | **Docs row added.** Every file added/removed gets a row in the Project_Structure.md Changelog table (GEMINI.md Lesson 1 mandate); new config semantics worth a sentence go in the file-map table too. | `python scripts\verify_structure.py` exits 0 |
| 7 | **Smoke test impact.** If the config changes any UI text, button state, or error message the smoke test asserts on (grep smoke-test.ps1 for "KEEP IN SYNC"), update the predicates in the SAME commit. If it adds a smoke-test parameter, give it a default that preserves current behavior. | `powershell -File android/scripts/smoke-test.ps1 -Build` passes |
| 8 | **Pattern check.** New script flag → argparse + `--dry-run`/`--model` convention (section 8). Nothing may contradict GEMINI.md or PATTERNS.md. | reread PATTERNS.md; add a pattern entry only if the decision is new and real (never aspirational) |
| 9 | **Re-verification line.** Add a one-line check for the new config to the Provenance section of whichever skill documents it. | n/a — authoring |

## When NOT to use this skill

- Release flow, version branches, CHANGELOG-as-signal, auto-merge mechanics → **voicebridge-release-gate-runbook**
- Installing JDK/SDK/AVD, first-build problems, toolchain env setup → **voicebridge-build-and-env**
- GCP STT/Translation request formats, quotas, API enablement details → **voicebridge-gcp-speech-apis-reference**
- WAV/PCM format, header stripping, recorder/player internals → **voicebridge-audio-pipeline-reference**
- App misbehaving at runtime (crashes, wrong transcripts) → **voicebridge-debugging-playbook**
- What files/services exist and how they relate → **voicebridge-architecture-contract**
- What broke historically and why (v0.0.5 merge incident, 88ac97a) → **voicebridge-failure-archaeology**
- Editing GEMINI.md / PATTERNS.md / Project_Structure.md themselves → **voicebridge-docs-and-writing**; changing gate rules → **voicebridge-change-control**
- Running/extending the smoke test as a diagnostic tool (not its parameters) → **voicebridge-diagnostics-and-tooling** / **voicebridge-validation-and-qa**
- Chunk 3 TTS work or research topics → **voicebridge-chunk3-voice-clone-tts-campaign** / **voicebridge-research-frontier**

## Provenance and maintenance

Authored 2026-07-13 by skill-distill (retiring-fellow distillation). Line numbers cite the
2026-07-13 working tree; the two build.gradle.kts files had uncommitted edits that day (see
VOLATILE note, section 5) — re-verify them first.

One-line re-verification commands (run from `C:\Docs\Build\mananUtils\VoiceBridge`):

```powershell
# local.properties keys + template contract
Get-Content android\local.properties.template

# gitignore guard + not-tracked status
git check-ignore -v android/local.properties; git ls-files android/local.properties

# credential-hygiene check location in the smoke test
Select-String -Path android\scripts\smoke-test.ps1 -Pattern "ls-files"

# buildConfigField + lint + versionName/compileSdk current state
Select-String -Path android\app\build.gradle.kts -Pattern "buildConfigField|abortOnError|versionName|compileSdk"

# smoke test parameter defaults
Select-String -Path android\scripts\smoke-test.ps1 -Pattern '^\s*\[(switch|string)\]'

# gradle.properties knobs
Get-Content android\gradle.properties

# pinned Gradle / AGP / Kotlin versions
Select-String -Path android\gradle\wrapper\gradle-wrapper.properties -Pattern distributionUrl; Get-Content android\build.gradle.kts

# uncommitted-migration volatility check
git status --short android/

# hook installed on this clone?
Test-Path .git\hooks\post-commit

# python flag conventions still hold
Select-String -Path scripts\*.py -Pattern "add_argument"

# blank-key error strings still match smoke-test predicates
Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\*.kt -Pattern "GCP_STT_API_KEY is not set"
```
