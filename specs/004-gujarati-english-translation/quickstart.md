# Quickstart: Gujarati→English Translation (Chunk 2)

## 0. No credential (error-path demo, what CI does)

Install a build with blank `GCP_STT_API_KEY`, launch, and type any text into the
"Gujarati transcript" field — `Translate (English)` enables. Tap it: an error card explains
the key is missing and that the same key covers Cloud Translation. No crash. Automated:

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge
powershell -File android\scripts\smoke-test.ps1 -Build   # step 9 = translate flow
```

## 1. Enable the API (no new key needed)

On the SAME GCP project as Chunk 1: APIs & Services → Library → enable
**Cloud Translation API**. Keep the existing `GCP_STT_API_KEY` in
`android/local.properties`. Rebuild + reinstall:

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge\android
.\gradlew assembleDebug
adb install -r app\build\outputs\apk\debug\app-debug.apk
```

## 2. Chunk 2 acceptance test (README.md)

1. Complete the Chunk 1 flow so Gujarati text sits in the transcript field — or skip
   recording entirely and type/paste Gujarati text directly.
2. Tap **Translate (English)** — spinner shows "Translating...".
3. The English translation appears in the "Translation (English)" card below.
4. Edit the transcript — the translation card disappears immediately (staleness guard).
5. Negative path: if Cloud Translation API is not enabled on the project, the error card
   shows the GCP message (`Translation API error 403: ...`).

## 3. Reproduce the wire call (optional)

```powershell
curl -s -X POST "https://translation.googleapis.com/language/translate/v2?key=$env:GCP_KEY" `
  -H "Content-Type: application/json; charset=utf-8" `
  -d '{"q":"કેમ છો","source":"gu","target":"en","format":"text"}'
# → {"data":{"translations":[{"translatedText":"How are you"}]}}
```

## Notes

- Free tier: 500K characters/month.
- Emulator behind corporate TLS interception needs the corp root CA in the AVD for live
  calls (same caveat as Chunk 1).
