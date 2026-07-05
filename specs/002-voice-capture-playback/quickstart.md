# Quickstart: Voice Capture & Playback (Chunk 0)

Chunk 0 needs no API key and no network — it runs fully offline.

## 1. One-time setup

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge\android
# Create local.properties from the template (only sdk.dir is required for Chunk 0)
Copy-Item local.properties.template local.properties
# edit: sdk.dir=C\:\\Android  and leave GCP_STT_API_KEY empty
```

JDK 17 required (build baseline: AGP 9.1.1 / Gradle 9.3.1 wrapper — already pinned in
`gradle/wrapper/gradle-wrapper.properties`).

## 2. Build and install

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge\android
.\gradlew assembleDebug
adb install -r app\build\outputs\apk\debug\app-debug.apk
```

## 3. Manual acceptance test (from README.md "Acceptance test — Chunk 0")

1. Launch VoiceBridge; grant microphone permission when prompted.
2. Tap **Record**, speak, tap **Stop**.
3. Tap **Play** — you hear the playback clearly.
4. Negative path: deny the permission instead — a card explains how to re-enable via
   Settings, and Record stays disabled.

Verify the artifact directly:

```powershell
adb shell run-as com.mananpatel.voicebridge ls -l files/
# recording.wav — starts with RIFF....WAVEfmt
```

## 4. Automated verification

```powershell
powershell -File android\scripts\smoke-test.ps1 -Build
```

Steps 4–7 of the smoke test assert the initial enabled/disabled matrix
(Record=on, Stop/Play=off), the recording state flip, and playback, with a screenshot per
step under `android/app/build/smoke-<timestamp>/`.
