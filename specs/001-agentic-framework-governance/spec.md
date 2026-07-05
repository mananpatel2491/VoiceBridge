# Feature Specification: Agentic Framework Governance & Spec Kit Adoption

**Feature Branch**: `retro/001-agentic-framework-governance` (as-built record — no branch created)

**Created**: 2026-07-05

**Status**: Shipped (v0.0.1, v0.0.5)

**Input**: retro-spec conversion of v0.0.1 (AVF Director-layer scaffold + agentic maintenance skills) and v0.0.5 (GitHub Spec Kit adoption)

## Why

VoiceBridge is built "vibe-coding" style by an AI Lead Agent under a human Director. Without
durable, repo-resident governance, every session re-litigates design decisions and loses
architectural context ("context rot"). This capability is the Director layer itself: a
constitution (`GEMINI.md`), a pattern registry (`PATTERNS.md`), a self-verifying architecture
map (`Project_Structure.md` + `scripts/verify_structure.py`), agentic maintenance scripts, and
— since v0.0.5 — the GitHub Spec Kit chain that turns the framework's 80/20 planning phase
into durable `specs/NNN-*/` artifacts.

## User Scenarios & Testing

### User Story 1 - Session bootstrap with full architectural context (Priority: P1)

A fresh agent session reads `GEMINI.md`, `PATTERNS.md`, and `Project_Structure.md` and can
navigate the codebase and inherit all prior decisions without the Director re-explaining them.

**Why this priority**: Context-rot prevention is the framework's reason to exist; every other
capability is developed through this loop.

**Independent Test**: Open a new agent session, ask it to locate the STT client and the audio
format contract using only the three governance docs; it should land on `SttService.kt` and
PATTERNS.md §2 without a codebase-wide search.

**Acceptance Scenarios**:

1. **Given** a fresh clone, **When** the agent reads `Project_Structure.md`, **Then** every
   application file is listed with a functional description (Application Layer table,
   `Project_Structure.md:23-50`) and a Pipeline Stage Registry maps each voice-pipeline stage
   to its current implementation (`Project_Structure.md:52-61`).
2. **Given** any file addition or removal, **When** `python scripts/verify_structure.py` runs,
   **Then** it exits non-zero listing files missing from the Changelog table
   (`scripts/verify_structure.py:78-84`) and exits 0 when all files are accounted for
   (`scripts/verify_structure.py:86-87`).

---

### User Story 2 - Spec-driven feature workflow (Priority: P2)

Any feature beyond a trivial fix runs the Spec Kit chain (specify → clarify → plan → tasks →
implement), producing durable artifacts under `specs/NNN-*/`, gated by a constitution
distillation.

**Why this priority**: Adopted in v0.0.5 as the concrete implementation of the 80/20
planning-first methodology (`GEMINI.md:53-56`); it governs all future work but arrived after
the app chunks shipped.

**Independent Test**: Run `/speckit-specify` (Claude Code) or `/speckit.specify` (Gemini CLI)
in-repo; a numbered `specs/NNN-*/spec.md` is produced from `.specify/templates/spec-template.md`.

**Acceptance Scenarios**:

1. **Given** the repo root, **When** listing Spec Kit integrations, **Then** ten Claude Code
   skills exist under `.claude/skills/speckit-*/` and ten Gemini CLI commands under
   `.gemini/commands/speckit.*.toml` (shipped in commit 9fdd075, v0.0.5).
2. **Given** a plan is produced, **When** its Constitution Check runs, **Then** it gates
   against `.specify/memory/constitution.md`, which declares `GEMINI.md` supreme on conflict
   (`.specify/memory/constitution.md:3-5`).

---

### User Story 3 - Agentic maintenance scripts (Priority: P3)

The agent runs Python hygiene scripts to keep the changelog, onboarding doc, and session
bootstrap prompts current, without manual bookkeeping.

**Why this priority**: Useful automation, but the repo functions without the Gemini-backed
scripts (only `verify_structure.py` is load-bearing as a gate).

**Independent Test**: `python scripts/verify_structure.py --dry-run` prints
`[DRY RUN] Verification mode active (read-only).` and performs the read-only check
(`scripts/verify_structure.py:95-97`).

**Acceptance Scenarios**:

1. **Given** an English intent string, **When**
   `python scripts/generate_bootstrap_prompt.py "<intent>"` runs with `GOOGLE_API_KEY` set,
   **Then** a structured session bootstrap prompt is generated with the three governance docs
   as context (`scripts/generate_bootstrap_prompt.py:40-49`).
2. **Given** no `--model` flag and a non-interactive stdin, **When** a Gemini-backed script
   selects a model, **Then** it queries the live model list and falls back to the default
   without blocking (`scripts/generate_bootstrap_prompt.py:13-38`) — the Non-Hardcoded LLM
   Selection pattern (`PATTERNS.md:8`).

