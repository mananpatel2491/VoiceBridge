# Contract: Skill Library Surface

The library's "API" is what a consuming agent (or human) may rely on. Breaking any row
below is a breaking change to the library and requires a sweep of the affected skills.

## Directory & frontmatter contract

| Guarantee | Detail |
| :--- | :--- |
| Location | `.claude/skills/voicebridge-<topic>/SKILL.md`, one directory per skill, 14 skills |
| Frontmatter | valid YAML; `name` = directory name; `description` ≤ 1024 chars containing load-triggers AND do-NOT-load routing |
| Required sections | "When NOT to use this skill" (sibling routing) and "Provenance and maintenance" (authored date + re-verification one-liners) |
| Grounding | operational claims cite `path:line` at HEAD of authoring (80b756f); volatile facts date-stamped 2026-07-13 |
| Doctrine | no skill documents a route around change control; sole sanctioned exception = the Bruno acknowledgment string (`PATTERNS.md:10`) |

## Sibling routing map (who owns what)

| Fact domain | Owning skill (single home) |
| :--- | :--- |
| Change classification, gates, release obligations, Spec Kit chain | voicebridge-change-control |
| Hook + smoke-test mechanics, KEEP-IN-SYNC selector table | voicebridge-release-gate-runbook |
| Symptom → triage → discriminating check | voicebridge-debugging-playbook |
| Incident history (v0.0.5 bypass, 88ac97a, docs drift, ANR flake) | voicebridge-failure-archaeology |
| Invariants, decisions, known-weak points | voicebridge-architecture-contract |
| WAV/PCM byte-level knowledge | voicebridge-audio-pipeline-reference |
| GCP STT v1 / Translation v2 request-response shapes | voicebridge-gcp-speech-apis-reference |
| Config axes + add-a-config checklist | voicebridge-config-and-flags |
| From-scratch machine setup | voicebridge-build-and-env |
| Measurement scripts + evidence collection | voicebridge-diagnostics-and-tooling |
| Evidence bar, acceptance tests, extending coverage | voicebridge-validation-and-qa |
| Docs of record, formats, docs-impact checklist, verify_structure exclusions | voicebridge-docs-and-writing |
| Chunk 3 executable campaign | voicebridge-chunk3-voice-clone-tts-campaign |
| Open research problems + evidence methodology | voicebridge-research-frontier |

## Script CLI contract

### `voicebridge-diagnostics-and-tooling/scripts/inspect_wav.py`

```
python inspect_wav.py <wav-path> [--json]
```

| Exit | Meaning |
| :--- | :--- |
| 0 | header valid AND matches contract (PCM, 16000 Hz, 16-bit, mono) |
| 1 | parseable but contract violations (wrong rate/bits/channels, zero data, header-not-written) |
| 2 | unreadable / not a WAV |

`--json` emits a machine-readable object (parsed fields + violation list). Pure stdlib —
no pip installs.

### `voicebridge-diagnostics-and-tooling/scripts/grab_diag.ps1`

```
powershell -File grab_diag.ps1
```

Produces a timestamped evidence folder: device list, `com.mananpatel.voicebridge`
versionName, filtered logcat (app + FATAL/AndroidRuntime), foreground activity,
screenshot. ASCII-only source (PowerShell 5.1 parses .ps1 as ANSI).

## Binary-pull contract (library-wide)

Every recipe that moves a binary file off the device uses the byte-safe two-step:

```powershell
& C:\Android\platform-tools\adb.exe shell "run-as com.mananpatel.voicebridge cp files/<f> /sdcard/<f>"
& C:\Android\platform-tools\adb.exe pull /sdcard/<f> <local>
```

`adb exec-out ... > file` from Windows PowerShell 5.1 is contractually a TRAP (UTF-16LE
re-encode + BOM, empirically verified 2026-07-13) and may appear in skills only as a
warning, never as a recipe.
