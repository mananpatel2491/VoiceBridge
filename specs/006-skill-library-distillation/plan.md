# Implementation Plan: Agent Skill Library (Repo-Discipline Distillation)

**Branch**: `v0.0.8` | **Date**: 2026-07-13 | **Spec**: [spec.md](./spec.md)

## Summary

A three-phase skill-distill run produced the library: (1) read-only discovery of the whole
repo (governance docs, all 6 Kotlin sources, smoke-test/hook machinery, specs 001–005, git
history) plus four Director decisions (full run approved; Chunk 3 voice-clone TTS as the
campaign target; leave the uncommitted gradle migration untouched; ship as a full v0.0.8
release); (2) 14 parallel authoring agents, one skill each, writing only inside
`.claude/skills/<name>/`, every claim verified against the repo; (3) a three-reviewer panel
(factual / doctrine / usability) over the complete set followed by a single fixer applying
all blocking + important findings.

## Technical Context

- **Artifact type**: Markdown skills (YAML frontmatter + body) + 2 executable diagnostic
  scripts. No app code touched — the two `build.gradle.kts` working-tree edits predate this
  capability and were deliberately left uncommitted.
- **Consumers**: Claude Code sessions (auto-discovery of in-repo `.claude/skills/`), any
  agent or human reading Markdown.
- **Script runtimes**: `inspect_wav.py` — Python 3 stdlib only (argparse/json/struct/sys,
  `.claude/skills/voicebridge-diagnostics-and-tooling/scripts/inspect_wav.py:34-37`);
  `grab_diag.ps1` — Windows PowerShell 5.1, ASCII-only (same constraint the smoke test
  documents for itself, `android/scripts/smoke-test.ps1:28`).
- **Testing harness**: reviewer panel re-ran shipped scripts in scratch dirs; the release
  itself is gated by the repo's own smoke test via the post-commit hook.
- **Cost posture**: $0/mo — no infra, no new services; authoring cost was session tokens.

## Constitution Check

Gated against `.specify/memory/constitution.md` (distillation; `GEMINI.md` supreme):

- **I. Context-First Architecture Map — PASS.** Discovery read `Project_Structure.md`
  first; the library lands as a `.claude/` addition, which the map already carries at
  directory level (`Project_Structure.md:18`); the v0.0.8 changelog table row records the
  addition.
- **II. Pattern Reference Integrity — PASS.** Skills restate PATTERNS.md rules with
  citations rather than re-deciding them; doctrine review explicitly hunted contradictions
  with `GEMINI.md`/`PATTERNS.md`; the grounding rule (actual codebase, never aspirational)
  is enforced by FR-005 — unbuilt provider interfaces/VAD/streaming are labeled open.
- **III. Voice Pipeline Discipline — PASS (docs-only).** No pipeline code changed; the
  audio contract and provider-interface mandate are *documented* (architecture-contract,
  audio-pipeline-reference, campaign Phase 0) rather than altered.
- **IV. Gated Validation — PASS.** No backend → Bruno gate not applicable (collections
  still `.gitkeep` placeholders); the release commit runs the authoritative gate:
  post-commit hook → `smoke-test.ps1 -Build -AutoMerge`.
- **V. Infrastructure-as-Code & Cost Gating — PASS.** No infra-dependent feature; no
  tagging; $0/mo. The campaign skill *encodes* this gate for the future Chunk 3.

Operational constraints: 80/20 honored (discovery + review dwarfed writing); one testable
change (the library) in the release; secrets untouched (no key material appears in any
skill — API-testing recipes read the key from `local.properties` without echoing it).

## Project Structure

### Documentation (this feature)

```
specs/006-skill-library-distillation/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
└── contracts/
    └── skill-library-contract.md
```

### Source Code (the capability itself)

```
.claude/skills/                                   # shipped in v0.0.8
├── voicebridge-architecture-contract/SKILL.md
├── voicebridge-audio-pipeline-reference/SKILL.md
├── voicebridge-build-and-env/SKILL.md
├── voicebridge-change-control/SKILL.md
├── voicebridge-chunk3-voice-clone-tts-campaign/
│   ├── SKILL.md
│   └── references/provider-survey-2026-07-13.md
├── voicebridge-config-and-flags/SKILL.md
├── voicebridge-debugging-playbook/SKILL.md
├── voicebridge-diagnostics-and-tooling/
│   ├── SKILL.md
│   └── scripts/{inspect_wav.py, grab_diag.ps1}
├── voicebridge-docs-and-writing/SKILL.md
├── voicebridge-failure-archaeology/SKILL.md
├── voicebridge-gcp-speech-apis-reference/SKILL.md
├── voicebridge-release-gate-runbook/SKILL.md
├── voicebridge-research-frontier/SKILL.md
└── voicebridge-validation-and-qa/SKILL.md
```

**Structure Decision**: one directory per skill inside the repo's existing `.claude/skills/`
(version-controlled with the project, auto-discovered in-repo), coexisting with the 10
`speckit-*` skills.

## Complexity Tracking

- **14 skills, not the taxonomy's nominal 16**: external-positioning and
  proof-and-analysis-toolkit were folded away (personal app, no publication surface);
  research-methodology merged into `voicebridge-research-frontier`; the Spec Kit workflow
  merged into `voicebridge-change-control`. Two domain references were split
  (audio pipeline vs GCP APIs) because their failure modes and audiences differ.
- **Parallel authoring risk (consistency)** was accepted and mitigated by the barrier
  review over the complete set — which is what caught cross-skill duplication and the
  self-contradicting `exec-out` recipe.