### Edge Cases

- **Python missing on PATH**: the smoke test skips `verify_structure.py` with a warning rather
  than failing (`android/scripts/smoke-test.ps1:164-172`).
- **`google-genai`/`python-dotenv` not installed**: Gemini-backed scripts exit with an
  actionable install message instead of a traceback
  (`scripts/generate_bootstrap_prompt.py:5-11`).
- **Missing `GOOGLE_API_KEY`**: `generate_bootstrap_prompt.py` reports where it looked and
  aborts; when present, it prints only a masked confirmation
  (`scripts/generate_bootstrap_prompt.py:54-59`).
- **Gitignored local Android build outputs**: excluded from the structure gate so the gate
  stays green on machines with local builds (`scripts/verify_structure.py:68-75`, fixed in
  v0.0.5).
- **Explicit non-goal**: `bruno/collections/` and `terraform/{environments,modules}/` are
  seeded with `.gitkeep` only — the Bruno gate and IaC gate are declared but have no backend
  API or infrastructure to act on yet.

## Requirements

### Functional Requirements

- **FR-001**: The repo MUST carry a supreme constitution (`GEMINI.md`) codifying the five core
  lessons: context-first architecture map, pattern reference integrity, agentic maintenance
  skills, continuous Bruno API validation, and IaC + cost gating (`GEMINI.md:8-34`).
- **FR-002**: Every file addition/removal MUST be logged in the `Project_Structure.md`
  Changelog table, machine-verified by `scripts/verify_structure.py` (parse logic
  `scripts/verify_structure.py:14-39`).
- **FR-003**: `verify_structure.py` MUST exclude `.git`, `__pycache__`, `.env`,
  `bootstrap_prompts/`, `docs/`, the Spec Kit payload dirs (`.specify/`, `.claude/`,
  `.gemini/`, `specs/`), and gitignored local Android build outputs
  (`scripts/verify_structure.py:55-75`).
- **FR-004**: All maintenance scripts MUST be Python, `argparse`-based, with `--dry-run` and
  `--model` bypass flags for CI compatibility (`PATTERNS.md:7-9`;
  `scripts/verify_structure.py:90-93`).
- **FR-005**: The Spec Kit constitution (`.specify/memory/constitution.md`) MUST be a
  distillation of `GEMINI.md` + `PATTERNS.md` that never introduces its own rules; `GEMINI.md`
  wins on conflict (`GEMINI.md:56`; `.specify/memory/constitution.md:3-5,43`).
- **FR-006**: Features beyond trivial fixes MUST run the Spec Kit chain, with artifacts
  persisted in `specs/NNN-*/` (`GEMINI.md:54-55`).
- **FR-007**: Cross-layer traceability MUST be maintained in `Function_Mapping.md` whenever
  endpoints/pipeline stages change (`Function_Mapping.md:12-16`).

### Key Entities

- **Constitution (`GEMINI.md`)**: supreme operating procedure; five core lessons + domain
  context + protocols.
- **Constitution distillation (`.specify/memory/constitution.md`)**: Spec Kit-facing five Core
  Principles, v1.0.0, ratified 2026-07-05.
- **Pattern registry (`PATTERNS.md`)**: 6 sections — architectural, voice-pipeline, coding,
  git workflow, smoke test, tooling patterns.
- **Architecture map (`Project_Structure.md`)**: framework/application tables + Pipeline Stage
  Registry + Changelog table (the structure-gate source of truth).
- **Changelog table row**: `| Date | Action | Files Affected | Summary |` — column 3 is parsed
  by the gate.

## Success Criteria

- **SC-001**: `python scripts/verify_structure.py` exits 0 on a clean checkout — evidenced by
  the v0.0.5 commit message ("gate green (exit 0)", commit 9fdd075) and re-verified in this
  retro run.
- **SC-002**: Five delivered releases (v0.0.1–v0.0.5) each have a Changelog-table row in
  `Project_Structure.md:65-73` and (v0.0.2–v0.0.4) a Keep-a-Changelog entry in `CHANGELOG.md`.
- **SC-003**: Spec Kit is operational in both agent CLIs: 10 skills + 10 commands shipped
  (v0.0.5) with zero infra cost (tooling-only change).

## Assumptions

- Python 3 is available on the dev machine for `scripts/` (the smoke test degrades gracefully
  without it).
- Gemini-backed scripts assume a `GOOGLE_API_KEY` in env or `.env` (`requirements.txt:1-2`:
  `google-genai`, `python-dotenv`); `verify_structure.py` needs no credentials.
- The Bruno and Terraform gates apply only once a backend/API/infra exists; today the app is
  client-only against Google-hosted APIs.
