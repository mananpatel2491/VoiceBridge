# Pattern Registry: VoiceBridge

This document records established engineering patterns and design decisions to ensure consistency and avoid "GIST debt".

## 1. Architectural Patterns

*   **Cross-Platform Automation**: All project maintenance and hygiene scripts must be written in Python to ensure compatibility across Windows, macOS, and Linux. Shell-specific scripts (Bash/PowerShell) are permitted only in specialized, hardened environments where a Python runtime is strictly prohibited.
*   **Non-Hardcoded LLM Selection**: Scripts interacting with LLMs must dynamically query available models rather than using hardcoded strings. This prevents breaking changes when models are deprecated or updated.
*   **Automation-First CLI**: All interactive scripts must support CLI arguments to bypass user input (e.g., `--model`) and allow for safe previewing of actions (e.g., `--dry-run`). This ensures scripts are compatible with CRON jobs and CI/CD pipelines.
*   **Contract-First Validation (Bruno)**: Every new API-exposed backend function requires a corresponding Bruno script. Commits are blocked unless Bruno validation passes. Exceptions require an explicit owner acknowledgment in the commit message: `"I understand bruno validation is failing and I allow the exception to have the code committed to github repo"`.
*   **Full-Stack Traceability Mapping**: Maintain a functional mapping between frontend components and backend endpoints in `Function_Mapping.md`. This map must be updated whenever functions are added, updated, or deleted to ensure cross-layer integrity.
*   **Proactive Hardening**: When updating an existing file, the agent must audit the logic for security risks (e.g., injection, leaked secrets, audio data leakage) and resource/memory leaks. If found, these must be patched immediately and logic added to prevent reintroduction.
*   **Production Readiness Gating**: Code containing comments indicating temporary setups, mocks, or non-production quality (e.g., `// TODO: temp`, `// fix later`) must be flagged. The agent must explicitly ask the Director if these should be addressed before proceeding.
*   **Infrastructure Migration Advisory**: When transitioning from local/mock implementations to production-ready infrastructure, the agent must present a comparative selection of technology options and seek the Director's arbitration before implementation.

## 2. Voice Pipeline Patterns

*   **Provider Interface Pattern**: Each pipeline stage (STT, LLM, TTS) must be implemented behind an abstract provider interface. Concrete implementations (e.g., `WhisperSTT`, `GeminiLLM`, `ElevenLabsTTS`) are injected at runtime. Never call a vendor SDK directly from business logic.
*   **Streaming-First Design**: All pipeline stages must expose a streaming API. Buffered (non-streaming) calls are acceptable only for batch processing use cases explicitly marked as such in the changelog.
*   **VAD Gating**: Voice Activity Detection must gate STT calls to prevent sending silence to paid APIs. The VAD threshold, frame size, and silence timeout must be documented in this file when set.
*   **Audio Format Contract**: All audio exchanged between pipeline stages must be PCM 16-bit, 16 kHz, mono, unless an exception is documented below with rationale.
*   **Latency Budget Tracking**: Each pipeline hop has a latency budget. When a new stage is added, its expected P50/P95 latency must be noted in `Project_Structure.md`.

## 3. Coding Standards

*   **CLI Argument Parsing**: Use the standard `argparse` library for all scripts to provide a consistent interface for flags and help menus.
*   **Async-First**: Voice pipeline components that perform I/O (network, audio device) must use `asyncio`. Synchronous calls in an async context require explicit justification in the code.

## 4. Tooling Conventions

*   **Dry-Run Safety**: Destructive or file-writing operations should be gated behind a check for a `dry_run` flag, printing the intended action to `stdout` instead of executing it.
