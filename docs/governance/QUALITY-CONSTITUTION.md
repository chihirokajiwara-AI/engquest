# A-KEN Quest — Quality Constitution (ENFORCED, universal)

Every recurring defect this project shipped had ONE root cause: a quality gate existed
as an *intention/convention* but was never **enforced** (automated + blocking). The
content-qa gate "existed" yet 10,531 distractors shipped corrupted twice; the asset
contract "existed" yet silent 🔊s and missing scene art shipped; unit tests were green
while screens crashed blank. Conventions don't hold. Only **enforced gates** hold.

These rules are MANDATORY, apply to EVERY change and EVERY agent, and are enforced by
`scripts/verify_quality.sh` (run pre-commit / CI). A change that fails any gate is NOT
done. "Done/fixed/works" is a measurement, never a claim.

## R1 — CONTENT INTEGRITY (enforced: content-integrity test)
No learning item may ship with: mixed-language options (an option set is uniformly EN
or uniformly JP per the item's format), ≠1 correct answer, duplicate options, an option
equal to the answer-key derivation, or wrong-type distractors. Applies to ALL content
(vocab JSONs, quest_data, exam items, placement bank). The 英検 answer/distractors are
never altered by a flavour/framing change.

## R2 — ASSET CONTRACT (enforced: asset-contract test)
Every asset key referenced in code or data (autoPlayAudio, audioAsset, imageAsset,
backgroundAsset, parallaxLayers, npc*Asset, scene plates…) MUST resolve to a real file,
OR be listed in an explicit `ALLOWED_MISSING` registry with a dated reason (e.g. the 6
founder-recorded phonemes). A silent errorBuilder/no-op fallback must NEVER mask a
missing asset that the design assumes exists. New referenced asset → file or registry.

## R3 — RENDER PROOF (enforced: smoke-test audit + screenshot discipline)
A screen is NOT done without BOTH: (a) a widget SMOKE TEST that pumps it and asserts
`tester.takeException() == null`; and (b) a real screenshot LOOKED AT (a `?preview=`
route + Playwright). Green unit tests ≠ a working screen (proven: the battle passed 22
unit tests and rendered a blank crash). Measure, don't assume.

## R4 — NO FIREBASE / NETWORK / HEAVY WORK IN BUILD OR INIT
Widgets must render with NO Firebase/network dependency. Persistence and side-effects
are lazy, guarded (try/catch), and fired from gestures/lifecycle-after-first-frame, not
field initializers or initState. (Root cause of the battle blank-crash: eager
`AuthService()`/`XpService()` hit `Firebase.instance` at init.)

## R5 — CHANGE COMPLETENESS (enforced: leakage grep)
A wholesale content/narrative/rename change ends with a repo-wide grep proving ZERO
residue (e.g. `魔王|王子|王女|prince|heir` after the restoration recast). Half-shipped =
self-contradiction on screen. The grep is part of the gate, not a hope.

## R6 — EVIDENCE OVER CLAIM (operator rule)
Memory, prior outputs, and assumptions are LEADS, not proof. When correctness matters,
verify with current direct evidence: actual files, logs, test output, screenshots, HTTP
codes, real API/system output. Conflicting evidence → current verified evidence wins.
Separate verified-fact / assumption / estimate. Never present speculation as fact.

## R7 — AGENT BRIEFING (operator rule)
No agent works from stale/isolated/incomplete context. Every agent brief includes:
objective, facts, verified evidence, constraints, assumptions, uncertainties, risks,
dependencies, required output, THESE RULES, and the live-research mandate (cite dated
2025–2026 sources; treat training priors AND existing code as stale-until-verified).

## R8 — OPUS INTERVENTION (operator rule)
A top-tier (Opus) reviewer reviews, corrects, and may redirect each parallel stream's
output BEFORE integration — adversarially, against this constitution + the real-world
objective (a kid passes 英検; premium calm Layton immersion; subscription retention;
child-safety/COPPA; Japan minor-monetization law). Integration waits on that review.

## R9 — SCOPE & SOUL GUARDS
- The moat is TOTAL 英検-pass specialization; every feature must serve "a kid passes 英検."
- The form is Layton soul + gentle async Duolingo retention; NO gacha, real-time PvP,
  kid chat, energy/heart paywalls, or child-buyable currency (law + parent-trust + the
  "premium calm" differentiation). Retention must be diegetic and gentle.
- AI generation stays inside one cohesive storybook style; never ship obvious AI slop.

## Enforcement
`scripts/verify_quality.sh` runs R1 (content-integrity), R2 (asset-contract), R3
(smoke-test presence), R5 (leakage grep), plus `flutter analyze` (0) and `flutter test`
(green). Wired as a pre-commit / pre-deploy gate. A failing gate blocks the change.
