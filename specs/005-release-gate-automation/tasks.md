---
description: "As-built task record for the smoke-test + git-hook release gate"
---

# Tasks: Release Gate Automation

As-built record — reconstructed 2026-07-05 from v0.0.3 (commit 93d1549) and hook fix
88ac97a. `[X]` = shipped with release; `[ ]` = genuinely open.

## Phase 1: Smoke test core (US1)

- [X] T001 [US1] `android/scripts/smoke-test.ps1` scaffold: params (Build/AutoMerge/AvdName/
  JavaHome/AndroidHome), Log/Fail accumulation, ASCII-only constraint (v0.0.3)
- [X] T002 [US1] Pre-flight gates: `local.properties` untracked check +
  `verify_structure.py` run with Python-absent SKIP path (v0.0.3)
- [X] T003 [US1] Build + emulator management: optional `assembleDebug`, AVD boot with
  `-no-snapshot-load -no-boot-anim`, `sys.boot_completed` poll (v0.0.3)
- [X] T004 [US1] Install + programmatic `pm grant RECORD_AUDIO` + monkey launch +
  screenshot-per-step (`Save-Shot`) (v0.0.3)
- [X] T005 [US1] UIAutomator helpers: `Get-Ui` (with ANR-dialog dismissal), `Get-Center`,
  `Tap-Element`, `Assert-Node`, `Assert-Enabled` via Compose semantics (v0.0.3)
- [X] T006 [US1] Chunk 0/1 walk: initial-state matrix, record/stop/play, transcribe-
  without-key error assertion (v0.0.3)
- [X] T007 [US1] Crash gate: logcat FATAL/AndroidRuntime scan + foreground-activity check
  (v0.0.3)
- [X] T008 [US1] Translate-flow step + initial Translate-disabled assertion (extended for
  Chunk 2) (v0.0.4)

## Phase 2: Git hook CI/CD (US2, US3)

- [X] T009 [US2] `android/scripts/hooks/post-commit`: version-branch guard, CHANGELOG
  detection, smoke-test routing, LF-only sh (v0.0.3)
- [X] T010 [US2] `-AutoMerge` path in smoke-test.ps1: branch re-validation,
  `merge --no-ff`, push main + branch, conflict rollback to branch (v0.0.3)
- [X] T011 [US3] `android/scripts/install-hooks.ps1`: template copier + workflow crib sheet
  (v0.0.3)
- [X] T012 [US2] Fix: release commits now run `-Build` so auto-merge never judges a stale
  APK (commit 88ac97a, v0.0.4 cycle)

## Phase 3: Supporting rails

- [X] T013 `lint{}` block in `android/app/build.gradle.kts`: abortOnError=false + HTML
  report — lint informs, smoke test gates (v0.0.3)
- [X] T014 `CHANGELOG.md` created (Keep-a-Changelog) as the release-signal file; Git
  Workflow + Smoke Test patterns registered in `PATTERNS.md` §4–5 (v0.0.3)

## Open follow-ups (genuinely pending)

- [ ] T015 `CHANGELOG.md` has no `[0.0.5]` entry — v0.0.5 (Spec Kit adoption) was released
  and merged manually (commit ba9bce5, message format differs from the hook's
  `Merge <branch> into main`), bypassing the documented auto-merge signal; changelog entry
  owed retroactively
- [ ] T016 Smoke test covers only the happy UI walk — no rotation, process-death, or
  permission-revocation scenarios (accepted gap at personal-app scale; record here so it is
  a choice, not an oversight)
- [ ] T017 Transcribe-result detection relies on `contains(@text,'Transcript')` matching
  the "Transcription complete." status line (`smoke-test.ps1:290-292`) — brittle if status
  copy changes; consider a dedicated content-desc like the transcript field's
- [ ] T018 Hook and script push to `origin` unconditionally on release pass — no offline
  mode; fails the release run when origin is unreachable
