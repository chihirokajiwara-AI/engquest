# refactor-instructions.md — A-KEN Quest / コトバ探偵 (Flutter 英検 RPG)

> Hand-off brief for an implementation model (e.g. `/goal`). **You are a careful
> refactorer, not a rewriter.** Reduce real, evidenced debt without changing
> existing behavior. Do **not** chase prettiness, do **not** assume old code is
> bad, do **not** make large deletions or rewrites without evidence and approval.
> When the correct behavior is not determinable from code, **stop and ask** — see
> §Stop-And-Ask and the "実装前に確認すべき質問" list at the end.
>
> Authored 2026-06-11 from an evidence-based read of the repo at commit `bcc3eb9`.
> Every claim below was grounded in a real file; spot-verified line counts and
> key files before writing. Re-verify against the live tree before acting — the
> tree moves.

---

## Objective

Make the codebase **easier to change safely** by paying down *evidenced* technical
debt — duplication, missing safety nets on critical paths, a few dependency-direction
smells, and small lifecycle/concurrency hazards — **without altering any
learner-visible behavior, 英検 content, scoring, billing, or consent semantics.**

Success = (1) every change is small and reversible; (2) all existing verification
gates stay green; (3) the protected behaviors in §Behaviors-To-Preserve are
provably unchanged (ideally now covered by a new test); (4) risky/structural
changes are written up as proposals, not implemented unilaterally.

This is **not** a "rewrite the architecture" task. Most items here are PROPOSE-ONLY.

---

## Project Understanding

**What it is.** A Flutter Web+Mobile English-learning RPG for Japanese children,
targeting 英検 (Eiken) grades 5級→準1級. Single codebase, two flavors:
`edilab` (free, all grades) and `aken` (commercial, ¥999/mo, only 5級 free).
Learning modes: **battle** (FSRS flashcards), **quest/explore** (narrative
Layton-style scenes with grammar/phonics ナゾ), **exam_practice** (full 英検
section simulation + CSE 合格率 meter), **speaking/voice** (pronunciation).

**Entry points.** `lib/main.dart` (generic, edilab default), `lib/main_edilab.dart`,
`lib/main_aken.dart` — each sets the flavor then runs `EngQuestApp` (`lib/app.dart`).
`app.dart` holds routing, the dark-RPG theme, the responsive portrait frame, the
boot state machine (loading → title → onboarding → prologue → **KotobaHomeScreen**,
the live home), and `?preview=<name>` offline design-audit routes.

**Major modules.** `lib/core/*` = cross-cutting services: `fsrs/` (FSRS-4.5 algo +
card repos: in-memory for tests, Firestore for prod), `audio/` (TtsService,
WordAudioPlayerService, SoundService), `dialog/` (ClaudeClient → backend proxy),
`firebase/` (anonymous auth, parent auth), `gamification/` (XP, achievements,
hint coins + anti-leak rail), `storage/` (PreferencesService), `config/`
(FlavorConfig, app_config), `analytics/`, `notifications/`, `billing/`.
`lib/features/*` = screens: `battle/`, `exam_practice/` (+ `pass/` CSE model),
`quest/` (+ `quest_data.dart` content, `ui/dq_ui.dart` shared framework),
`explore/` (scene_view, nazo_screen, hotspot), `onboarding/`, `home/`,
`parent_dashboard/`, `speaking/`, `settings/`, `legal/`, `character/`,
`world_map/`. `crafting/` and `guild/` are empty `.gitkeep` stubs (v2).

**Data flow (learning interaction).** Question/content source (vocab JSON via
VocabRepository, `quest_data.dart`, exam item pools) → scoring (FSRS card repo for
battle; first-try-correct → SkillAccuracy → `cse_model.dart` for 合格率; MockExamScorer)
→ persistence (SharedPreferences via PreferencesService; Firestore for FSRS cards &
parent data) → AnalyticsService events (consent-gated). Writing answers go to Claude
via the backend proxy (`api.akenquest.jp`).

**External deps (pubspec).** firebase_core/auth/firestore/analytics/messaging,
purchases_flutter (RevenueCat), audioplayers, speech_to_text, http (backend proxy),
shared_preferences, url_launcher, crypto, timezone, equatable. JP font is bundled
locally (`assets/fonts/NotoSerifJP.ttf` via `pubspec` fonts + `app_fonts.dart`);
google_fonts' runtime CDN fetch is deliberately avoided (it left tofu on the demo).

---

## Behaviors To Preserve

Each is an invariant with code/test evidence. A refactor must keep these provably
true. Where a test exists, keep it green; where one is missing, **add it first**
(see Phase 2) before touching nearby code.

