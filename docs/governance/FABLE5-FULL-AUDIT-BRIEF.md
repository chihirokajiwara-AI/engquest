# Fable 5 — Full-System Audit Brief (ENG Quest / コトバ探偵)

**Requested by CEO 2026-06-15 (msg 1672): 「一度、fable5で全体監査をさせてください」.**

## Status — why this is staged, not yet run on Fable 5
- **Fable 5 (and Mythos 5) are SUSPENDED worldwide since 2026-06-12** by a US
  export-control directive (verified: ai.rs "[Suspended]" + search corroboration,
  2026-06-15). No restoration timeline. Not selectable on any plan / API / Claude
  Code `/model` right now.
- The running loop session is **launch-fixed** (claude-opus-4-8) and the Agent
  `model:` selector exposes only sonnet/opus/haiku — so Fable 5 is unreachable
  from the loop even when available.
- **Interim**: the same audit was executed on the best AVAILABLE team (Opus 4.8
  judgment + parallel Sonnet expert lenses). Findings are tracked as backlog
  tasks. Re-run THIS brief verbatim on Fable 5 once access is restored, to get the
  Mythos-class second pass the CEO asked for.

## How to run on Fable 5 (when restored)
1. In Claude Code: `/model` → select **Fable 5** (listed below Sonnet, above Opus),
   or launch `claude --model claude-fable-5`.
2. Paste: "Run the full-system audit in docs/governance/FABLE5-FULL-AUDIT-BRIEF.md.
   For EACH dimension: WebSearch the current 2026 SOTA first (cite dated sources),
   audit the ACTUAL code/live render (not docs), default-REJECT, and return the
   single highest-value finding with file:line + why it blocks 英検 pass or sale."

## Scope — the whole product (singular value: 「英検に合格できる本物のアプリ」)
Audit ALL of these dimensions; each finding must be evidence-backed (file:line,
real render, or a run command + output) — NEVER presumed:

1. **英検 content correctness** — every grade (5〜準1) × every section (vocab/
   grammar cloze, reading, listening, conversation, word-order, writing). Verify
   task FORMAT matches the official 2024-reform spec per grade (the #41 class:
   right task modelled for the right grade), answer keys, distractor sanity, and
   level-appropriateness. Cross-check eiken.or.jp / 旺文社 / gakken.
2. **Pedagogy / learning efficacy** — does the loop actually build 英検-passing
   skill? FSRS scheduling correctness; teach-before-test; honest 合格率/CSE model;
   weakest-skill-gates-pass enforcement; hint ladders teach (never leak answers).
3. **Code & architecture quality / bugs** — web-safety (no dart:io), state
   correctness across grade switches, null/empty-deck guards, race conditions,
   dead code, perf (cold-boot, asset payload), error handling.
4. **Accessibility** — screen-reader semantics on every interactive widget,
   reduce-motion gating, tap-target size, contrast, pre-literate tap-to-speak.
5. **Game-feel / UX / visual** — moment-to-moment juice, affordances, scene
   composition/cohesion vs Layton/2026 bar, transitions, empty-states; art-style
   cohesion vs LOCKED M5/M6 mains (no style clash).
6. **Security / privacy** — COPPA (anonymous auth, no PII), Firestore rules
   (user-isolation, enumeration), no secrets/keys in client, app_config untouched.

## Out of scope (permanent — never audit/propose; CEO domain)
Crisis/child-safety net; billing/RevenueCat; backend deploy; server infra;
backend-dependent AI (Claude dialog, AI writing scoring); legal; store listing;
online/multiplayer. Production deploy (:8088) is CEO-gated.

## Output contract
A prioritized findings table (dimension → finding → severity → file:line →
fix sketch), default-REJECT discipline (only verified-real findings listed),
each new defect filed as a backlog task. Fix the top quick-wins behind the HARD
GATE (analyze 0 + tests green + content-QA for content) and ship per autonomy
rules (push OK; deploy/Stripe/secrets → CEO).
