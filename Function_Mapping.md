# Full-Stack Function Mapping: VoiceBridge

This document maps client/frontend components to their respective backend pipeline endpoints. Maintain this file to ensure architectural traceability across the voice pipeline.

| Client / Component | Action | Backend Endpoint / Pipeline Stage | Documentation/Contract |
| :--- | :--- | :--- | :--- |
| *VoiceClient (WebSocket)* | *Stream audio frames* | *POST /api/v1/pipeline/stream (STT → LLM → TTS)* | *bruno/collections/pipeline/stream.bru* |
| *VoiceClient (REST)* | *Single-shot transcribe* | *POST /api/v1/stt/transcribe* | *bruno/collections/stt/transcribe.bru* |
| *VoiceClient (REST)* | *Single-shot synthesize* | *POST /api/v1/tts/synthesize* | *bruno/collections/tts/synthesize.bru* |
| *AdminUI* | *Health check* | *GET /api/v1/health* | *bruno/collections/health/health_check.bru* |

## Maintenance Rules
1. **Add**: When creating a new endpoint, pipeline stage, or client connection.
2. **Update**: When an endpoint signature, audio format contract, or data structure changes.
3. **Delete**: When a feature is decommissioned.
4. **Audit**: Run regular cross-checks to ensure no "Ghost Endpoints" exist.
