# Project Structure: VoiceBridge

This document provides a functional map of the codebase, enabling the Lead Agent (Gemini) to navigate and implement features with full architectural context.

## Core Framework (The 'Director' Layer)

| Path | Purpose |
| :--- | :--- |
| `GEMINI.md` | **Constitution**: The central nervous system and non-negotiable operating procedures. |
| `Project_Structure.md` | **Architecture Map**: This document. Functional mapping of the codebase. |
| `requirements.txt` | **Dependencies**: Python package requirements for the project. |
| `GEMINI_Getting_Started.md` | **Onboarding**: Auto-updated guide on using Gemini Code Assist features. |
| `PATTERNS.md` | **Pattern Registry**: Living document for established engineering patterns and design decisions. |
| `scripts/` | **Agentic Skills**: Maintenance and hygiene scripts accessible to agents. |
| `bruno/` | **API Validation**: Bruno collections and documentation for contract testing. |
| `bootstrap_prompts/` | **Plan Archive**: Systematic prompts generated from user intent to start new sessions. |
| `terraform/` | **Infrastructure-as-Code**: GCP/Terraform configuration for cost-gated deployments. |

## Application Layer (TBD)

| Path | Purpose |
| :--- | :--- |
| `src/` | Application source code (voice pipeline, provider implementations, server). |
| `docs/architecture_overview.html` | **Visual Guide**: A 1-page HTML overview of the VoiceBridge framework. (Excluded from `verify_structure.py` checks) |
| `Function_Mapping.md` | **Traceability Map**: Correlates frontend/client components with backend pipeline endpoints. |

## Pipeline Stage Registry

| Stage | Role | Provider Interface | Current Implementation |
| :--- | :--- | :--- | :--- |
| Audio Capture | Microphone input / audio stream ingestion | `AudioCapture` | TBD |
| STT | Speech-to-Text transcription | `STTProvider` | TBD |
| LLM | Language model reasoning & response generation | `LLMProvider` | TBD |
| TTS | Text-to-Speech synthesis | `TTSProvider` | TBD |
| Audio Output | Speaker output / audio stream egress | `AudioOutput` | TBD |

## Changelog

| Date | Action | Files Affected | Summary |
| :--- | :--- | :--- | :--- |
| 2026-06-15 | INITIALIZE | `Project_Structure.md`, `GEMINI.md`, `README.md`, `.gitignore`, `LICENSE`, `PATTERNS.md`, `Function_Mapping.md`, `requirements.txt`, `scripts/README.md`, `scripts/generate_bootstrap_prompt.py`, `scripts/optimize_changelog.py`, `scripts/update_getting_started.py`, `scripts/verify_structure.py`, `bruno/README.md`, `terraform/README.md` | **V0.0.1 Baseline**: Director Layer operational. Voice pipeline constitution, pattern registry, and agentic skills scaffolded. Ready for autonomous vibe coding. |
