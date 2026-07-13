---
name: voicebridge-change-control
description: >-
  Change-control runbook for the VoiceBridge repo (C:\Docs\Build\mananUtils\VoiceBridge):
  how every change is classified, branched, committed, gated, and documented. Load this
  skill WHENEVER you are about to create a branch, commit, merge, release a version,
  write a CHANGELOG entry, decide whether a change needs the Spec Kit chain, decide
  whether the Bruno or Terraform gate applies, or when someone asks "how do I ship a
  change / cut a release?" — this skill owns whether a change may ship and what it
  obligates (mechanics of the hook itself: voicebridge-release-gate-runbook). Also load it when a
  merge to main appears to have happened without a CHANGELOG entry (that is a process
  incident — see the v0.0.5 case inside). Do NOT load it for build/emulator environment
  problems (voicebridge-build-and-env), for driving or debugging the smoke test itself
  (voicebridge-release-gate-runbook), for app-crash diagnosis (voicebridge-debugging-playbook),
  or for architecture questions (voicebridge-architecture-contract).
---

# VoiceBridge Change Control

Every rule in this file exists because something went wrong (or almost did). Rationale
and the historical incident are given with each rule. Precedence of documents:
**GEMINI.md wins over everything** (constitution of record) > `PATTERNS.md` (pattern
registry) > `.specify/memory/constitution.md` (a distillation for Spec Kit — it never
introduces rules and never wins on conflict; see its own precedence header at
`.specify/memory/constitution.md:3-5`).

**Never document, suggest, or use a way around these gates.** The single sanctioned
exception is the Bruno acknowledgment string in section 6 — nothing else.

## Glossary (defined once)

| Term | Meaning |
| :--- | :--- |
| Version branch | Git branch named exactly `vX.Y.Z` (e.g. `v0.0.8`). All work happens here; `main` is merge-only. |
| Release signal | A commit on a version branch that modifies `CHANGELOG.md`. This is what tells the hook "this version is done". |
| The hook | `.git/hooks/post-commit`, installed from the template `android/scripts/hooks/post-commit` by `powershell -File android/scripts/install-hooks.ps1`. `.git/` is untracked, so re-install after every fresh clone. |
| Smoke test | `android/scripts/smoke-test.ps1` — emulator UIAutomator drive of the app (text-based selectors, screenshot per step, logcat crash gate). The authoritative definition of "done" for a version (PATTERNS.md §5). |
| Auto-merge | The `-AutoMerge` tail of the smoke test: on pass, merge the version branch to `main` and push both branches to `origin`. |
| Spec Kit | GitHub Spec Kit feature workflow: `specify → clarify → plan → tasks → implement`, artifacts under `specs/NNN-slug/`. |
| Bruno | API contract-testing tool. Collections live under `bruno/` (currently only a README plus `.gitkeep` placeholders in `collections/` and `docs/` — no backend exists yet, 2026-07-13). |
| Director | The user/owner (high-level intent, arbitration, final review — GEMINI.md role definition). |

## 1. Change classification — decide this FIRST

| Change type | Version branch? | Spec Kit chain? | Smoke test | Bruno | Terraform/cost gate | Doc bookkeeping (section 8) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Docs-only (README, PATTERNS, specs, CHANGELOG fix) | Yes — even docs ship via `vX.Y.Z` (v0.0.6 and v0.0.7 were docs-only releases) | No | Runs anyway on every version-branch commit (hook is unconditional) | No | No | Changelog-table row if files added/removed; CHANGELOG entry at release |
| App code — trivial fix (bug fix, rename, small refactor) | Yes | No ("beyond a trivial fix" threshold, GEMINI.md:54) | Yes; if you renamed any button text, update smoke-test selectors in the SAME commit (PATTERNS.md §5) | No (no backend) | No | Changelog-table row for added/removed files; CHANGELOG entry at release |
| App code — new feature (new chunk, new pipeline stage, new screen) | Yes | **YES — mandatory** (GEMINI.md:53-56) | Yes; extend the smoke test to cover the new flow (v0.0.4 added a translate step — CHANGELOG.md:64-67) | Only if it adds a backend API | Only if it needs infra | All of section 8 |
| Infra-dependent (anything creating GCP resources beyond free-tier direct API calls) | Yes | Yes | Yes | Yes, once an API exists | **YES** (section 7) | All of section 8 + `terraform/` update |
| Backend/API-exposed function (none exist yet, 2026-07-13) | Yes | Yes | Yes | **YES** (section 6) | Usually yes | All of section 8 + `Function_Mapping.md` row |

