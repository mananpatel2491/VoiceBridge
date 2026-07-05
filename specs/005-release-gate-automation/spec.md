# Feature Specification: Release Gate Automation (Smoke Test + Git Hook CI/CD)

**Feature Branch**: `retro/005-release-gate-automation` (as-built record — no branch created)

**Created**: 2026-07-05

**Status**: Shipped (v0.0.3; hook `-Build` fix in the v0.0.4 cycle, commit 88ac97a)

**Input**: retro-spec conversion of v0.0.3 (commit 93d1549 — smoke test, CI/CD hook, script
infrastructure) + commit 88ac97a (hook passes `-Build` on release commits)

## Why

VoiceBridge has no cloud CI — the dev machine IS the pipeline. Before v0.0.3, "does the app
still work" was a manual phone ritual. This capability codifies that ritual as a single
repeatable command (`android/scripts/smoke-test.ps1`) that builds, boots an emulator, drives
the real UI through every chunk's flow with screenshot evidence, and scans for crashes — and
wires it into git so that every commit on a version branch is smoke-tested, and a commit
that updates `CHANGELOG.md` (the release signal) is additionally auto-merged to `main` and
pushed. The smoke test is the authoritative definition of "done" for a version
(`PATTERNS.md:41`; constitution Principle IV).

## User Scenarios & Testing

### User Story 1 - One-command verification (Priority: P1)

A developer (or agent) runs one command and gets a pass/fail verdict on the full
Record → Stop → Play → Transcribe → Translate flow, with per-step screenshots for diagnosis.

**Why this priority**: The gate everything else depends on; also the constitution's
definition of done.

**Independent Test**: `powershell -File android/scripts/smoke-test.ps1 -Build` on a machine
with SDK + AVD → green summary and a screenshot folder; introduce a UI regression (rename a
button) → red summary naming the missing element.

**Acceptance Scenarios**:

1. **Given** a healthy build, **When** the smoke test runs, **Then** it executes steps 0–10:
   credential hygiene, `verify_structure.py`, optional `assembleDebug`, emulator ensure,
   install + programmatic mic grant, launch, initial-state assertions, record/stop/play,
   transcribe-without-key, translate flow, logcat crash scan + foreground check
   (`android/scripts/smoke-test.ps1:150-359`).
2. **Given** any step failure, **When** the run ends, **Then** failures are accumulated (not
   fail-fast) and reported together with the screenshot directory, exit 1
   (`android/scripts/smoke-test.ps1:74,368-375`).
3. **Given** UI drift, **When** elements are located, **Then** taps resolve from a live
   `uiautomator dump` by `@text`/`@content-desc` — never pixel coordinates
   (`android/scripts/smoke-test.ps1:79-117`; pattern `PATTERNS.md:42`).

---

### User Story 2 - Auto-merge on release commit (Priority: P1)

When the developer commits an update to `CHANGELOG.md` on a `vX.Y.Z` branch (the release
signal), the hook builds fresh, smoke-tests, and on pass merges `--no-ff` to `main` and
pushes both branches; on fail it stays on the branch.

**Why this priority**: Removes the human step where a broken build could be merged; encodes
the version-branch workflow (`PATTERNS.md:33-37`).

**Independent Test**: On a `vX.Y.Z` branch, commit a `CHANGELOG.md` change — observe
`>>> [post-commit] CHANGELOG.md updated -- build + smoke test + auto-merge to main...`; on a
non-version branch, observe silence (hook no-ops).

**Acceptance Scenarios**:

1. **Given** a commit on a branch NOT matching `^v[0-9]+\.[0-9]+\.[0-9]+$`, **When** the
   hook fires, **Then** it exits immediately (`android/scripts/hooks/post-commit:14-17`).
2. **Given** a version-branch commit that does NOT touch `CHANGELOG.md`, **When** the hook
   fires, **Then** it runs the smoke test WITHOUT `-Build`/`-AutoMerge` (intermediate
   commit; no merge) (`android/scripts/hooks/post-commit:26-30`).
3. **Given** a version-branch commit that touches `CHANGELOG.md`, **When** the hook fires,
   **Then** it runs `smoke-test.ps1 -Build -AutoMerge` (fresh APK — the 88ac97a fix), and on
   pass the script checks out `main`, merges `--no-ff`, and pushes `main` + the branch
   (`android/scripts/hooks/post-commit:31-41`; `android/scripts/smoke-test.ps1:377-407`).
4. **Given** a merge conflict, **When** auto-merge fails, **Then** the script checks the
   feature branch back out so the developer can fix it
   (`android/scripts/smoke-test.ps1:392-397`).

---

### User Story 3 - Reinstallable hooks on any clone (Priority: P2)

Because `.git/hooks/` is untracked, a fresh clone can restore the pipeline with one command.

**Why this priority**: Without it the gate silently disappears on new machines.

**Independent Test**: Delete `.git/hooks/post-commit`, run
`powershell -File android/scripts/install-hooks.ps1`, confirm the file returns and prints
the workflow crib sheet.

**Acceptance Scenarios**:

1. **Given** hook templates in `android/scripts/hooks/`, **When** the installer runs,
   **Then** every template is copied into `.git/hooks/` with a per-file confirmation
   (`android/scripts/install-hooks.ps1:27-32`).

### Edge Cases

- **`local.properties` accidentally tracked**: step 0 fails the run with removal
  instructions (`android/scripts/smoke-test.ps1:155-161`) — secrets gate.
