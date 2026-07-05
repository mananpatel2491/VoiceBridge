---
description: "As-built task record for the AVF governance framework + Spec Kit adoption"
---

# Tasks: Agentic Framework Governance & Spec Kit Adoption

As-built record — reconstructed 2026-07-05 from v0.0.1 (commit 1c056d4) and v0.0.5
(commit 9fdd075). `[X]` = shipped, with the shipping release; `[ ]` = genuinely open.

## Phase 1: Director-layer scaffold (US1)

- [X] T001 [US1] Author `GEMINI.md` constitution — five core lessons, VoiceBridge domain
  context, 80/20 protocol (v0.0.1)
- [X] T002 [US1] Author `PATTERNS.md` — architectural, voice-pipeline, coding, tooling
  patterns (v0.0.1)
- [X] T003 [US1] Author `Project_Structure.md` with Core Framework / Application tables,
  Pipeline Stage Registry, and Changelog table (v0.0.1)
- [X] T004 [US1] Author `Function_Mapping.md` traceability map + maintenance rules (v0.0.1)
- [X] T005 [P] [US1] Seed `bruno/` (README + collections/docs `.gitkeep`) and `terraform/`
  (README + environments/modules `.gitkeep`) gate directories (v0.0.1)
- [X] T006 [P] [US1] Add `README.md`, `LICENSE`, `docs/architecture_overview.html` (v0.0.1)

## Phase 2: Agentic maintenance skills (US3)

- [X] T007 [US3] Implement `scripts/verify_structure.py` — changelog↔tree gate, exit 0/1
  (v0.0.1)
- [X] T008 [P] [US3] Implement `scripts/generate_bootstrap_prompt.py` — prompt architect with
  dynamic model selection + masked key echo (v0.0.1)
- [X] T009 [P] [US3] Implement `scripts/optimize_changelog.py` — Gemini-backed changelog
  consolidation with `--dry-run` (v0.0.1)
- [X] T010 [P] [US3] Implement `scripts/update_getting_started.py` — onboarding doc updater
  (v0.0.1)
- [X] T011 [US3] `requirements.txt` (`google-genai`, `python-dotenv`) + `scripts/README.md`
  inventory (v0.0.1)

## Phase 3: Spec Kit adoption (US2)

- [X] T012 [US2] Initialize Specify CLI v0.12.5 payload: `.specify/` (templates, PowerShell
  helpers, workflows, integrations) (v0.0.5)
- [X] T013 [P] [US2] Install 10 Claude Code skills `.claude/skills/speckit-*/` and 10 Gemini
  CLI commands `.gemini/commands/speckit.*.toml` (v0.0.5)
- [X] T014 [US2] Seed `.specify/memory/constitution.md` as a GEMINI.md+PATTERNS.md
  distillation with explicit precedence header (v0.0.5)
- [X] T015 [US2] Codify the Spec-Driven Feature Workflow in `GEMINI.md:53-56`, `PATTERNS.md:16`,
  `README.md:169-171`; map rows in `Project_Structure.md:18-21` (v0.0.5)
- [X] T016 [US2] Fix `scripts/verify_structure.py` to exclude Spec Kit dirs + gitignored local
  Android build outputs; gate green (v0.0.5)

## Open follow-ups (genuinely pending)

- [X] T017 `GEMINI_Getting_Started.md` was mapped in `Project_Structure.md:12` but the file was
  never generated — ghost map row removed (also removed the ghost `bootstrap_prompts/` row;
  re-add a map row if/when `scripts/update_getting_started.py` is first run) (v0.0.7)
- [X] T018 `Function_Mapping.md` placeholder rows annotated as reserved-for-future-backend
  (status note + per-row "reserved (N/A today)" markers; file kept, not deleted) — replace
  with real rows when the first backend/API ships, per its own maintenance rules (v0.0.7)
- [ ] T019 Populate `bruno/collections/` with real collections when the first backend API
  ships (Bruno gate currently has nothing to validate)
- [ ] T020 Populate `terraform/environments|modules/` when the first infra-dependent feature
  ships (cost gate currently trivially $0/mo)
- [ ] T021 Regenerate `.specify/memory/constitution.md` next time `GEMINI.md`/`PATTERNS.md`
  materially change (standing rule, `.specify/memory/constitution.md:43`)
