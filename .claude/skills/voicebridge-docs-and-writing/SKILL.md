---
name: voicebridge-docs-and-writing
description: >
  VoiceBridge documentation-of-record maintenance rules, per-doc update triggers,
  templates, and house style. Load this skill whenever you are about to CREATE, EDIT,
  or REVIEW any of the repo's governing documents — GEMINI.md, PATTERNS.md,
  Project_Structure.md, CHANGELOG.md,
  Function_Mapping.md, README.md, or the specs/NNN-*/ Spec Kit artifact sets — or when
  you need to know WHICH doc a new fact belongs in, how to word a changelog entry,
  record a rejected alternative, or what docs a code change obligates before
  committing (the docs-impact checklist). Also load it when
  verify_structure.py fails, when you suspect docs drift (ghost rows, stale claims),
  or when writing any prose destined for the repo. Do NOT load it for executing the
  release/merge process itself (voicebridge-release-gate-runbook), for changing what
  the docs govern rather than the docs themselves (voicebridge-change-control), for
  build/environment setup (voicebridge-build-and-env), or for debugging app behavior
  (voicebridge-debugging-playbook).
---

# VoiceBridge: Docs of Record and House Style

You are maintaining the documentation system of a personal Android app (Kotlin +
Jetpack Compose) that translates Gujarati speech to English for a grandparent /
grandchild WhatsApp video call. The docs are not decoration: two of them are
machine-enforced gates (`Project_Structure.md` via `scripts/verify_structure.py`,
`CHANGELOG.md` via the post-commit auto-merge hook). A wrong or missing doc update
blocks or mis-fires a release.

**Jargon defined once:**

- **Director** — the human owner (user). Approves constitution amendments and arbitrates.
- **Constitution of record** — `GEMINI.md`. Wins over every other document on conflict.
- **Distillation** — `.specify/memory/constitution.md`, a Spec Kit-facing summary of
  GEMINI.md + PATTERNS.md. Never introduces rules; never wins on conflict.
- **Chunk** — a staged product increment (Chunk 0 skeleton -> 1 STT -> 2 Translation ->
  3 voice-clone TTS -> 4 real-time relay). Chunks 0-2 shipped as of 2026-07-13.
- **Release signal** — a commit on a `vX.Y.Z` branch that modifies `CHANGELOG.md`. The
  post-commit hook treats it as "this version is done": smoke test, then auto-merge to
  `main` and push (PATTERNS.md:34).
- **Ghost row** — a map/table row referencing a file or endpoint that does not exist.
  The v0.0.7 release existed almost entirely to remove these (see cautionary tale below).
- **Retro-spec** — an as-built Spec Kit document set written AFTER the code shipped,
  reconstructing what was actually built (specs 001-005 are all retro-specs, v0.0.6).

## 1. The seven docs of record — one-screen map

| Doc | Role | Update trigger | Enforced by |
| :-- | :-- | :-- | :-- |
| `GEMINI.md` | Constitution of record | Amendment only, Director approval required | Convention (supreme on conflict, GEMINI.md:56) |
| `PATTERNS.md` | Pattern registry | A design decision is made AND reflected in actual code | Grounding rule (GEMINI.md:17) |
| `Project_Structure.md` | Architecture map + file-inventory Changelog table | ANY file add/remove, immediately | `scripts/verify_structure.py` (exit 1 on drift) |
| `CHANGELOG.md` | Version history (Keep a Changelog / SemVer) | Version complete — this edit IS the release signal | Post-commit hook auto-merge (PATTERNS.md:34) |
| `Function_Mapping.md` | Client<->backend traceability | Reserved for future backend — do NOT add rows until a real backend ships | Its own maintenance-rules list (Function_Mapping.md:18-22) |
| `README.md` | Human-facing overview: key decisions, chunk status table, acceptance tests | New chunk ships, or setup/build facts change | Convention |
| `specs/NNN-*/` | Durable per-feature Spec Kit artifacts (7 files each) | New feature (spec-first) or retro-spec of shipped work; task boxes updated when open items close | `speckit-*` skills / convention |

Also real but subordinate:

