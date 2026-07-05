# Research: Agentic Framework Governance & Spec Kit Adoption

As-built record — decisions reconstructed 2026-07-05 from v0.0.1 and v0.0.5 history,
`PATTERNS.md`, and commit 9fdd075.

## Decision 1 — Python-only maintenance scripts

**Choice**: all hygiene/maintenance scripts are Python with `argparse`, `--dry-run`, and
`--model` bypass flags (`PATTERNS.md:7-9,28`).
**Why**: cross-platform (Windows/macOS/Linux) and CI/CRON-safe without a shell dependency.
**Rejected**: Bash/PowerShell for maintenance scripts — permitted only where a Python runtime
is prohibited (`PATTERNS.md:7`). Note the *Android* smoke test (spec 005) is deliberately
PowerShell because it drives Windows-hosted adb/emulator tooling — an accepted, documented
exception in that capability, not this one.

## Decision 2 — Machine-verified changelog instead of trust

**Choice**: `Project_Structure.md`'s Changelog table is parsed and diffed against the real
file tree by `scripts/verify_structure.py:14-39,52-76`; drift fails the gate.
**Why**: "log every file immediately" (`GEMINI.md:12`) is only credible if enforced; the gate
also runs inside the smoke test (`android/scripts/smoke-test.ps1:163-172`), so releases cannot
ship with an unlogged file.
**Rejected**: manual review of the map — the exact failure mode (silent drift) the framework
exists to prevent.

## Decision 3 — Dynamic Gemini model selection

**Choice**: Gemini-backed scripts query `client.models.list()` and pick from live models, with
`--model` as an automation bypass and a hard fallback (`scripts/generate_bootstrap_prompt.py:13-38`).
**Why**: prevents breakage when model IDs are deprecated (`PATTERNS.md:8`).
**Rejected**: hardcoded model strings.

## Decision 4 — GitHub Spec Kit as the 80/20 planning implementation (v0.0.5)

**Choice**: adopt Specify CLI v0.12.5 with dual integrations — Claude Code skills
(`.claude/skills/speckit-*`) and Gemini CLI commands (`.gemini/commands/speckit.*.toml`) — and
persist planning artifacts in `specs/NNN-*/` (`GEMINI.md:53-56`).
**Why**: the 80/20 methodology previously produced planning output that died with the session;
Spec Kit makes the 80% durable and reviewable.
**Rejected**: continuing with ad-hoc `bootstrap_prompts/` as the only planning artifact (the
generator remains available but is no longer the primary planning path).

## Decision 5 — Constitution distillation, never a second constitution

**Choice**: `.specify/memory/constitution.md` is generated as a distillation of `GEMINI.md` +
`PATTERNS.md` with an explicit precedence header; it "never introduces rules of its own"
(`.specify/memory/constitution.md:3-5,43`; `PATTERNS.md:16`).
**Why**: two sources of governance truth would fork; agents already treat `GEMINI.md` as
supreme.
**Rejected**: writing a standalone Spec Kit constitution (the Specify CLI default) — would
drift from `GEMINI.md`.

## Decision 6 — Directory-level mapping for Spec Kit payload (v0.0.5)

**Choice**: exclude `.specify/`, `.claude/`, `.gemini/`, `specs/` (and gitignored local
Android build outputs) from the structure gate (`scripts/verify_structure.py:64-75`), mapping
them as single rows in `Project_Structure.md:18-21`.
**Why**: the toolkit payload is ~40 vendored files that would bloat the Changelog table with
no navigational value; local build outputs made the gate machine-dependent.
**Rejected**: file-by-file logging of vendored toolkit content.
