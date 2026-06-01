<!-- Generated 2026-06-02 by CEO+CxO panel (8 agents). Verified-data-grounded; audit-revised. -->

# A-KEN Quest — Revenue Roadmap (Definitive · CEO Final)
**Date: 2026-06-01 · Owner: CEO · Status: Committed for execution**

---

## 1. Executive Summary

**The bet:** Own the structurally empty 小学生〜中2 / 英検5〜3級 segment before Recruit (スタディサプリ) moves down-age. Market growing 15% over 5 years; 小学生 receivers up ~1.5× in a decade (375,991/yr). No competitor combines child-RPG UX + FSRS + full 英検 exam simulation for this age band. 英検 runs three times a year — a free, recurring demand spike and the retention hook nobody else exploits.

**The honest strategic posture (audit #5, #e accepted):** This is **consumer-first to ~1,200 paid, then B2B2C to scale.** I will NOT pretend ASO + three exam dates produce 167,000 installs. The roadmap therefore gates on **proven distribution, not product milestones.** No proven channel = no Phase 2 spend.

**The number:** **¥1,480/month · ¥9,800/year (45% effective discount) · 7-day opt-out trial.** One price, defended in §3. Undercuts スタサプ but — per audit #8 — we position against **mikan**, not スタサプ.

**The repositioning (audit #10 accepted):** We are explicitly downgrading from the original "premium ¥3,000 / B2-by-high-school" thesis to "affordable exam-prep with a 5級→準1級 upsell ladder." The lifetime value now comes from **grade-ladder progression across years**, not a high monthly price. If the ladder does not deliver multi-year LTV (validated in §4), the ¥1,480 decision reopens.

**The path (calendar-honest, audit #7 accepted):**
- **Phase 0 (Jun–mid-Jul 2026, 4–6 weeks):** Launch readiness — audio, native IAP, deploy, store submission incl. kids-category review latency. **Plus one distribution probe.**
- **Phase 1 (mid-Jul–Oct 2026):** Prove ONE scalable channel with measured CAC. Target ~150 paid only if channel proof lands.
- **Phase 2 (Nov 2026–Apr 2027):** Scale the proven channel. Target ~1,000–1,200 paid.
- **Phase 3 (May 2027–Apr 2028):** Decide consumer-ceiling vs B2B2C. 5,000 paid is a **B2B2C-gated** target, not a consumer-funnel promise.

**Capital:** Self-funding on contribution margin (not "break-even Month 1" — that claim is dropped per audit #14). One real COGS line added: **commercial Claude API key** (audit #11 accepted — the Max-proxy is a ToS/availability landmine, fixed below).

---

## 2. Market & Positioning

| Dimension | Verified data | Implication |
|---|---|---|
| 英検志願者総数 | 449万人/年 (2024), +15% / 5yrs | Growing TAM, deadline-driven demand |
| 小学生受験者 | 375,991人/年, ~1.5× / 10yrs | Fastest-growing, under-served cohort |
| 中学生 | 3級が高校入試内申に直結 | High urgency = parent willingness to pay |
| 準1級 | 8× / 10yrs | Long upsell ladder per family |
| 競合空白 | スタサプ=中高生講師動画 / mikan=単語帳 / Santa=TOEIC社会人 | 小学生向け英検RPGは競合不在 |

**Positioning (audit #8 accepted — anchor on mikan, not スタサプ):**
*"mikanは単語、A-KENは合格まで。過去問シミュレーション × AIキャラ対話 × 科学的間隔反復(FSRS)を、子どもが毎日遊びたくなるRPGで。"*
The +48% premium over mikan (¥1,000, 9M DL) is justified by **exam-simulation + retention**, and that superiority must be *proven with D7/D30 retention data*, not asserted. スタサプ (¥2,178, Recruit brand + school channel) is a different, higher-trust product; we do not claim parity.

**Beachhead:** 小学4年〜中2 / 英検5〜3級. Parent = payer, child = user.

**Moats (durability order):** (1) FSRS × 英検配点の一体設計 (~1yr+ to replicate); (2) child-engagement retention data (compounds with time); (3) parent-trust brand (COPPA, ad-free, no PII); (4) — if pursued — 塾 contractual lock-in.

---

## 3. Pricing & Packaging Decision

**DECISION: ¥1,480/month · ¥9,800/year · 7-day opt-out trial.**

### Conflict resolution (one number, defended)

| CxO | Proposed | Why I did NOT take it |
|---|---|---|
| CTO | ¥980 | Too close to mikan (¥1,000); signals "vocab commodity," underprices the RPG+AI+exam bundle. |
| Growth / CPO | ¥1,980 | Requires brand trust we have not earned at launch. Correct as a **Phase 3 price test** (grandfather existing), not a launch price. |
| **CFO / Market** | **¥1,480** | **Selected** — 32% under スタサプ for narrative headroom, 48% over mikan to signal depth, survives Japan-conservative conversion. |

### Trial structure (audit-aware)
**Opt-out, 7-day.** The verified 2.7× conversion advantage (48.8% vs 18.2%) is decisive, and the payer is an adult card-holder, not the child, so the COPPA-minor objection is weak. **But audit #4 is accepted:** opt-out trials skew to *monthly* plans, so I model **20% annual mix at launch**, not 40%. Chargeback mitigation: Day-5 "試験まで◯日 / 課金前リマインド" email + frictionless native cancel (no dark patterns = parent trust).

### Packaging — gate by FEATURE DEPTH, not grade (audit #9 accepted, original plan OVERRIDDEN)
*Override rationale: gating 5級 "free forever" hands our fastest-growing 小学生 cohort a free product at exactly their level, with conversion deferred ~1yr past the churn window. We gate depth instead.*
- **Free (all grades incl. 5級):** vocab flashcards + FSRS, 3 AI-dialog turns/day, exam Part 1 (10問/日上限), streaks/badges. (Top-of-funnel engine across every entry grade.)
- **Paid (¥1,480, all grades):** unlimited exam simulation (Part 1–4), unlimited AI dialog, full-grade audio, **full parent dashboard with 学習進捗・弱点分野・継続日数** (the parent hook — see below), all 5,300+ paid-grade words.
- **Annual:** ¥9,800/yr surfaced at checkout (education revenue is 22% annual / 9% monthly; annual collects ~8mo upfront and structurally cuts churn).

### Parent hook — repositioned (audit #6 accepted, original "合格可能性スコア" OVERRIDDEN)
*Override rationale: we have zero 英検 outcome data, so a pass-probability prediction is unbackable and invites refunds/1-star reviews ("said 80%, kid failed").* The paid hook is **学習進捗・弱点分野診断・継続日数レポート** — things we fully control and can show truthfully. A predictive 合格可能性スコア is deferred to Phase 3+ *only after* we have collected real pre/post-exam outcome data to calibrate it.

---

## 4. Unit Economics

Assumptions flagged. **Audit-corrected: two-stage churn, sub-median LTV, 20% annual mix, real COGS line.**

| Metric | Value | Basis / Assumption |
|---|---|---|
| List monthly | ¥1,480 | Decision |
| List annual | ¥9,800 (¥817/mo eff.) | Decision |
| Plan mix (launch) | **80% monthly / 20% annual** | Audit #4 — opt-out skews monthly |
| Gross blended ARPU | ¥1,347/mo | (0.8×1,480)+(0.2×817) |
| Store fee (mobile) | 15% (Small Business <$1M) | Verified |
| Stripe (web) | 3.6% | Verified |
| Rail mix | 85% mobile / 15% web | ASSUMPTION |
| Effective fee | ~13.3% | blended |
| **Net ARPU** | **~¥1,168/mo** | after fees |
| **Commercial Claude API (haiku)** | **~$11–50/mo COGS, capped $50** | Audit #11 — real key, not Max proxy |
| Firebase | ¥0 → Blaze from ~1,000 DAU | Audit #12 — see below |
| Other variable cost/user | ~¥25/mo at scale | TTS pre-generated ($0 runtime) |
| **Gross margin** | **~95–96%** | after real COGS lines |
| **Churn — two-stage (audit #2)** | **First-renewal 30% + steady-state 12%** | Verified: M1 churn 15–40%; ~30% annuals auto-renew-off |
| **LTV (net, cohort-weighted, sub-median)** | **~¥5,500** | Audit #2/#3 — below ¥7,000 category median until 6mo real data |
| **CAC ceiling @ 3:1** | **≤ ¥1,800** | Audit #3 — re-derived on honest LTV |
| **CAC ceiling @ 5:1** | **≤ ¥1,100** | efficiency target |
| Blended install→paid | **2.5–3%** (model at 3% for funnel) | Japan < NA P25 5.5% |

**LTV derivation (cohort-weighted, audit #2):** Of a paying cohort, ~30% churn at first renewal; survivors decay at 12%/mo. Net ARPU ¥1,168 × cohort-weighted expected lifetime ≈ **¥5,500**. I plan on this, not ¥8,783. **Multi-year ladder upside (5級→準1級 across school years) is real but UNMODELED until proven** — it is the thesis that justifies ¥1,480, and §7 gates on confirming it.

**CAC reality check (audit #13 accepted):** Japanese education-keyword UA can run ¥3,000–5,000 fully-loaded per paying customer. With a ¥1,800 ceiling, **paid UA is presumed non-viable until proven otherwise** by the Phase 1 probe. If the probe shows CAC > ¥3,000, the plan is structurally organic + B2B2C only and the 5,000 target is re-derived downward (§5 Phase 3).

---

## 5. Phased Roadmap to Revenue

Owners: **CTO** (build/infra), **CPO** (product/funnel), **Growth** (acquisition), **CFO** (finance), **Market** (positioning/partnerships), **CEO** (decisions/BD). Phases gate on **channel proof**, not product completion (audit #e accepted).

### Phase 0 — Launch Readiness + Distribution Probe · 2026-06-01 → ~2026-07-15 (4–6 weeks)
**Goal:** Ship a payable, audible, deployed app on iOS/Android/Web — AND start one distribution experiment in parallel.

| Action | Owner | Why |
|---|---|---|
| Pre-generate all ~7,900 MP3s (one-time ~$13 batch), serve from VPS nginx, rewire `WordAudioPlayerService` to HTTP-fetch | CTO | Kills audio gap + recurring TTS cost. #1 blocker. |
| **StoreKit 2 (iOS) + Play Billing (Android); Stripe web-only** | CTO | Stripe-for-digital-goods = guaranteed rejection. Critical path. |
| **Migrate commercial inference to a commercial Anthropic API key** | CTO | Audit #11 — Max proxy is ToS + single-point-of-failure. ~$11–50/mo is trivial; eat it. |
| Set ¥1,480/¥9,800 in Stripe + App Store Connect + Play Console + product headers | CFO | Resolve ¥999/¥3,000 conflict before any user sees it. |
| Paywall gate by **feature depth** (Part 2–4, unlimited dialog, dashboard) at all grades | CPO | Audit #9 packaging. |
| Parent dashboard hook = 進捗/弱点/継続日数 (NOT pass-prediction) | CPO | Audit #6. |
| Day-1 + Day-5 parent emails (VPS worker / Firebase Functions) | CPO | Activate payer, cut chargebacks. |
| Production deploy (VPS+nginx) + GitHub Actions + UptimeRobot + Firebase budget alert | CTO | Code is in git, not live. |
| Store listings: JP copy + screenshots, privacy manifest, COPPA/個人情報保護法 labels — **treat kids-category review as serialized risk** | CTO/Market | Audit #7 — Apple review latency is calendar time. |
| **Distribution probe (pick ONE): (a) sign 1 塾 paid pilot, or (b) ¥150–200K paid-UA test w/ tracked CAC, or (c) 英検-influencer collab w/ tracked installs** | CEO/Growth | Audit #13/#e — measure a real channel before betting on it. |
| Beta 50 (family/塾/SNS) → 30+ store reviews | CEO/Growth | ASO ratings velocity. |

**Exit criteria:** Audio plays iOS+Android+Chrome; real payment writes `subscriptions/{uid}`; live on 3 surfaces; ≥30 reviews; **distribution probe instrumented with first CAC/conversion read.** **CUT:** T31 AI assets, T09 Crafting, T10 Guild, T14 a11y, T15 i18n.

### Phase 1 — Prove ONE Channel · ~2026-07-15 → 2026-10-31
**Goal:** Channel proof first; ~150 paid is a *consequence*, not the goal. Gate hard.

| Action | Owner |
|---|---|
| Run the Phase-0 probe channel to a statistically real CAC read (≥¥150K spend or ≥1 signed 塾 cohort) | Growth/CEO |
| ASO keyword cluster (英検 単語/アプリ/5級/4級/3級, 小学生 英語, 英語 RPG) — supporting, not sole, channel | Growth |
| 6月→10月英検 campaign playbook (T-60 ASO → T-30 push → T-14 trial activation) | Growth |
| Instrument 5 activation events; **North Star = D7-retained users**; measure D30 | CPO |
| Measure two-stage churn on first real cohort | CFO |

**Exit GATE (all required to unlock Phase 2 spend):** ONE channel with **CAC ≤ ¥1,800** at install→paid ≥ 2.5%; D7 retention ≥ 35%; first-renewal churn ≤ 30%. **If no channel clears CAC ≤ ¥1,800 → do NOT scale; pivot to B2B2C-primary or hold and iterate product. No proven channel = no Phase 2.**

### Phase 2 — Scale the Proven Channel · 2026-11-01 → 2027-04-30
**Goal:** ~1,000–1,200 paid via the *one* channel that cleared the gate. Do not diversify before proof.

| Action | Owner |
|---|---|
| Pour budget into the single proven channel; add a second only after it clears the same ¥1,800 gate | Growth |
| 1月 & (run-up to) 6月英検 cycles | Growth |
| Annual-plan emphasis + Day-11 reminder; weekly parent report | CPO/CFO |
| **If B2B2C is the proven channel:** build minimum institutional product (admin dashboard, class roster, invoicing) — budgeted, not assumed (audit #5) | CTO/CPO |
| Firebase: model real Firestore ops/user; **budget Blaze from ~1,000 DAU**; aggressively batch/cache FSRS reads, write-at-session-end | CTO |

**Exit criteria:** ≥1,000 paid; steady churn ≤ 12%; first-renewal ≤ 30%; LTV:CAC ≥ 3:1 sustained on the proven channel; **explicit consumer-vs-B2B2C decision made for Phase 3.**

### Phase 3 — Scale Decision · 2027-05-01 → 2028-04-30
**Goal:** 5,000 paid IS B2B2C-gated. State it honestly (audit #1/#5).

| Action | Owner |
|---|---|
| **If B2B2C proven:** close 塾/学校 cohorts (英検準会場 17,000+; ~¥500/生徒 institutional) — the only credible 1,200→5,000 path; build the sales motion + institutional product fully | CEO/Market/CTO |
| **If consumer-only:** re-derive target to what the proven channel delivers (~1,500–2,500 realistic in 18mo); raise/operate on that honest number | CEO/CFO |
| Price test ¥1,980 for new users (grandfather existing) at ~3,000 paid | CFO |
| Post-合格 upsell (3級→準2級→2級) — **validate the multi-year ladder LTV thesis here** | CPO |
| Calibrated 合格可能性スコア *only after* real outcome data collected (audit #6 deferred, not abandoned) | CPO |

**Exit criteria:** 5,000 paid **iff** B2B2C cohort pipeline closes; otherwise honest consumer ceiling with ≥3:1 LTV:CAC. ¥75M ARR is a B2B2C-conditional number, not a consumer promise.

---

## 6. Budget & Allocation

**Recurring external cash-out (at ~5,000 MAU) — honest, with real COGS:**

| Item | Monthly | Note |
|---|---|---|
| Hetzner VPS | ¥0 incr. | Already paid; static + proxy |
| Google TTS | ¥0 | Pre-generated MP3s; one-time ~$13 |
| Firebase | ¥0 → ~¥2,000–5,000 (Blaze) | Audit #12 — Blaze from ~1,000 DAU, NOT 8,300 MAU |
| **Claude API (commercial haiku)** | **~$11–50 (cap $50)** | Audit #11 — real key, real (tiny) COGS |
| Apple/Google fee | 15% of mobile rev | Small Business Program |
| Stripe (web) | 3.6% of web rev | ~15% of revenue |
| UptimeRobot / GitHub Actions | ¥0 | Free tiers |
| **New external cash** | **~¥20K/mo + store % of rev** | Margin ~95–96% |

### Scenario A — Bootstrap (founder time priced honestly, audit #14)
**No "break-even Month 1" claim.** Contribution margin is positive from first paid cohort; founder labor is deferred cost, not free. Path to covering a market-rate founder salary requires ≥~600 paid at net ARPU ¥1,168 (~¥700K/mo gross margin).

| Quarter | Product | Growth/Distribution | Infra | Ops/Legal |
|---|---|---|---|---|
| Q1 (Jul–Sep'26) | 55% | 35% (probe) | 5% | 5% |
| Q2 (Oct–Dec'26) | 35% | 50% | 10% | 5% |
| Q3 (Jan–Mar'27) | 30% | 55% | 10% | 5% |
| Q4 (Apr–Jun'27) | 25% | 60% | 10% | 5% |

Honest trajectory: ~150 (Q1, channel-proof-gated) → ~500 (M9) → ~1,000–1,200 (M12) → 5,000 **only via B2B2C** (~M18–24).

### Scenario B — Funded ¥5M (12-month deployment)

| Quarter | Product | Growth/Distribution | Infra | Ops/Legal | Total |
|---|---|---|---|---|---|
| Q1 | ¥700K | ¥1,000K (incl. paid-UA + 塾 probe) | ¥150K | ¥650K (COPPA/個情法 front-loaded) | ¥2,500K |
| Q2 | ¥400K | ¥800K | ¥150K | ¥150K | ¥1,500K |
| Q3 | ¥300K | ¥400K | ¥100K | ¥100K | ¥900K |
| Q4 | ¥100K | ¥600K | ¥100K | ¥200K | ¥1,000K |

Compresses timeline ~6mo. **Contribution-margin positive ~Month 7** (not "break-even Month 1"). CAC discipline ≤ ¥1,800; paid-UA continues only if probe clears it.

---

## 7. KPIs & Milestones

| Phase (dates) | Paid (end) | MRR net | ARR | install→paid | First-renewal churn | Steady churn | CAC | LTV:CAC |
|---|---|---|---|---|---|---|---|---|
| **P0** (mid-Jul'26) | 0 (beta 50) | ¥0 | — | — | — | — | probe read | — |
| **P1** (Oct'26) | ~150 *(gated)* | ~¥175K | ~¥2.1M | ≥2.5% | ≤30% | — | **≤¥1,800** | ≥3:1 |
| **P2** (Apr'27) | ~1,000–1,200 | ~¥1.3M | ~¥16M | ≥2.5–3% | ≤30% | ≤12% | ≤¥1,800 | ≥3:1 |
| **P3** (Apr'28) | 5,000 *(B2B2C-gated)* | ~¥5.8M | ~¥70M *(B2B2C-conditional)* | n/a (institutional) | — | 8–12% | ≤¥1,800 | ≥3:1 |

**Decision gates (channel-proof, not revenue-only):**
- **Phase 1 gate:** CAC ≤ ¥1,800 on ONE channel → unlock Phase 2 spend. Else pivot/hold.
- **Multi-year ladder gate:** confirm 5級→4級 grade-advance retention before pricing the LTV thesis as durable.
- **~3,000 paid:** A/B price ¥1,980 (grandfather existing).
- **B2B2C gate:** ≥2 signed 塾 cohorts before committing to the 5,000 target.

**North Star throughout: D7-retained users** (leading indicator of the retention superiority that justifies the mikan premium).

---

## 8. Top Risks & Mitigations

| Risk | P | Impact | Mitigation | Owner |
|---|---|---|---|---|
| **Cold-start distribution — no scalable channel** *(audit's #1 kill-reason)* | HIGH | Stalls at a few hundred paid | Phase 1 gates on proving ONE channel with measured CAC before any scale spend; B2B2C as explicit alternative GTM, budgeted not assumed | CEO/Growth |
| **Audio broken at launch** | HIGH | Kills D1 retention, 1-star reviews | Pre-generated MP3 path; test iOS+Android+Chrome before public launch — Phase 0 blocker | CTO |
| **Stripe-on-mobile rejection** | HIGH if unaddressed | 1–3 wk store delay | StoreKit 2 + Play Billing; Stripe web-only; serialize kids-category review | CTO |
| **Claude Max for commercial proxy = ToS/availability landmine** *(audit #11)* | HIGH | Feature + dev env death on ban | **Commercial API key from day one**; $50 hard cap. Tiny COGS beats existential risk — correct capital efficiency | CTO |
| **Churn worse than modeled (two-stage)** *(audit #2)* | MED-HIGH | LTV/CAC breaks | Modeled at 30% first-renewal + 12% steady; annual emphasis, 試験日 countdown, 進捗 hook, AI streak-recovery | CPO/CFO |
| **Paid UA CAC > ¥1,800 in Japan** *(audit #13)* | MED-HIGH | No scalable paid channel | ¥150–200K probe BEFORE betting; if >¥3,000, pivot to organic + B2B2C and re-derive 5,000 | Growth/CFO |
| **B2B2C is a second, unbuilt company** *(audit #5)* | MED | 5,000 target unreachable | Treat 5,000 as B2B2C-gated; budget institutional product (admin/roster/invoicing) before committing; 6–9mo sales cycle planned, not wished | CEO/CTO |
| **Firebase Spark blown at ~1,000 DAU, not 8,300 MAU** *(audit #12)* | MED | Silent cost/outage | Model real FSRS ops/user; batch reads, write-at-session-end, client cache; budget Blaze from 1,000 DAU; ¥10K alert | CTO |
| **Recruit/Google enters 小学生英検** | MED, rising | Existential | Build parent-trust + retention-data moat in the window; lock 塾 partnerships early | CEO/Market |
| **mikan premium not justified by retention** *(audit #8)* | MED | +48% price unsupported | Prove D7/D30 retention superiority empirically; position "単語 vs 合格まで"; reprice if retention parity | Market/CPO |
| **Repositioning loses premium LTV** *(audit #10)* | MED | LTV thesis fails at ¥1,480 | Validate multi-year 5級→準1級 ladder LTV (§7 gate); if ladder weak, revisit ¥1,480 | CFO/CPO |

---

**Bottom line:** One price (¥1,480/¥9,800, opt-out trial), positioned against **mikan** not スタサプ. Gate by feature depth, not grade. Honest two-stage churn → LTV ~¥5,500 → CAC ceiling ¥1,800. Real commercial Claude key as a tiny COGS line, not a Max-proxy landmine. **Phases gate on proven distribution, not product** — Phase 1 must surface ONE channel with measured CAC ≤ ¥1,800 or we pivot. 5,000 paid is explicitly **B2B2C-conditional**; the honest consumer ceiling is ~1,000–2,500 in 18 months. Phase 0 is 4–6 calendar weeks with a distribution probe running in parallel. No "break-even Month 1" theater — contribution-margin positive from first cohort, founder cost named. The three killers — broken audio, store rejection, cold-start distribution — are Phase 0 blockers and a hard Phase 1 gate. Execute Phase 0 in June; first revenue and first real channel read in July.