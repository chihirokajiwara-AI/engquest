# ENG Quest Dev Bootstrap — SETUP NEEDED

**Status**: Local repo initialized, 1 commit ready, remote push blocked.

## What Was Done Today (2026-05-26)

1. ✅ Repo initialized at `/root/engquest`
2. ✅ Flutter project scaffold + pubspec.yaml
3. ✅ Full MVP spec written (`docs/spec/mvp.md`) — 10 components, 4 spikes
4. ✅ Spike S01 complete: on-device Whisper feasibility research
   - **Decision**: `whisper_ggml_plus` v1.5.2 + `base.en` (142MB), hybrid architecture
   - See: `src/spikes/on-device-whisper/README.md`
5. ✅ Git commit: `5115847` on `main` branch

## Blocked: Remote Push

**Problem**: No GitHub PAT or SSH key in container. Cannot push to remote.

**What CEO must do**:
1. Create GitHub repo (e.g. `chihirokajiwara-AI/engquest`)
2. Add GitHub PAT to GCP Secret Manager as `aesthetic-ai-vertex/github-pat-engquest`
   OR push the existing SA key (`/root/.hermes/gdrive-automation-sa-key.json`) to container
3. Run: `git -C /root/engquest remote add origin https://github.com/chihirokajiwara-AI/engquest.git`
4. Run: `git -C /root/engquest push -u origin main`

## Next Development Steps

1. Spike S02: FSRS-4.5 Dart implementation feasibility
2. Delegate C01 to Claude Code: Implement `lib/core/fsrs/fsrs_algorithm.dart`
3. Delegate C02 to Claude Code: Build 300-word content DB (`lib/data/content/`)

## Container Notes

- This Docker container is ephemeral — repo at `/root/engquest` will be lost on restart
- Bootstrap script needed for persistence: clone from GitHub after container restart
- Python: `/usr/local/bin/python3` (3.11.15) + `requests` installed
- Git: 2.47.3
