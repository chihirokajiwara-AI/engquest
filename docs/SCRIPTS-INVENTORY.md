# Scripts Inventory — ENG Quest Flutter

_Last updated: 2026-06-02_

---

## scripts/

| Script | Purpose | Usage | Notes |
|--------|---------|-------|-------|
| `pre-push-quality-gate.sh` | Fail-safe local CI mirror: runs analyze + test + audio checks on the pushed commit range in an ephemeral worktree; blocks push on any failure | Invoked by `.git/hooks/pre-push` automatically | ARMED; Telegram alert on block; kill-switch: `ENGQUEST_SKIP_PREPUSH=1` |
| `build_audio_manifest.py` | Rebuilds `assets/content/audio_manifest.json` for all 300 A1 words; mirrors MP3s from `web/audio/` into `assets/audio/a1/` and `web/audio/a1/` | `python3 scripts/build_audio_manifest.py` | No TTS API calls — pure re-packaging; fixes missing `storagePath` that caused app startup crash |
| `generate_kokoro_audio.py` | Batch TTS via local Kokoro for all Eiken grades; outputs to `assets/audio/{grade}/` | `python3 scripts/generate_kokoro_audio.py [--grade eiken2] [--dry-run]` | ¥0 cost; preferred audio generation path; requires `~/.venvs/kokoro` + ffmpeg |
| `generate_gtts_audio.py` | Generates 300 A1 MP3s via Google Translate TTS (no API key); outputs flat `web/audio/` layout | `pip install gTTS && python3 scripts/generate_gtts_audio.py` | Fallback when Cloud TTS unavailable; idempotent (skips files >1KB); 3 retries/word |
| `generate_tts_audio.py` | Batch-generates MP3s via Google Cloud TTS API (Neural2-C); updates manifest `status: pending → ready` | `export GOOGLE_TTS_API_KEY=... && python3 scripts/generate_tts_audio.py` | Legacy; ~$0.0006/30 words; also uploads to Firebase Storage |
| `generate_category_images.py` | Generates per-category SVG illustrations (emoji + gradient) to `web/images/categories/` and `assets/images/categories/` | `python3 scripts/generate_category_images.py` | Idempotent; stdlib only; reads categories from `vocab_a1_300.json` |
| `merge_vocab.py` | Merges `new_words_batch*.json` into `assets/data/eiken2_vocab.json`, deduplicating by word and re-assigning sequential IDs | `python3 scripts/merge_vocab.py` | 32 batch files in `scripts/`; stdlib only |
| `verify_audio_assets.py` | CI: confirms manifest `status=ready` MP3s exist byte-identical in both `assets/audio/a1/` and `web/audio/a1/`; also checks flat `web/audio/` | `python3 scripts/verify_audio_assets.py` | Run by pre-push gate and CI; **PASSES** (T35 resolved 2026-06-11; 300/300 ready, a1 pair byte-identical, manifest-consistent — re-verified 2026-06-12) |
| `test_audio_manifest.py` | CI: validates `audio_manifest.json` schema matches Dart `AudioManifestEntry.fromJson` contract; checks all 300 MP3s exist and are non-zero | `python3 scripts/test_audio_manifest.py` | Run by pre-push gate and CI; **PASSES** (300/300, Dart-schema-valid — re-verified 2026-06-12) |
| `verify_web_demo_assets.py` | Validates standalone `web/index.html` has all 300 audio MP3s and category SVGs resolving without 404 | `python3 scripts/verify_web_demo_assets.py` | Not in CI; exit 0 = all contracts hold |
| `test_category_images.py` | Validates generated SVGs are well-formed, complete (one per category), wired in `web/index.html`, and precached in `web/sw.js` | `python3 scripts/test_category_images.py` | Not in CI |
| `test_word_audio.py` | Validates every A1 word has a real MP3 matching `playPronunciation()` naming, with valid MP3 headers | `python3 scripts/test_word_audio.py` | Not in CI |
| `audit_live.sh` | #49 slice-1: measures the live cold-boot payload over HTTP (size/latency) | `scripts/audit_live.sh [base_url]` | Loop-run real-browser audit; not in pre-push/CI (network) |
| `audit_live_render.sh` | #49 slice-2: renders the live app in headless Chrome + asserts the Flutter view painted (catches white-screen/blank/tofu) | `scripts/audit_live_render.sh [base_url]` | Loop-run; shoots at 1280×900. NOTE: `--window-size` does NOT propagate to Flutter web's logical viewport — use `audit_phone_*` for true phone-width checks |
| `audit_phone_render.mjs` | #49 slice-2b: **phone-accurate** render via Playwright device emulation (real viewport+DPR Flutter reads); asserts `scrollWidth==innerWidth` (no horizontal overflow) at 320/390/430 CSS px + captures screenshots | `node scripts/audit_phone_render.mjs <base> <preview> [outDir]` | Resolves Playwright from a sibling repo's `node_modules`; the only audit that reproduces true phone reflow / CJK clip |
| `audit_phone_all.sh` | #49: phone-layout **regression gate** — sweeps every key preview route through `audit_phone_render.mjs` and fails on any phone-width overflow; serves `build/web` itself if no base given | `scripts/audit_phone_all.sh [base_url] [route ...]` | Catches the "画面からズレている" class device-free at build time; loop/manual (browser deps — not in fast pre-push) |