1. **英検 question integrity.** Question text, `choices`, and `correctIndex` are
   authoritative and untouched at runtime (`quest_data.dart`,
   `exam_practice/eiken_exam_config.dart`). The ONLY runtime generation is 大問1
   cloze distractors (next item). Never shuffle/mutate correct indices of authored
   questions.
2. **Runtime anti-leak distractors.** `distractor_generator.dart`
   `buildAntiLeakDistractors` regenerates 3 distractors per cloze (same first letter,
   same POS, single token, no synonym/sentence overlap, generic-word blocklist;
   returns `null` → item skipped when <3 clean candidates). The JSON `distractors`
   field is **intentionally discarded** — do not "restore" it, do not suppress the
   `null` path.
3. **Honest 合格率 / CSE.** First-try correctness (not retries) feeds accuracy
   (`nazo_screen.dart` `firstTryCorrect`, never overwritten on retry). `cse_model.dart`
   banks `min(rawAccuracy, passTargetRaw)` per skill; readiness can reach 100 only
   when all skills are measured and at target (targets: 0.60 for 5級–2級, 0.70 for
   準1級). Never revert to `totalCSE / passingCSE`.
4. **FSRS scheduling.** New + Good → Review with interval ≥ 1 day, by design
   (`fsrs_algorithm.dart`; `test/core/fsrs/fsrs_card_repository_test.dart`). Do not
   "fix" New+Good into a Learning step.
5. **Anti-leak hint rail.** Every authored hint passes
   `hintViolatesAnswerRail(textJa, answer, distractors) == false`
   (`hint_coin_service.dart`; coverage test
   `test/features/explore/nazo_hint_rail_test.dart` iterates all scene hotspots).
   The conservative substring match is **intentional** — do not relax to word-boundary.
6. **Web compatibility.** No `dart:io` anywhere in `lib/`. Every `Image.asset` has an
   `errorBuilder` fallback. Use `http`/`kIsWeb`. (`scene_view.dart`, `dq_ui.dart`.)
7. **Bundled font coverage.** All displayed JP glyphs must be covered by the single
   bundled subset (`assets/fonts/NotoSerifJP.ttf`, regenerated by
   `scripts/subset_jp_font.py` from source). Adding new JP text requires regenerating
   the subset or it renders as tofu (□) — a real past incident (e.g. 囚).
8. **Audio asset contract.** `scripts/verify_audio_assets.py` + `test_audio_manifest.py`
   are hard CI gates (byte-identical MP3 pairs vs `audio_manifest.json`). See
   Stop-And-Ask Q-A about the T35 unresolved state.
9. **Consent/COPPA persistence.** Voice + parental consent stored as
   (ISO-8601 UTC timestamp + policy-version) in PreferencesService; re-prompt when
   version constant changes; null = never granted. Do not simplify to a bare bool
   without confirming (Stop-And-Ask Q-E).
10. **Paywall/flavor gating.** `FlavorConfig.isGradeFree(grade)` (edilab: all free;
    aken: only 5級). Flavor set once at startup. Do not hardcode unlocks or merge flavors.
11. **Child-safety copy.** No scolding; wrong answers in teach/blend/word/phrase steps
    replay audio (`penalizeWrong == false`), only the grammar Quiz flashes red. No
    dead-end/failure screens. (`quest_data.dart`.)

---

## Non-Negotiables

Hard rules; any violation is a stop-the-line failure.

- **NEVER** `import 'dart:io'` in `lib/` (web compat; CLAUDE.md §Critical Constraints).
- **NEVER** modify `lib/core/config/app_config.dart` API keys or commit any secret/.env.
- **NEVER** `git push --force`. Never rewrite published history.
- **CI gates must stay green**: `flutter analyze --fatal-infos --fatal-warnings`,
  `dart format --output=none --set-exit-if-changed .`, `flutter test`,
  `python3 scripts/verify_audio_assets.py`, `python3 scripts/test_audio_manifest.py`,
  Android+iOS build checks (`.github/workflows/ci.yml`). A pre-push hook mirrors these.
- **AI-generated learning content** (vocab distractors, example sentences, phonics
  steps, 英検 problems, hint/narrative text) must pass the **content-qa** subagent
  before commit (`.claude/agents/content-qa.md`). This gate exists because 7,923
  distractors were once silently corrupted.
- **Heavy jobs** (image/audio gen, model work, long builds) ONLY via
  `scripts/safe-job.sh <name> <timeout> <cmd>` (detached + hard timeout); a
  PreToolUse hook blocks otherwise.
