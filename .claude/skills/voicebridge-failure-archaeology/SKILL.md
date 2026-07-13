---
name: voicebridge-failure-archaeology
description: The VoiceBridge incident and dead-end ledger — incidents, docs-drift bugs, flakes, and rejected alternatives, each with symptom, root cause, evidence (commit SHA / file:line), status, and the rule it created. Load this skill when a symptom feels like it "must have happened before" (release merged without a CHANGELOG entry, smoke test passing against a stale APK, docs contradicting the repo, an ANR dialog breaking UI automation), when about to re-propose a possibly-rejected technology (DeepL, Azure Translator, OpenAI/Whisper, Flutter/React Native, M4A audio), when you need the WHY behind a rule in GEMINI.md/PATTERNS.md, or when asked "has this failed before?", "why is it done this way?", or to write a post-mortem. Do NOT load it for executing a release (voicebridge-release-gate-runbook), live debugging of a NEW failure (voicebridge-debugging-playbook), current architecture facts (voicebridge-architecture-contract), or build/env setup (voicebridge-build-and-env).
---

# VoiceBridge Failure Archaeology

The complete record of what has gone wrong (or was deliberately not attempted) in this
repo, so you never re-debug a solved problem or re-litigate a settled decision.

**Jargon, defined once:**
- **Release gate / auto-merge signal**: on a `vX.Y.Z` branch, a commit that touches
  `CHANGELOG.md` tells the installed post-commit hook to build, smoke-test on the
  emulator, and on pass auto-merge to `main` and push both branches. Commits that do NOT
  touch `CHANGELOG.md` run the smoke test only. Source: `android/scripts/hooks/post-commit`.
- **Smoke test**: `android/scripts/smoke-test.ps1` — UIAutomator-driven emulator walk of
  the Record→Stop→Play→Transcribe→Translate flow, screenshot per step, logcat crash scan.
- **Docs drift**: repo documentation asserting something the code/repo no longer (or
  never) did. Treated here as a real defect class, not cosmetics.
- **ANR**: Android "Application Not Responding" system dialog.
- **Retro-spec**: as-built Spec Kit document sets written after the fact (`specs/001-005`).

All dates below are commit dates from `git log`. Repo state verified 2026-07-13.

## When NOT to use this skill

| You want to... | Use instead |
| :--- | :--- |
| Run or fix a release / hook / smoke test today | `voicebridge-release-gate-runbook` |
| Debug a brand-new failure with no history match | `voicebridge-debugging-playbook` |
| Change code under governance rules | `voicebridge-change-control` |
| Know how the app is structured now | `voicebridge-architecture-contract` |
| Audio format / WAV header details | `voicebridge-audio-pipeline-reference` |
| GCP STT/Translation API request shapes | `voicebridge-gcp-speech-apis-reference` |
| API keys, local.properties, build flags | `voicebridge-config-and-flags` |
| JDK/SDK/Gradle environment setup | `voicebridge-build-and-env` |
| adb/emulator/screenshot tooling how-tos | `voicebridge-diagnostics-and-tooling` |
| Test strategy and QA checklists | `voicebridge-validation-and-qa` |
| Writing docs/CHANGELOG entries correctly | `voicebridge-docs-and-writing` |
| Plan Chunk 3 (voice-clone TTS) | `voicebridge-chunk3-voice-clone-tts-campaign` |
| Explore unproven future approaches | `voicebridge-research-frontier` |

## Incident index

| # | Date | Title | Class | Status |
| :- | :--- | :--- | :--- | :--- |
| INC-1 | 2026-07-05 | v0.0.5 released with NO CHANGELOG entry — auto-merge signal bypassed | process incident | Fixed retroactively (v0.0.7) |
| INC-2 | 2026-06-15 | Post-commit hook omitted `-Build` — releases could smoke-test a stale APK | CI defect | Fixed (88ac97a) |
| INC-3 | 2026-07-05 | Docs-drift batch: false wrapper claim, ghost map rows, unannotated placeholders | docs drift | Fixed (v0.0.7) |
| INC-4 | 2026-06-15 | Rejected-alternative decisions (DeepL, Azure, OpenAI, Whisper, Flutter/RN, M4A) | settled decisions | Closed — do not reopen without new evidence |
| INC-5 | (recurring) | Cold-boot ANR dialog flake breaks UI automation | environment flake | Mitigated in-script (auto-dismiss) |

