# Quickstart: Gujarati Speech-to-Text (Chunk 1)

## 0. Without any credential (error-path demo, what CI does)

Build and install as in spec 002's quickstart with `GCP_STT_API_KEY=` left blank, then:
Record → Stop → tap **Transcribe (Gujarati)** — an error card appears naming
`GCP_STT_API_KEY` and pointing at `local.properties.template`. No crash. This exact flow is
smoke-test step 8:

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge
powershell -File android\scripts\smoke-test.ps1 -Build
```

## 1. Get a real key (one key serves STT and Translation)

1. console.cloud.google.com → create/select a project.
2. Enable **Cloud Speech-to-Text API** (APIs & Services → Library).
3. Credentials → Create credentials → API key.
4. `android/local.properties`:
   ```
   sdk.dir=C\:\\Android
   GCP_STT_API_KEY=AIza...
   ```
5. Rebuild + reinstall:
   ```powershell
   cd C:\Docs\Build\mananUtils\VoiceBridge\android
   .\gradlew assembleDebug
   adb install -r app\build\outputs\apk\debug\app-debug.apk
   ```

## 2. Chunk 1 acceptance test (README.md)

1. Record yourself speaking Gujarati, tap Stop.
2. Tap **Transcribe (Gujarati)** — button shows "Transcribing..." with a spinner.
3. Gujarati text appears in the editable transcript field.
4. Say nothing during recording instead → field shows `(No speech detected)`.

## 3. Inspect the wire call (optional)

The request is a plain REST POST — reproducible outside the app:

```powershell
# body.json: {"config":{"encoding":"LINEAR16","sampleRateHertz":16000,"languageCode":"gu-IN"},"audio":{"content":"<base64 pcm>"}}
curl -s -X POST "https://speech.googleapis.com/v1/speech:recognize?key=$env:GCP_KEY" `
  -H "Content-Type: application/json" -d '@body.json'
```

(Strip the first 44 bytes of `recording.wav` before base64-encoding — the app does this at
`SttService.kt:45`.)

## Notes

- Emulator + corporate TLS interception: a corp root CA may need to be installed in the AVD
  for real GCP calls to succeed (environment quirk; the error card will show the TLS failure
  otherwise).
- Free tier: 60 audio-minutes/month — ample for testing.
