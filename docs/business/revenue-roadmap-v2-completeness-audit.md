# Completeness Critic — Still-Missing Roles & Residual Gaps

Confirmed the most dangerous claim: `しにたい` (in `_japaneseProfanity` / `_violentKeywords`) triggers `rejectionMessage()` → "その言葉は使えないよ。べつの言い方をしてみてね！" ("You can't use that word. Try saying it differently!"). A child expressing suicidal ideation gets scolded for word choice, with no crisis resource, no log, no parent alert. R-NEW-1 verified against live code. I have everything I need.

---

# Brutal Completeness Review — ENG Quest / A-KEN Quest
*Children's 英検 subscription app, Japan. Critic perspective: ex-operator, kids EdTech.*

**Verdict up front:** The addendum is the best document this project has produced — it correctly demotes "features" and elevates legal/safety/instrumentation to the critical path. I verified its load-bearing code claims against the live repo and **they hold** (self-harm silent-deflection, in-memory `subscriptions = new Map()` at server.js:369, verbatim `system` passthrough at server.js:723, FSRS-4.5 hardcoded, 準2級プラス absent). But a completeness critic's job is what's still missing. Three of the addendum's own "P0 controls" are **non-existent paper controls** that will not survive contact with a real child or a real auditor, and several world-class perspectives are entirely absent.

---

## 1. World-Class Roles STILL Missing Entirely (ranked by impact on THIS business)

### A. Child Clinical Safety / 児童精神・発達 advisor — **CRITICAL, #1 missing role**
The addendum invented a crisis-escalation protocol (R-NEW-1) but **no one on the panel is qualified to author it.** "Warm in-app message + よりそいホットライン + parent push" written by engineers is itself a liability: pushing a self-harm alert to a parent can *endanger* a child in an abusive home (the parent may be the stressor). A real protocol needs a child psychologist's input on (a) what the AI says in the 5 seconds before a human arrives, (b) when NOT to alert a parent, (c) age-differentiated response. This is the one gap where getting it *slightly* wrong is worse than the current silent deflection. **Cheap control: one spot consult with a 児童精神科医 or よりそいホットライン's own institutional guidance (¥30–80k) to review the protocol copy before it ships.** No engineer should author crisis language for children.

### B. Insurance / 賠償責任 (E&O + 個人情報漏えい + D&O-lite) — **HIGH, entirely absent**
Every other panel quantifies regulatory *fines*; nobody bought the backstop. A children's app handling minors' data + AI dialog + payments is uninsurable-by-omission. A single 個人情報漏えい incident (Firestore misconfig → child data leak) is ¥10–50M in notification/remediation for a solo founder with no balance sheet — that's bankruptcy, not a line item. **Cheap control: サイバー保険 + 賠償責任保険 (¥3–8万/yr at this scale via 損保ジャパン/東京海上 SME products). Buy before launch, not before scale.** The Finance panel models 消費税 to the yen but never asked "what's the loss-of-business-ending event and who pays for it." That's a tell that Finance was treated as accounting, not risk.

### C. Localization/翻訳 QA for the *English* content — **HIGH, sneaky-absent**
Everyone obsessed over Japanese UI/legal copy. **Nobody owns correctness of the English being taught.** This is a 英検 product; if a vocab gloss, example sentence, or NPC dialog contains a grammatical error or a katakana-English false friend, you are actively teaching wrong English to children paying ¥1,480/mo, and one screenshot of "Let's enjoy to study!" in your own app destroys 英検-prep credibility instantly. The vocab banks (eiken5/4/pre2/3/2/準1) were generated/curated at velocity — there is **no native-English-reviewer gate.** **Cheap control: native-speaker spot-audit of 200 random items + all NPC system-prompt persona text (¥20–40k on a per-item basis), then an ongoing 5%-sample QA agent.**

### D. 知財/弁理士 — *partially* addressed (商標), **patent/copyright freedom-to-operate absent**
The addendum books a benrishi hour for 英検® and the app-name trademark — correct, but scoped too narrowly. Missing: (1) the **AI-generated mascot/monster/world assets (T31)** have murky copyright and possible Midjourney-ToS/style-infringement exposure if "Midjourney+trace" is used as the addendum casually suggests — that's a litigation invitation if the trace lands near an existing IP; (2) no copyright clearance on bundled MP3 audio / sound effects. **Cheap control: fold a freedom-to-operate + asset-provenance check into the *same* benrishi hour; ban "trace existing art" in writing.**

### E. Accessibility/特別支援 (developmental disability / dyslexia) — beyond WCAG — **MEDIUM-HIGH**
The Kids-UX panel covers WCAG 2.2 AA (contrast, target size) — that's *web* a11y. It does **not** cover the population reality: ~6.5% of Japanese schoolchildren have 読み書き困難 (文科省 2022 survey). A reading-heavy 英検 app with no dyslexia-friendly mode (font, spacing, TTS-everything, reduced-text path) excludes a meaningful, underserved, and *highly retentive* paying segment — and "発達障害の子でも続けられた" is the single most powerful WOM testimonial in the Japanese parent market. This is a growth opportunity disguised as a compliance gap. **Cheap control: UDフォント option + global TTS-on-tap (you already have Google TTS wired) — near-zero marginal cost, large differentiation.**