---

## INC-1 — v0.0.5 shipped without a CHANGELOG entry (auto-merge signal bypassed)

- **Date**: 2026-07-05 (release); discovered and fixed later the same window, in v0.0.7.
- **Observed**: v0.0.5 (GitHub Spec Kit adoption) was on `main`, but `CHANGELOG.md` had
  no `[0.0.5]` section. The release-gate rule says updating `CHANGELOG.md` IS the release
  signal — so this release never emitted the signal at all.
- **Root cause**: the v0.0.5 branch was merged to `main` **manually** instead of letting
  the hook auto-merge. Tell-tale: the merge commit message `Merge v0.0.5 - GitHub Spec
  Kit adoption` (ba9bce5) does not match the hook's `Merge <branch> into main` format
  used by adebdbb / 6ddef50. Since no commit touched `CHANGELOG.md`, the auto-merge
  signal — and the paper trail — were both skipped.
- **Evidence**:
  - Release commit 9fdd075 (`git show 9fdd075 --stat` — no CHANGELOG.md in the file list).
  - Manual merge ba9bce5 (message format differs from hook merges).
  - Retroactive entry + admission note: `CHANGELOG.md:31-49` (the `### Note` block at
    lines 47-49 marks the entry as added retroactively in v0.0.7).
  - Task record: `specs/005-release-gate-automation/tasks.md:49-52` (T015, marked [X]).
- **Status**: FIXED — historical `[0.0.5]` entry added retroactively in v0.0.7
  (commit 16a7308), explicitly flagged as retroactive.
- **Lesson encoded**: the CHANGELOG-update-as-release-signal rule now appears in
  `CHANGELOG.md:6-7` (header rule) and `PATTERNS.md` §4 "Git Workflow" (Auto-Merge
  Signal bullet). Operating rule for you: **never merge a `vX.Y.Z` branch to `main` by
  hand.** If you find a version on `main` with no CHANGELOG entry, that is this incident
  pattern — add the entry retroactively WITH a note saying so, and record it in the
  relevant spec's tasks.md. There is no sanctioned way to route around the release gate.

## INC-2 — Hook did not pass `-Build` on release commits (stale-APK risk)

- **Date**: 2026-06-15, fixed same day by commit 88ac97a (`fix: hook now passes -Build
  on release commits; smoke-test example updated`).
- **Observed / risk**: on a CHANGELOG (release) commit, the v0.0.3 hook invoked
  `smoke-test.ps1 -AutoMerge` **without** `-Build`. Without `-Build`, the smoke test
  reuses whatever APK was last built — so a release could pass the gate and auto-merge
  to `main` while testing an APK that did not contain the release's code.
- **Root cause**: v0.0.3 hook authoring oversight — the `-Build` switch existed in
  `smoke-test.ps1` but the release branch of the hook's if/else never passed it (only
  the flag combination distinguished release from intermediate runs).