- **Python absent**: `verify_structure.py` step is skipped with a warning, not failed
  (`android/scripts/smoke-test.ps1:164-172`).
- **No booted emulator**: boots `voicebridge_avd` headless-ish (`-no-snapshot-load
  -no-boot-anim`, minimized window) and polls `sys.boot_completed` up to ~3 min
  (`android/scripts/smoke-test.ps1:188-200`).
- **Cold-boot ANR dialog**: transient "isn't responding / keeps stopping" dialogs are
  detected in the UI dump and dismissed before assertions
  (`android/scripts/smoke-test.ps1:84-97`).
- **adb stderr noise**: `$ErrorActionPreference = "Continue"` + stderr suppression in the
  `Adb` wrapper so routine adb chatter can't abort the run
  (`android/scripts/smoke-test.ps1:55-57,77`).
- **No API key in CI**: transcribe/translate steps accept EITHER a result card OR an error
  card — flow-fires-without-crash is the assertion (see specs 003/004).
- **Non-ASCII in the script**: deliberately ASCII-only because Windows PowerShell 5.1 reads
  `.ps1` as ANSI (`android/scripts/smoke-test.ps1:28`).

## Requirements

### Functional Requirements

- **FR-001**: The smoke test MUST gate on credential hygiene (untracked
  `local.properties`) and structure integrity (`verify_structure.py`) before any build
  (`android/scripts/smoke-test.ps1:150-173`).
- **FR-002**: UI element location MUST use `uiautomator dump` XPath over `@text` /
  `@content-desc` — pixel coordinates are prohibited; selectors are a maintained contract
  with `MainActivity.kt` labels (`android/scripts/smoke-test.ps1:23-26,101-117`;
  `PATTERNS.md:42`).
- **FR-003**: The enabled/disabled matrix MUST be asserted via Compose semantics propagated
  into the accessibility tree: initial (Record on; Stop/Play/Translate off), recording
  (Stop on/Record off), stopped (Play/Transcribe on)
  (`android/scripts/smoke-test.ps1:128-140,215-269`).
- **FR-004**: Every step MUST save a numbered screenshot to
  `android/app/build/smoke-<timestamp>/` (gitignored)
  (`android/scripts/smoke-test.ps1:142-148`; `PATTERNS.md:43`).
- **FR-005**: The run MUST fail unconditionally on `FATAL EXCEPTION` / `E AndroidRuntime`
  in logcat or if the app is not the foreground activity at the end
  (`android/scripts/smoke-test.ps1:346-359`; `PATTERNS.md:44`).
- **FR-006**: The post-commit hook MUST act only on `vX.Y.Z` branches; `CHANGELOG.md` in
  the commit is the sole auto-merge trigger (`android/scripts/hooks/post-commit:14-24`).
- **FR-007**: Release-commit runs MUST build a fresh APK (`-Build`) before judging
  (commit 88ac97a; `android/scripts/hooks/post-commit:33-34`).
- **FR-008**: `-AutoMerge` MUST re-verify the branch name pattern before merging, and MUST
  push both `main` and the version branch on success
  (`android/scripts/smoke-test.ps1:380-405`).
- **FR-009**: Hooks MUST be reinstallable from tracked templates via
  `install-hooks.ps1` (`android/scripts/install-hooks.ps1`; `PATTERNS.md:36`).
- **FR-010**: Lint MUST warn without blocking (`abortOnError=false`, HTML report) — the
  smoke test, not lint, is the quality gate (`android/app/build.gradle.kts:44-50`, added
  v0.0.3).

### Key Entities

- **Smoke run artifact dir**: `android/app/build/smoke-<yyyyMMdd-HHmmss>/` — numbered PNGs +
  `ui.xml` dumps (primary debugging artifact, `PATTERNS.md:43`).
- **Hook template**: `android/scripts/hooks/post-commit` (sh, LF-only, ASCII) → installed
  copy in `.git/hooks/`.
- **Release signal**: a commit on `vX.Y.Z` touching `CHANGELOG.md`.

## Success Criteria

- **SC-001**: Every release since v0.0.3 (v0.0.3, v0.0.4) merged to `main` via a passing
  hook-triggered smoke run — evidenced by merge commits `adebdbb` ("Merge v0.0.3 into
  main") and `6ddef50` ("Merge v0.0.4 into main") matching the script's
  `"Merge $branch into main"` message format (`android/scripts/smoke-test.ps1:392`).
- **SC-002**: A full smoke run produces ≥7 step screenshots (launch, initial-state,
  recording, stopped, playback, transcribe-result, translate-result) and exits 0
  (`Save-Shot` call sites across steps).
- **SC-003**: Regressions in button labels/state are caught without a device-farm: selector
  and semantics assertions fail loudly with the offending element named
  (`android/scripts/smoke-test.ps1:111-140`).

## Assumptions

- Dev machine: Windows with Android SDK at `C:\Android`, JDK 17 at the Eclipse Adoptium
  default path, an AVD named `voicebridge_avd` (all overridable via parameters,
  `android/scripts/smoke-test.ps1:47-53`).
- `origin` is reachable and writable when auto-merge fires (it pushes both branches).
- Windows PowerShell 5.1 semantics (ANSI `.ps1` reading, adb-stderr behavior) — the script
  is written defensively for exactly this host.
- Single-developer repo: auto-merge assumes no concurrent work on `main`.
