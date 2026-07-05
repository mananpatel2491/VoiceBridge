# Quickstart: Agentic Framework Governance & Spec Kit Adoption

Everything here runs offline except the Gemini-backed scripts (which need `GOOGLE_API_KEY`).

## 1. Run the structure gate (no credentials needed)

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge
python .\scripts\verify_structure.py
# SUCCESS: All files are accounted for in the changelog.   (exit 0)
```

Break it on purpose: create any untracked file at repo root (e.g. `touch scratch.txt`) and
re-run — the gate exits 1 and names the file. Delete the file to go green again.

## 2. Preview changelog consolidation (dry-run, needs GOOGLE_API_KEY)

```powershell
pip install -r requirements.txt          # google-genai + python-dotenv
python .\scripts\optimize_changelog.py --dry-run
```

Without `GOOGLE_API_KEY` in env or `.env` the script aborts with a clear message — that
failure mode is itself part of the contract (no silent fallback).

## 3. Generate a session bootstrap prompt

```powershell
python .\scripts\generate_bootstrap_prompt.py "Plan Chunk 3 voice-clone TTS" --model models/gemini-1.5-flash
```

Output lands in `bootstrap_prompts/` (created on first use; the directory is excluded from the
structure gate, `scripts/verify_structure.py:60`).

## 4. Exercise the Spec Kit chain

In a Claude Code session at repo root: `/speckit-specify <feature description>` — or in Gemini
CLI: `/speckit.specify <feature description>`. Artifacts appear under `specs/NNN-<slug>/`
seeded from `.specify/templates/`. The Constitution Check in any generated plan gates against
`.specify/memory/constitution.md` (GEMINI.md remains supreme).

## 5. Verify governance docs are current

```powershell
python .\scripts\verify_structure.py     # map ↔ tree integrity
git log --oneline -5                     # each release has a matching Changelog-table row
```
