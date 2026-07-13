# Research: Agent Skill Library (Repo-Discipline Distillation)

Decisions embodied by the shipped library, with rationale and rejected alternatives.

## Decision 1 — Campaign target: Chunk 3 voice-clone TTS

**Choice**: the single executable campaign skill targets Chunk 3 (voice-clone TTS), not
Chunk 4 (two-phone relay) or release-gate hardening.
**Why**: Director decision 2026-07-13 — Chunk 3 is the next unstarted chunk and the hardest
research problem (preserve the speaker's voice in translated speech; Gujarati is the hard
axis). Chunk 4 depends on Chunk 3 existing; gate hardening is tracked as open tasks in
`specs/005-release-gate-automation/tasks.md:53-60` already.
**Rejected**: Chunk 4 campaign (premature — no TTS to relay); release-gate campaign
(valuable but not the *hardest live problem*).

## Decision 2 — 14-skill taxonomy adaptation

**Choice**: instantiate the distillation taxonomy at 14 skills — merge
external-positioning + proof-and-analysis-toolkit away, fold research-methodology into
`voicebridge-research-frontier`, fold the Spec Kit workflow into
`voicebridge-change-control`; split the domain reference into audio-pipeline vs
GCP-speech-APIs.
**Why**: personal app with no publication surface (nothing to position externally); the
Spec Kit chain IS change control here (`GEMINI.md:53-56`); audio-byte-level knowledge and
cloud-API knowledge serve different failure modes.
**Rejected**: a monolithic single handbook (untargetable triggers, context bloat for small
models); the full 16-skill taxonomy (thin categories produce filler).

## Decision 3 — Byte-safe device-file pulls (the empirical find of the run)

**Choice**: all recipes that pull binary files off the device use the two-step route
(`adb shell run-as ... cp` to `/sdcard`, then `adb pull`); `adb exec-out ... > file` from
PowerShell 5.1 is documented ONLY as a trap.
**Why**: reviewers empirically demonstrated on this machine that PowerShell 5.1 `>`
re-encodes native binary stdout as UTF-16LE with BOM (a 32,044-byte WAV became 64,094
bytes starting FF FE). Worse, the corruption *increases* size, so naive size sanity checks
pass, and a corrupted pull fakes the "header never written" failure signature — sending an
engineer to hunt a nonexistent bug in `AudioRecorder.stop()`
(android/app/src/main/java/com/mananpatel/voicebridge/AudioRecorder.kt:80-86, which
deliberately does NOT cancel the header-writing job). Four skills originally shipped the
corrupting recipe; the fixer purged all four.
**Rejected**: keeping `exec-out` with a warning (a warning next to a copy-pasteable
corrupting command still gets pasted).

## Decision 4 — Spike artifacts live outside the repo tree

**Choice**: the Chunk 3 campaign's scratch directory is `$env:TEMP\vb-spike-tts\`, not an
in-repo `.spike-tts/`.
**Why**: `scripts/verify_structure.py` walks the *disk tree* and fails on any file missing
from the Project_Structure.md changelog, regardless of git tracking
(`scripts/verify_structure.py:52-76`); an in-repo scratch dir would redden the gate (and
the root `.gitignore` covers `*.wav`/`*.pcm` but not the spike's `.json` responses).
Additionally: family-member voice samples are treated like credentials — they must never
be committable even by accident.

## Decision 5 — Frontmatter description cap at 1024 chars

**Choice**: every skill description compressed to ≤ 1024 characters while preserving
trigger phrases and Do-NOT routing.
**Why**: long descriptions degrade trigger matching for smaller models and blow the skill
listing budget; the usability reviewer flagged 10 of 14 as over-cap. Verified lengths now
966–1024.

## Decision 6 — Single-home facts with cross-references

**Choice**: each fact has ONE owning skill; siblings point rather than restate. Ownership
settled by the fixer: hook/auto-merge mechanics → release-gate-runbook; incident
narratives → failure-archaeology; smoke-selector KEEP-IN-SYNC table → release-gate-runbook;
verify_structure exclusion list → docs-and-writing §2.3.
**Why**: duplicated runbook steps drift independently — the repo's own v0.0.7 docs-drift
episode is the precedent.
**Rejected**: self-contained repetition per skill (bloat + guaranteed drift).

## Decision 7 — Provider survey as a dated reference file

**Choice**: Chunk 3 provider facts (ElevenLabs / Google Cloud TTS / XTTS-class local /
device-native fallback) live in
`.claude/skills/voicebridge-chunk3-voice-clone-tts-campaign/references/provider-survey-2026-07-13.md`,
date-stamped in the filename, every claim labeled candidate.
**Why**: provider capabilities/pricing drift fast; a dated file makes staleness visible at
a glance and regeneration cheap without touching the campaign's stable phase structure.
