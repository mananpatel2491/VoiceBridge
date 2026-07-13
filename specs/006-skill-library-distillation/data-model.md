# Data Model: Agent Skill Library

No runtime storage — the capability is a set of version-controlled files consumed by
agents. The "data model" is the skill file anatomy and the script I/O shapes.

## Skill directory shape

```
.claude/skills/<skill-name>/
├── SKILL.md            # required
├── scripts/            # optional — executable tooling (diagnostics skill only)
└── references/         # optional — dated volatile material (campaign skill only)
```

## SKILL.md schema

| Field / Section | Requirement | Verified example |
| :--- | :--- | :--- |
| `name` (YAML) | = directory name | `.claude/skills/voicebridge-change-control/SKILL.md:2` |
| `description` (YAML) | ≤ 1024 chars; states WHEN to load AND when NOT (sibling routing); block scalar (`>-`) where the text contains `: ` | `voicebridge-change-control/SKILL.md:3-15`; lengths verified 966–1024 across all 14 |
| Body | imperative runbook voice; tables/checklists; every jargon term defined once (glossary tables) | glossary at `voicebridge-change-control/SKILL.md:30-40` |
| Citations | `path:line` into the repo for every operational claim | throughout |
| "When NOT to use this skill" | required; names the sibling to use instead | all 14 |
| "Provenance and maintenance" | required; authored-date 2026-07-13 + one-line re-verification commands for drift-prone facts | all 14 |

## Script I/O shapes

### `inspect_wav.py` (diagnostics skill, pure stdlib)

- **Input**: path to a WAV file; flags `--json` (machine-readable) — argparse.
- **Parses**: the canonical 44-byte header exactly as `AudioRecorder.buildWavHeader()`
  writes it (offset table embedded in the script docstring,
  `.claude/skills/voicebridge-diagnostics-and-tooling/scripts/inspect_wav.py:9-22`).
- **Contract checks**: sample rate 16000, 16-bit, mono
  (`inspect_wav.py:39-40` constants), plus the `header-not-written` detection (44 zero
  bytes = app killed before `writeWavHeader()` ran).
- **Exit codes**: 0 = valid + contract OK; 1 = violations; 2 = unreadable/not WAV.

### `grab_diag.ps1` (diagnostics skill, PowerShell 5.1, ASCII-only)

- **Input**: none required (optional target folder).
- **Output**: timestamped evidence folder — device list, app versionName dump, filtered
  logcat (app + FATAL/AndroidRuntime), foreground activity, screenshot.

## Config/env keys read by the capability

None of its own. Skills *document* the repo's existing axes (`GCP_STT_API_KEY`, `sdk.dir`,
smoke-test parameters) — ownership of those stays with `android/local.properties` and
`android/scripts/smoke-test.ps1:47-53`; the authoritative skill-side inventory is
`voicebridge-config-and-flags/SKILL.md`.

## Persistence

`N/A — nothing persisted at runtime; the library is static Markdown + two stateless
scripts whose outputs land in caller-chosen scratch/evidence folders outside the repo.`
