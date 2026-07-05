# Full-Stack Function Mapping: VoiceBridge

This document maps client/frontend components to their respective backend pipeline endpoints. Maintain this file to ensure architectural traceability across the voice pipeline.

> **Status (v0.0.7): reserved for future backend.** No backend/API exists yet — the app
> currently calls GCP STT/Translation REST APIs directly from the device. The rows below
> are illustrative placeholders (italicized) reserved for the future backend; none of the
> endpoints or `.bru` contracts exist today. Replace with real rows when the first
> backend/API ships, per the maintenance rules.

| Client / Component | Action | Backend Endpoint / Pipeline Stage | Documentation/Contract |
| :--- | :--- | :--- | :--- |
| *VoiceClient (WebSocket)* | *Stream audio frames* | *POST /api/v1/pipeline/stream (STT → LLM → TTS)* — *reserved (N/A today)* | *bruno/collections/pipeline/stream.bru (reserved)* |
| *VoiceClient (REST)* | *Single-shot transcribe* | *POST /api/v1/stt/transcribe* — *reserved (N/A today)* | *bruno/collections/stt/transcribe.bru (reserved)* |
| *VoiceClient (REST)* | *Single-shot synthesize* | *POST /api/v1/tts/synthesize* — *reserved (N/A today)* | *bruno/collections/tts/synthesize.bru (reserved)* |
| *AdminUI* | *Health check* | *GET /api/v1/health* — *reserved (N/A today)* | *bruno/collections/health/health_check.bru (reserved)* |

## Maintenance Rules
1. **Add**: When creating a new endpoint, pipeline stage, or client connection.
2. **Update**: When an endpoint signature, audio format contract, or data structure changes.
3. **Delete**: When a feature is decommissioned.
4. **Audit**: Run regular cross-checks to ensure no "Ghost Endpoints" exist.
