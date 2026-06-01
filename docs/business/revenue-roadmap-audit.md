# A-KEN Quest — Adversarial Audit (VC + EdTech operator + CFO)

This is an analysis task. The roadmap and all data are provided inline. No file investigation is needed — I'll audit directly.

# A-KEN Quest Revenue Roadmap — Adversarial Audit

**Panel: VC Partner / EdTech Operator / Unit-Economics CFO. Verdict at the end.**

The plan is well-structured and self-aware (it flags its own assumptions, which is rare and good). But "well-structured" is not "investable." Below is where it breaks under load.

---

## (a) Unrealistic / Unsupported Numbers

**1. The funnel arithmetic to 5,000 paid is never actually drawn — and when you draw it, it collapses.**
The plan asserts 150 → 900 → 5,000 paid but never reconciles this with its own conversion assumption (2.5–4% install→paid) and the stated reality that *Japan is below NA's P25 of 5.5%*. To get 5,000 paid at a generous 3% you need **~167,000 installs**. The plan's only ¥0-UA channels in Phases 1–2 are ASO + three 英検 dates a year. ASO for a brand-new app with 30 reviews does not produce six-figure install volume in Japan against スタサプ and mikan's SEO/ASO dominance. The 900→5,000 jump is hand-waved onto "塾 B2B2C" (see b).
**Fix:** Build the funnel bottom-up per channel with explicit install volumes and a stated blended conversion. If the only way to 5,000 is B2B2C, then this is a B2B2C company and the entire consumer-funnel framing is wrong — re-plan around institutional sales cycles, not ASO.

**2. 12% monthly churn is presented as "conservative." It is optimistic.**
The plan's own verified data says month-1 churn on monthly plans is **15–40%**, and ~30% of annuals turn off auto-renew in month 1. A 12% *steady-state* number quietly ignores the brutal first-renewal cliff. For a child-engagement product where the *child* must stay engaged but the *parent* pays, post-exam-date abandonment is a near-certainty. Blended real churn for the first 3 months is likely 25–35%.
**Fix:** Model two-stage churn: a first-renewal cliff (use 30%) plus steady-state (12%). Recompute LTV on the cohort-weighted blend — it will land closer to ¥5,000–6,000, not ¥8,783, which breaks the CAC≤¥2,900 ceiling at 3:1.

**3. LTV ¥8,783 assumes a "modest premium" over the ¥7,000 benchmark with zero justification.**
A brand-new, unproven consumer app should model *below* category median, not above. Combined with finding #2, the LTV is doubly inflated.
**Fix:** Anchor LTV at ¥5,000–6,000 until you have 6 months of real retention data. Set the CAC ceiling at ≤¥1,800 (3:1) accordingly.

**4. Net ARPU ¥1,054 leans on a 40% annual mix at launch.**
40% annual adoption is an aspirational steady-state, not a launch reality — opt-out free trials convert disproportionately into *monthly* plans because the trial CTA is monthly. New apps see 10–20% annual mix early.
**Fix:** Model 20% annual for Phase 1–2, re-test. This lowers ARPU and worsens the churn exposure (more people on the high-churn monthly plan).

---

## (b) Hand-Wavy Steps in the Path to 5,000

**5. "塾 B2B2C carries the jump to 5,000" — this is the load-bearing wall, and it's drawn as a single table row.**
The plan itself admits a "6–9 month close cycle" for 塾 and the founder is only ~30% on distribution. To move ~4,000 incremental paid via institutions at ~¥500/student you need to close *dozens* of schools, each requiring procurement, billing integration, teacher training, and a fundamentally different product (admin dashboards, class management, invoicing — none of which are built or budgeted). This is a second company bolted onto the side.
**Fix:** Either (a) commit to B2B2C as the primary GTM and build/budget the institutional product + a real sales motion (this changes the whole plan), or (b) drop the 5,000 target to what consumer channels can credibly deliver (likely 1,000–1,500 in 18 months) and raise on *that* honest number.