### F. Roles correctly judged NOT worth a seat (subtract, don't add)
To be disciplined: **災害/事業継続, ESG/教育倫理 as standalone seats, ナレーション収録サプライ, 広告運用専門, dedicated コミュニティ/SNS, ガバナンス/取締役** are all *premature* for a solo pre-revenue app. BCP = "Hetzner + Firebase multi-region, documented in one paragraph." Ad-ops = founder + the Data panel's instrumentation until P2. A board = nonsense pre-funding. Naming these as gaps would be cargo-culting a Series-B org chart onto a solo founder. The addendum's operating-model section is right to resist this; I'm reinforcing it.

---

## 2. Gaps That Remain UNADDRESSED Even After the Addendum

1. **The crisis protocol is unauthored and possibly harmful (see 1A).** The addendum lists it as a ~1-day P0 eng task. It is not an eng task. Marked "controlled," actually wide open.

2. **"Verifiable parental consent" is described but the *mechanism* is non-compliant as specified.** The addendum's P0 control is "parent email → click-through verification." Under the **COPPA 2025 final rule the addendum itself cites**, email-click is the *weakest* VPC method and is **only permitted for internal use** — the moment you send a persistent identifier to Firebase Analytics / Anthropic / Google TTS (i.e., always), you need a *stronger* method (credit-card transaction, signed form, gov-ID, or knowledge-based). The addendum quietly relies on email-click while simultaneously sending data to three third parties. **The control contradicts its own cited regulation.** This is the kind of gap that passes internal review and fails an FTC inquiry.

3. **No data-breach notification runbook.** 個情法 mandates 個人情報保護委員会 reporting (and 本人通知) within set timelines for leaks involving 要配慮 / large volumes. A children's-data breach is reportable. There is a retention schedule but **no incident-notification SOP and no defined 72h clock owner.** Untouched.

4. **Refund/未成年取消 operational reality is half-built.** The addendum adds a consent *gate* (good) but the 取消権 survives even *with* a flawed consent record. There's a Stripe-dispute SOP but **no modeled cash reserve for a 取消 wave**, and no answer for the StoreKit/Play path where Apple/Google control refunds unilaterally. Partially addressed.

5. **Reliance on `kIsWeb` + Firebase across web AND new mobile builds (T01) means the consent/billing/crisis flows must work on 3 platforms** — the addendum writes controls once but the repo now ships web + iOS + Android. No cross-platform test matrix for the *safety* paths. Untouched.

6. **English-content correctness (1C) and dyslexia access (1E)** — untouched.

7. **AI cost/abuse ceiling.** Prompt caching is addressed; **rate-limiting per child / cost-runaway from a looping or adversarial user is not** (the proxy has a rate-limiter Map, but no per-uid daily token budget). A single bad actor or bug can run up the Anthropic bill. Partially addressed.

---

## 3. The Single Most Dangerous Remaining Blind Spot

> **An engineer-authored child-suicide response shipping as a checked-off "P0 safety control" — giving the founder, parents, and the App Store false confidence that the #1 risk is handled when it is, at best, untested and at worst harmful.**

This is more dangerous than the *current* silent deflection, because the current state is a known-open wound, while a shipped-but-wrong protocol is a **hidden** one that everyone believes is closed. The verified code today literally tells a child who types `しにたい`: *"You can't use that word. Try saying it differently."* The addendum's fix — parent-push + a hotline number an engineer picked — could surface a child's private crisis to an unsafe parent, or give a 7-year-old a phone number instead of a human. Both the disease and the proposed cure were written without anyone qualified in the room.

**The cheap control (do this before any other safety work):**
- **One spot consultation (¥30–80k, or free via よりそいホットライン / いのちの電話 institutional guidance) with a child-mental-health professional to author/review three things:** (a) the exact AI response copy at the moment of detection, age-banded; (b) the parent-alert *decision rule* (default: do NOT auto-alert; surface a resource to the child + log to a monitored safety@ queue for human judgment); (c) escalation routing for institutional (塾/学校) deployments where a counselor exists.
- **Until that review exists, ship the minimal honest version:** detect → show the child a warm, non-judgmental message + the crisis line + "話してくれてありがとう" → write `safety_events` (category only) → route to a human inbox. **Do not auto-push to parents.** Logging + human-in-the-loop is the cheap, defensible floor; automated parental alerting is the expensive, dangerous "feature" to avoid.

A world-class kids-EdTech operator does not let engineers write the words a suicidal child reads. That single sentence of professional review is the highest-ROI ¥50k in the entire roadmap.

---

**One structural note for the founder:** the pattern across all three answers is the same — *the addendum is excellent at identifying what's broken and weak at validating that its own fixes are correct.* Email-consent contradicts COPPA; engineer-authored crisis copy contradicts child-safety practice; no English-reviewer contradicts the entire 英検 value prop. Apply your own `SINGLE_CORRECTION_TRIGGERS_FULL_REVIEW` rule to the addendum itself: it found the flaws, now pressure-test the remedies before marking them `[x]`.

Relevant files verified:
- `/Users/openclaw/dev/engquest-flutter/lib/core/dialog/content_filter.dart` (silent-deflection confirmed, lines 122–148)
- `/Users/openclaw/dev/engquest-flutter/backend/server.js` (in-memory `subscriptions` Map line 369; verbatim `system` passthrough line 723)
- `/Users/openclaw/dev/engquest-flutter/lib/core/billing/billing_service.dart` (`// TODO` deploy URL line 59)
- `/Users/openclaw/dev/engquest-flutter/lib/core/fsrs/fsrs_algorithm.dart` (FSRS-4.5 hardcoded, `targetRetention = 0.9` line 29)
- `/Users/openclaw/dev/engquest-flutter/lib/features/legal/` (consent gate / privacy / ToS scaffolds already present — addendum's P0 partially in progress)