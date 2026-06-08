# Completeness Critic — 2026-06-08 (re-prioritization after the #59 run)

Contract cadence ("every ~5 iterations run a completeness critic"). The loop has spent
~5 iterations on **pillar 3 (world/character)** — building the 5 headliners into the cases
(real progress). This critic steps back: **what's missing/shallow/unverified, and is the
loop attacking the highest-value pillar?** Answer: **no — verified P0 launch-blockers
(pillars 1/10/11 + commercial) sit unaddressed and outrank world/character polish.**

## Verified launch-blockers (re-checked against CURRENT code 2026-06-08)

These were flagged by the 2026-06-02 expert panel and are **still live** (line-cited):

1. **[EXISTENTIAL] Child-safety crisis gap.** `lib/core/dialog/content_filter.dart`:
   self-harm keywords (`しにたい`/`suicide`/`want to die`/`kill myself`, lines 63, 87-102)
   are handled by the SAME `sanitize()→null` reject path as profanity (lines 187-190), so a
   suicidal child receives `rejectionMessage()` = 「その言葉は使えないよ。べつの言い方をして
   みてね！」 (lines 201-203) — a *profanity scold*. A prior safety fix was **reverted**
   (commit "Revert fix(safety): route self-harm signals to crisis support…"), leaving the
   gap live. **NOT auto-fixable by the loop:** the response a child sees is customer-facing
   safety copy (FORBIDDEN) and, per the safety memory, an engineer-authored crisis response
   can be *worse* than silence — it needs a 児童精神 professional consult (¥30-80k = spending,
   FORBIDDEN) to author the copy + the alert-decision rule. **→ ESCALATE.**
2. **Billing not persisted + no IAP validation.** `backend/server.js:369`
   `const subscriptions = new Map()` (+ `:367` `// TODO: Replace with Firestore persistence`)
   → a server restart silently downgrades every paying user to free; no StoreKit/Play receipt
   validation anywhere. Makes T30/T32 effectively NOT done. **→ ESCALATE** (billing = FORBIDDEN;
   also depends on backend deploy #7).
3. **Jailbreakable child-facing AI.** `backend/server.js:722-723`
   `sanitizedRequest.system = requestData.system` passes the client-controlled system prompt
   to Anthropic verbatim (only length-checked). Engineer-able (lock/own the system prompt
   server-side) BUT needs a backend persona-design decision and the backend is undeployed
   (#7) + not covered by `verify_quality` (Dart-only gate). **→ queue with #7; not a clean
   one-iteration loop ship.**
4. **Legal: no parental-consent gate at payment** (未成年取消権 voids charges) + VPC method
   vs COPPA-2025. **→ ESCALATE** (legal = FORBIDDEN).

## Why the loop didn't catch this sooner
The per-iteration audits are change-scoped; the standing pillars (§A/§F of AUTONOMOUS-LOOP)
list safety/billing/AI/legal, but the loop kept picking the CEO's most recent steer
(composition → world → characters). This critic is the corrective: **safety + the SOLE
value + monetization outrank polish.**

## Re-prioritized backlog (highest value first)
- **P0 — ESCALATE NOW (CEO owns; FORBIDDEN to auto-do):** #1 child-safety crisis gap
  (existential), billing persistence + IAP validation, legal parental-consent gate. These
  are **hard launch-blockers** — do NOT launch until resolved.
- **P0 — loop-buildable (top pillar = pedagogy):** #60 grade-map decontamination (the
  mastery-gate integrity — 準2/準2+ contain 2級/準1 grammar; "case-closed = would pass this
  grade" is the load-bearing claim). Engineer-able + content-qa-gated.
- **P1 — security (queue with #7):** lock the server-side system prompt (jailbreak).
- **P1 — depth/polish:** deeper #59 per-item mechanics; #56 title-hero precache; #57
  lean-Layton spine; #61 art governance.
- **Gated on CEO approval:** #58 character art + gender-selection.

## Honest note
The 5-headliner world work (this run) was genuine, gated, content-QA'd progress — but a
beautiful world with a suicidal-child-scold in `content_filter` is not shippable. The loop
should not ship/launch until the P0 launch-blockers are CEO-decided.