**6. "合格可能性スコア" is named the parent purchase hook but has no validation methodology.**
A predicted pass-probability score for a national standardized exam is a serious claim. If it's wrong, it generates refunds and 1-star reviews ("said 80% likely, kid failed"). The plan flags the "合格保証 expectation gap" risk but still makes the score the *core* paid hook.
**Fix:** Either validate the score against real 英検 outcomes before launch (you have no outcome data yet, so you can't), or reposition the hook to something defensible you actually control — 学習進捗 / 弱点分野 / 継続日数. Don't sell a prediction you can't back.

**7. Phase 0 in "~9 eng-days" with a solo founder is fantasy scheduling.**
StoreKit 2 + Play Billing + pre-generating/serving 7,900 MP3s + rewiring the audio service + paywall + parent-email infra + CI/CD + store submission (with Apple review latency) + 50-user beta. Apple review alone can burn a week of calendar time per rejection, and first-time kids-category apps with IAP get scrutinized hard.
**Fix:** Re-baseline Phase 0 to 4–6 calendar weeks and treat App Store kids-category + COPPA/個人情報保護法 review as a serialized risk, not a parallel checkbox.

---

## (c) Pricing / Positioning Weaknesses vs スタサプ & mikan

**8. The "32% under スタサプ" narrative misreads the competitor.**
スタサプ ENGLISH at ¥2,178 is *講師動画型* with Recruit's brand, sales force, and school channel. You are not 32% cheaper than the same thing — you're a different, unproven thing. Price-anchoring against スタサプ implies parity of trust you haven't earned. Meanwhile mikan at ¥1,000 with **9M cumulative downloads** is the real competitor for the budget-conscious parent, and you're 48% *more expensive* than a known brand.
**Fix:** Stop anchoring on スタサプ. Position explicitly against mikan: "mikanは単語、A-KENは合格まで." Justify the premium with the *exam-simulation + RPG retention* bundle, and be ready to prove retention superiority, because that's the only thing that justifies +48% over a 9M-download incumbent.

**9. The free tier (英検5級 forever) cannibalizes your fastest-growing, most-defensible segment.**
The plan's own beachhead is 小学生, and 小学生 overwhelmingly sit at 5級/4級. Giving 5級 away "forever" means your highest-growth cohort can use the product for free at exactly the level they need. You've gated the *upsell* (4級+) but the entry cohort has little reason to convert until they advance — which may be a year away, well past the churn window.
**Fix:** Gate by *feature depth*, not grade. Let 5級 be free for vocab/flashcards but gate exam-simulation, AI dialog volume, and the parent dashboard *at every grade including 5級*. The parent pays for the exam-prep + reporting, not the grade.

**10. ¥999 vs ¥1,480 vs ¥3,000 conflict resolution is decisive but the ¥3,000 origin is ignored.**
The ¥3,000 figure in the other CLAUDE.md was tied to the *original product thesis* (英検準1級/B2 by high school — a premium, long-horizon outcome). Picking ¥1,480 silently abandons that premium-outcome positioning. That may be correct, but the plan doesn't acknowledge it's a strategic downgrade of the value proposition.
**Fix:** State explicitly that you're repositioning from "premium B2-outcome" to "affordable exam-prep," and confirm the LTV ladder (5級→準1級 upsell) still gets you to the same lifetime value at the lower monthly price. If it doesn't, the ¥1,480 decision needs revisiting.

---

## (d) Hidden Costs & Capital-Efficiency Violations

**11. Claude Max for a commercial backend proxy is the single biggest hidden liability — and it's buried as a "MED" risk.**
Anthropic's consumer Max subscription is for *personal* use. Routing thousands of paying customers' dialog turns through a Max-funded proxy is almost certainly a ToS violation and a single point of total failure: if Anthropic throttles or bans the account, the AI dialog feature dies for all users *and* your dev environment dies. The plan's PAID_ASSETS_FIRST principle is actively pushing you toward a compliance landmine here.
**Fix:** This is not "confirm with Anthropic and set a $50 cap." Move commercial inference to a *commercial* Anthropic API key from day one and budget it as a real (small) COGS line. At haiku pricing it's ~$11–50/mo — trivial. Eating a tiny metered cost to avoid an existential ToS/availability risk is the *correct* application of capital efficiency. The "no tokens outside the Claude sub" constraint is a false economy here.

**12. Firebase Spark free-tier headroom is overstated and load-bearing.**
"Spark covers ≤~8,300 MAU" assumes near-zero per-user read/write, but FSRS is read/write-heavy (card states, review logs) and the parent dashboard aggregates. 5万 reads/day ÷ even 50 reads/active-user/day = 1,000 DAU, not 8,300 MAU. You will blow Spark well before 5,000 paid and silently fall onto Blaze.
**Fix:** Model Firestore ops/user empirically from the actual FSRS + dashboard query patterns. Budget Blaze from ~1,000 DAU and put a real (small) line item in. Better: aggressively cache and batch, but don't *plan* on the free tier surviving to 5,000 paid.

**13. CAC discipline ≤¥2,000 with a real LTV of ~¥5,500 (post-correction) leaves almost no room for paid UA.**
Japanese mobile UA for a parenting/education keyword is not cheap; CPI + the conversion funnel can easily exceed ¥3,000–5,000 fully-loaded for a paying customer. The plan green-lights paid UA at "CAC<¥2,000 confirmed" but never shows that's achievable in Japan for this category. If paid UA can't hit ¥2,000, Phases 2–3 have *no* scalable channel except the unproven B2B2C.
**Fix:** Run a small paid-UA probe in Phase 1 (¥100–200K) purely to measure real blended CAC before betting the roadmap on it. If it's >¥3,000, the plan is structurally organic/B2B2C-only and the 5,000 target must be re-derived.

**14. "Founder sweat equity, ¥0 incremental cash, break-even Month 1" hides the largest cost: founder time and opportunity cost.**
Break-even Month 1 is true only because labor is priced at zero. That's fine for a bootstrap but it's not a capital-efficiency win — it's deferred cost. An investor reads "break-even Month 1" as either naive or misleading.
**Fix:** Drop the "break-even Month 1" claim from any investor-facing version. Show contribution margin and a path to covering a market-rate founder salary.

---

## (e) The Single Most Likely Reason This Plan Fails

**Cold-start distribution.** Strip away the polish and this is a brand-new consumer app with zero brand, ~30 seed reviews, and no proven acquisition channel, competing in a category where Recruit owns the school/brand channel and mikan owns 9M downloads. The plan's two organic pillars (ASO + three exam dates) cannot produce the ~150k+ installs the funnel math requires, and the B2B2C escape hatch is a different, unbuilt, unbudgeted, 6–9-month-cycle business. **The most probable failure: the app launches cleanly, works well, and simply never gets in front of enough parents — stalling at a few hundred paid users with no channel that scales to 5,000.**

**Fix:** Before writing more roadmap, run a *distribution* spike, not a product spike. Pre-launch: validate ONE scalable channel with real money/time — e.g., a single 塾 partnership signed as a paid pilot, or a ¥200K paid-UA test with measured CAC, or a 英検-influencer collab with tracked installs. The roadmap's phases should gate on *channel proof*, not product milestones. No proven channel = no plan.

---

## Verdict

**Merely functional. Not yet world-class or investable as written.**

This is a genuinely strong *operating plan for a product that's already found a channel* — the unit-economics framing, assumption-flagging, risk table, and Phase 0 engineering discipline are above-average and show real rigor. But investability turns on the one thing the plan assumes rather than proves: **a repeatable, scalable path to customers.** As written:

- The path to 5,000 is funnel-math that doesn't close on consumer channels and silently outsources the gap to an unbuilt B2B2C business.
- LTV/churn are quietly optimistic, collapsing the CAC headroom that the whole "self-funding" story rests on.
- The "free assets" thesis pushes a genuine ToS/availability landmine (Claude Max for commercial inference).
- It abandons the original premium ¥3,000 thesis without acknowledging the strategic trade.

**What would make it investable:** (1) one proven, scalable acquisition channel with measured CAC; (2) honest two-stage churn and a re-derived LTV/CAC; (3) a decision on whether this is a consumer or B2B2C company — and a plan built around that answer, not both; (4) move commercial inference to a commercial API key. Do those four and the underlying product quality could make this a credible seed bet. Today it's a polished plan resting on an unproven distribution assumption — which is the most common way EdTech companies die.