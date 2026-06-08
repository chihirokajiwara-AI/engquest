# Commercial Quality Audit — 2026-06-08 (first run)

Trigger: CEO msg 913 — "Is a super-strict audit of image/page quality in the loop?
As it stands there is NO mechanism to raise this to a world-class, commercially-
sellable bar." + msg 914 — "the extra game-y features added (pitched as making a
sellable 英検 app) are NOT needed."

Answer: there was no standing mechanism. There is now — see
`docs/governance/AUTONOMOUS-LOOP.md §H`. This is its first run.

## Method
- Captured 8 live screens from the deployed demo (`?preview=` routes, 390×844):
  title, onboarding, prologue5, kotobahome, explore, questmap, exam, passmeter.
  (`/tmp/qaudit/*.png`.)
- Ran a perspective-diverse, **default-REJECT** panel against a commercial bar:
  art-direction (Opus), product/UX commercial-readiness (Opus), subtract-skeptic
  (Opus), 英検-pedagogy (Sonnet). Bar grounded in dated 2026 sources:
  [Duolingo shape-language art system](https://blog.duolingo.com/shape-language-duolingos-art-style/),
  [Duolingo oversized tap-targets → +15% task success](https://octet.design/journal/duolingo-case-study/),
  [UX for kids — clear visuals, motor limits, ≥48dp targets](https://www.ramotion.com/blog/ux-design-for-kids/),
  [paywall/onboarding: value+trust before commitment](https://adapty.io/blog/how-to-fix-your-onboarding-flow/).
- **Adversarially verified every factual claim before acting.**

## Verdict (all four critics): NOT sellable today.

## THE convergent finding (all 4 — observable, not a spec claim; = CEO 914)
**The game-y layer sits ON the critical path while the actual 英検 value is buried.**
- kotobahome: the primary CTA is the story ("じけんげんばへ"); 英検れんしゅう is the
  smallest, bottom-most item; the hero element is a 0-day streak.
- prologue5 + explore: a Japanese-only story prologue and a hidden-object "village"
  gate/precede any English; neither practices an 英検 item.
- passmeter (合格率 — the actual sell) is a buried sub-screen of the exam menu.
→ Recommendation (per 914 + subtract-before-add): re-foreground 英検 practice + the
  pass-meter as the primary daily path; make story/world/exploration optional,
  never-blocking (a post-practice reward, not the front door). **This is a major
  spec change (reverses the 2026-06-06 "painted world is the landing" decision) →
  ESCALATED to CEO for go before execution.**

## Verified backlog (ranked)
1. [BLOCKER · architecture · CEO-GO] Re-foreground 英検 practice + pass-meter; demote
   story/world to optional reward. (convergent)
2. [BLOCKER · visual] Three clashing visual systems (ornate parchment/filigree vs
   dark-navy/gold card vs sepia painted scene). Unify on the dark-navy/gold card
   system; retire parchment. (art)
3. [BLOCKER · value] PassMeter is the core sell but under-designed (flat bars + bare
   "92%"), buried, and the % has no shown basis (reads fabricated). Design a real
   gauge; surface to the parent; show n-questions basis. (art+ux+pedagogy)
4. [BLOCKER · visual · ties #48] explore scene reads as ungoverned AI-art with
   illegible floating hotspots; heaviest asset; teaches nothing. Cut or replace +
   demote off the study path. (art+subtract+ux)
5. [MAJOR · ux] Onboarding collects AGE via a small slider, not 英検 grade target —
   fails the ≥48dp motor bar for young children AND age≠level. Replace with large
   grade-target buttons. (ux+pedagogy)
6. [MAJOR · decision] Bilingual double-labeling on every control/heading clutters +
   adds reading load for a Japanese-child audience. Decide: Japanese-primary,
   de-emphasize English. (art+ux — brand decision)
7. [MAJOR · visual] Emoji-as-icons (home), placeholder "Sage" avatar (onboarding),
   and inline-paren furigana instead of true ruby. Custom icon set; on-model Sage
   (art-gated); real ruby. (art)
8. [MAJOR · ux] Exam hub has equal-weight CTAs (mock vs pass-meter) — no dominant
   primary. (art+ux)
9. [MINOR] "つづきから/Continue" offered on a fresh install; low-contrast outline
   CTAs near WCAG-fail; settings gear small/low-contrast.

## REFUTED findings (adversarial verification caught these — do NOT act)
- ❌ "英検5級 mock includes 語句の並びかえ, which is not a 5級 section." **FALSE.**
  [Official 英検5級 大問3 IS 語句の並びかえ](https://www.eiken.or.jp/eiken/exam/grade_5/)
  (rearrange ①–④ to a given Japanese sentence). The codebase
  (`eiken_exam_config.dart` + `word_ordering_test.dart:14`) is CORRECT. Acting on
  this would have removed a real 5級 section = a regression.
- ❌ "準1級 missing from the grade map." `quest_map_screen.dart:159` + `eiken_exam_config.dart:398`
  both include `pre1`; the screenshot was likely not scrolled.
- ❌ "Title shows 英機 (not 英検)." Misread; the title renders 英検（えいけん）.

The Sonnet pedagogy critic produced ≥2 false spec claims → its spec-level output is
down-weighted; the three Opus critics' *observable* (visual/UX) findings held up.
**Lesson for the mechanism: visual/UX observations are reliable; factual 英検-spec
claims MUST be verified against eiken.or.jp + the codebase's own guards before any
action.**