- **Spec-freeze**: do not re-design a CEO-approved spec on your own; escalate first.
- Firestore rules (`firestore.rules`, 172 lines) isolate per-user data — don't widen.

---

## Stop-And-Ask Conditions

Stop and ask (do **not** guess) if a change would:
- alter any item in §Behaviors-To-Preserve, or any `choices`/`correctIndex`/question text;
- touch billing, RevenueCat keys, IAP validation, or paywall logic;
- touch auth, consent persistence, Firestore schema, or saved SharedPreferences keys;
- delete code whose necessity you cannot prove from references;
- change a public/serialized contract (JSON shapes, model `fromJson`, analytics event
  names/params);
- require choosing between multiple designs with a product trade-off.

The concrete open questions surfaced by analysis are listed at the very end
("実装前に確認すべき質問") — those must be answered by the CEO before the
PROPOSE-ONLY items that depend on them are implemented.

---

## Baseline Commands

Record results BEFORE any edit; re-run after each phase.

```bash
git status                      # must be clean of unrelated changes; do not mix in
git rev-parse --short HEAD      # record the baseline sha
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
dart format --output=none --set-exit-if-changed .
flutter test                                   # full suite (currently ~1150 pass, 2 skip)
python3 scripts/verify_audio_assets.py
python3 scripts/test_audio_manifest.py
python3 scripts/subset_jp_font.py              # regen font subset if JP text changed
```

> Note at authoring time the working tree had ONE unrelated uncommitted file
> (`scripts/generate_scene_art.py`, an art-pipeline change in progress). Do **not**
> fold it into refactor commits. Confirm `git status` before starting.

---

## Debt Map

Severity × scope. **PROPOSE-ONLY** = write a design note + get approval, do not
implement now. **SAFE-NOW** = small, reversible, behavior-preserving; implement
behind the Phase order, each with its own commit + verification. All file:line refs
were grounded in the tree; re-confirm before editing.

### A. Safety-net gaps (add tests first — highest leverage, behavior-preserving)
- **A1 — `buildAntiLeakDistractors` unit coverage.** ✅ ALREADY DONE — a thorough
  test exists (`test/features/exam_practice/distractor_generator_test.dart`, 176 lines)
  covering first-letter, synonym, phrase, POS, underscore, generic-confusable,
  generic-as-answer, sentence-echo, and null-when-<3. No action. (An initial analysis
  pass wrongly flagged this as missing; re-verification against the tree corrected it
  — a reminder to always confirm "no test exists" claims before acting.)