## 2. Version-branch flow and the auto-merge signal

**Rule** (PATTERNS.md §4:33-37): all work on a branch named `vX.Y.Z`; never commit
directly to `main`. Updating `CHANGELOG.md` in a commit is the signal a version is
complete.

The full release loop:

```powershell
git checkout main
git pull origin main
git checkout -b v0.0.8                      # next version branch
# ... make changes, intermediate commits ...
git commit -m "feat: <description>"         # hook: smoke test only (no -Build), NO merge
# ... finish work, write CHANGELOG entry + doc rows ...
git commit -m "chore: v0.0.8"               # hook: -Build + smoke test + auto-merge + push
```

**Hook and `-AutoMerge` mechanics**: step-by-step hook behavior and the auto-merge tail
(with line citations) live in **voicebridge-release-gate-runbook sections 1-2** — that
skill is the single source for HOW the gate executes; this skill owns WHETHER/WHAT may
ship. Policy facts you still need here:

- Commits on `main` or any non-`vX.Y.Z` branch run nothing — which is why committing to
  `main` directly bypasses ALL gates and is forbidden.
- On a failed release run you stay on the version branch; fix and recommit. The
  CHANGELOG is already in HEAD, so the next commit that touches anything else will NOT
  re-signal — either touch CHANGELOG again (e.g. fix a typo in the entry) or re-run
  manually: `powershell -File android/scripts/smoke-test.ps1 -Build -AutoMerge`.
- On a passing release run the script pushes both branches to origin unconditionally
  (known open gap, specs/005-release-gate-automation/tasks.md T018, still `[ ]`), then
  prints `Next: git checkout -b v<next-version>` — do that; never keep working on main.

**Rationale**: the merge-to-main is machine-performed only after a machine-verified
green run. A human (or agent) merging by hand skips the verification — see section 3.

