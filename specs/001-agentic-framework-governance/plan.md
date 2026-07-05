# Implementation Plan: Agentic Framework Governance & Spec Kit Adoption

**Branch**: `retro/001-agentic-framework-governance` | **Date**: 2026-07-05 | **Spec**: [spec.md](./spec.md)

**Input**: As-built reconstruction from v0.0.1 (commit 1c056d4) and v0.0.5 (commit 9fdd075).

## Summary

v0.0.1 scaffolded the AVF "Director layer": `GEMINI.md` constitution, `PATTERNS.md` registry,
`Project_Structure.md` map with a machine-verifiable Changelog table, `Function_Mapping.md`,
four Python maintenance scripts under `scripts/`, and placeholder `bruno/` + `terraform/`
gate directories. v0.0.5 layered GitHub Spec Kit on top (Specify CLI v0.12.5): `.specify/`
toolkit + templates, `.claude/skills/speckit-*` and `.gemini/commands/speckit.*.toml`
integrations, and a seeded constitution distillation at `.specify/memory/constitution.md`,
plus a `verify_structure.py` fix to exclude Spec Kit dirs and local Android build outputs.

## Technical Context

**Language/Version**: Python 3 (maintenance scripts); Markdown governance docs

**Primary Dependencies**: `google-genai`, `python-dotenv` (`requirements.txt:1-2`) — only for
the three Gemini-backed scripts; `verify_structure.py` is stdlib-only

**Storage**: none — governance state lives in tracked Markdown files

**Testing**: `scripts/verify_structure.py` (structure gate, also invoked by the smoke test at
`android/scripts/smoke-test.ps1:163-172`)

**Target Platform**: cross-platform dev machines (Windows primary); scripts are
Python-for-portability per `PATTERNS.md:7`

**Project Type**: repo governance / dev tooling

**Performance Goals**: N/A — offline doc tooling

**Constraints**: $0/mo (no infra; v0.0.5 explicitly "Tooling-only change: no infra, no cost")

**Scale/Scope**: 1 repo, 5 releases governed to date

## Constitution Check

Gated against `.specify/memory/constitution.md` (distillation of `GEMINI.md`, which is supreme).

- **I. Context-First Architecture Map — PASS.** This capability *implements* the principle:
  the Changelog table (`Project_Structure.md:63-73`) plus the `verify_structure.py` gate makes
  "no deferred bookkeeping" mechanically enforceable.
- **II. Pattern Reference Integrity — PASS.** `PATTERNS.md` was seeded in v0.0.1 and updated
  in the same commits that shipped behavior (e.g. Spec Kit distillation bullet,
  `PATTERNS.md:16`, shipped with v0.0.5).
- **III. Voice Pipeline Discipline — PASS (scoped).** No pipeline code in this capability; the
  discipline itself (provider seams, PCM contract, VAD) is codified here as governance text
  (`GEMINI.md:41-45`, `PATTERNS.md:18-24`) for the app capabilities to satisfy.
- **IV. Gated Validation — PASS (declared, gate seeded).** The Bruno rules and exception
  string are codified (`GEMINI.md:24-29`, `bruno/README.md`); `bruno/collections/` holds only
  `.gitkeep` because no backend API exists yet — the Android gate of record is the smoke test
  (spec 005).
- **V. Infrastructure-as-Code & Cost Gating — PASS.** `terraform/README.md` codifies the
  cost-gated deployment process; no infra-dependent feature has shipped, so
  `terraform/{environments,modules}/` remain `.gitkeep` placeholders and the posture is $0/mo.

## Project Structure

### Documentation (this feature)

```text
specs/001-agentic-framework-governance/
├── spec.md
├── plan.md              # this file
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
└── contracts/
    └── tooling-contract.md
```

### Source Code (repository root)

```text
GEMINI.md                          # constitution of record          (v0.0.1; Spec Kit section v0.0.5)
PATTERNS.md                        # pattern registry                (v0.0.1; Spec Kit bullet v0.0.5)
Project_Structure.md               # architecture map + changelog    (v0.0.1; Spec Kit rows v0.0.5)
Function_Mapping.md                # cross-layer traceability map    (v0.0.1)
README.md, LICENSE                 # onboarding + MIT               (v0.0.1)
requirements.txt                   # google-genai, python-dotenv     (v0.0.1)
docs/architecture_overview.html    # visual 1-pager                  (v0.0.1)
scripts/
├── README.md                      # skill inventory                 (v0.0.1)
├── verify_structure.py            # structure gate                  (v0.0.1; exclusions fixed v0.0.5)
├── generate_bootstrap_prompt.py   # prompt architect                (v0.0.1)
├── optimize_changelog.py          # Gemini changelog consolidation  (v0.0.1)
└── update_getting_started.py      # onboarding doc updater          (v0.0.1)
bruno/                             # API-validation gate (seeded)    (v0.0.1)
terraform/                         # IaC gate (seeded)               (v0.0.1)
.specify/                          # Spec Kit toolkit + templates    (v0.0.5)
.claude/skills/speckit-*/          # 10 Claude Code skills           (v0.0.5)
.gemini/commands/speckit.*.toml    # 10 Gemini CLI commands          (v0.0.5)
```

**Structure Decision**: governance lives at repo root as flat Markdown (agent-readable on
session start); tooling is segregated into `scripts/` (Python) and `.specify/`/`.claude/`/
`.gemini/` (Spec Kit payload, mapped at directory level and excluded from the structure gate).

## Complexity Tracking

No violations. The only non-obvious choice — excluding whole Spec Kit directories from the
structure gate instead of logging ~40 toolkit files row-by-row — is justified in
`scripts/verify_structure.py:64-66` (mapped at directory level in `Project_Structure.md:18-21`).
