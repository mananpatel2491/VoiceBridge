# Data Model: Agentic Framework Governance & Spec Kit Adoption

No database. The "data" of this capability is structured Markdown plus script configuration.

## Changelog table (the structure-gate contract)

Defined in `Project_Structure.md` under `## Changelog` (`Project_Structure.md:63-73`), parsed
by `scripts/verify_structure.py:14-39`:

| Column (index) | Meaning | Gate use |
|---|---|---|
| Date (0/1) | ISO date of the change | ignored |
| Action (2) | INITIALIZE / ADD / UPDATE / DELETE | ignored |
| Files Affected (3) | comma-separated backticked paths | **parsed**: split on `,`, backticks stripped, normalized to POSIX (`verify_structure.py:29-37`) |
| Summary (4) | human summary | ignored |

Gate semantics: every actual file (after exclusions, `verify_structure.py:55-75`) must appear
in the union of all "Files Affected" cells; missing files → exit 1 with a listed diff
(`verify_structure.py:78-84`).

## Pipeline Stage Registry (architecture metadata)

`Project_Structure.md:52-61` — one row per pipeline stage: Stage, Role, Provider Interface,
Current Implementation. Current rows: Audio Capture → `AudioRecorder.kt`, STT →
`SttService.kt`, Translation → `TranslationService.kt`, LLM → TBD, TTS → TBD, Audio Output →
`AudioPlayer.kt`. (Note: the "Provider Interface" names `STTProvider`/`TranslationProvider`
are registry-declared targets; no such Kotlin interfaces exist in code yet — see spec 003/004
open items.)

## Spec Kit constitution metadata

`.specify/memory/constitution.md:45` — `**Version**: 1.0.0 | **Ratified**: 2026-07-05 |
**Last Amended**: 2026-07-05`; regenerated whenever `GEMINI.md`/`PATTERNS.md` materially
change (`.specify/memory/constitution.md:43`).

## Config / env keys

| Key | Read by | Default / behavior |
|---|---|---|
| `GOOGLE_API_KEY` | `scripts/generate_bootstrap_prompt.py:56-59` (via env or repo-root `.env`), `optimize_changelog.py`, `update_getting_started.py` | required; abort with a pointer to where it was looked up; masked echo on success |
| `--model` (CLI) | all Gemini-backed scripts | bypasses interactive model pick; fallback `models/gemini-1.5-flash` (`generate_bootstrap_prompt.py:20-24`) |
| `--dry-run` (CLI) | all scripts | preview mode; `verify_structure.py` is read-only regardless (`verify_structure.py:92-96`) |

## Python dependencies

`requirements.txt:1-2` — `google-genai`, `python-dotenv`. Import failures produce an
actionable message, not a traceback (`scripts/generate_bootstrap_prompt.py:5-11`).
