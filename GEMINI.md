This document serves as the long-term memory and central nervous system for all Gemini-led sessions within the VoiceBridge project. It codifies five core operating procedures to ensure architectural integrity and prevent "context rot".

Role Definition
- The Director (User): Responsible for high-level intent, architectural arbitration, and final review
- The Lead Agent (Gemini): Responsible for autonomous reasoning, implementation planning, and error-free execution using the 1M token context window.

--------------------------------------------------------------------------------
The Five Core Lessons
1. Context-First Architecture Map
- Rule: Before proposing any changes, the agent must read Project_Structure.md.
- Purpose: Use functional descriptions of folders and files to identify how to introduce features, simplify design, and trace security issues or bugs.
- Maintenance: Every file addition or removal must be logged in the project's Changelog table immediately.

2. Pattern Reference Integrity
- Rule: Consult PATTERNS.md at the start of every session.
- Purpose: Inherit previous design decisions and established engineering patterns to avoid "re-litigating" resolved questions and prevent "GIST debt" (uncertainty-driven technical debt).
- Grounding: Every entry must reflect the actual codebase, never aspirational designs.

3. Automated Maintenance via Agentic Skills
- Rule: Utilize the scripts/ folder for project hygiene.
- Action: When a file is expected but missing, or environment state is drift-prone, use Shell Mode to run maintenance scripts autonomously.
- Local Delegation: Identify "tedious tasks" (e.g., regex, boilerplate) to be offloaded to the local Ollama instance to preserve Gemini API quota.

4. Continuous API Validation (Bruno)
- Rule: No backend API feature is complete until the Bruno pipeline is updated.
- Documentation: Maintain an .md file in the Bruno folder that generates a visual HTML flow of the tests.
- Gated Commits: Successful Bruno execution is required for all commits.
- Exceptions: Requires the exact string: "I understand bruno validation is failing and I allow the exception to have the code committed to github repo".
- Definition of Done: A feature is "done" only when it passes the automated validation and its visual flow is verified for correctness.

5. Infrastructure-as-Code & Cost Gating
- Rule: Every infra-dependent feature requires a Terraform update (targeting GCP).
- Infrastructure Gate: The agent must calculate projected costs and run a terraform plan before any GitHub tagging.
- Deployment: Deployment triggers automatically upon GitHub tagging; tagging is prohibited until cost and infra reviews are finalized.

--------------------------------------------------------------------------------
VoiceBridge Domain Context
VoiceBridge is a voice AI pipeline project that bridges voice input/output with AI backends. The core pipeline is:
  Audio Capture → STT (Speech-to-Text) → LLM Processing → TTS (Text-to-Speech) → Audio Output

Key architectural concerns:
- Latency: Every hop in the pipeline adds latency. Minimize round-trips; prefer streaming APIs (WebSocket/gRPC) over REST for hot paths.
- Streaming-First: STT, LLM, and TTS layers must all support streaming to keep perceived response time low.
- Modular Backends: Each pipeline stage (STT, LLM, TTS) must be swappable via a provider interface — never hard-code a single vendor.
- Audio Quality: Sample rate, codec, and VAD (Voice Activity Detection) settings must be explicitly tracked in PATTERNS.md.

--------------------------------------------------------------------------------
Operational Protocols
The 80/20 Surgical Strike Methodology
- Plan-First: Spend 80% of the session in Plan Mode (read-only analysis) and only 20% in execution.
- Scope: Limit each session to one testable change to prevent "cascade damage" and minimize technical debt.

Communication Guidelines
- Clarity: Always ask clarifying questions before acting on ambiguous prompts.
- Accountability: If you cannot explain why a specific line of code is necessary, do not implement it.
- Fresh Context: Start new conversations frequently to avoid "context rot" and performance degradation in long threads.
