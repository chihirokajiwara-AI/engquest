<!-- Generated 2026-06-02 by 14-agent missing-expert panel + completeness critic. Live-2026-researched, dated sources. -->

# v2 Gap-Closure Addendum to the Revenue Roadmap
*ENG Quest / A-KEN Quest — appended to docs/business/revenue-roadmap.md (v1, 2026-06-02). This addendum integrates 11 previously-missing expert panels: Legal/Compliance(JP), Learning-Science/SLA/英検, Data/Experimentation, Security/Privacy-Eng, Kids-UX/A11y, BD/Partnerships, CS/Trust&Safety, Finance/Tax(JP), Brand/Creative/IP, People/Org, AI/ML-Eng — and a subsequent completeness-critic pass that surfaced 5 additional missing roles and 7 residual gaps. It does NOT restate v1; it states only what v1 MISSED and what now changes.*

---

## 1. Summary — The Most Important Gaps v1 Missed (Ranked)

v1's panel was 5 generalists (CFO, CMO, CPO, CTO, Market). It produced a sound pricing/positioning thesis but had **zero coverage of legal, safety, learning-science, instrumentation, and brand** — the exact domains that determine whether the product can legally launch, survive contact with parents, and actually convert spend into users. Ranked by "kills the launch / kills the unit econ" severity:

1. **Child-safety AI escalation is absent and now legally mandated (existential).** A child typing `しにたい` gets scolded for word choice — the live code returns "その言葉は使えないよ。べつの言い方をしてみてね！" ("You can't use that word. Try saying it differently!") — no crisis resource, no parent alert, no log. CA SB 243 / NY / Idaho-Oregon-Washington (2026) now mandate a self-harm escalation protocol with crisis referral. This is the single most likely product-ending 事故 (CS/Trust&Safety + AI/ML + People/Org all independently flagged it #1). **Critical caveat (added post-critic): the fix is NOT an engineering task** — see §1A and the residual-gaps note in §7.

2. **AI dialog is jailbreakable; the content filter is a keyword blocklist that fails ~60% of adversarial prompts.** The proxy passes a client-controlled `system` prompt verbatim (server.js:723). One viral screenshot of inappropriate output → App Store kids-category removal. (AI/ML-Eng + Security.) SafeTutors benchmark, arXiv:2603.17373, March 2026.

3. **未成年者取消権 + missing parental-consent gate = every Stripe charge is legally voidable, breaking the entire churn/LTV model.** 民法5条: a minor's contract without guardian consent is retroactively cancellable (時効 up to 20 years). v1 has no age gate at the payment moment. Chargeback cascade → Stripe account risk → payment-infra loss. (Legal + CS + Finance.)

4. **Billing entitlement lives in an in-memory `Map` (`subscriptions = new Map()`, server.js:369) with a `// TODO: Replace with Firestore` — a server restart silently downgrades every paying subscriber to free.** Plus: native IAP receipts are never server-validated. (Security-Eng.) This is a correctness defect v1 marked "done" (T30/T32).

5. **The phase gates (CAC ≤ ¥1,800, churn ≤ 30%, install→paid ≥ 2.5%) are unmeasurable — there is no subscription-lifecycle instrumentation, and the attribution mechanism v1 implies (Firebase Dynamic Links) is dead since Aug 2025.** Spending P1 UA money produces false signal. (Data/Experimentation.)

6. **COPPA 2025/2026 final rule (eff. April 22, 2026 — already past) + 個情法 令和8年改正 make "anonymous auth = compliant" false.** Persistent identifiers and voiceprints now need verifiable parental consent before going to ANY third party — including Firebase Analytics (`analyticsStorageConsentGranted: true` is set unconditionally) and Google TTS. **And (added post-critic) the consent *method* matters:** email-click VPC is permitted only for internal use; sending identifiers to Firebase/Anthropic/Google TTS requires a *stronger* method — see §2 Legal P0 and §7. (Security + Legal + Data.)

7. **英検 content is stale: 準2級プラス (launched Apr 2025, the highest-converting cohort) is unsupported, Writing is now 2 tasks not 1, and FSRS is 2 major versions behind (FSRS-7 / FSRS-6 personalization vs hardcoded 4.5 global weights mis-tuned for children).** (Learning-Science + AI/ML.)

8. **No brand/IP foundation: no mascot, no preview video, no Japanese-style ASO creative — poor store creative can cut install→paid from 2.5% to ~0.8%, tripling effective CAC before P1's first data point.** Plus "ENG Quest" is an unregistered trademark and "英検®" usage is unverified (store-removal risk). (Brand/IP + BD.)

9. **The CAC≤¥1,800 thesis is contradicted on two fronts: net ARPU is overstated (consumption-tax + 仕入税額控除 ignored → ~¥945 not ¥1,168), and the B2B2C P3 "17,000 準会場" gate is a category error** (準会場 = exam venues, not a sales channel; 準1級 can't even be taken at 準会場; real addressable ≈ 1,500–3,000 教室; sales cycle 6–12mo must start in P1/P2, not P3). (Finance + BD.)

10. **Single-age UI for a 4–18 span fails kids-UX and WCAG 2.2 (now ISO/IEC 40500:2025, required at kids-category submission), and the paywall is a dark-pattern aimed at minors** with a sub-4.5:1 escape link and a trivially-solvable arithmetic parental gate Apple rejects. v1 deferred all a11y to T14 (May 2027). (Kids-UX/A11y.)

**Cross-cutting meta-gap (v1):** v1 treated "COPPA/個情法 labels" and "store submission" as a one-line compliance checkbox. In reality these are P0 *architecture* requirements (parental-consent flow, crisis protocol, billing persistence, instrumentation) — and **the realistic P0 is 10–14 weeks, not 4–6**, once the missing workstreams are added.

**Cross-cutting meta-gap (addendum, surfaced by completeness critic):** *the addendum is strong at identifying what's broken and weak at validating that its own fixes are correct.* Three of its own "P0 controls" are non-existent paper controls until pressure-tested: (a) the crisis protocol is **unauthored** and an engineer-written version may be *worse* than silence; (b) the email-click consent method **contradicts the COPPA rule the addendum itself cites**; (c) no one owns correctness of the **English being taught** — a single grammatical error in-app destroys 英検-prep credibility. Per `SINGLE_CORRECTION_TRIGGERS_FULL_REVIEW`, every remedy below is marked with whether it is *validated* or *requires expert authoring before `[x]`*.

---

## 2. New Requirements / Controls by Domain (each tagged P0/P1/P2/P3)

### Legal / Compliance (JP)
- **P0** — Age + parental-consent gate: parent verification before child account activates; branch 13-未満 vs 14–17. Store the consent record in Firestore as the 法定代理人同意の証跡 (neutralizes most 民法5条 取消権). **CORRECTED (post-critic): email-click alone is the *weakest* VPC method and COPPA-permitted only for internal use. Because identifiers flow to Firebase/Anthropic/Google TTS, use a stronger VPC — card-transaction (¥0 auth via the Stripe gate already being built), signed form, gov-ID, or knowledge-based check.** Use the existing payment step as the VPC carrier where possible (kills two birds). (~5–8d, was ~3–5d.)
- **P0** — 特商法 最終確認画面 on *every* payment path (Stripe + StoreKit2 + Play): initial ¥0(7d) + recurring ¥1,480, auto-renew notice, concrete cancel steps, term — all visible without scroll, on/above the buy button. (措置命令 + 売上3%課徴金 risk; 2025: 1,159 注意喚起.)
- **P0** — Store category decision: list under **Education, not Kids** (recommended) to avoid Kids-category subscription-UI/external-link constraints — but still satisfy the adjacent Guideline 1.3 requirements. Document the rationale.
- **P0** — Privacy policy + ToS rewritten for children's data: data categories, purpose, third-party processors (Firebase/Anthropic/Google TTS), and a 16-未満-保護者同意 clause (pre-empting 令和8年改正). Confirm each processor's DPA.
- **P0 (NEW, post-critic)** — **Data-breach notification runbook:** 個情法 mandates 個人情報保護委員会 報告 + 本人通知 within set timelines; a children's-data leak is reportable. Define the 72h clock owner, the report template, and the 本人通知 path. (~0.5d to draft; owner = founder.)
- **P1** — ステマ規制-compliant ambassador program: written contracts forcing "PR/広告/提供" disclosure; no content direction permitted; 1-page partner guideline PDF, signed. (景表法 売上3%課徴金; 2024–25 total ¥333.48M.)
- **P1** — ToS: "保護者の同意の上でのご利用に限る" + refund policy (in-trial full refund, post-trial no mid-month refund).
- **P2** — 令和8年改正 migration prep (consent-management already built in P0 minimizes delta).
- **P3** — Separate B2B (塾/学校) ToS + DPA; clarify who carries the 情報主体通知義務 for institution-registered children.

### Learning Science / SLA / 英検
- **P0** — Add 準2級プラス to the grade selector (display "近日公開" if content not ready); without it, the highest-converting 中3–高1 cohort bounces to mikan.
- **P0** — Japanese FSRS grade buttons: Hard→むずかしかった, Good→わかった, Easy→かんたん (Again→もう一度 done). For `childAge<8`, collapse to 2 buttons (4-level grading exceeds metacognitive capacity → scheduling noise).
- **P0** — `targetRetention` 0.90→0.85 for `childAge<12` (children forget faster than adult-tuned weights predict); lower Grade-5 initial-stability weight. (3-line change; fsrs_algorithm.dart:29.)
- **P0** (2h) — Post-exam outcome survey ("合格/不合格/結果待ち"): passers → review prompt; failers → CS outreach + suppress review prompt. Converts outcomes into review-gated ratings + pass-rate data + churn-recovery.
- **P1** — 準2級プラス content (~1,700 net-new words by merging pre2+2 banks; A2–B1; 17 vocab + 6 long-passage Part-1 items).
- **P1** — Per-user FSRS weight optimization (collect review logs → Cloud Function optimizer after 50+ reviews).
- **P1** — Exam-mode scheduling: user sets 受験日 → deadline-convergent intervals (last review 2–3d pre-exam); surface 受験日 prominently in onboarding.
- **Correction flag** — No peer-reviewed RCT links commercial vocab-SRS to 英検 pass rates → marketing must NOT make a causal pass-guarantee claim (UNVERIFIED-ASSUMPTION).

### Data / Experimentation / Growth-Eng
- **P0 (blocker, before any UA ¥)** — Subscription-lifecycle instrumentation (SE-MVI): `trial_start / trial_convert / trial_cancel / subscription_renew / subscription_churn / paywall_shown / paywall_cta_tapped`, each carrying `plan_type, grade_selected, days_in_trial, source`; wired from StoreKit2 + Play Billing callbacks.
- **P0** — `source` taxonomy (`organic_aso | organic_wom | paid_apple_search | paid_meta | influencer_{handle} | juku_{id}`) written at account creation.
- **P0** — Replace dead Firebase Dynamic Links with Branch.io free tier (or VPS short-link redirector); integrate Apple Search Ads Attribution API (no IDFA/ATT).
- **P0** — `analyticsStorageConsentGranted: false` by default; flip only after parental consent screen.
- **P0** — Weekly SE-MVI query: `installs_by_source, trial_start_rate, trial_convert_rate, M1_renewal_rate`. **Gate: 2 weeks of correct numbers before a single yen of paid UA.**
- **P1** — A/B discipline: pre-register sample size (block tests where required N > available installs — at 150 paid, most tests are underpowered); add SRM check (alert if split deviates >5% from 50:50); switch primary metric from `retentionScore` to `converted_to_paid` (FSRS score → guardrail).
- **P1** — BigQuery export + 3 cohort queries (install→trial D0–3, trial→paid D7, paid→grade_advance M3).
- **P2** — `grade_upgrade` events (validate ladder-LTV thesis); "healthy subscriber" signature → `at_risk` flag → Day-21 re-engagement.
- **P3** — 合格可能性スコア only after ≥500 validated exam outcomes (Brier-scored); separate B2B2C cohort analytics (`institution_id`).

### Security / Privacy-Eng
- **P0** — Persist subscription entitlement to Firestore on every Stripe webhook; `/billing/status` reads Firestore (Map = 5-min cache only). (~1h; eliminates the silent-downgrade 事故.)
- **P0** — Lock `link_codes`: `allow read: if isOwner(...)` (currently any signed-in user can enumerate 6-digit codes → child-account takeover) + rules-level `expiresAt` TTL.
- **P0** — Lock the Claude proxy `system` prompt server-side: client sends `npc_persona` enum → server maps to a fixed dictionary; remove verbatim passthrough (server.js:723).
- **P0** — `DELETE /user/account` endpoint + Auth `onDelete` cascade Firestore cleanup; self-service in-app deletion (not email-only).
- **P0** — Written data-retention schedule in the privacy policy + cron deletion (FTC COPPA 2025 requires it).
- **P0 (NEW, post-critic)** — **Per-uid daily token budget at the proxy.** The existing rate-limiter Map caps request *frequency* but not cumulative cost; a looping or adversarial child can run up the Anthropic bill. Add a per-uid daily token ceiling → 429 + graceful in-app message past the cap. (~2h.)
- **P0 (NEW, post-critic)** — **Cross-platform safety-path test matrix.** With T01 shipping web + iOS + Android, the consent / billing / crisis flows now exist on 3 platforms but are written once. Add an explicit test matrix asserting each *safety* path (consent gate, parental-handoff, crisis escalation, entitlement persistence) works on all three. (~1d.)
- **P1** — App Store Server API JWS verification for StoreKit2 + Google Play Developer API verification for Play Billing (never trust client `Transaction.currentEntitlements` / `PurchaseStatus.purchased`).
- **P1** — Confirm `age`/`birthYear` never reaches Firestore (replace with CEFR-band enum).
- **P2** — Parental-consent gate for third-party processing (Firebase Analytics/Google TTS/Claude) + withdrawal mechanism; MASVS log hygiene; CSP/SRI on the nginx-served web build.
- **P3** — Verify Firestore region = `asia-northeast1` (cannot change post-creation; blocker for school/gov contracts); document Firebase-region + Hetzner(DE)-proxy cross-border data-flow map for 個情法.

### Kids-UX / Design / A11y
- **P0** — Parental-handoff dialog before `onSubscribe()` fires (routes through OS-level parental authorization; prevents the direct-charge 事故).
- **P0** — Upgrade parental gate from addition to 2-digit multiplication OR 保護者生年入力; rewrite gate copy to adult register; **add a non-cognitive alternative (WCAG 2.2 SC 3.3.8).**
- **P0** — Equal-visual-weight free/paid options on the paywall; fix `grey[600]` escape link (3.8:1 → ≥4.5:1) and `#4FC3F7` heading contrast (2.6:1 fails AA).
- **P0** — In-app subscription-management/cancel link (Apple + Google require it).
- **P0** — `UiProfile` (young 4–7 / middle 8–12 / senior 13–18): young = 60dp targets, icon+furigana + TTS-on-tap, 2-option answers, ±buttons not slider. (Single-age UI = onboarding placement-test is uncompletable by a 4-yr-old who can't read hiragana.)
- **P1 (NEW, post-critic)** — **Dyslexia/特別支援 mode** (beyond WCAG, which is *web* a11y only): ~6.5% of Japanese schoolchildren have 読み書き困難 (文科省 2022). UDフォント option + global TTS-on-tap (Google TTS already wired) + reduced-text path. **Near-zero marginal cost, large differentiation** — "発達障害の子でも続けられた" is the highest-value WOM testimonial in the JP parent market. Growth lever disguised as a compliance gap. (~1–2d.)
- **P1** — Semantics wrappers (slider, answer buttons, progress bar, paywall CTA); parent-dashboard PIN/biometric + 30-min session lock; make `/parent-login` unreachable from the child stack; CI a11y lint (min 44dp).
- **P2** — Full WCAG 2.2 AA pass; middle/senior text-complexity profiles. **(Moved up from T14/P4 — kids-category submission requires AA.)**

### CS / Trust & Safety
- **P0** — Crisis escalation (replaces silent deflection): warm in-app message + crisis line + `safety_events` Firestore write (category, not raw text) + route to a monitored human inbox. **CORRECTED (post-critic): this copy and the alert-decision rule MUST be authored/reviewed by a child-mental-health professional, NOT an engineer (see §1A / new role A). Default rule: do NOT auto-push to parents** (a self-harm alert can endanger a child in an abusive home where the parent is the stressor). Human-in-the-loop + logging is the defensible floor; automated parental alerting is the dangerous "feature" to avoid until the protocol is professionally reviewed. **Mark `[x]` only after expert sign-off.**
- **P0** — Persistent 「AIキャラクター」 disclosure badge + system-prompt clause permitting an honest "I am a magical AI character, not a real person."
- **P0** — Mandatory parental-consent gate before any paywall (anti-voidable-contract).
- **P0** — 2-tap in-app report flow (「AIの返答がおかしかった」「こわい」「その他」) → `reports` collection; parent-dashboard badge.
- **P1** — Voice/COPPA disclosure (separate consent checkbox) or disable Web Speech for launch and drop the permission; refund/chargeback SOP (suspend on `charge.dispute.created`, respond in 48h with consent evidence); 5% daily AI-response audit log.
- **P2** — Incident-response playbook (SNS-trend → 2h log pull); age-gate at subscription.
- **P3** — Institutional DPA (no ad use, 30-day deletion, 72h breach notice); annual third-party safety/pentest (~¥300k, UNVERIFIED).

### AI / ML-Eng
- **P0** — Hardened system prompt: safety rule as line 1 (highest priority, ignore persona-change/"pretend"/"forget instructions"); server-side response length guard (>300 chars rejected at proxy); log all filter triggers.
- **P0** — Prompt caching (`cache_control: ephemeral` on the ~110-token system prompt) — verify the proxy passes the field through (~$1,200/yr avoidable now, more at scale).
- **P1** — Age-band system-prompt variants (4–7 / 8–12 / 13–18); for 4–7 use forced-choice quick replies (no free text → removes filter risk for the youngest cohort).
- **P1** — Per-user / age-cohort FSRS weights (shared with Learning-Science Gap 1).
- **P2** — Inject 2–3 of the user's due FSRS cards into the dialog system prompt (contextualized practice; zero-cost differentiation).

### Brand / Creative / IP
- **P0** — Define 1 named mascot (Japanese name + 3 emotional states + personality brief) appearing in icon / screenshot 1 / onboarding / battle-result / level-up. (~¥0–50k, Skeb/Coconala. **BANNED (post-critic): "Midjourney+trace existing art" — fold an asset-provenance check into the benrishi hour and prohibit tracing in writing; trace-near-existing-IP is a litigation invitation.**)
- **P0** — 5–6 Japanese ASO screenshots (mascot + benefit headline) + 30-sec preview video + trust copy (「広告なし / 保護者管理機能 / COPPA対応」); commit a tagline (「冒険しながら、英検に強くなる。」); privacy policy at stable VPS URL; J-PlatPat trademark conflict check (free).
- **P1** — 1-page 世界観バイブル + story intro (3–5 panels); narrative zone names; file JPO trademark (class 41, ~¥12k); Apple Product-Page-Optimization A/B on icon (free).
- **P0 (BD overlap)** — 英検® trademark-usage review; do not put "英検" in the app *name*; use only "英検®受験対策に対応"-style phrasing (¥3–5k benrishi hour).

### BD / Partnerships
- **P0** — Minimal 塾-pilot spec (20–30 free accounts × 3mo, success metric defined) — its existence shifts P1 speed by ~3 months.
- **P1** — Run 塾 BD in parallel with consumer-channel proof: target 50 英語/英検-specialist 教室; KPI = 5 pilots / 50–100 accounts; one trade-show (¥10–30万); collect pre/post mock-exam data (consent) for school sales.
- **P1** — 英検協会 first contact (trademark licence + EdTech-vendor window).
- **P2** — Test 塾一括ライセンス (¥30–50k/yr/教室, unlimited students) vs individual; repurpose parent dashboard → 教室長 role; approach 私立中高 英語科主任 ahead of the Oct–Dec budget window.
- **P3** — Replace "17,000 準会場" with a real target: B2C 2,000 + B2B2C 3,000 (≈100 教室 × 30); route 準1級 (本会場-only) via B2C/進学校 sales, NOT 準会場.

### Finance / Tax (JP)
- **P0** — Display all prices 税込 (¥1,480 incl.); register as 適格請求書発行事業者 (e-Tax, before launch — secures Apple/Google fee 仕入税額控除); add 税込/税抜/消費税 fields to Firestore sales records (cannot be back-computed); confirm Apple/Google adequate-invoice settings.
- **P0 (NEW, post-critic)** — **Risk-transfer, not just risk-modeling:** Finance was treated as accounting; it must also own the loss-of-business-ending event. Buy サイバー保険 + 賠償責任保険 (個人情報漏えい + E&O) **before launch** — see new role B. (~¥3–8万/yr; the cheapest backstop against a single-incident bankruptcy.)
- **P1** — 前受収益 ledger for annual plans (recognize ¥817/mo, not ¥9,800 up-front); measure real refund rate and re-run LTV; check 消費税中間申告 cash timing.
- **P1 (NEW, post-critic)** — **Model a 取消/refund-wave cash reserve.** 民法5条 取消権 survives even a flawed consent record; the StoreKit/Play paths let Apple/Google refund unilaterally. Hold a reserve sized to a plausible 取消 wave; do not treat refund rate as zero. (Sizing TBD after first 90 days of dispute data.)
- **P2** — freee/MoneyForward for revenue recognition; evaluate デジタル化・AI導入補助金2026 (register as IT導入支援事業者); 中途解約返金ポリシー文書化.
- **P3** — B2B invoices meeting all インボイス要件; ring-fence consumption tax in a separate account (¥740k/mo at 5,000 users is a 預かり金, not revenue); document revenue recognition for audit/fundraise.

---

## 3. v1 Corrections — Numbers/Assumptions Contradicted by 2026 Live Research

| v1 claim | Correction | Source (dated) |
|---|---|---|
| net ARPU ¥1,168, margin ~95% | Consumption-tax + 仕入税額控除 ignored. Real net ≈ **¥945/mo** (¥1,036 store-handoff − ¥91 net 消費税). Margin overstated. | 国税庁 消費税室 プラットフォーム課税Q&A (2024-07); Apple Small Business Program |
| Store fee 30% baseline | At <$1M revenue → **15%** (Apple SBP). P0–P3 stay under $1M (≈¥88.8M/yr at 5,000) → 15% applies; v1 understated early ARPU. | Apple Developer (bdl07n0d, 2025) |
| "COPPA/個情法 labels" = compliance done | COPPA 2025 final rule (eff. **April 22, 2026 — already past**) requires verifiable parental consent before ANY persistent identifier/voiceprint → third party; `analyticsStorageConsentGranted:true` is non-compliant. 個情法 令和8年改正: 16-未満 consent shifts to 保護者 (法定化). | Respectlytics COPPA 2026; Securiti FTC 2025; 牛島総合法律事務所 (2026-01-09) |
| No 未成年者取消権 modeling | 民法5条: minor's contract without guardian consent is voidable, 時効 up to 20yr → potential **full refund on all Stripe charges**; breaks churn/LTV math. | 横浜市消費生活総合センター (current); 消費者契約法 |
| 7-day opt-out trial as a product (no display spec) | 改正特商法 最終確認画面 strictly enforced (2025: **1,159 注意喚起**, 売上3%課徴金). | compliance-ad.jp (2025); caa.go.jp 最終確認画面PDF (2022-06-01) |
| "native IAP (StoreKit2)" with no validation note | Legacy `verifyReceipt`/shared-secret deprecated; JWS server-side verification via App Store Server API required. | Adapty/Qonversion (2025) |
| 6 grades cover the market | **準2級プラス launched Apr 2025** (A2–B1, ~4,000 words) — unserved; highest-converting 中3–高1 cohort. | eiken.or.jp/eiken/2025newgrade/ (2025) |
| 2024 reform "Part1–4 unchanged" | **Writing now 2 tasks** (email/summary) at all grades 3+; Reading counts reduced at pre2+. | eiken.or.jp/eiken/info/2025/change.html (2025) |
| FSRS-4.5 is current | **FSRS-6/7** current; per-user forgetting-curve personalization; app 2 majors behind; global weights mis-tuned for children. | open-spaced-repetition/srs-benchmark (2026); awesome-fsrs (FSRS-6 = Anki 25.07) |
| Content filter sufficient for child safety | Blocklists fail **~60%** of adversarial jailbreaks; system-prompt hardening + crisis escalation now mandatory (CA SB 243 + 2026 state laws). | SafeTutors arXiv:2603.17373 (2026-03); Davis Polk / MultiState (2026) |
| Firebase Dynamic Links for attribution (implied) | **Dead since Aug 2025.** SKAN → AdAttributionKit (iOS 18+, WWDC 2025). | Firebase docs (2025); Aarki AAK FAQ (2025) |
| install→paid 2.5–3% fixed | Highly creative-sensitive; weak ASO can cut it to **~0.8%** (3× CAC) before P1's first data point. | AppTweak / ASO Mobile / Educational App Store (2026) |
| LTV ~¥5,500 robust | RevenueCat 2026: **~72% of annual subscribers cancel in Year 1**; without narrative/emotional hooks, churn stays ~30–40% → LTV ~¥2,400–3,200, too thin vs ¥1,800 CAC. | RevenueCat State of Subscription Apps 2026; Brand panel |
| 準会場 17,000+ as P3 sales gate | Category error: 準会場 = exam venues, NOT a channel; real addressable ≈ **1,500–3,000 教室**; 準1級 cannot be taken at 準会場; 塾 sales cycle 6–12mo. | eiken.or.jp 準会場制度 (2025); 矢野経済研究所 (2025-10, 教育産業 ¥2.86兆 +0.7%, 塾停滞) |
| a11y deferred to T14 (~May 2027) | WCAG 2.2 = ISO/IEC 40500:2025; AA required at kids-category submission → deferral = rejection. WCAG covers *web* a11y only — does NOT cover 読み書き困難 (~6.5% of JP schoolchildren, 文科省 2022). | adaquickscan.com (2025-10); 文部科学省 通常の学級に在籍する特別な教育的支援を必要とする児童生徒調査 (2022) |
| P0 = 4–6 weeks | 8+ parallel workstreams + new P0 legal/safety/instrumentation = **10–14 weeks** for a solo operator. | ShipSquad Solo Founder Index 2026 |

---

## 4. New / Updated TOP RISKS (merge into the existing register)

| # | Risk | Sev | Phase | Cheapest control (owner) |
|---|---|---|---|---|
| R-NEW-1 | AI silently swallows a child self-harm signal → media/App Store removal | **Critical** | P0 | 3-tier `ContentFilter` severity enum + crisis line + `safety_events` log + human inbox (~1d eng) — **but copy/alert-rule authored by child-mental-health pro first (R-NEW-18)** |
| R-NEW-2 | Jailbroken NPC emits inappropriate content to a child → kids-category removal | **Critical** | P0 | System-prompt hardening (line-1 safety rule) + server `system` lockdown + 300-char output guard (~4h) |
| R-NEW-3 | 未成年 charges without consent → 民法5条 mass refunds → Stripe account suspension (payment-infra loss) | **Critical** | P0 | Strong-VPC consent gate (card/gov-ID, NOT email-click) before any charge; store consent record (~5–8d) |
| R-NEW-4 | In-memory subscription Map → server restart silently downgrades all payers → chargebacks + review rejection | **Critical** | P0 | 1 Firestore write per webhook; status reads Firestore (~1h) |
| R-NEW-5 | Phase gates unmeasurable + dead Dynamic Links → ¥1M+ P2 spend on false CAC signal | High | P0 | SE-MVI instrumentation + Branch.io + 2-week-valid-data gate before UA (~2d) |
| R-NEW-6 | COPPA-2026 / 個情法 non-compliance (Firebase Analytics + voice consent) → FTC exposure + store rejection | High | P0 | `analyticsStorageConsentGranted:false` default; voice disclosure or disable; retention schedule (~1d) |
| R-NEW-7 | 英検® trademark misuse → 協会 complaint → store delisting + poisoned BD | High | P0 | Remove "英検" from app name; benrishi 1h review (¥3–5k) |
| R-NEW-8 | 特商法 最終確認画面 non-compliance → 措置命令 / 売上3%課徴金 / app removal | High | P0 | Compliant confirmation screen on all 3 payment paths (caa.go.jp checklist) |
| R-NEW-9 | Weak ASO creative → install→paid ~0.8% → CAC ceiling broken before P1 | High | P0 | Mascot + 5 screenshots + 30s video (<¥60k, 1 week) |
| R-NEW-10 | link_codes enumerable → child-account takeover | High | P0 | `isOwner` rule + TTL (~30min) |
| R-NEW-11 | 準2級プラス unsupported → highest-converting cohort bounces to mikan | High | P0 sel./P1 cont. | Add grade (近日公開) P0; ~1,700-word content P1 |
| R-NEW-12 | Paywall dark-pattern + direct child charge → FTC/COPPA + store removal | High | P0 | Parental-handoff dialog + equal-weight free option + AA contrast (~1d) |
| R-NEW-13 | net ARPU overstated (tax) → unit econ off by ~19% | Med-High | P0 | Register 適格請求書発行事業者; 税込 pricing; tax fields in records |
| R-NEW-14 | B2B2C P3 starts from zero leads (6–12mo cycle) → P3 revenue miss | Med-High | P1 | Begin 塾 BD + pilot-data collection in P1, not P3 |
| R-NEW-15 | Annual ¥9,800 booked as revenue not 契約負債 → MRR/ARR misstated, audit risk | Med | P1 | 前受収益 ledger; recognize ¥817/mo |
| R-NEW-16 | Underpowered A/B tests at 150 users → false positives drive P2 | Med | P1 | Pre-register sample size; SRM check; primary metric = converted_to_paid |
| R-NEW-17 | No human-in-the-loop for AI dialog → institutional buyers block | Med | P2 | Filter→log→weekly review + parent session-summary feature |
| **R-NEW-18** | **Engineer-authored crisis copy ships as checked-off "P0 safety" → false confidence; may surface a child's crisis to an abusive parent or hand a 7-yr-old a phone number instead of a human. Worse than the known-open current wound.** | **Critical** | **P0** | **¥30–80k spot consult with 児童精神科医 / よりそいホットライン institutional guidance to author age-banded copy + alert-decision rule. Until then ship minimal honest floor: warm message + line + 「話してくれてありがとう」 + log + human inbox, NO auto parent-push (new role A).** |
| **R-NEW-19** | **個人情報漏えい / E&O incident → ¥10–50M notification+remediation → solo-founder bankruptcy (no balance sheet)** | **High** | **P0** | **サイバー保険 + 賠償責任保険 ¥3–8万/yr before launch (new role B)** |
| **R-NEW-20** | **Wrong English taught (gloss/example/NPC error) → one screenshot ("Let's enjoy to study!") destroys 英検-prep credibility** | **High** | **P0** | **Native-speaker spot-audit of 200 random items + all NPC persona text (¥20–40k); ongoing 5%-sample QA agent (new role C)** |
| **R-NEW-21** | **VPC method (email-click) contradicts cited COPPA rule → passes internal review, fails FTC inquiry** | **High** | **P0** | **Use card-transaction/gov-ID/KBA VPC; carry it on the existing payment step (Legal P0, corrected)** |
| **R-NEW-22** | **No data-breach notification SOP → miss 個情法 報告/本人通知 deadline → regulatory penalty + trust collapse** | **Med-High** | **P0** | **1-page runbook: 72h clock owner + 個人情報保護委員会 report template + 本人通知 path (~0.5d)** |
| **R-NEW-23** | **AI-asset provenance (Midjourney+trace) → copyright/style-infringement litigation; murky T31 asset ownership** | **Med** | **P0** | **Ban tracing in writing; freedom-to-operate + provenance check folded into the same benrishi hour (new role D scope)** |
| **R-NEW-24** | **No per-uid token budget → looping/adversarial child runs up Anthropic bill** | **Med** | **P0** | **Per-uid daily token ceiling → 429 + graceful message (~2h)** |
| **R-NEW-25** | **Safety paths (consent/crisis/billing) written once but ship on web+iOS+Android (T01) → untested on ≥2 platforms** | **Med** | **P0** | **Cross-platform safety-path test matrix (~1d)** |

---

## 5. Updated P0 Launch-Blocker Checklist (what MUST be added before launch)

v1's P0 (MP3 pre-gen + WordAudioPlayerService rewire, native IAP, commercial Anthropic key, VPS deploy, store submission, 1 distribution probe) **stands but is insufficient.** The following are now hard launch blockers — legal/compliance/security/safety first. **Items marked ⚠ require expert authoring/sign-off before they may be marked `[x]` (per the meta-gap).**

**Legal / Compliance**
- [ ] Parental-consent gate using a **strong VPC method (card-transaction/gov-ID/KBA, NOT email-click)** → activate; branch 13-未満 / 14–17; consent record stored as 法定代理人同意証跡. ⚠ legal spot-review.
- [ ] 特商法 最終確認画面 on Stripe + StoreKit2 + Play (amounts, auto-renew, cancel steps, term — no scroll).
- [ ] Privacy policy + ToS rewritten for children's data (processors named, 16-未満-保護者同意 clause, retention schedule, in-app deletion) at a stable VPS URL.
- [ ] **Data-breach notification runbook** (72h clock owner + 報告 template + 本人通知 path).
- [ ] Store-category decision documented (Education recommended); 英検® usage reviewed; "英検" removed from app name.
- [ ] 適格請求書発行事業者 registration filed; 税込 pricing everywhere.

**Safety (CS + AI/ML)**
- [ ] ⚠ Crisis-escalation protocol **authored/reviewed by a child-mental-health professional** (age-banded copy + alert-decision rule; default NO auto parent-push); minimal honest floor (warm message + line + log + human inbox) shippable in the interim.
- [ ] System-prompt hardened (line-1 safety rule, persona-lock) + server-side `system` lockdown + 300-char output guard.
- [ ] 「AIキャラクター」 disclosure badge.
- [ ] Mandatory parental-consent gate before any paywall + parental-handoff dialog before IAP fires.
- [ ] 2-tap in-app report flow → `reports` collection.
- [ ] Trust & Safety incident-response SOP (1 page) + monitored safety@ inbox; **verify content_filter.dart is wired into the live DialogService path (not just present).**

**Security**
- [ ] Subscription entitlement persisted to Firestore on every webhook; status reads Firestore.
- [ ] `link_codes` locked to owner + TTL.
- [ ] `DELETE /user/account` + Auth onDelete cascade.
- [ ] `analyticsStorageConsentGranted:false` by default.
- [ ] Per-uid daily token budget at the proxy.
- [ ] Cross-platform safety-path test matrix (web + iOS + Android).

**Instrumentation (gate on UA)**
- [ ] SE-MVI subscription-lifecycle events + `source` taxonomy.
- [ ] Branch.io (or VPS short-link) replacing dead Dynamic Links; Apple Search Ads Attribution API.
- [ ] Weekly SE-MVI query producing valid numbers for ≥2 weeks **before any paid UA.**

**Learning / Product**
- [ ] 準2級プラス in grade selector (近日公開 acceptable); Japanese FSRS grade buttons (+2-button mode <8); targetRetention 0.85 for <12.
- [ ] Post-exam outcome survey (review-gating).
- [ ] **English-content correctness audit** (native-speaker spot-check of 200 items + all NPC persona text) before store submission.

**Kids-UX / A11y**
- [ ] Parental gate upgraded (multiplication/birth-year) + non-cognitive alternative (SC 3.3.8); adult-register copy.
- [ ] Paywall: equal-weight free option, AA contrast fixes, in-app cancel/management link.
- [ ] `young` (4–7) UiProfile (60dp targets, TTS labels, 2-option answers).

**Brand / IP**
- [ ] Mascot (name + 3 states), 5 Japanese screenshots, 30s preview video, tagline, trust copy; J-PlatPat conflict check.
- [ ] **Tracing existing art banned in writing; asset-provenance / freedom-to-operate folded into the benrishi hour.**

**Risk-transfer (Finance)**
- [ ] サイバー保険 + 賠償責任保険 bound before launch.

---

## 6. Revised Team Roster — Covered vs Hire/Contract (and When)

**Operating-model baseline (newly articulated):** solo founder + AI-agent stack (Claude Max + Firebase + Hetzner, already paid). 2026 data validates this model (36.3% of new ventures solo-founded; AI stack replaces ¥10–18M/mo of headcount). v1 never wrote down *who executes* — that omission is itself a gap. The map below replaces "founder does everything implicitly."

**Now covered (founder + AI agents — no hire):**
- Codegen, bug triage, content QA *screening* (NOT final English correctness — see new role C), weekly metrics summaries, changelog drafting → **Claude Code agents.**
- First-line CS via email/in-app + safety@ triage (escalate flagged → founder) → **Claude email-triage agent.**
- Founder-owned (never delegated): legal decisions, app-store relationships/appeals, pricing, institutional-relationship calls, content strategy.
- **P0 action:** write the AI-Agent Delegation Map (2h) — which tasks are agent-permanent vs founder-owned vs human-contractor — *before* coding, to prevent the 8-workstream collision.

**Roles to contract/hire, with triggers and timing.** The first five (A–E) are the completeness-critic's newly-identified roles; A is the single highest-ROI spend in the entire roadmap:

| Role | When | Trigger | Structure / cost |
|---|---|---|---|
| **A. Child clinical-safety / 児童精神・発達 advisor (spot)** | **P0 — BEFORE any other safety work** | Crisis protocol must exist before launch; engineers must NOT author child-suicide response copy | 1 spot consult, **¥30–80k** (or free via よりそいホットライン / いのちの電話 institutional guidance) — author/review (a) age-banded detection copy, (b) parent-alert decision rule (default: do NOT auto-alert), (c) institutional (塾/学校 counselor) escalation routing |
| **B. Insurance / 賠償責任 (サイバー + E&O)** | **P0 — before launch, not before scale** | Any children's-data + AI + payments product is uninsurable-by-omission; one leak = bankruptcy for a no-balance-sheet solo founder | SME products via 損保ジャパン / 東京海上, **¥3–8万/yr**; サイバー保険 + 賠償責任保険 |
| **C. Native-English content reviewer** | **P0 (audit) → ongoing 5% sample** | This is a 英検 product; one wrong gloss/example in-app destroys prep credibility; vocab banks were velocity-generated with no native gate | Per-item spot-audit **¥20–40k** for 200 random items + all NPC persona text; then ongoing 5%-sample QA agent + periodic human spot-check |
| **D. 弁理士 / IP (spot, broadened)** | **P0** | Before store submission | 1h spot, **¥3–5k** — 英検® usage + app-name + screenshot review **AND** freedom-to-operate + AI-asset provenance (mascot/monster/world T31, bundled MP3/SFX); ban "trace existing art" in writing |
| **E. Accessibility / 特別支援 (dyslexia) — design-led, not a hire** | **P1** | After P0 ships; before broad WOM push | Folded into Kids-UX work: UDフォント + global TTS-on-tap + reduced-text path (~1–2d founder/agent build, optional ¥20–30k 特別支援 spot-review). Growth lever, not just compliance |
| **Legal/compliance review (spot)** | **P0** | Before launch | Spot review of 特商法 confirmation screen, ToS/privacy children's-data clauses, **and the corrected strong-VPC consent flow** |
| **Illustrator (mascot)** | **P0** | Before store creative | Skeb/Coconala ¥30–50k (tracing banned) |
| **Part-time CS / community (業務委託)** | **P1, ~100 paid** | Founder >3h/wk on CS, OR rating <4.2, OR a complaint unanswered >24h | 業務委託, 10–20h/wk, ¥1,500–2,500/h; **Freelance-Act-compliant written contract** (scope, ≤60-day payment, no unjust termination) |
| **塾 BD (founder-led, then contractor)** | **P1 contact → P2 pilot** | Begin in P1 (6–12mo cycle); do NOT defer to P3 | Founder 20% time in P1; consider senior 業務委託 in P2 |
| **First near-FT hire (sales or editorial)** | **P2** | Only if founder is the *revenue* bottleneck AND MRR ≥ ¥1.5M | 正社員 or long-term 業務委託 (payroll ≤35–43% of MRR at 1,000 users) |
| **Accounting (freee/MF + spot 税理士)** | **P2** | At ~1,000 users / annual-plan volume | Software + spot 税理士 for 前受収益 + 消費税 申告 |
| **Dedicated institutional sales (正社員)** | **P3** | MRR ≥ ¥15M (~1,500+ paid) | ¥6–8M/yr; only role that *cannot* be an AI agent (relationship/paper-contract/3-9mo cycle) |
| **Annual third-party safety/pentest vendor** | **P3** | B2B2C scale / institutional due diligence | ~¥300k/yr (UNVERIFIED 2027 pricing) |

**Roles deliberately NOT seated (subtract, don't add — completeness critic concurs):** 災害/BCP standalone (= "Hetzner + Firebase multi-region, one paragraph"), ESG/教育倫理 standalone seat, ナレーション収録サプライ, 広告運用専門 (= founder + Data instrumentation until P2), dedicated コミュニティ/SNS, ガバナンス/取締役 (nonsense pre-funding). Naming these would be cargo-culting a Series-B org chart onto a solo founder.

**Org at 5,000 users (P3 steady state):** 1 founder (product/strategy/institutional) + 1 CS/community (業務委託) + 1 institutional sales (正社員) + AI-agent stack, plus standing spot relationships (child-safety advisor, native-English QA, 弁理士, 税理士) and bound insurance. Human cost ~¥10–12M/yr vs ~¥70M ARR → <17% of revenue. Sustainable.

---

## 7. Known Residual Gaps (Accepted, with Trigger to Revisit)

Nothing below is silently dropped. Each is consciously deferred or accepted at the current stage, with the explicit condition that flips it back to active.

| # | Residual gap | Why accepted now | Trigger to revisit |
|---|---|---|---|
| RG-1 | **Crisis protocol ships as the "minimal honest floor" (message + line + log + human inbox, no auto parent-push) ahead of full professional authoring** | Honest logged human-in-the-loop floor is strictly safer than today's silent deflection; child-safety advisor (role A) is a ¥30–80k spot, schedulable but may not land before code-complete | MUST have role-A sign-off before public launch; any real `safety_events` write before sign-off → escalate to founder same-day |
| RG-2 | **取消/refund-wave cash reserve is unsized** | No live dispute data yet; sizing on assumption would be guesswork | Set reserve after first 90 days of Stripe/StoreKit dispute data; re-run if monthly dispute rate >1% |
| RG-3 | **Dyslexia/特別支援 mode deferred to P1** | Not a launch blocker (WCAG AA at P0 covers store submission); high-value but not gating | Build before any broad WOM/PR push that targets 特別支援 parents; or upon first institutional (塾/学校) inquiry citing accessibility |
| RG-4 | **No peer-reviewed RCT links the SRS method to 英検 pass rates** | Cannot manufacture evidence; controlled by forbidding causal pass-guarantee marketing | Revisit once ≥500 validated post-exam outcomes exist (enables an internal correlational claim, still not causal) |
| RG-5 | **FSRS personalization (per-user weights, FSRS-6/7 migration) deferred to P1** | P0 ships a children-tuned global config (0.85 retention <12); personalization needs ≥50 reviews/user of data first | Build the Cloud Function optimizer once median active user has ≥50 reviews logged |
| RG-6 | **Annual third-party safety pentest deferred to P3** | Premature pre-revenue; insurance (role B) + benrishi + self-audit cover the interim | First institutional due-diligence request, or B2B2C contract requiring it |
| RG-7 | **Voice/Web Speech may launch disabled** | COPPA voiceprint consent is heavy; dropping the permission removes the whole risk class for launch | Re-enable only with a dedicated voice-consent checkbox + processor DPA confirmed |
| RG-8 | **Cross-border data-flow map (Firebase asia-northeast1 + Hetzner-DE proxy) documented but not re-architected** | Acceptable for B2C under 個情法 with disclosure; only blocks gov/school contracts | Any 公立校/自治体 contract, or 個情法 越境移転 guidance tightening |
| RG-9 | **B2B/institutional analytics, DPA, 情報主体通知義務 split deferred to P3** | No institutional customers yet; building now is speculative | First signed 塾/学校 pilot converting to paid |
| RG-10 | **準2級プラス ships as "近日公開" placeholder at P0, full content at P1** | Selector presence stops the cohort bounce; ~1,700-word bank is real work | Content must land within P1 or the placeholder becomes a trust liability — hard deadline end of P1 |

---

*Net effect of this addendum: v1's pricing/positioning thesis survives, but P0 expands from a 4–6-week engineering checklist to a 10–14-week launch-readiness program whose critical path is legal/compliance/safety — not features — and whose own remedies must themselves be pressure-tested before being marked done. The two highest-ROI line items in the entire roadmap are non-engineering: a ¥30–80k child-safety consult to author the crisis response, and a ¥3–8万/yr insurance binding to survive a single data incident. The CAC≤¥1,800 unit-econ thesis must be re-validated against corrected net ARPU (~¥945) and instrumented (not assumed) conversion data before any P2 scale spend.*