## scripts/content-pipeline/

| Script | Purpose | Usage | Notes |
|--------|---------|-------|-------|
| `validate_vocab.py` | Validates vocab JSON files: required fields, no duplicate IDs/words, correct `fsrsState`, `distractors` count == 3, `totalWords` accuracy | `python3 scripts/content-pipeline/validate_vocab.py assets/data/eiken5_vocab.json` | Accepts file or directory; use before committing new content |
| `cross_grade_check.py` | Detects duplicate word IDs and English words across all grade files in `assets/data/` | `python3 scripts/content-pipeline/cross_grade_check.py` | Complement to `validate_vocab.py`'s within-file checks |
| `check_coverage.py` | Reports word count per grade vs. target totals (e.g., Eiken 5: 600, Pre-1: 3,000) | `python3 scripts/content-pipeline/check_coverage.py` | Reads all `assets/data/*.json` automatically |
| `generate_audio.sh` | Shell wrapper: generates TTS MP3s via Google Cloud TTS API for a vocab JSON file; maps CEFR level to output dir | `./scripts/content-pipeline/generate_audio.sh assets/data/eiken5_vocab.json` | Requires `GOOGLE_CLOUD_API_KEY` and `jq`; idempotent; ~5 req/sec rate limit |

## deploy/

| Script | Purpose | Usage | Notes |
|--------|---------|-------|-------|
| `install_nginx.sh` | Idempotent nginx installer for Hetzner VPS: persistent web root at `/var/www/engquest`, gzip/cache headers, SPA fallback, systemd watchdog timer | `sudo bash deploy/install_nginx.sh` | Run as root on VPS; replaces throwaway `python -m http.server` |
| `recover_live_demo.sh` | One-liner post-reboot recovery: clones repo to `/opt/engquest-src` (never `/tmp`), seeds web root, runs `install_nginx.sh`, installs cron backstop | `curl -fsSL .../recover_live_demo.sh \| sudo bash` | Resilient against `/tmp` wipe on reboot; never leaves site blank |
| `engquest-watchdog.sh` | Self-healing watchdog: re-syncs web root if missing, (re)starts nginx, health-checks `:8080` and `:80` | Run by systemd `engquest-watchdog.timer` every 2 min | Deployed to VPS by `install_nginx.sh`; exit 1 if still unhealthy after repair |
| `test_nginx_config.py` | Static verification of nginx config + install script: 37 checks (ports, gzip, cache, SPA, watchdog, reboot resilience) without live VPS | `python3 deploy/test_nginx_config.py` | Also runs `bash -n` syntax check on install script |
| `test_recover_live_demo.py` | Verifies `recover_live_demo.sh` uses persistent path, has fallback chain, is idempotent, ends with health check | `python3 deploy/test_recover_live_demo.py` | Exit 0 = all checks pass |
| `com.aesthetic.engquest-dev.plist` | macOS launchd plist: runs `scripts/engquest-dev.sh` every 2 hours on Mac Mini | `launchctl load deploy/com.aesthetic.engquest-dev.plist` | Local dev automation only; not deployed to VPS |

## .git/hooks/

| Hook | Notes |
|------|-------|
| `pre-push` | Active quality gate — invokes `scripts/pre-push-quality-gate.sh` on every push. Blocks if analyze/test/audio checks fail. Remove file to disarm, or set `ENGQUEST_SKIP_PREPUSH=1` to bypass with alert. |
