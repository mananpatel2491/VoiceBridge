# Implementation Plan: Release Gate Automation (Smoke Test + Git Hook CI/CD)

**Branch**: `retro/005-release-gate-automation` | **Date**: 2026-07-05 | **Spec**: [spec.md](./spec.md)

**Input**: As-built reconstruction from v0.0.3 (commit 93d1549) and the hook fix 88ac97a
(v0.0.4 cycle).

## Summary

A ~400-line PowerShell smoke test (`android/scripts/smoke-test.ps1`) that is the repo's
entire CI/CD: pre-flight hygiene gates → optional `assembleDebug` → emulator ensure → adb
install with programmatic permission grant → UIAutomator-dump-driven UI walk of all shipped
chunks with per-step screenshots → logcat crash gate → optional `-AutoMerge` (checkout main,
`merge --no-ff`, push both branches). A POSIX-sh post-commit hook template routes commits:
version-branch + CHANGELOG touch = `-Build -AutoMerge`; version-branch only = smoke test;
other branches = no-op. `install-hooks.ps1` re-seeds `.git/hooks/` from tracked templates.

## Technical Context

**Language/Version**: Windows PowerShell 5.1 (ASCII-only source by design,
`smoke-test.ps1:28`); POSIX sh for the hook (Git for Windows runs hooks as sh, LF-only,
`hooks/post-commit:4`)

**Primary Dependencies**: adb + emulator from the Android SDK (`C:\Android` default), JDK 17
(Adoptium default path), `uiautomator` on-device, git CLI; Python optional (structure gate
step degrades to SKIP)

**Storage**: screenshot/dump artifacts under `android/app/build/smoke-<timestamp>/`
(gitignored); no persistent state

**Testing**: self-testing by construction — this IS the test harness; its own failure modes
are accumulated via `Fail()` and reported in the summary block (`smoke-test.ps1:70-74,361-375`)

**Target Platform**: Windows dev machine driving an Android emulator (AVD `voicebridge_avd`)
or attached device

**Project Type**: dev tooling / local CI-CD

**Performance Goals**: full run ≈ build time + emulator boot (≤3 min poll,
`smoke-test.ps1:195-199`) + ~30 s UI walk

**Constraints**: $0/mo — no cloud CI by deliberate choice; must run non-interactively from a
git hook (`-NonInteractive`, programmatic permission grant)

**Scale/Scope**: 1 script + 1 hook + 1 installer; 11 test steps; 5 UI elements under
assertion

## Constitution Check

Gated against `.specify/memory/constitution.md` (distillation of `GEMINI.md`, supreme).

- **I. Context-First Architecture Map — PASS.** All three files mapped
  (`Project_Structure.md:45-47`) and logged in the v0.0.3 Changelog rows
  (`Project_Structure.md:69-70`).
- **II. Pattern Reference Integrity — PASS.** This capability *authored* the Git Workflow
  and Smoke Test pattern sections in the same release (`PATTERNS.md:31-45`,
  `CHANGELOG.md:45-46`) — patterns recorded from shipped reality.
- **III. Voice Pipeline Discipline — PASS (indirect).** No pipeline code; the gate enforces
  the pipeline's UI truthfully (selector sync contract with `MainActivity.kt`,
  `smoke-test.ps1:26`) including the no-key error paths that keep API-format failures
  visible.
- **IV. Gated Validation — PASS (this IS the gate).** `smoke-test.ps1 -Build` is the
  constitution's authoritative definition of done for a version
  (`.specify/memory/constitution.md:19`; `PATTERNS.md:41`). Bruno remains N/A (no repo
  backend). PowerShell instead of Python is the documented exception to the
  cross-platform-scripts pattern: the script drives Windows-hosted adb/emulator/JDK paths
  and is invoked by a Windows hook host (see Complexity Tracking).
- **V. Infrastructure-as-Code & Cost Gating — PASS.** Zero infra: local emulator CI at
  $0/mo; the push step targets GitHub, not deployment (tagging/deploy gates remain unused —
  no tags exist yet by design).

## Project Structure

### Documentation (this feature)

```text
specs/005-release-gate-automation/
├── spec.md
├── plan.md              # this file
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
└── contracts/
    └── release-gate-contract.md
```

### Source Code (repository root)

```text
android/scripts/
├── smoke-test.ps1             # 11-step gate + -AutoMerge release flow  (v0.0.3; translate step v0.0.4)
├── install-hooks.ps1          # re-seed .git/hooks from templates       (v0.0.3)
└── hooks/
    └── post-commit            # sh router: version-branch → smoke test,
                               # CHANGELOG touch → -Build -AutoMerge     (v0.0.3; -Build fix 88ac97a)
android/app/build.gradle.kts   # lint{} block: abortOnError=false        (v0.0.3)
CHANGELOG.md                   # created as the release-signal file      (v0.0.3)
```

**Structure Decision**: test tooling lives under `android/scripts/` (app-scoped, unlike the
repo-level Python `scripts/`) because it is inseparable from the Android SDK toolchain; hook
templates are tracked next to the installer so the untracked `.git/hooks/` is always
reconstructible.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| PowerShell script despite the "Python for maintenance scripts" pattern (`PATTERNS.md:7`) | Drives Windows-pathed adb/emulator/gradlew.bat and is invoked by a Windows hook host; interop (Start-Process, exit-code plumbing, `[xml]` XPath) is native here | A Python port would still shell out to the same Windows binaries — portability gain is illusory while the AVD/JDK paths are Windows-only; the pattern itself scopes the exception ("specialized, hardened environments") |
| Auto-merge pushes to origin from a local hook | Single-developer repo; the push completes the release signal so main is never ahead locally | Manual push was the status quo the capability exists to remove; conflict path safely returns to the branch |