- **Evidence**:
  - Before: `git show 93d1549:android/scripts/hooks/post-commit` (line
    `-File "android/scripts/smoke-test.ps1" -AutoMerge` — no `-Build`).
  - Fix diff: `git show 88ac97a` (2 files, 4 insertions/4 deletions: hook + the usage
    example in `smoke-test.ps1`'s comment header).
  - Current state: `android/scripts/hooks/post-commit:34` passes `-Build -AutoMerge`.
- **Status**: FIXED. Note the fix lives in the **tracked template**
  `android/scripts/hooks/post-commit`; the live hook is a copy in `.git/hooks/` placed
  by `android/scripts/install-hooks.ps1`. A clone (or a hook installed before 88ac97a)
  can silently still run the old behavior.
- **Lesson encoded**: after any hook template change — and after every fresh clone —
  re-run `powershell -File android/scripts/install-hooks.ps1` (PATTERNS.md §4 "Install
  Hooks on Clone"). Verify the live hook matches the template:

  ```powershell
  git -C "C:\Docs\Build\mananUtils\VoiceBridge" diff --no-index android/scripts/hooks/post-commit .git/hooks/post-commit
  ```

  (No output = in sync.) Broader lesson: a gate that tests a stale artifact is worse
  than no gate — it manufactures false confidence. When touching the gate, prove the
  artifact under test is the artifact being shipped.

## INC-3 — v0.0.7 docs-drift batch (three independent doc lies, one sweep)

- **Date**: 2026-07-05, commit 16a7308 (v0.0.7, docs only).
- **Observed**: three separate places where governance docs asserted things that were
  false or never true:
  1. **README wrapper lie**: `README.md` claimed "`gradle-wrapper.jar` binary is not
     committed" and instructed a copy-from-Saraswati bootstrap (a PowerShell `Copy-Item`
     block copying `gradlew`/`gradlew.bat`/`gradle-wrapper.jar` from the sibling
     Saraswati repo). In reality the wrapper IS tracked in git — the instruction was a
     leftover from initial bootstrapping and would have sent a new engineer on a
     pointless (and cross-repo-coupling) errand.
  2. **Ghost map rows**: `Project_Structure.md` mapped `GEMINI_Getting_Started.md`
     ("Onboarding: Auto-updated guide...") and `bootstrap_prompts/` ("Plan Archive...")
     — neither the file nor the directory ever existed in the repo. They were scaffold
     rows copied from the AVF framework template at v0.0.1 for artifacts
     (`scripts/update_getting_started.py`, `generate_bootstrap_prompt.py` outputs)
     that were never actually generated.
  3. **Unannotated placeholders**: `Function_Mapping.md` listed backend endpoints
     (`POST /api/v1/stt/transcribe`, `/tts/synthesize`, `/pipeline/stream`,
     `GET /api/v1/health`) and `bruno/collections/*.bru` contracts as if real. No
     backend exists — the app calls GCP REST APIs directly from the device. A reader
     (human or model) could burn hours hunting for a server that was never built.
- **Root cause**: template-scaffold content and bootstrap-era instructions were never
  reconciled against reality as the repo evolved; nothing gated "does the doc match the
  repo?" (`scripts/verify_structure.py` checks that files ARE mapped, not that mapped
  files exist as described).
- **Fix applied** (all in 16a7308): README section rewritten to "Gradle wrapper
  (already committed)" with the copy block deleted; both ghost rows removed from
  `Project_Structure.md`; `Function_Mapping.md` given a "Status (v0.0.7): reserved for
  future backend" banner plus per-row "reserved (N/A today)" markers (file kept, not
  deleted — the future backend will fill it). The missing `[0.0.5]` entry (INC-1) rode
  in the same commit.
- **Evidence**: `git show 16a7308` (6 files); task records
  `specs/001-agentic-framework-governance/tasks.md:51-56` (T017 ghost rows, T018
  placeholder annotation) and `specs/005-release-gate-automation/tasks.md:49-52`
  (T015); current state `Function_Mapping.md:5-9` (status banner).
- **Status**: FIXED. `Function_Mapping.md` remains a placeholder by design — replace
  rows with real ones only when a first backend/API actually ships (its own
  maintenance rules, plus open task T019 in specs/001 for real Bruno collections).
- **Lesson encoded**: docs drift is a defect class with its own release (v0.0.7).
  When you find one drifted claim, sweep for siblings — they cluster (all three here
  came from the same bootstrap era). Never state a file/endpoint exists in a governance
  doc without checking the tree; annotate aspirational rows as reserved instead of
  deleting or leaving them bare.

## INC-4 — Rejected alternatives (settled decisions; do not re-propose without new evidence)

