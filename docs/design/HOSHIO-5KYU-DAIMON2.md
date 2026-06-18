# ホシオ（星緒） — 5級 大問2 villager (designed 2026-06-19, CEO 2063 "drive, don't wait")

Designed by a sonnet character-agent (latest-first), reviewed on the main loop. A
MINOR NPC for the 5級 town presenting a 大問2 (会話文の文空所補充) ナゾ. Per
EIKEN5-LAYTON-NAZO-PLAN.md item-5: engineering = NONE (maps onto the existing
QuestEncounter NazoScreen already renders, like kCelArticleNazo); this is a
content+framing task. Spec-frozen → wire from a VERIFIED 会話 item, content-QA, then
present to CEO (build+present, not ask-first).

## Villager
- **Name:** ホシオ（星緒, ほしお） — elderly village stargazer + former postman who
  delivered handwritten star-charts so no one got lost at night.
- **Secret hook (gentle, age-appropriate):** the night the サイレント came he was on
  his roof counting stars; by morning every star-NAME had vanished. He still climbs
  up at dusk, reaching for names he can't quite catch.
- **Visual (dusty-teal/brass cohesive):** stooped figure in a deep-navy hooded coat
  with brass telescope-lens buttons; oversized round spectacles with dusty-teal
  lenses (the single warm silhouette anchor); long comet-trail white eyebrows; a
  blank rolled star-chart under one arm.
- **Grey→colour reveal:** coat ash-grey→deep navy, brass gleams, one tiny
  constellation blooms on his chart — "…あ。あの星は、そういう名前じゃったか" (one
  star-name returned, proportionate to a minor NPC).

## 大問2 ナゾ framing (frame a VERIFIED bank item; do NOT ship the sample English)
- **framingJa:** 「星の夜に交わされた、ふたりのやくそく。ぽっかり消えたことばを、うめてあげよう。」
- **npcLine:** "I heard two voices last night — before the grey came. I think they
  were asking about plans. Can you remember what came next?"
- **npcLineJa:** 「むかし、ふたりのこえがきこえた。なにかのやくそくのはなし。でも、つぎのことばがきえてしまったんじゃ。きみ、おぼえておるかい？」
- **onCorrect (teach-why, ≤2 lines, fires AFTER correct):** explain the be-verb /
  response agreement from the chosen bank item's 解説, in タロ/ホシオ voice. タロ/ホシオ
  NEVER state the answer; framing is flavour only.

## Wiring plan (next build)
1. Pull a real verified 5級 会話 item from `conversationItemsForTest('5')` (already
   content-QA'd + shuffled) → its choices/correctIdx/解説. Do NOT author the English.
2. Author a `kHoshioConversationNazo` QuestEncounter (npcName='ホシオ', npcLine/
   npcLineJa/framingJa/onCorrect above, choices/correctIndex from the bank item) —
   mirror `kCelArticleNazo` exactly (QuestEncounter extends QuestStep; pass as `step:`).
2b. teachCard like スラ=kGreetingTeach if the ナゾ needs a teach-first card.
3. Place ホシオ as an NPC hotspot in the 5級 scene (mirror セル). Verify the case-
   identity header shows ホシオ (the `header shows case identity` test).
4. content-QA the framing prose (CLAUDE.md gate). analyze 0 + flutter test (incl.
   nazo_hint_rail / header-identity). Then present to CEO.
NB pure-kana hint ladder must not leak the answer (nazo_hint_rail_test).
