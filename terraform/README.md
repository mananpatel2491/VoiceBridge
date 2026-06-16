# Infrastructure-as-Code (terraform/)

This directory contains Terraform configurations for managing GCP infrastructure for VoiceBridge.

## Gated Deployment Process
1. Update Terraform configs for any infra-dependent feature.
2. Run `terraform plan` and calculate projected costs (pay special attention to real-time audio API costs — STT/TTS per-second billing).
3. Cost and infra reviews must be finalized before GitHub tagging.
4. Deployment triggers automatically upon tagging.

## Cost Awareness
Voice pipeline services (STT, TTS, LLM) are typically billed per-second or per-character. Every infra change must include a projected monthly cost estimate at the expected call volume.

## Structure
- `environments/`: Environment-specific configurations (dev, prod).
- `modules/`: Reusable infrastructure modules (Cloud Run, Firestore, etc.).