These are dead ends by decision, not by failed attempt. Each was evaluated and rejected
with recorded rationale. Reopening one requires new evidence that the rationale no
longer holds — route through change control, and consider `voicebridge-research-frontier`.

| Alternative | For | Rejected because | Evidence |
| :--- | :--- | :--- | :--- |
| DeepL | Translation (Chunk 2) | **No Gujarati support** — eliminated immediately | `README.md:16`; CHANGELOG `[0.0.4]` Decisions |
| Azure Translator | Translation | Gujarati yes, but separate Azure account/key — extra setup, no synergy with the existing GCP key | `README.md:17`; CHANGELOG `[0.0.4]` |
| OpenAI GPT-4o | Translation | Only indirect (prompt-based) Gujarati, higher cost, no natural pairing with GCP STT | `README.md:18`; CHANGELOG `[0.0.4]` |
| OpenAI Whisper | STT (Chunk 1) | Gujarati accuracy undertested in production vs GCP's explicit `gu-IN` acoustic model; GCP is plain REST, no vendor SDK | `README.md:31-35` |
| Flutter / React Native | App framework | Platform-channel **bridge latency** on audio I/O — unacceptable for the Chunk 4 near-real-time pipeline; Kotlin gives raw PCM via `AudioRecord`/`AudioTrack` with zero JNI overhead | `README.md:24-27`; CHANGELOG `[0.0.2]` Decisions |
| M4A/AAC audio | Recording format | GCP STT does not accept it without a decode step; WAV/LINEAR16 is zero-conversion end-to-end and the same PCM format Chunk 4 will use | `README.md:39-42`; CHANGELOG `[0.0.2]` |

The winning pattern behind all six: **one GCP project, one API key
(`GCP_STT_API_KEY`), zero format conversions, zero bridge hops.** Any proposal that
adds a second provider account, a second credential, or an audio transcode step is
fighting the recorded architecture rationale — flag it explicitly if you propose it.

## INC-5 — Cold-boot ANR dialog flake in the smoke test

- **Date**: recurring environment flake (mitigation present in the current script;
  verified 2026-07-13).
- **Observed**: on a cold-booted emulator (AVD `voicebridge_avd`), Android sometimes
  shows a system dialog — "\<app\> isn't responding" or "\<app\> keeps stopping" — from
  first-boot jank. The dialog sits on top of the app, so UIAutomator dumps see the
  dialog's nodes instead of the app's buttons and every text-based selector misses:
  the smoke test would fail with no real app defect.
- **Root cause**: emulator cold-boot resource contention (first boot + APK install +
  app launch racing), not an app bug. Transient by nature.
- **Mitigation (in-script, automatic)**: `Get-Ui` in
  `android/scripts/smoke-test.ps1:79-99` — every UI dump is scanned for nodes whose
  text contains `responding` or `keeps stopping` (line 85). If found, the script taps
  the dialog's `Wait` button by its bounds center (lines 87-89); if no `Wait` button,
  it sends keyevent 4 (BACK, line 91); then waits 800 ms and re-dumps so the caller
  gets a clean UI tree (lines 93-96). Log line to recognize:
  `dismissing transient system ANR dialog (cold-boot jank)` (yellow).
- **Status**: MITIGATED. Because the dismissal lives inside `Get-Ui`, every UI query in
  the whole script is protected — you should never see this dialog kill a run.
- **Lesson encoded**: UI automation against an emulator must assume the OS will
  interpose transient chrome; handle it at the single choke point where UI trees are
  fetched, not per-step. If the smoke test ever fails on selectors right after boot,
  check `android\app\build\smoke-<timestamp>\ui.xml` and the step screenshots for a system dialog FIRST, before
  suspecting app code. (Related open gap: transcript detection via
  `contains(@text,'Transcript')` is brittle — T017 below.)

---

## Known open gaps (recorded, NOT incidents — do not "discover" these as new)

From `specs/005-release-gate-automation/tasks.md:53-60` and the Pipeline Stage
Registry. All are conscious, recorded choices at personal-app scale:

