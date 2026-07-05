# Tooling Contract: governance scripts & Spec Kit surface

No REST API exists in this capability; the contract surface is CLI + document precedence.

## scripts/verify_structure.py (the load-bearing gate)

| Aspect | Contract |
|---|---|
| Invocation | `python scripts/verify_structure.py [--dry-run] [--model X]` (`--model` is a no-op, kept for fleet consistency, `verify_structure.py:91`) |
| Input | `Project_Structure.md` Changelog table, column 3 "Files Affected" (`verify_structure.py:26-37`) |
| Exclusions | `.git`, `__pycache__`, `.env`, `bootstrap_prompts/`, `docs/`, `Project_Structure.md` itself; top-level `.specify/`, `.claude/`, `.gemini/`, `specs/`; `android/.gradle/`, `android/app/build/`, `android/local.properties` (`verify_structure.py:55-75`) |
| Exit 0 | `SUCCESS: All files are accounted for in the changelog.` |
| Exit 1 | `CRITICAL: The following N files are missing from Project_Structure.md:` + sorted list (`verify_structure.py:81-84`); also exit 1 if no `Project_Structure.md` found upward of the script (`verify_structure.py:43-45`) |
| Consumers | smoke test step 0 (`android/scripts/smoke-test.ps1:163-172`) — failure there is recorded as `verify_structure.py failed (changelog mismatch)` |

## Gemini-backed scripts (generate_bootstrap_prompt / optimize_changelog / update_getting_started)

| Aspect | Contract |
|---|---|
| Credentials | `GOOGLE_API_KEY` from env or repo-root `.env`; abort with location hint if absent; masked echo (`AIza...xxxx`) if present (`generate_bootstrap_prompt.py:54-59`) |
| Model selection | `--model` override → live `models.list()` pick → fallback `models/gemini-1.5-flash`; non-interactive stdin (EOFError) auto-selects default (`generate_bootstrap_prompt.py:13-38`) |
| Safety | `--dry-run` previews without writing (`PATTERNS.md:49`) |
| Missing deps | import failure prints `pip install -r requirements.txt` guidance and exits (`generate_bootstrap_prompt.py:5-11`) |

## Bruno gate (declared; inert until a backend exists)

- Rule: no backend API feature is complete until `bruno/collections/` is updated and passing
  (`GEMINI.md:24-29`, `bruno/README.md`).
- Exception protocol: commit message must contain the exact string
  `I understand bruno validation is failing and I allow the exception to have the code committed to github repo`.
- Current state: `bruno/collections/.gitkeep` only — nothing to validate; no hook enforces
  Bruno today (the post-commit hook runs the smoke test only, see spec 005).

## Spec Kit precedence contract

- `.specify/memory/constitution.md` is a distillation; **GEMINI.md wins on conflict**
  (`.specify/memory/constitution.md:3-5`).
- Trigger forms: Claude Code `/speckit-<verb>` (skills in `.claude/skills/`), Gemini CLI
  `/speckit.<verb>` (TOML in `.gemini/commands/`); 10 verbs each: analyze, checklist, clarify,
  constitution, converge, implement, plan, specify, tasks, taskstoissues.
- Artifacts: `specs/NNN-<slug>/` seeded from `.specify/templates/` (spec, plan, tasks,
  checklist, constitution templates).
