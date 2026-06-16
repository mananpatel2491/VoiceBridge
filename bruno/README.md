# API Validation (bruno/)

This directory contains Bruno collections for continuous API validation and contract testing of the VoiceBridge pipeline endpoints.

## Rules
1. No backend API feature is complete until the Bruno pipeline is updated.
2. Maintain a visual HTML flow of tests (documented in this directory).
3. Voice pipeline endpoints (stream, transcribe, synthesize) must have latency assertions where applicable.

## Structure
- `collections/`: Bruno collection files organized by pipeline stage (stt/, tts/, pipeline/, health/).
- `docs/`: Visual flow documentation and test reports.

## Exception Protocol
If Bruno validation must be bypassed for a commit, the commit message MUST contain the exact string:
`I understand bruno validation is failing and I allow the exception to have the code committed to github repo`