- **A2 — Automated font-coverage CI gate.** ✅ DONE (commit on the same branch).
  `test/qa/vocab_gloss_charset_test.dart` (#97) is only a foreign-script tripwire and
  explicitly deferred true subset coverage to CI follow-up. Added
  `scripts/verify_font_coverage.py` (asserts the committed subset's cmap covers every
  in-scope JP source char; gracefully skips if fontTools absent), wired into `ci.yml`
  (with `pip install fonttools`) and the pre-push gate. Currently green (1997/1997).
- **A3 — 2 skipped tests** in `reading_pool_integrity_test.dart` (pre2plus/pre1
  listening pools = 0 items). These intentionally surface a CONTENT gap, not a code
  bug — see Stop-And-Ask Q-D before "fixing". Do not delete the skips; do not author
  content here (out of scope).

### B. Lifecycle / concurrency hazards (small, but verify the race first)
- **B1 — Async `setState` guards.** SAFE-NOW *after confirming the race*.
  `battle_screen.dart` (~line 282–325) awaits multiple repo calls; confirm every
  `setState`/state-mutation after an `await` is `mounted`-guarded. `mock_exam_screen.dart`
  timer (~line 86–100): confirm the periodic callback can't call `_submit()` after
  `_leaving`/dispose. Fix = add the missing guard only. Verify: existing smoke tests +
  manual rapid-back navigation. Keep each fix a 1–3 line commit.
- **B2 — Uncancelled timers pattern.** PROPOSE-ONLY. Many screens hand-cancel timers
  in `dispose` (`prologue_screen`, `quest_screen`, `scene_view`). A `DisposableTimerMixin`
  would reduce footguns but touches many files — propose, don't sweep.

### C. Duplication / structure (mostly PROPOSE-ONLY — large surface)
- **C1 — 7 exam-practice screens (~7.5 kLoC) repeat the answer/explanation/streak
  state machine.** PROPOSE-ONLY. `reading_practice_screen.dart` (1830),
  `writing_practice_screen.dart` (1481), `conversation_practice_screen.dart` (962),
  `vocab_grammar_practice_screen.dart` (911), `word_ordering`, `listening`. A
  `PracticeScreenBase`/mixin for shuffle+explanation-panel+streak could help, but
  this is a big structural change → design note + approval; do incrementally
  (extract ONE shared piece, e.g. the explanation panel, behind tests) only if approved.
- **C2 — `main.dart`/`main_edilab.dart`/`main_aken.dart` repeat ~30 lines of init.**
  SAFE-NOW (low risk) — extract `lib/core/main_bootstrap.dart` `initializeApp(Flavor)`;
  the three entry points call it. Verify: run both flavors compile/boot
  (`flutter run -t lib/main_edilab.dart`, `…main_aken.dart`) + full test.

### D. Dependency direction
- **D1 — CSE model lives under a feature but is cross-cutting.** PROPOSE-ONLY.
  `features/exam_practice/pass/cse_model.dart` + `skill_accuracy_store.dart` are
  imported by `battle`, `home`, `parent_dashboard`, `world_map`. Moving them to
  `lib/core/models/` clarifies ownership but touches many imports and a saved-data
  surface (skill accuracy) → propose; verify no behavior change to 合格率.

### E. Contracts / types
- **E1 — `VocabItem.fromJson` casts hard (`as String`, `as List`).** PROPOSE-ONLY.
  A malformed/renamed field crashes at load. Consider defensive parse + clear error.
  Risk: touches a serialized contract consumed from bundled JSON and possibly
  Firestore → confirm data source stability first (Stop-And-Ask Q-F) before changing.
- **E2 — JSON `distractors` field unused.** PROPOSE-ONLY / Stop-And-Ask Q-G. Removing
  it simplifies the model but it's a stored schema field — confirm no other consumer
  before any deletion.

### F. Logging
- **F1 — ~42 ungated `debugPrint` sites, no levels.** PROPOSE-ONLY. A thin
  `core/logging` wrapper would centralize observability, but it's a wide mechanical
  sweep with low urgency — propose; do not mass-edit during this pass.

### Explicitly NOT refactor debt (separate initiatives — see Out-of-scope)
- Billing placeholder keys (`billing_config.dart`: `rc_placeholder_*`) — secret/release work.
- Stubbed pronunciation scorer (`pronunciation_scorer.dart`) — backend feature, gated.
- Missing pre2plus/pre1 listening content — content authoring, gated by content-qa.

---

## Implementation Phases

Strictly in order; each phase is its own set of small commits; verify after each.

1. **Confirm state & baseline.** Run all §Baseline Commands; record sha + results.
   Confirm `git status` has no unrelated changes mixed in.
2. **Add safety nets first.** A1 (distractor unit test), A2 (font-coverage test).
   These are additive and lock §Behaviors before any structural touch. Commit each
   separately; full suite green.
3. **Obviously-safe cleanups.** C2 (extract `main_bootstrap`). Tiny, reversible.
   Verify both flavors boot.
4. **Small, verified lifecycle fixes.** B1 — ONLY after reproducing/confirming each
   race; one guard per commit; do not refactor surrounding code.
5. **Clarify boundaries (PROPOSE-ONLY this pass).** Write design notes for D1 (CSE→core),
   C1 (practice-screen base), E1/E2 (contract hardening / field removal), B2, F1. Do
   **not** implement without CEO approval — these touch broad surfaces or saved data.
6. **Make-testable improvements.** Only those that are additive and approved.
7. **Large design changes.** None implemented without explicit approval.

Stop and ask whenever an open question (below) blocks a step.

---

## Verification Requirements

- After EVERY commit: `flutter analyze --fatal-infos --fatal-warnings` = 0,
  `dart format --set-exit-if-changed .` clean, `flutter test` green (no NEW skips),
  audio scripts pass. Regenerate the font subset if any JP source text changed and
  confirm the cmap covers it.
- New tests must actually exercise real data (assert a non-zero count, like the hint
  rail coverage test does) — no vacuous green.
- For any content touch: run the **content-qa** subagent BEFORE commit.
- For any heavy job: `scripts/safe-job.sh` only.
- Behavior parity: for each §Behaviors item near your change, point to the test that
  proves it still holds (add one if absent).

---

## Reporting Format

At the end, report:
1. The baseline sha and the exact commands run + results (before/after).
2. Per change: the commit sha, files touched, which debt item, the verification output.
3. Which PROPOSE-ONLY items have design notes awaiting approval (with the open question
   they depend on).
4. Anything you stopped on and why.
Keep it factual; if a gate failed, show the output — never claim green without proof.

---

## Out-of-scope Items

Do not do these under "refactoring":
- Billing key configuration / RevenueCat sandbox wiring (secret + release work).
- Backend/AI features: pronunciation scoring (Azure/Claude), dynamic content gen.
- Authoring new 英検 content (listening pools, vocab) — content + content-qa initiative.
- Art/asset generation.
- The empty `crafting/`/`guild/` v2 stubs (leave as-is).
- Any visual redesign or palette change (the dark-RPG look is intentional/approved).
- Resolving T35 (audio asset contract decision) — needs a CEO product decision (Q-A).

---

## 決定事項 — autonomously resolved (agent-researched + code-verified, 2026-06-11)

These were the open questions; per CEO directive they were **decided** via a
principal-engineer agent (latest-2026 research + code evidence), not escalated.
Each was re-verified against the live tree. **No item required CEO sign-off** (no
secret / billing key / legal sign-off / prod-data migration). Findings:

- **Q-A (Audio contract / T35) → RESOLVED; T35 is STALE.** Premise was wrong:
  `assets/audio/a1` AND `web/audio/a1` each hold 300 MP3s, `verify_audio_assets.py`
  **passes** (300/300 byte-identical, manifest-consistent), and `tts_service.dart:243,
  365` reads the bundled asset **first** (`_loadBundledAsset` → `rootBundle.load`) as
  the live 英検5級 offline source. No "empty dirs / red CI" as T35 described. Decision:
  mark T35 done; (optional cleanup) drop the vestigial flat `web/audio` presence check
  in `verify_audio_assets.py` (it guards the removed standalone demo) — not urgent
  since the gate is green.
- **Q-B (WorldMapScreen) → KEEP.** Orphaned from production nav (no live
  `pushNamed('/world')`; reachable only via the `?preview=worldmap` audit harness +
  the `/world` route declaration). It compiles, serves screenshot audits, and is a
  re-link point for the world-exploration pillar. Re-surfacing it as a hub is a
  spec/UX decision (spec-freeze) — not a refactor action. Do **not** delete.
- **Q-C (JSON `distractors` field) → KEEP as inert.** Confirmed zero runtime readers
  (the `.distractors` at `vocab_grammar_practice_screen.dart:243` is the *local
  generated* list, not the model field). Safe to remove, but removal touches the model
  + 300 `vocab_a1.dart` literals for zero benefit → leave as-is; never revert the
  runtime generator.
- **Q-D (skipped listening tests) → LEAVE (intentional gap-markers).** The 2 skips are
  the deliberate "shortfall-visible" mechanism (`skip: have>=want ? false : 'SHORTFALL…'`);
  structural + count-floor groups stay green for all grades. Trigger: when pre2plus/pre1
  listening pools are authored (content-qa gated), the skips auto-flip to green — no
  test change needed.
- **Q-E (consent timestamps) → KEEP timestamp + policy-version (do NOT simplify).**
  They are load-bearing (`ts != null` is part of both consent-skip conditions;
  version-bump forces re-consent). Per COPPA amended Rule (eff. 2025-06-23, compliance
  2026-04-22; new §312.10 data-retention policy) and Japan APPI 2026 (under-16
  guardian-consent), a dated, versioned consent record is the conservative, defensible
  shape for a children's app; a bare bool would be a compliance regression.
- **Q-F (VocabItem source) → bundled-only; hardening is DEFENSIVE-ONLY.** `fromJson`
  is fed solely by `rootBundle` JSON (`vocab_repository.dart:104,151`); Firestore holds
  only per-user FSRS progress, never VocabItems. Hardening is safe anytime but low-value
  now (CI + content-qa already catch malformed bundled JSON). Add a comment; revisit
  only if vocab ever goes remote.
- **Q-G (CSE→core move) → DEFER-WITH-TRIGGER.** Architecturally correct but ~30-file
  import churn for zero functional gain; `skill_accuracy_store` persists to
  SharedPreferences with a **key schema that must not change** (data-loss risk).
  Fold into the next deliberate exam_practice/core-extraction refactor; when done,
  preserve `_correctKey`/`_totalKey` strings byte-identically + add a key-stability test.

**Remaining true escalations (these alone need CEO/secret/legal): none in this set.**
Genuine product-level escalations live elsewhere (billing keys, backend deploy GO,
store/art spend) and are out of scope for this refactor.

---

_End. Posture: subtract evidenced debt, preserve behavior, decide autonomously with
research + evidence (escalate only secrets/billing/legal/prod), propose the big
structural moves. Highest value here: the Phase-2 safety nets + the resolved
decisions above — not large rewrites._