**Historical fix — commit `88ac97a`**: a release gate that doesn't build what it tests
is theater — if you ever edit the hook template, re-run `install-hooks.ps1` (templates
don't self-install) and re-verify `-Build` is on the release path. Full incident record
with evidence commits: voicebridge-failure-archaeology INC-2.

## 3. The v0.0.5 bypass incident — why the signal is never skipped

**What happened, in one line**: v0.0.5 was merged to main manually, without a CHANGELOG
entry — bypassing the release signal and its green-smoke-test guarantee; the entry was
added retroactively in v0.0.7. Full incident record with evidence commits and the
tell-tale merge-message format: **voicebridge-failure-archaeology INC-1**.

**Rules derived from this incident:**

1. Never run `git merge` into `main` by hand. The only sanctioned path to `main` is the
   hook-triggered auto-merge after a passing smoke test.
2. Never release without a CHANGELOG entry in the release commit. "I'll add it later"
   creates the exact hole v0.0.7 had to patch.
3. If you find a merge commit on `main` whose message is not `Merge vX.Y.Z into main`,
   treat it as a process incident: verify the smoke test would pass on that state, add
   any missing CHANGELOG entry retroactively with an italic incident note (copy the
   v0.0.5 note's format, CHANGELOG.md:48-49), and log the fix in the changelog table.
4. Retroactive fixes are themselves releases: v0.0.7 went through the full branch →
   CHANGELOG → hook → auto-merge flow even though it was docs-only.

## 4. Spec Kit feature workflow

**Rule** (GEMINI.md:53-56): any new feature beyond a trivial fix MUST run the chain
`specify → clarify → plan → tasks → implement` before code is written. The chain is the
concrete implementation of the 80/20 planning phase; artifacts persist in `specs/NNN-slug/`.

Command forms (both installed, verified 2026-07-13):

| Environment | Form | Location |
| :--- | :--- | :--- |
| Claude Code | **dash**: `/speckit-specify`, `/speckit-clarify`, `/speckit-plan`, `/speckit-tasks`, `/speckit-implement` (also analyze/checklist/constitution/converge/taskstoissues) | `.claude/skills/speckit-*/` |
| Gemini CLI | **dot**: `/speckit.specify`, `/speckit.clarify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.implement` | `.gemini/commands/speckit.*.toml` |

Constitution precedence inside the chain: the Spec Kit constitution
`.specify/memory/constitution.md` is a **distillation** of GEMINI.md + PATTERNS.md with
an explicit precedence header. It never introduces rules of its own; **on any conflict
GEMINI.md wins** (GEMINI.md:56, PATTERNS.md:16). When GEMINI.md materially changes,
regenerate the distillation — do not patch the distillation alone.

Existing spec sets (`specs/001-*` … `specs/005-*`) are **as-built retro-specs** (v0.0.6):
tasks marked `[X]` shipped; tasks marked `[ ]` are genuinely open gaps (e.g. provider
interfaces `STTProvider`/`TranslationProvider` are named in the Pipeline Stage Registry
but NOT extracted in code; no VAD gating; no streaming; hook pushes unconditionally).
Do not mark them `[X]` without shipping them; do not restate them as done.

## 5. Commit conventions

(PATTERNS.md §4:37) —

| Prefix | Use |
| :--- | :--- |
| `feat:` | New features |
| `fix:` | Bug fixes |
| `chore:` | Maintenance — CHANGELOG update, dependency bump |
| `chore: vX.Y.Z` | **The release commit** — the one that updates CHANGELOG.md and triggers auto-merge |

The merge commit itself is authored by the script as `Merge vX.Y.Z into main`
(smoke-test.ps1:392) — never write merge commits by hand (section 3).

## 6. The Bruno gate (dormant today, binding the moment a backend ships)

**Status 2026-07-13**: no backend exists. The app calls GCP STT/Translation REST APIs
directly from the device; `bruno/` holds only a README and `Function_Mapping.md` rows
are italicized reserved-for-future-backend placeholders (Function_Mapping.md:4-9). So
the gate currently has nothing to gate — it is **dormant, not deleted**.

**The binding rule** (GEMINI.md:24-29, PATTERNS.md:10): every new API-exposed backend
function requires a corresponding Bruno script; no backend API feature is complete
until the Bruno pipeline is updated; successful Bruno execution is required for all
commits; maintain an .md in `bruno/` that generates a visual HTML flow of the tests.

The ONLY sanctioned exception — an explicit owner acknowledgment in the commit message,
exact string (PATTERNS.md:10):

```
I understand bruno validation is failing and I allow the exception to have the code committed to github repo
```

Nothing else — no paraphrase, no "temporary skip", no commenting out the gate.

## 7. The Terraform/cost gate (GEMINI.md rule 5)

**Rule** (GEMINI.md:31-34): every infra-dependent feature requires a Terraform update
(targeting GCP) under `terraform/`. Before any GitHub **tagging**: calculate projected
costs and run `terraform plan`. Tagging triggers deployment, so **tagging is prohibited
until cost and infra reviews are finalized**.

What counts as infra-dependent: anything that creates or configures GCP resources —
a backend service, Cloud Run, buckets, service accounts, paid API tiers. What does NOT:
the current direct-from-device GCP STT/Translation calls (free tier: STT 60 min/mo,
Translation 500K chars/mo — `.specify/memory/constitution.md:22`), docs, app-only code.

**Status 2026-07-13**: `terraform/` contains only README/`.gitkeep` scaffolding; like
Bruno, this gate is dormant until the first infra-dependent feature (likely Chunk 3
voice-clone TTS or Chunk 4 relay — neither started). Terraform/tflint/checkov are NOT
installed on this machine — plan for tool installation when the gate first activates.

## 8. Mandatory doc bookkeeping per change

| Artifact | When to update | Enforcement |
| :--- | :--- | :--- |
| `Project_Structure.md` changelog table (bottom of file) | EVERY file addition or removal, immediately — row = Date / Action / Files Affected / Summary (GEMINI.md:12) | **Machine-enforced**: `scripts/verify_structure.py` runs as step 0 of every smoke test (smoke-test.ps1:167-169) and fails the run if any tracked file is missing from the table's "Files Affected" column. Exclusions (verify_structure.py:53-74): `.git`, `docs/`, `__pycache__`, `.specify/` `.claude/` `.gemini/` `specs/` (mapped at directory level), gitignored Android build outputs. A forgotten row = red gate = no merge. |
| `Project_Structure.md` map tables | New/renamed/deleted files change the functional map too — never leave ghost rows (v0.0.7 removed two ghost rows that pointed at nonexistent files) | Manual; audit during review |
| `CHANGELOG.md` | One entry per release, Keep-a-Changelog format, in the release commit itself | Its update IS the auto-merge signal (section 2); its absence is the v0.0.5 incident (section 3) |
| `PATTERNS.md` | Whenever a new engineering pattern or design decision is established — grounded in actual code, never aspirational (GEMINI.md:17) | Manual |
| `Function_Mapping.md` | Whenever endpoints/backend functions are added/changed/deleted (currently placeholder-only) | Manual; paired with the Bruno gate |
| Smoke-test selectors | Same commit as any UI button rename / screen addition (smoke-test.ps1:26, PATTERNS.md §5) | Enforced by the smoke test failing |

## 9. Pre-commit checklist

Intermediate commit on `vX.Y.Z`:

- [ ] On a `vX.Y.Z` branch (`git branch --show-current`), not `main`
- [ ] Message prefixed `feat:` / `fix:` / `chore:`
- [ ] CHANGELOG.md NOT staged (unless you intend to release — it will fire auto-merge)
- [ ] New/removed files have a `Project_Structure.md` changelog-table row (else the hook's smoke test goes red)
- [ ] UI text changed → smoke-test selectors updated in this commit
- [ ] Emulator available (`voicebridge_avd`) — the hook will drive it

Release commit (`chore: vX.Y.Z`):

- [ ] All of the above, plus:
- [ ] CHANGELOG.md entry written under `## [X.Y.Z] - <date>` (Added/Changed/Fixed/Decisions)
- [ ] `Project_Structure.md` map + changelog table complete for the whole version
- [ ] New feature? Spec Kit artifacts exist in `specs/NNN-*/` with tasks updated
- [ ] New pattern? `PATTERNS.md` updated. New endpoint? `Function_Mapping.md` + Bruno
- [ ] Infra touched? Terraform updated, costs projected, `terraform plan` reviewed — and NO git tag until reviews are final
- [ ] `python scripts/verify_structure.py` exits 0 locally
- [ ] Prepared for the hook to build, smoke-test, merge to main, and **push both branches to origin** (unconditional — don't release with unpushable state)
- [ ] After the green run: `git checkout -b v<next>` before any further work

## When NOT to use this skill

| You actually need | Sibling skill |
| :--- | :--- |
| Running/debugging the smoke test, emulator, hook mechanics failing | `voicebridge-release-gate-runbook` |
| JDK/SDK/Gradle/AGP build environment issues | `voicebridge-build-and-env` |
| App crashes, STT/translation runtime errors | `voicebridge-debugging-playbook` |
| Why past decisions/incidents happened, in depth | `voicebridge-failure-archaeology` |
| Architecture rules, provider interfaces, pipeline contracts | `voicebridge-architecture-contract` |
| WAV/PCM format details | `voicebridge-audio-pipeline-reference` |
| GCP STT/Translation API specifics | `voicebridge-gcp-speech-apis-reference` |
| API keys, local.properties, buildConfigField flags | `voicebridge-config-and-flags` |
| Test/QA strategy beyond the gate | `voicebridge-validation-and-qa` |
| Writing docs/specs style | `voicebridge-docs-and-writing` |
| Building Chunk 3 (voice-clone TTS) | `voicebridge-chunk3-voice-clone-tts-campaign` |
| Researching new approaches/providers | `voicebridge-research-frontier` |
| Logcat/adb/diagnostic tooling | `voicebridge-diagnostics-and-tooling` |

## Provenance and maintenance

Authored 2026-07-13 by skill-distill (repo state: main at `80b756f`, v0.0.7). Updated
same day: the AGP 9 built-in-Kotlin migration was committed in v0.0.8 after it blocked
the release (voicebridge-failure-archaeology INC-6).

Re-verify before trusting drift-prone claims:

| Claim | One-line re-verification |
| :--- | :--- |
| Hook behavior / flags | `Get-Content android/scripts/hooks/post-commit` |
| Auto-merge tail | `Select-String -Path android/scripts/smoke-test.ps1 -Pattern 'AutoMerge' -Context 0,5` |
| Bruno exception string | `Select-String -Path PATTERNS.md -Pattern 'I understand bruno'` |
| Bruno/Terraform still dormant | `Get-ChildItem bruno, terraform -Recurse -File` |
| Spec Kit command forms | `Get-ChildItem .claude/skills, .gemini/commands` |
| Constitution precedence | `Get-Content .specify/memory/constitution.md -TotalCount 5` |
| verify_structure exclusions | `Select-String -Path scripts/verify_structure.py -Pattern 'startswith|rel_path.parts'` |
| Latest release / branch state | `git log --oneline -5; git branch -a` |
| Open gaps still open | `Select-String -Path specs/005-release-gate-automation/tasks.md -Pattern '\[ \]'` |
