# VoiceBridge Constitution

> **Precedence**: `GEMINI.md` is the Project Constitution of record for this repository.
> This file is its Spec Kit–facing distillation, consumed by the `/speckit.*` workflow.
> On any conflict, `GEMINI.md` (and `PATTERNS.md` for design decisions) wins.

## Core Principles

### I. Context-First Architecture Map
Before proposing any change, read `Project_Structure.md` and use its functional descriptions to decide how a feature lands. Every file addition or removal is logged in the Changelog table immediately — no deferred bookkeeping. Cross-layer integrity is tracked in `Function_Mapping.md`, updated whenever functions are added, changed, or deleted.

### II. Pattern Reference Integrity
Consult `PATTERNS.md` at the start of every session. Inherit prior design decisions instead of re-litigating them; never record aspirational designs — every pattern entry must reflect the actual codebase.

### III. Voice Pipeline Discipline
The product is a voice pipeline: Audio Capture → STT → (Translation) → LLM → TTS → Audio Output. Every stage sits behind a swappable provider interface — never call a vendor SDK from business logic. Streaming-first design, VAD gating of paid STT calls, and the PCM 16-bit / 16 kHz / mono audio contract are mandatory unless an exception is documented in `PATTERNS.md`. Latency budgets per hop are tracked in `Project_Structure.md`.

### IV. Gated Validation — NON-NEGOTIABLE
No backend API feature is complete until the Bruno pipeline is updated and passing; successful Bruno execution gates all commits (the only exception requires the exact acknowledgment string recorded in `PATTERNS.md`). For the Android app, `android/scripts/smoke-test.ps1 -Build` is the authoritative definition of "done" for a version: build gate, UIAutomator-driven UI flow (selectors resolved by text/content-desc, never pixel coordinates), screenshot-per-step, and an unconditional crash gate on logcat.

### V. Infrastructure-as-Code & Cost Gating
Every infra-dependent feature requires a Terraform update (GCP). Projected costs are calculated and `terraform plan` is reviewed before any GitHub tagging; tagging (which triggers deployment) is prohibited until cost and infra reviews are finalized. Development stays inside free tiers (GCP STT 60 min/mo, Translation 500K chars/mo).

## Operational Constraints

- **80/20 Surgical Strike**: 80% of a session is read-only planning, 20% execution; one testable change per session to prevent cascade damage. The Spec Kit chain (`specify → clarify → plan → tasks → implement`) is the concrete implementation of the planning phase — specs in `specs/NNN-*/` are the durable artifacts of the 80%.
- **Chunked Delivery**: The app is built in staged, individually-acceptance-tested chunks (Chunk 0 skeleton → 1 STT → 2 Translation → 3 voice-clone TTS → 4 real-time two-phone relay). A chunk ships only when its acceptance test in `README.md` passes.
- **Roles**: The Director (user) owns intent, arbitration, and final review. The Lead Agent owns autonomous reasoning, planning, and error-free execution.
- **Proactive hardening**: when touching an existing file, audit for security risks (injection, leaked secrets, audio data leakage) and resource/memory leaks; patch immediately.
- **Production readiness**: temporary/mock markers (`TODO: temp`, `fix later`) must be flagged to the Director before proceeding.
- **Secrets stay local**: API keys live in `android/local.properties` (gitignored) and are injected via `buildConfigField` — never committed.

## Development Workflow

- Version-branch git flow: work on a `vX.Y.Z` branch, never commit directly to `main`. Updating `CHANGELOG.md` is the release signal — the post-commit hook (installed by `android/scripts/install-hooks.ps1`) runs the smoke test and auto-merges to `main` on pass; non-CHANGELOG commits run the smoke test only.
- Commit convention: `feat:` / `fix:` / `chore:`; the release commit is `chore: vX.Y.Z`.
- Maintenance scripts in `scripts/` are Python, cross-platform, `argparse`-based with `--dry-run` support; run `verify_structure.py` after every feature. Tedious mechanical work may be delegated to the local Ollama instance to preserve API quota.
- Clarify ambiguous prompts before acting; if a line of code cannot be justified, it is not implemented.
- Start fresh sessions frequently to avoid context rot; durable memory lives in `Project_Structure.md`, `PATTERNS.md`, `GEMINI.md`, and `specs/`.

## Governance

This distillation is regenerated whenever `GEMINI.md` or `PATTERNS.md` materially changes. Amendments to the actual constitution happen in `GEMINI.md` under Director approval; this file never introduces rules of its own. All spec/plan/task artifacts produced by `/speckit.*` must be verified for compliance against the principles above.

**Version**: 1.0.0 | **Ratified**: 2026-07-05 | **Last Amended**: 2026-07-05
