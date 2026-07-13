# Feature Specification: Agent Skill Library (Repo-Discipline Distillation)

**Feature Branch**: `retro/006-skill-library-distillation` (as-built record — shipped on the `v0.0.8` branch with the capability itself)

**Created**: 2026-07-13

**Status**: Shipped (v0.0.8 — same release as this spec set)

**Input**: retro-spec conversion of the skill-distill run of 2026-07-13 (14 `voicebridge-*`
skills authored under `.claude/skills/` by parallel agents, verified by a
factual/doctrine/usability reviewer panel, fixed by a fixer pass)

## Why

VoiceBridge's working discipline — the release gate, the audio contract, the GCP call
shapes, the incident history, the docs bookkeeping — lived partly in governance docs
(`GEMINI.md`, `PATTERNS.md`) and partly in the head of whichever strong model or engineer
last worked here. A junior engineer or a smaller AI model dropped into this repo could read
the constitution but not *operate*: they would not know that a failed transcribe with a
blank key is a **passing** CI outcome, that the 44-byte WAV header is written *after*
recording stops, or that pulling a WAV with PowerShell 5.1 `>` silently corrupts it. This
capability distills that operational knowledge into 14 self-contained, trigger-routed
skills under `.claude/skills/voicebridge-*/`, auto-discovered by Claude Code when working
in-repo, so the project can be debugged, extended, validated, and advanced without its
original authors.

## User Scenarios & Testing

### User Story 1 - A smaller model ships a change safely (Priority: P1)

An engineer or model with zero VoiceBridge context needs to make a change and release it.
Loading `voicebridge-change-control` gives the classification table, branch/commit/gate
obligations, and the pre-commit checklist; `voicebridge-release-gate-runbook` explains what
the hook will do to their commit.

**Why this priority**: Change control is the discipline everything else protects; the v0.0.5
bypass incident (release merged with no CHANGELOG entry) is exactly the failure this
prevents.

**Independent Test**: Ask a fresh session "how do I release a version in this repo?" — it
should load `voicebridge-change-control` (its description names that trigger,
`.claude/skills/voicebridge-change-control/SKILL.md:3-15`) and answer with the version-branch
+ CHANGELOG-signal flow, not an invented one.

**Acceptance Scenarios**:

1. **Given** a pending change, **When** the skill is consulted, **Then** it classifies the
   change (docs-only / app code / infra-dependent / feature-needs-spec) and states the gates
   each class requires, with the GEMINI.md > PATTERNS.md > distillation precedence explicit
   (`.claude/skills/voicebridge-change-control/SKILL.md:20-28`).
2. **Given** the question "can I skip the smoke test?", **Then** the skill offers no route
   around the gate — the only sanctioned exception documented is the exact Bruno
   acknowledgment string from `PATTERNS.md:10`.

---

### User Story 2 - Debugging a failure without archaeology (Priority: P1)

A developer hits a failure (build, smoke test, STT 403, silent WAV) and needs the
discriminating experiment, not a guess. `voicebridge-debugging-playbook` maps symptom →
ranked causes → check command → fix; `voicebridge-failure-archaeology` explains which past
incident produced each rule.

**Why this priority**: Wrong-path debugging is the highest time cost for newcomers; the
playbook encodes traps that were empirically expensive (e.g. the PowerShell `>` binary
corruption that fakes a "header never written" diagnosis).

**Independent Test**: Simulate "my pulled recording starts with bytes FF FE and won't play" —
the playbook routes to the byte-safe two-step `/sdcard` pull before any app-code diagnosis.

**Acceptance Scenarios**:

1. **Given** a recording pulled via `adb exec-out ... > file.wav` in PowerShell 5.1,
   **When** the playbook's WAV triage is followed, **Then** it requires a byte-safe re-pull
   first and only then header diagnosis via
   `.claude/skills/voicebridge-diagnostics-and-tooling/scripts/inspect_wav.py`.
2. **Given** a smoke-test "could not find UI element" failure, **Then** the playbook routes
   to the KEEP-IN-SYNC selector contract owned by `voicebridge-release-gate-runbook`.

---

### User Story 3 - Executing Chunk 3 (voice-clone TTS) as a campaign (Priority: P2)

When Chunk 3 starts, `voicebridge-chunk3-voice-clone-tts-campaign` provides numbered,
decision-gated phases: constitution constraints first (cost gate, provider-interface
pattern, audio contract), a date-stamped ranked provider survey
(`references/provider-survey-2026-07-13.md`), a spike protocol with measurable acceptance,
integration gates, and promotion through change control — with wrong paths explicitly
fenced (vendor SDK in business logic, breaking the 16 kHz mono contract, committing family
voice samples).

**Why this priority**: Chunk 3 is the hardest live problem (Director decision 2026-07-13)
but is not yet in progress.

**Independent Test**: The campaign's Phase 0 gates are checkable today: PATTERNS.md §2
requires a provider interface; GEMINI.md rule 5 requires the cost gate before tagging.

**Acceptance Scenarios**:

1. **Given** the campaign is opened, **Then** every provider claim is labeled
   candidate/unproven and date-stamped 2026-07-13 (provider facts drift).
2. **Given** a spike, **Then** scratch artifacts land in `$env:TEMP\vb-spike-tts\`, never in
   the repo tree (`scripts/verify_structure.py` walks the disk tree regardless of git
   tracking — `scripts/verify_structure.py:52-76`).

---

### User Story 4 - Measuring instead of eyeballing (Priority: P3)

`voicebridge-diagnostics-and-tooling` ships two executable scripts:
`scripts/inspect_wav.py` (header parse + contract check + header-not-written detection,
exit codes 0/1/2) and `scripts/grab_diag.ps1` (one-shot ADB evidence collector).

**Independent Test**: `python .claude/skills/voicebridge-diagnostics-and-tooling/scripts/inspect_wav.py <file> --json`
on a healthy recording returns the parsed header and exit 0; on a 44-zero-byte-prefixed
file reports "header-not-written".

## Edge Cases

- **Skill triggers on a repo that moved**: descriptions embed the repo path; the provenance
  sections carry re-verification one-liners for drift-prone facts.
- **Pre-existing `speckit-*` skills**: the library coexists with the 10 Spec Kit skills in
  the same directory; reviewers were scoped to `voicebridge-*` only.
- **Uncommitted working-tree state at authoring time**: the AGP built-in-Kotlin migration
  edits to the two `build.gradle.kts` files were present but uncommitted; the gate later
  proved them load-bearing and they shipped in this release (see Assumptions and
  tasks.md Phase 5).
- **Known-unhandled (non-goals)**: no skill automates its own regeneration; no skill covers
  a backend (none exists — `Function_Mapping.md:5-9` is reserved-for-future-backend).

## Requirements

- **FR-001**: The library MUST consist of exactly 14 skills named `voicebridge-*` under
  `.claude/skills/`, each a directory with a `SKILL.md` bearing valid YAML frontmatter
  (`name`, `description` ≤ 1024 chars).
- **FR-002**: Every skill description MUST state when to load it AND when NOT to (sibling
  routing), so smaller models trigger the right skill.
- **FR-003**: Every operational claim (command, flag, path, error string, line citation)
  MUST be verified against the repo at authoring time; volatile facts MUST be date-stamped
  2026-07-13; every skill MUST end with a "Provenance and maintenance" section carrying
  re-verification commands.
- **FR-004**: No skill may document a route around change control; the only sanctioned
  exception is the Bruno acknowledgment string (`PATTERNS.md:10`).
- **FR-005**: Unshipped/unproven material (provider interfaces, VAD, streaming, all Chunk 3
  provider claims) MUST be labeled open/candidate — never presented as existing behavior.
- **FR-006**: Shipped scripts MUST be executable as delivered (`inspect_wav.py` pure stdlib
  with `--json`; `grab_diag.ps1` ASCII-only for PowerShell 5.1) and tested before shipping.
- **FR-007**: The library MUST pass a three-lens review (factual, doctrine, usability) with
  all blocking and important findings applied before commit.

## Key Entities

- **Skill**: a directory `.claude/skills/<name>/` with `SKILL.md` (+ optional `scripts/`,
  `references/`). Full anatomy in [data-model.md](./data-model.md).
- **Campaign**: the executable, decision-gated variant (chunk3-voice-clone-tts) with phases,
  gates, and fenced wrong paths.
- **Diagnostic script**: executable tooling shipped inside a skill's `scripts/` dir.

## Success Criteria

- **SC-001**: 14/14 skills authored and present on disk (verified 2026-07-13; 17 files,
  ~340 KB total including 2 scripts and 1 reference survey).
- **SC-002**: Review pass produced 30 findings (19 blocking/important); all 19 applied,
  0 rejected outright; 1 latent YAML defect found and fixed in the final pass; all 24
  SKILL.md files in the directory (14 new + 10 speckit) parse with valid frontmatter.
- **SC-003**: The blocking find — PowerShell 5.1 `>` corrupting `adb exec-out` binary
  output — was *empirically demonstrated* on this machine (32,044-byte file became
  64,094 bytes with FF FE BOM) and purged from all 4 affected recipes.
- **SC-004**: `scripts/verify_structure.py` stays green with the library present
  (`.claude` is excluded at directory level — `scripts/verify_structure.py:66`).

## Assumptions

- Claude Code auto-discovers in-repo skills under `.claude/skills/` when a session works
  inside the repo (same mechanism as the existing `speckit-*` skills).
- Citations reference HEAD at commit 80b756f (v0.0.7) as of authoring. The AGP
  built-in-Kotlin migration, uncommitted at authoring time, was committed later in the
  same v0.0.8 release after the gate proved HEAD unbuildable without it (tasks.md
  Phase 5, failure-archaeology INC-6); skill volatile-notes were settled accordingly.
- The machine profile assumed by env-specific skills: JDK 17 Adoptium, SDK `C:\Android`,
  AVD `voicebridge_avd` — the same defaults parameterized in `android/scripts/smoke-test.ps1:47-53`.
