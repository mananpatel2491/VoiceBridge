---
name: voicebridge-release-gate-runbook
description: >
  Operate VoiceBridge's release machinery since v0.1.0: the Android track of the shared
  mananutils-platform release process. Covers the dev loop (115g vb to the OnePlus 11 5G),
  what CI checks on a PR (android-ci.yml), what an rc or final tag does
  (android-release.yml: signed APK, emulator smoke test, pre-release, promotion), the
  on-phone checklist, release.py rc/final/cleanup (owner runs them; agents only --dry-run),
  and reading a failed CI or release run. Load it whenever you are about to open a PR, cut
  or check a release candidate, update the release checklist, touch the workflows, signing
  or versioning in build.gradle.kts, or diagnose a red CI/release run or an APK that won't
  install. Do NOT load it for deciding WHETHER a change is allowed or how to document it
  (voicebridge-change-control), root-causing app defects (voicebridge-debugging-playbook),
  JDK/SDK install problems (voicebridge-build-and-env), or STT/translation API semantics
  (voicebridge-gcp-speech-apis-reference). The Windows PowerShell gate (smoke-test.ps1 +
  post-commit auto-merge) this skill used to describe was removed in v0.1.0.
---

# VoiceBridge Release Runbook (v0.1.0+)

The source of truth is the platform runbook:
https://github.com/mananpatel2491/mananutils-platform/blob/main/docs/release-process.md#android-apps
(read its Troubleshooting table for any red run). This page is the VoiceBridge-specific layer.

## Dev loop

| Step | Command |
|---|---|
| Build + install + launch the debug build on the test phone | `115g vb` (Chromebook) or `cd android && ./gradlew installDebug` |
| Evidence | `115g log` (app logcat), `115g shot`, `115g crash`; files in `~/115g-logs/` |
| What CI runs, before a PR | `cd android && ./gradlew testDebugUnitTest lintDebug assembleDebug` |

- Debug package: `com.mananpatel.voicebridge.debug`. Release: `com.mananpatel.voicebridge`.
- Test phone: OnePlus 11 5G at 10.0.0.50 (`115g`). Never the Nexus 6P: it's house DNS.
- Lint errors fail the build (`abortOnError = true`).

## A version, end to end

1. Branch `vX.Y.Z` from `main`; commit; add the CHANGELOG entry; push with
   `git push origin refs/heads/vX.Y.Z`; open a PR (vendored template). CI must be green.
2. Owner: `python3 scripts/release.py rc X.Y.Z` → tag `vX.Y.Z-rc.N` →
   `android-release.yml`: unit tests, `lintRelease`, signed `assembleRelease`, certificate check
   against `ANDROID_CERT_SHA256`, emulator smoke (install, launch, alive after 20 s), then a
   GitHub pre-release with the APK, its SHA-256 and `.github/release-checklist.md`.
3. Owner: install the APK (`115g install <apk>`), work through the checklist. A fix → commit,
   push, next rc.
4. Merge the PR. Owner: `python3 scripts/release.py final X.Y.Z` (refuses if `main`'s files
   differ from the last rc) → the workflow promotes that rc's APK unchanged.
5. Delete the rc pre-releases, `release.py cleanup X.Y.Z`, delete the branch (runbook "Cleanup").

Agents run `release.py` only with `--dry-run` (it prints the tag it would push).

## Keep in sync

| When you change | Also update |
|---|---|
| A button label or a screen | `.github/release-checklist.md` |
| A new Google API call | Use `.androidClient()` (`AndroidClientHeaders.kt`), add the API to the key's `--api-target` list (owner) |
| Signing, version or package id in `build.gradle.kts` | The workflows' assumptions, the key's Android restriction (package + SHA-1) |
| The vendored kit (`scripts/release.py`, `test_release.py`, PR template, `release.pin`) | Never here: change mananutils-platform, then vendor again |

## VoiceBridge specifics the platform runbook doesn't cover

- The release signing config is only created when `ANDROID_KEYSTORE_PATH` is set: AGP 9.1
  refuses a signing config without a `storeFile` (the runbook's snippet assumes otherwise).
- `Requests from this Android client application are blocked`: the build's package + SHA-1
  isn't on the key, or the request lacks the headers. Debug builds from another machine have
  another debug key.
- The smoke job only checks launch: the UIAutomator flow of the old `smoke-test.ps1`
  (Record → Transcribe → Translate) is not in CI. The checklist covers it on the phone.
