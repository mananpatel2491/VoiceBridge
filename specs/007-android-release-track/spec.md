# Feature Specification: Android Release Track (shared release process)

**Feature Branch**: `v0.1.0`

**Created**: 2026-10-21

**Status**: Released in v0.1.0 on 2026-10-21; SC-001 to SC-003 met (light spec: the decisions were made in mananutils-platform)

**Supersedes**: `specs/005-release-gate-automation/` (Windows PowerShell smoke test + post-commit
auto-merge hook)

**Source of truth**: [mananutils-platform release runbook, "Android apps"](https://github.com/mananpatel2491/mananutils-platform/blob/main/docs/release-process.md#android-apps)
(PR #8, commit 42e80af). This spec records how VoiceBridge adopts it; it doesn't restate or
re-decide the runbook.

## Why

The old gate ran only on Windows (PowerShell + a local emulator), merged and pushed to `main`
from a post-commit hook, produced no signed or versioned artifact (the app said 0.0.4 through
v0.0.9), and couldn't run from the Chromebook. The shared process gives every mananutils app
the same branch → rc → final flow, with the APK the owner tested being the one released.

## Requirements

- **FR-001**: Releases use the vendored `scripts/release.py` (`rc`, `final`, `cleanup`), pinned by
  `scripts/release.pin`; CI fails if the copies differ from the pin.
- **FR-002**: A `vX.Y.Z-rc.N` tag builds, tests, lints and signs a release APK, smoke-tests it on
  an emulator and publishes it on a GitHub pre-release. A `vX.Y.Z` tag promotes the last rc's
  APK when the files are the same, otherwise builds it the same way.
- **FR-003**: Signing secrets and `LOCAL_PROPERTIES` live only in the GitHub environment
  `android-release` (v* tags only). The APK's certificate must equal `ANDROID_CERT_SHA256`.
- **FR-004**: The version comes from the tag (`versionName` X.Y.Z, `versionCode`
  X*10000+Y*100+Z); `RELEASE_TAG` / `GIT_SHA` in `BuildConfig`; local builds `0.0.0-dev`, code 1.
- **FR-005**: The debug build has its own package id (`.debug`) and installs next to a release
  build.
- **FR-006**: PRs, `main` and `v*` branches run unit tests, lint (errors fail) and a debug build
  without secrets; an empty API key must still compile.
- **FR-007**: The API key built into the public APK is restricted to the app (package +
  certificate SHA-1, release and debug), to the STT and Translation APIs, with a per-day quota
  cap. VoiceBridge-specific: the app sends `X-Android-Package` / `X-Android-Cert` on every Google
  API request, because its plain REST calls don't send them by themselves.
- **FR-008**: Before `final`, the owner works through `.github/release-checklist.md` on the test
  phone (microphone, real network, the key restriction: what an emulator can't show).
- **FR-009**: The PowerShell gate (`smoke-test.ps1`, `install-hooks.ps1`, `hooks/post-commit`) is
  removed, and living docs describe the new flow.

## Success criteria

- **SC-001**: `release.py rc 0.1.0 --dry-run` prints tag `v0.1.0-rc.1`.
- **SC-002**: A locally signed tag build reports `versionName 0.1.0`, `versionCode 100`.
- **SC-003**: The first rc's APK installs on the OnePlus 11 5G and passes the checklist,
  including Transcribe and Translate with the restricted key.

## Out of scope

- An instrumented UI test in the smoke job (the old UIAutomator flow): possible later, the
  workflows are templates the app may extend.
- A backend proxy that holds the API key (the runbook's real fix, when usage is worth abusing).