| Doc | Role |
| :-- | :-- |
| `.specify/memory/constitution.md` | Distillation of GEMINI.md + PATTERNS.md. Regenerate when those materially change (open standing task, specs/001-agentic-framework-governance/tasks.md:61-62). Never edit it to introduce a rule. |
| `docs/architecture_overview.html` | One-page visual guide; excluded from verify_structure.py checks (verify_structure.py:61). |
| `scripts/README.md`, `bruno/README.md`, `terraform/README.md` | Directory-local inventories. Keep in sync when their directory's contents change. |

## 2. Per-doc rules

### 2.1 GEMINI.md — the constitution

- **What it is**: role definitions (Director / Lead Agent), the Five Core Lessons,
  VoiceBridge domain context, and operational protocols (80/20 plan-first, Spec Kit
  workflow, communication rules).
- **Update trigger**: constitutional amendment ONLY, and only under Director approval.
  Never edit it as a side effect of feature work. If a feature seems to require a
  GEMINI.md change, stop and surface the amendment to the Director as its own decision.
- **Precedence**: GEMINI.md:56 — ".specify/memory/constitution.md ... never introduces
  rules of its own; on conflict, GEMINI.md wins."
- **Follow-on obligation**: when GEMINI.md (or PATTERNS.md) materially changes,
  regenerate the distillation `.specify/memory/constitution.md`. This is an OPEN
  standing task — 001/T021, marked `[ ]` at
  specs/001-agentic-framework-governance/tasks.md:61-62, anchored to the governance
  clause near the end of `.specify/memory/constitution.md` ("This distillation is
  regenerated whenever GEMINI.md or PATTERNS.md materially changes"). If you amend
  GEMINI.md, doing the regeneration in the same version is the correct closure of T021
  for that change; if you cannot, say so explicitly in the changelog entry.

### 2.2 PATTERNS.md — the pattern registry

- **The grounding rule (non-negotiable)**: "Every entry must reflect the actual
  codebase, never aspirational designs" (GEMINI.md:17; restated in the distillation).
  Before adding a pattern, point at the code that embodies it. If you cannot cite a
  file, it is not a pattern yet — it is a proposal, and it belongs in a spec's
  research.md or an open `[ ]` task, not here.
- **Known historical tension (do not "fix" silently)**: Section 2 (Voice Pipeline
  Patterns, PATTERNS.md:18-24) contains constitution-mandated targets that code has
  NOT yet reached — provider interfaces (`STTProvider`/`TranslationProvider` are named
  in Project_Structure.md's Pipeline Stage Registry but not extracted in Kotlin), VAD
  gating (none exists), streaming-first (all calls are buffered REST), latency-budget
  rows (none in Project_Structure.md). These gaps are tracked as `[ ]` tasks in the
  specs. When writing docs, describe them as **open gaps**, never as shipped behavior.
  Changing Section 2 itself is a constitution-adjacent edit — Director call.
- **Where new patterns go** (append to the matching numbered section):

  | Section | Line (2026-07-13) | Add here when the pattern is about... |
  | :-- | :-- | :-- |
  | 1. Architectural Patterns | PATTERNS.md:5 | Cross-cutting engineering policy (script portability, validation gating, hardening) |
  | 2. Voice Pipeline Patterns | PATTERNS.md:18 | Audio formats, pipeline stages, provider interfaces, latency |
  | 3. Coding Standards | PATTERNS.md:26 | Language/library conventions (argparse, async) |
  | 4. Git Workflow | PATTERNS.md:31 | Branching, commit messages, the auto-merge signal, hooks |
  | 5. Smoke Test | PATTERNS.md:39 | The smoke-test gate's selectors, screenshots, crash gate |
  | 6. Tooling Conventions | PATTERNS.md:47 | Script flags and safety behavior (dry-run) |

- **Format**: one bold-titled bullet per pattern: `*   **Name**: rule, rationale,
  and the exception path if any.` Documented exceptions (e.g., an audio-format
  deviation) go directly under the pattern they except, with rationale
  (PATTERNS.md:23).
- **The only sanctioned change-control exception string** lives here
  (PATTERNS.md:10): commits with failing Bruno validation require the exact
  acknowledgment `"I understand bruno validation is failing and I allow the exception
  to have the code committed to github repo"`. Never paraphrase it, never document any
  other bypass.

### 2.3 Project_Structure.md — architecture map + the enforced Changelog table

Three parts, all mandatory:

1. **Functional map tables** — "Core Framework (The 'Director' Layer)" and
   "Application Layer": `| Path | Purpose |` rows. Every mapped path must exist. A
   mapped path for a file that does not exist is a ghost row (v0.0.7 removed two).
2. **Pipeline Stage Registry** (Project_Structure.md:50-59) — Stage / Role / Provider
   Interface / Current Implementation. `TBD` marks unbuilt stages; interface names
   here are the intended contract, not proof of extraction (see 2.2).
3. **The Changelog table** (Project_Structure.md:61+) — columns exactly
   `| Date | Action | Files Affected | Summary |`. **Every file addition or removal
   gets a row IMMEDIATELY** — "no deferred bookkeeping" (GEMINI.md:12).

**How the enforcement works** (`scripts/verify_structure.py`, run from anywhere in the
repo — it walks up to find Project_Structure.md):

- It parses everything after the `## Changelog` heading, taking **column index 3
  (Files Affected)**, splitting on commas, stripping backticks
  (verify_structure.py:26-37). So: list files comma-separated, in backticks, with
  repo-relative POSIX paths — exactly like the existing rows.
- It then walks the tree and fails (exit 1) listing every real file with no row.
- **Exclusions — the directory-level mapping convention** (verify_structure.py:55-75):
  `.git/`, `Project_Structure.md` itself, `__pycache__/`, `.env`,
  `bootstrap_prompts/` (generated output), `docs/`, and — mapped at DIRECTORY level in
  the functional map instead of file-by-file — anything under **`.specify/`,
  `.claude/`, `.gemini/`, `specs/`** (verify_structure.py:66). Gitignored local build
  outputs `android/.gradle/`, `android/app/build/`, `android/local.properties` are
  also skipped.
- Consequence 1: adding a file under `.claude/skills/` or `specs/` needs **no
  Changelog-table row per file** — but the parent directory must keep its
  directory-level row in the Core Framework map (rows exist at
  Project_Structure.md:16-19), and a table row naming the directory (e.g.
  `specs/001-.../`) is the established style for release-visible additions (see the
  v0.0.6 row).
- Consequence 2: adding a file anywhere else (android sources, scripts/, root .md)
  WILL fail the gate until you add its row. Add the row in the same working session
  as the file, not later.

**Row conventions** (grounded in the existing table): Action is uppercase —
`INITIALIZE` (first row only), `ADD`, `UPDATE` (use `REMOVE` for deletions; none has
occurred yet as of 2026-07-13, so removals so far have been folded into UPDATE rows
like v0.0.7's "ghost map rows removed"). Summary starts with a bold version marker
for release rows (`**v0.0.7 — docs drift fixes (docs only).**`) and states cost
impact (`$0/mo`) and "docs only" / "no app code changes" when true.

**Verify command (PowerShell, from repo root):**

```powershell
python .\scripts\verify_structure.py
```

Green output: `SUCCESS: All files are accounted for in the changelog.` Red output
lists the missing files — add rows for exactly those, nothing else.

### 2.4 CHANGELOG.md — version history AND the release trigger

- **Format**: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) + SemVer,
  stated at CHANGELOG.md:3-4. Newest first. `## [Unreleased]` stays at top (may be
  empty). Version heading: `## [0.0.7] - 2026-07-05`. Subsections used in this repo:
  `### Added`, `### Changed`, `### Fixed`, `### Decisions`, `### Note`.
- **Release-signal semantics (the sharp edge)**: CHANGELOG.md:6-7 — "updating this
  file in a commit on a vX.Y.Z branch triggers the post-commit hook to auto-merge
  that branch to main and push both to origin." Therefore:
  - Do NOT touch CHANGELOG.md in an intermediate commit. Stage the changelog edit
    only in the final `chore: vX.Y.Z` release commit.
  - Conversely, NEVER ship a version without a changelog entry — that bypasses the
    signal and the smoke-test-gated merge. This exact failure happened in v0.0.5
    (merged manually, no entry; entry added retroactively in v0.0.7 with a
    `### Note` explaining the retro-add — CHANGELOG.md:47-49). If you ever must
    document a past release after the fact, copy that pattern: full entry under the
    correct version heading plus an italicized `### Note` naming the commit and the
    bypass.
  - Execution details of the hook/smoke test are the release-gate runbook's domain,
    not this skill's.
- **Decisions blocks — the rejected-alternatives convention**: when a version chose
  between vendors/approaches, add a `### Decisions` subsection recording the winner
  AND the losers with one-line reasons (see CHANGELOG.md:68-72 for v0.0.4: chose GCP
  Translation v2; rejected DeepL "no Gujarati", Azure "separate provider/key", OpenAI
  "no natural pairing"; and CHANGELOG.md:95-99 for v0.0.2). Purpose: prevent
  re-litigating settled questions in later sessions. If the decision is
  broad/durable, ALSO promote it to a comparison table in README.md's Key Decisions
  section and, once code embodies it, a PATTERNS.md entry.
- **Entry style**: bold-lead bullet naming the feature, then specifics; note cost
  (`$0/mo`) and scope (`docs only`, `no app code changes`) where applicable;
  reference spec task IDs when closing them (e.g. "005-release-gate-automation
  T015").

### 2.5 Function_Mapping.md — reserved for a future backend

- **Current status (2026-07-13)**: placeholder. The status blockquote
  (Function_Mapping.md:5-9) says it plainly: no backend/API exists — the app calls
  GCP STT/Translation REST directly from the device; all four table rows are
  italicized illustrations marked "reserved (N/A today)" with reserved `.bru`
  contract paths that do not exist.
- **Do NOT** add rows for the on-device GCP calls — the table maps client components
  to *this project's own* backend endpoints, and there are none. Do NOT delete the
  file either (kept deliberately, 001/T018).
- **When the first backend ships**: replace the italic placeholder rows with real
  rows and delete the status blockquote, following the maintenance rules the file
  itself carries (Function_Mapping.md:18-22): **Add** on new endpoint/stage/client
  connection; **Update** on signature/audio-contract/data-structure change;
  **Delete** on decommission; **Audit** periodically for ghost endpoints. Each real
  row must point at a real Bruno contract under `bruno/collections/` (that
  population is open task 001/T019).

### 2.6 README.md — chunk status + acceptance tests + key decisions

- **Chunk Status table** (README.md:69-75): the single source for "what's built".
  When a chunk ships: flip its row to Built in the same release that ships it.
  Chunks 3 and 4 are `Not started` as of 2026-07-13 — do not upgrade them
  speculatively.
- **Acceptance tests live HERE**, one per chunk, as numbered manual steps: Chunk 0 at
  README.md:115-120, Chunk 1 at README.md:141-146, Chunk 2 at README.md:148-154.
  Every new chunk MUST add its acceptance test section — the distillation's chunked-
  delivery clause says a chunk ships only when its README acceptance test passes.
  Style: numbered steps, observable outcomes, and an explicit error-path step ("if
  the key is missing ... a clear error card appears").
- **Key Decisions section** (README.md:7-43): comparison tables for durable
  technology choices (columns tailored per decision, winner bolded, losers with
  reasons). Add one when a Decisions block in CHANGELOG.md is durable enough to
  matter to a newcomer.
- **Build/setup sections**: keep command blocks copy-pasteable PowerShell with real
  paths. When a setup fact changes (wrapper, SDK path, key handling), fix README in
  the same commit — README's stale "wrapper is uncommitted" claim was one of the
  v0.0.7 drift bugs.

### 2.7 specs/NNN-*/ — Spec Kit artifact sets

- **Full-7 artifact set per feature** (verified layout of specs/001 and specs/004):
  `spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, `tasks.md`,
  `contracts/`. New feature -> next `NNN-slug` via the `/speckit-specify` chain
  (spec-first). Shipped-but-unspecced work -> retro-spec.
- **Retro-spec as-built convention** (grounded in specs/001 tasks.md:7-8):
  - tasks.md opens with a provenance line: "As-built record — reconstructed
    \<date\> from \<version\> (commit \<sha\>) ..."
  - `[X]` = shipped, and the line ENDS with the shipping release in parens, e.g.
    `(v0.0.5)` — or a commit sha for hook-fix-style unversioned work.
  - `[ ]` = **genuinely open**. Never check a box to make a spec look finished. The
    open boxes ARE the backlog (e.g. 001/T019 Bruno collections, T020 Terraform,
    T021 distillation regeneration).
  - Artifacts are grounded in code with `path:line` citations.
- **When you close an open item**: flip `[ ]` to `[X]`, append the shipping version,
  and reference the task ID in the CHANGELOG entry (v0.0.7 did exactly this for
  T015/T017/T018).

## 3. House style (all repo prose)

| Rule | Detail |
| :-- | :-- |
| Tables over prose | Any enumerable set of facts (options compared, files listed, statuses) is a Markdown table, not a paragraph. Every doc of record already does this — match it. |
| `path:line` citations | Claims about code cite `file.kt:123` or `script.ps1:28`. Re-verify line numbers before writing them; they drift. |
| Date-stamp volatile facts | Anything that can silently change (statuses, "currently", line numbers, tool versions) carries a date, e.g. "(2026-07-13)". |
| No oversell | Unbuilt = "Not started" / `TBD` / `[ ]` / "reserved (N/A today)". Never describe mandated-but-unbuilt behavior (streaming, VAD, provider interfaces) as existing. |
| Cost + scope markers | Release-facing entries state `$0/mo` when true and "docs only" / "no app code changes" when true. |
| ASCII-only in `.ps1` files | smoke-test.ps1:28 — "Windows PowerShell 5.1 reads .ps1 as ANSI; non-ASCII breaks parsing." No arrows, em dashes, or checkmark glyphs in PowerShell sources or strings they emit. (Companion rule: the sh hook template is LF-only — specs/005 research.md Decision 7.) |
| Backticked repo-relative POSIX paths | In tables and changelog rows: `` `android/scripts/smoke-test.ps1` ``, comma-separated — verify_structure.py parses exactly this shape. |
| Precedence footers | Any derived/summary doc states what it derives from and who wins on conflict (model: the blockquote atop `.specify/memory/constitution.md`). |

## 4. Cautionary tale: the v0.0.7 docs-drift episode

An entire release (v0.0.7, 2026-07-05) was spent paying down documentation lies.
What had drifted, and the lesson each encodes:

| Drift bug | What it was | Lesson |
| :-- | :-- | :-- |
| Ghost map rows | `Project_Structure.md` mapped `GEMINI_Getting_Started.md` and `bootstrap_prompts/` — neither existed (never generated) | Map rows only for files that exist NOW. A planned file gets a `[ ]` task, not a map row. |
| Stale README claim | README instructed copying the Gradle wrapper from Saraswati — but the wrapper had been committed all along | When a setup fact changes, grep README for the old claim in the same commit. |
| Missing `[0.0.5]` entry | v0.0.5 was merged manually with no CHANGELOG entry, silently bypassing the auto-merge signal and its smoke-test gate | The changelog entry is not paperwork; it IS the release mechanism. No entry = no gated release happened. |
| Unlabeled placeholders | `Function_Mapping.md` rows read like real endpoints | Placeholders must be visibly marked ("reserved (N/A today)", italics, status blockquote). |

Root cause in every case: a doc was written for an intended future instead of the
actual present, then nobody reconciled. The grounding rule (2.2) and the checklist
below exist to make that impossible.

## 5. Docs-impact checklist — run before EVERY commit

Walk this top to bottom; each "yes" creates an obligation in the SAME commit (or, for
the CHANGELOG line, the release commit):

1. **Files added/removed anywhere outside `.specify/`, `.claude/`, `.gemini/`,
   `specs/`, `docs/`?** -> Add a Changelog-table row in `Project_Structure.md`
   (Date/Action/Files Affected/Summary), plus a functional-map row if it is a
   durable component. Then run:
   ```powershell
   python .\scripts\verify_structure.py
   ```
   Must print SUCCESS / exit 0.
2. **New feature dir under `specs/` or new skill under `.claude/skills/`?** -> No
   per-file rows needed (directory-level convention), but confirm the parent
   directory has its map row and consider a directory-level Changelog row for
   release visibility.
3. **Design decision made (chose X over Y)?** -> `### Decisions` block queued for
   this version's CHANGELOG entry; promote to README Key Decisions table if durable.
4. **New pattern actually embodied in code now?** -> PATTERNS.md bullet in the right
   numbered section, with the code that proves it. Not embodied yet? -> `[ ]` task
   in the relevant spec instead.
5. **Chunk shipped or chunk-facing behavior changed?** -> README Chunk Status table
   + add/adjust the acceptance test steps.
6. **Backend endpoint added/changed/removed?** (none exists as of 2026-07-13) ->
   Function_Mapping.md real row + Bruno contract path. Otherwise leave it alone.
7. **GEMINI.md or PATTERNS.md materially changed?** -> Director approval confirmed?
   Regenerate `.specify/memory/constitution.md` (001/T021) or state in the changelog
   why not.
8. **Closed any spec `[ ]` task?** -> Flip to `[X] (vX.Y.Z)` in that tasks.md and
   name the task ID in the CHANGELOG entry.
9. **Is this the release commit?** -> Write the CHANGELOG entry now (Keep-a-Changelog
   subsections, cost/scope markers) and remember: including it fires the auto-merge
   signal. Not the release commit? -> CHANGELOG.md must be untouched.
10. **Any `.ps1` touched?** -> ASCII-only scan; any hook template touched -> LF-only.
11. **Wrote a fact that can drift?** -> date-stamp it; wrote a claim about code? ->
    `path:line` it, freshly verified.

## 6. When NOT to use this skill

| You are actually trying to... | Use instead |
| :-- | :-- |
| Run/ship a release, operate the post-commit hook, smoke test, auto-merge | voicebridge-release-gate-runbook |
| Decide whether a change is allowed, get approvals, handle the Bruno exception flow | voicebridge-change-control |
| Understand or modify the app's architecture/contracts themselves | voicebridge-architecture-contract |
| Debug app or emulator failures | voicebridge-debugging-playbook |
| Study past incidents in depth (the v0.0.5 bypass, hook -Build fix 88ac97a) | voicebridge-failure-archaeology |
| Work on WAV/PCM specifics | voicebridge-audio-pipeline-reference |
| Work on GCP STT/Translation request shapes | voicebridge-gcp-speech-apis-reference |
| Manage local.properties, BuildConfig, flags | voicebridge-config-and-flags |
| Set up JDK/SDK/Gradle/emulator | voicebridge-build-and-env |
| Use/extend scripts and diagnostics tooling | voicebridge-diagnostics-and-tooling |
| Design tests/QA beyond doc obligations | voicebridge-validation-and-qa |
| Plan/execute Chunk 3 voice-clone TTS | voicebridge-chunk3-voice-clone-tts-campaign |
| Explore unshipped/novel approaches | voicebridge-research-frontier |

This skill owns the WRITING and MAINTENANCE of the documents; the moment your
question becomes "may I make this change" or "how do I ship it", switch skills.

## 7. Provenance and maintenance

Authored 2026-07-13 by skill-distill (retiring-fellow handover). All line numbers and
statuses verified against the working tree on 2026-07-13. Re-verify before trusting:

| Volatile fact | One-line re-verification (PowerShell, repo root) |
| :-- | :-- |
| Changelog-table gate still enforced + exclusion list | `python .\scripts\verify_structure.py` then `Select-String -Path scripts\verify_structure.py -Pattern '\.specify'` |
| Release-signal wording | `Select-String -Path CHANGELOG.md -Pattern 'auto-merge' ; Select-String -Path PATTERNS.md -Pattern 'Auto-Merge Signal'` |
| PATTERNS.md section line numbers | `Select-String -Path PATTERNS.md -Pattern '^## '` |
| GEMINI.md grounding + precedence clauses | `Select-String -Path GEMINI.md -Pattern 'aspirational|GEMINI.md wins'` |
| Function_Mapping.md still placeholder | `Select-String -Path Function_Mapping.md -Pattern 'reserved for future backend'` |
| Chunk status table | `Select-String -Path README.md -Pattern 'Not started'` |
| Open standing task T021 (distillation regen) | `Select-String -Path specs\001-agentic-framework-governance\tasks.md -Pattern 'T021'` |
| Full-7 spec set shape | `Get-ChildItem specs\001-agentic-framework-governance` |
| ASCII-only .ps1 rule source | `Select-String -Path android\scripts\smoke-test.ps1 -Pattern 'ASCII-only'` |
| Bruno exception string (exact) | `Select-String -Path PATTERNS.md -Pattern 'I understand bruno validation'` |
