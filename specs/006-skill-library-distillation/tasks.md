---
description: As-built task record — skill library distillation (v0.0.8)
---

# Tasks: Agent Skill Library (Repo-Discipline Distillation)

As-built record — reconstructed 2026-07-13 from the skill-distill run shipped in v0.0.8.
`[X]` = shipped with release; `[ ]` = genuinely open.

## Phase 1 — Discovery (read-only)

- [X] T001 Read the full repo: governance docs, all 6 Kotlin sources, smoke-test/hook
  machinery, scripts/, specs 001–005, git history v0.0.1–v0.0.7 (v0.0.8)
- [X] T002 Director decisions captured: full run approved; campaign target = Chunk 3
  voice-clone TTS; leave uncommitted gradle migration untouched; ship as full v0.0.8
  release (v0.0.8, 2026-07-13)

## Phase 2 — Authoring (14 parallel agents, one skill each)

- [X] T003 [P] voicebridge-change-control (v0.0.8)
- [X] T004 [P] voicebridge-debugging-playbook (v0.0.8)
- [X] T005 [P] voicebridge-failure-archaeology (v0.0.8)
- [X] T006 [P] voicebridge-architecture-contract (v0.0.8)
- [X] T007 [P] voicebridge-audio-pipeline-reference (v0.0.8)
- [X] T008 [P] voicebridge-gcp-speech-apis-reference (v0.0.8)
- [X] T009 [P] voicebridge-config-and-flags (v0.0.8)
- [X] T010 [P] voicebridge-build-and-env (v0.0.8)
- [X] T011 [P] voicebridge-release-gate-runbook (v0.0.8)
- [X] T012 [P] voicebridge-diagnostics-and-tooling incl. tested `inspect_wav.py` +
  `grab_diag.ps1` (v0.0.8)
- [X] T013 [P] voicebridge-validation-and-qa (v0.0.8)
- [X] T014 [P] voicebridge-docs-and-writing (v0.0.8)
- [X] T015 [P] voicebridge-chunk3-voice-clone-tts-campaign incl. dated provider survey
  reference (v0.0.8)
- [X] T016 [P] voicebridge-research-frontier (v0.0.8)

## Phase 3 — Review & fix

- [X] T017 [P] Factual review — empirically verified commands/paths/claims; found the
  PowerShell 5.1 `>` binary-corruption trap in 4 skills (v0.0.8)
- [X] T018 [P] Doctrine review — contradiction/overreach hunt vs GEMINI.md + PATTERNS.md
  (v0.0.8)
- [X] T019 [P] Usability review — trigger quality, duplication ownership, description caps
  (v0.0.8)
- [X] T020 Fixer applied 19/19 blocking+important findings + safe minors; final YAML pass
  over all 24 SKILL.md files; found and fixed 1 latent frontmatter defect (v0.0.8)

## Phase 4 — Docs of record & release

- [X] T021 specs/006 as-built spec set (this folder) (v0.0.8)
- [X] T022 CHANGELOG `[0.0.8]` entry + Project_Structure.md changelog row (v0.0.8)
- [X] T023 Release via the repo's own gate: v0.0.8 branch, `chore: v0.0.8` commit →
  post-commit hook → smoke test → auto-merge + push (v0.0.8)

## Open follow-ups

- [ ] T024 Regenerate `references/provider-survey-2026-07-13.md` when Chunk 3 actually
  starts (provider facts drift; filename carries the date for staleness visibility)
- [ ] T025 When button labels/screens change, sweep skill KEEP-IN-SYNC references along
  with the smoke-test selectors (release-gate-runbook owns the contract table)
- [ ] T026 When the first backend ships, author a Bruno/backend operations skill and
  activate the dormant Bruno-gate content in voicebridge-change-control
- [ ] T027 The uncommitted AGP built-in-Kotlin migration (two build.gradle.kts files)
  remains in the working tree — decide, commit or discard; skills mark it volatile