- **T016**: smoke test is happy-path only — no rotation, process-death, or
  permission-revocation coverage.
- **T017**: transcribe-result detection matches `contains(@text,'Transcript')` against
  the "Transcription complete." status line (`smoke-test.ps1:290-292`) — breaks if the
  status copy changes; a content-desc would be sturdier.
- **T018**: the hook/script push to `origin` unconditionally on release pass — no
  offline mode; an unreachable origin fails the release run.
- **Provider interfaces**: `STTProvider`/`TranslationProvider` are named in
  `Project_Structure.md`'s Pipeline Stage Registry but NOT extracted in code —
  `SttService.kt`/`TranslationService.kt` are singleton Kotlin `object`s called
  directly from MainViewModel (SttService.kt:26, TranslationService.kt:12). Also
  open: no VAD gating, no streaming, no latency-budget rows.

If you fix one, mark the task `[X]` in the owning spec's tasks.md and add a CHANGELOG
entry through the normal release gate — that is how INC-1's lesson stays learned.

## How to do archaeology yourself (when this ledger doesn't cover it)

```powershell
# Full history with per-commit file stats
git -C "C:\Docs\Build\mananUtils\VoiceBridge" log --stat --date=short --format="%h %ad %s"

# Inspect any commit in full
git -C "C:\Docs\Build\mananUtils\VoiceBridge" show <sha>

# Read a file AS IT WAS at a commit (used above to prove INC-2's before-state)
git -C "C:\Docs\Build\mananUtils\VoiceBridge" show <sha>:android/scripts/hooks/post-commit

# Which commits touched a file
git -C "C:\Docs\Build\mananUtils\VoiceBridge" log --follow --oneline -- <path>
```

Then cross-reference: `CHANGELOG.md` (per-version Decisions/Fixed blocks),
`specs/*/tasks.md` "Open follow-ups" sections (incidents get task IDs), and
`Project_Structure.md`'s mandatory changelog table (every structural change has a row —
enforced by `scripts/verify_structure.py`). A merge commit whose message does not read
`Merge <branch> into main` is a manual merge — treat it as an INC-1-pattern suspect.

## Provenance and maintenance

Authored 2026-07-13 by skill-distill (repo state at commit 80b756f, v0.0.7 on main).
All SHAs, line numbers, and quotes verified against the live repo on that date.
Volatile note (2026-07-13): the working tree had uncommitted `build.gradle.kts` edits
(AGP 9 built-in-Kotlin migration); nothing above depends on them.

Re-verification one-liners (run from anywhere):

```powershell
# INC-1: retroactive-note still present in CHANGELOG
Select-String -Path "C:\Docs\Build\mananUtils\VoiceBridge\CHANGELOG.md" -Pattern "retroactively"

# INC-2: hook template still passes -Build on release commits
Select-String -Path "C:\Docs\Build\mananUtils\VoiceBridge\android\scripts\hooks\post-commit" -Pattern "-Build -AutoMerge"

# INC-3: Function_Mapping still marked reserved / README wrapper claim still true
Select-String -Path "C:\Docs\Build\mananUtils\VoiceBridge\Function_Mapping.md" -Pattern "reserved for future backend"
Select-String -Path "C:\Docs\Build\mananUtils\VoiceBridge\README.md" -Pattern "already committed"

# INC-4: rejection table still in README
Select-String -Path "C:\Docs\Build\mananUtils\VoiceBridge\README.md" -Pattern "DeepL"

# INC-5: ANR auto-dismiss still in Get-Ui (line drift possible; pattern is the anchor)
Select-String -Path "C:\Docs\Build\mananUtils\VoiceBridge\android\scripts\smoke-test.ps1" -Pattern "keeps stopping"

# Open gaps: still open?
Select-String -Path "C:\Docs\Build\mananUtils\VoiceBridge\specs\005-release-gate-automation\tasks.md" -Pattern "\[ \]"
```

If any check fails, the repo has moved — update the affected entry (and only it),
re-date the volatile facts, and keep every claim cited to a SHA or file:line.
