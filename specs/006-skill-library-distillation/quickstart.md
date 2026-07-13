# Quickstart: Agent Skill Library

## 1. See the library

```powershell
Get-ChildItem C:\Docs\Build\mananUtils\VoiceBridge\.claude\skills -Directory |
  Where-Object Name -like 'voicebridge-*'
```

Expect 14 directories (plus the 10 pre-existing `speckit-*` ones).

## 2. Use it from Claude Code

Open a Claude Code session anywhere inside the repo. The skills are auto-discovered (same
mechanism as the `speckit-*` skills). Trigger them naturally:

| You ask | Skill that should load |
| :--- | :--- |
| "How do I cut a release here?" | voicebridge-change-control |
| "Smoke test can't find the Record button" | voicebridge-release-gate-runbook |
| "Transcribe returns 403" | voicebridge-debugging-playbook |
| "Set this repo up on a new laptop" | voicebridge-build-and-env |
| "Start Chunk 3" | voicebridge-chunk3-voice-clone-tts-campaign |

Each skill's "When NOT to use" section routes you to the right sibling if you landed wrong.

## 3. Run the shipped diagnostics

```powershell
# Parse and contract-check a WAV (exit 0 = healthy, 1 = contract violation, 2 = not a WAV)
python C:\Docs\Build\mananUtils\VoiceBridge\.claude\skills\voicebridge-diagnostics-and-tooling\scripts\inspect_wav.py `
  $env:TEMP\rec.wav --json

# One-shot ADB evidence bundle (device must be connected / emulator booted)
powershell -File C:\Docs\Build\mananUtils\VoiceBridge\.claude\skills\voicebridge-diagnostics-and-tooling\scripts\grab_diag.ps1
```

To get a WAV off the device byte-safely first (NEVER `exec-out ... >` in PowerShell 5.1):

```powershell
& C:\Android\platform-tools\adb.exe shell "run-as com.mananpatel.voicebridge cp files/recording.wav /sdcard/recording.wav"
& C:\Android\platform-tools\adb.exe pull /sdcard/recording.wav $env:TEMP\rec.wav
```

## 4. Verify the library's own health

```powershell
# All frontmatter parses and descriptions are within the 1024-char cap
Get-ChildItem C:\Docs\Build\mananUtils\VoiceBridge\.claude\skills\voicebridge-* -Filter SKILL.md -Recurse |
  Select-String -Pattern '^name:' | Measure-Object   # expect Count : 14

# Repo gates stay green with the library present
python C:\Docs\Build\mananUtils\VoiceBridge\scripts\verify_structure.py
```

The full app-level gate (build + emulator UI drive) remains
`powershell -File android/scripts/smoke-test.ps1 -Build` from the repo root — the library
adds nothing to it and must never weaken it.
