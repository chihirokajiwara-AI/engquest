# A-KEN Quest — CxO Panel Raw Inputs

## CFO
# A-KEN Quest — CFO Financial Model

---

## 1. Pricing Recommendation

**Recommended price: ¥1,480/month**

| Option | Rationale | Verdict |
|--------|-----------|---------|
| ¥999 | Below mikan Premium (¥1,000). Positions as commodity. Leaves margin too thin after store fees. | Reject |
| ¥1,480 | 32% below スタディサプリ (¥2,178). Clear value anchor. Covers store fees + infra at modest scale. RPG differentiator justifies premium over mikan. | **Select** |
| ¥1,980 | Viable but narrows funnel; requires stronger brand. Revisit at 2,000 paid users. | Stretch goal |
| ¥2,178 | Direct price parity with market leader. Requires equivalent brand trust — not achievable at launch. | Reject for now |
| ¥3,000 | Original CLAUDE.md target. Inconsistent with verified competitive data. Only Santa charges this range, and Santa is TOEIC/AI-first with massive UA budget. | Reject |

**Funnel structure: opt-in free trial, 14 days, then hard paywall**

ASSUMPTION: Opt-in trial chosen over opt-out because COPPA anonymous-auth base skews younger; parents must consciously subscribe. Verified opt-in conversion = 18.2% trial→paid vs opt-out 48.8% — we take the conservative figure.

---

## 2. Conversion Funnel (Verified Benchmarks)

```
App Install
    │
    ▼
Free Trial Start (opt-in, 14-day)     — ASSUMPTION: 35% of installs start trial
    │                                    (education category, Japan conservative)
    ▼
Trial → Paid Conversion               — 18.2% (verified, opt-in benchmark)
    │
    ▼
Month 1 Retention                     — 60–85% (15–40% churn on first renewal)
    │                                    ASSUMPTION: 25% churn M1 (midpoint, Japan)
    ▼
Steady-state Monthly Churn            — ASSUMPTION: 8%/month after M3
                                         (education category, conservative)
```

| Metric | Value | Source |
|--------|-------|--------|
| Install → trial start | 35% | ASSUMPTION (conservative Japan) |
| Trial → paid | 18.2% | Verified (opt-in, RevenueCat 2025) |
| Install → paid (blended) | **6.4%** | 35% × 18.2% |
| M1 churn | 25% | ASSUMPTION (midpoint of 15–40%) |
| Steady-state monthly churn | 8% | ASSUMPTION |
| 12-month LTV (education) | ¥7,000 | Verified ($45 ≈ ¥7,000) |

---

## 3. Unit Economics

### Revenue per subscriber (gross)

| Tier | Price | Store fee | Net/user/month |
|------|-------|-----------|----------------|
| Mobile (iOS/Android) — sub $1M | ¥1,480 | 15% = ¥222 | **¥1,258** |
| Mobile (iOS/Android) — over $1M | ¥1,480 | 30% = ¥444 | ¥1,036 |
| Web/Stripe direct | ¥1,480 | 3.6% = ¥53 | **¥1,427** |

ASSUMPTION: Below $1M ARR for the entire model horizon shown — 15% store fee applies throughout.

**Blended net ARPU: ¥1,290/month**
(ASSUMPTION: 90% mobile, 10% web/Stripe direct)

### Variable cost per user/month

| Cost item | Amount | Basis |
|-----------|--------|-------|
| Claude API (haiku dialog) | ¥0 | Claude Max flat-rate — already paid |
| Firebase Firestore | ¥0 | Spark free tier covers <1,000 DAU; Blaze kicks in ~2,000+ MAU |
| Firebase overage (>2,000 MAU) | ASSUMPTION: ¥15/user/month | ~50 reads/day × 30 days |
| Google TTS | ASSUMPTION: ¥8/user/month | 1M chars/month/user @ $4/1M Neural2 |
| Hetzner VPS backend proxy | ¥0 | Already paid, shared |
| Stripe payment processing | ¥53 (web only, 10% of users) | 3.6% already in ARPU calc |

**Total variable cost/user/month: ¥23** (at scale; negligible pre-500 MAU)

### Gross margin per subscriber

| Scale | Net ARPU | Variable cost | Gross margin | Gross margin % |
|-------|----------|---------------|--------------|----------------|
| <500 MAU | ¥1,290 | ¥8 | ¥1,282 | **99.4%** |
| 500–2,000 MAU | ¥1,290 | ¥23 | ¥1,267 | **98.2%** |
| 2,000–5,000 MAU | ¥1,290 | ¥23 | ¥1,267 | **98.2%** |

Software margin is effectively infrastructure-fixed. The cost curve is near-flat.

### LTV / CAC Ceiling

```
LTV = ARPU_net × (1 / monthly_churn)
    = ¥1,267 × (1 / 0.08)
    = ¥1,267 × 12.5
    = ¥15,838

LTV/CAC = 3 target → CAC ceiling = ¥15,838 / 3 = ¥5,279
LTV/CAC = 5 (efficient) → CAC ceiling = ¥15,838 / 5 = ¥3,168
```

**CFO recommendation: hold CAC ≤ ¥3,000 in bootstrap; ≤ ¥5,000 in funded scenario.**

Note: Verified 12-month education LTV is ¥7,000 (industry average). Our model shows ¥15,838 because churn assumption is 8% steady-state, which implies longer retention than average. ASSUMPTION: A-KEN Quest retains better than average due to exam deadline urgency (英検試験日 = hard forcing function). If churn is actually 12%/month, LTV = ¥10,558, CAC ceiling = ¥3,519. Model holds.

---

## 4. Monthly P&L — Launch to 5,000 Paid Users

### Growth trajectory assumptions

ASSUMPTION: Organic-first (app store, school/塾 word-of-mouth, SNS). No paid UA in bootstrap.

| Quarter | Paid users (end) | New paid/month | Monthly churn |
|---------|-----------------|----------------|---------------|
| Q1 (M1–M3) | 50 → 150 | ~50 | 25% M1, 15% M2-3 |
| Q2 (M4–M6) | 150 → 400 | ~85 | 10% |
| Q3 (M7–M9) | 400 → 900 | ~175 | 8% |
| Q4 (M10–M12) | 900 → 1,800 | ~310 | 8% |
| Q5 (M13–M15) | 1,800 → 3,000 | ~430 | 8% |
| Q6 (M16–M18) | 3,000 → 5,000 | ~700 | 8% |

### Scenario A — Bootstrap (near-zero spend)

Fixed costs: ¥0 incremental (Claude Max + Hetzner VPS already paid). One developer (founder/existing team) = sweat equity.

| Month | Paid Users | MRR (gross) | Store fee | MRR (net) | Infra cost | Net P&L |
|-------|-----------|-------------|-----------|-----------|------------|---------|
| M1 | 50 | ¥74,000 | ¥11,100 | ¥62,900 | ¥0 | **¥62,900** |
| M3 | 150 | ¥222,000 | ¥33,300 | ¥188,700 | ¥0 | **¥188,700** |
| M6 | 400 | ¥592,000 | ¥88,800 | ¥503,200 | ¥5,000 | **¥498,200** |
| M9 | 900 | ¥1,332,000 | ¥199,800 | ¥1,132,200 | ¥15,000 | **¥1,117,200** |
| M12 | 1,800 | ¥2,664,000 | ¥399,600 | ¥2,264,400 | ¥27,000 | **¥2,237,400** |
| M15 | 3,000 | ¥4,440,000 | ¥666,000 | ¥3,774,000 | ¥45,000 | **¥3,729,000** |
| M18 | 5,000 | ¥7,400,000 | ¥1,110,000 | ¥6,290,000 | ¥75,000 | **¥6,215,000** |

**Bootstrap break-even: Month 1** (no incremental fixed costs)
**ARR at 5,000 users: ¥88.8M gross / ¥75.5M net**

Bootstrap constraint: Growth is limited by organic reach. 5,000 users in 18 months is aggressive — requires active distribution (英検塾パートナー, Twitter/TikTok content). ASSUMPTION: founder dedicates 30% time to distribution.

### Scenario B — Funded ¥3M–¥10M

Funded spend unlocks paid UA (Meta/TikTok Japan education ads), 塾・学校 BD, freelance content creation.

**¥5M raise modeled** (midpoint, realistic for pre-revenue EdTech in Japan 2025).

ASSUMPTION: ¥5M deployed over 12 months. Target: 5,000 paid users by M12 (6 months faster than bootstrap).

| Month | Paid Users | MRR (net) | Monthly Spend | Cumulative Cash |
|-------|-----------|-----------|--------------|-----------------|
| M1 | 200 | ¥258,000 | ¥600,000 | ¥4,658,000 |
| M3 | 600 | ¥755,400 | ¥550,000 | ¥3,023,400 |
| M6 | 1,500 | ¥1,890,500 | ¥450,000 | ¥1,313,900 |
| M9 | 3,000 | ¥3,801,000 | ¥300,000 | ¥2,114,700* |
| M12 | 5,000 | ¥6,290,000 | ¥200,000 | ¥10,204,700* |

*Cumulative cash turns positive at M7 (MRR exceeds monthly burn). Cash balance is initial ¥5M + cumulative net P&L.

**Funded break-even (MRR > monthly spend): Month 7**
**Funded runway on ¥5M: ~10 months to self-sustaining MRR**

---

## 5. Quarter-by-Quarter Budget Allocation

### Scenario A — Bootstrap (total available = founder time + ¥0 cash)

| Quarter | Product % | Growth % | Infra % | Ops/Legal % | Notes |
|---------|-----------|----------|---------|-------------|-------|
| Q1 (M1-3) | 60% | 30% | 5% | 5% | Launch T31 (AI assets), fix TTS wiring, App Store live |
| Q2 (M4-6) | 40% | 45% | 10% | 5% | 塾アウトリーチ, SNS content, referral mechanic |
| Q3 (M7-9) | 30% | 55% | 10% | 5% | Firebase Blaze upgrade, content for 準1級 |
| Q4 (M10-12) | 25% | 60% | 10% | 5% | Scale distribution, annual plan launch |

### Scenario B — Funded ¥5M (cash deployment)

| Quarter | Product | Growth | Infra | Ops/Legal | Total | Notes |
|---------|---------|--------|-------|-----------|-------|-------|
| Q1 | ¥800K (32%) | ¥900K (36%) | ¥150K (6%) | ¥650K (26%) | ¥2,500K | T31 AI assets, TikTok UA test, legal (COPPA/個情法) |
| Q2 | ¥400K (27%) | ¥700K (47%) | ¥150K (10%) | ¥250K (17%) | ¥1,500K | 塾BD, Meta ads scale, annual plan A/B |
| Q3 | ¥300K (33%) | ¥400K (44%) | ¥100K (11%) | ¥100K (11%) | ¥900K | MRR > burn; reduce UA, optimize CAC |
| Q4 | ¥100K (10%) | ¥600K (60%) | ¥100K (10%) | ¥200K (20%) | ¥1,000K* | Series A prep, school contract BD |

*Q4 spend increases because MRR is self-funding growth investment by this point.

**Budget allocation rationale:**
- Product heavy in Q1: T31 (AI character generation) is the last unchecked task; TTS audio wiring is confirmed broken; these are conversion-rate risks.
- Legal front-loaded: COPPA anonymous auth + 個人情報保護法 for minor users. Japan App Store review requires privacy policy + parental consent flow. One legal review at launch is cheaper than a reject/ban.
- Growth accelerates Q2 onward once product is stable and CAC is measured.
- Infra stays flat — Hetzner + Firebase Blaze is sufficient to 5,000 users; no new infrastructure needed.

---

## 6. Key Milestones & Decision Gates

| MRR | Paid Users | Action |
|-----|-----------|--------|
| ¥500K | ~400 | Confirm CAC < ¥3,000. If yes: scale UA. If no: fix product first. |
| ¥2M | ~1,550 | Launch annual plan (¥12,800/year = 28% discount). Annual plans cut churn structurally. |
| ¥4M | ~3,100 | Raise price to ¥1,980 for new users (grandfather existing). A/B test. |
| ¥6.3M | ~5,000 | Series A signal: ¥75M ARR run-rate, <8% monthly churn. |

---

## 7. Immediate CFO Priorities (Pre-Launch)

1. **Fix the ¥999 vs ¥3,000 price inconsistency** — set ¥1,480 in all product headers, Stripe config, and App Store Connect before first user sees it.
2. **Wire Google TTS** — audio is a confirmed gap; broken audio = immediate 1-star reviews = kills conversion.
3. **Confirm Firebase Blaze budget cap** — set a hard ¥10,000/month spending alert in Firebase console before launch. Runaway Firestore reads at scale can erode the near-100% gross margin fast.
4. **Annual plan at launch or Month 2** — verified data shows annual plans reduce churn by ~70% vs monthly. At ¥12,800/year, you collect ~8.7 months upfront, dramatically improving cash position.
5. **Do not build T31 (AI character generation) before fixing TTS and pricing** — content gaps kill retention; broken core mechanics kill conversion first.

---

## Growth
# A-KEN Quest — GTM & Path to 5,000 Paid

## 0. Price Decision: Resolve the Conflict First

| Signal | Implication |
|--------|-------------|
| ¥999/month (product header) | Accessible; competes with mikan Premium |
| ¥3,000/month (CLAUDE.md) | Matches スタディサプリ tier; needs stronger ROI story |
| Competitor anchor: スタディサプリ ¥2,178 | Middle ground is validated |
| Target parent: ¥3,000/month stated willingness | Plausible for 英検合格 outcome |

**Recommendation: ¥1,980/month or ¥14,800/year**

Rationale:
- Sits below スタディサプリ (¥2,178) → price leadership narrative
- Year plan = ¥1,233/month effective → converts price-sensitive parents who plan for one exam cycle (6 months)
- ¥14,800/year × 5,000 = ¥74M ARR before churn; monthly mix will drag this, model accordingly
- ASSUMPTION: Japanese education app paid conversion 2–3% (below North America P25; conservative)

---

## 1. Unit Economics Model

| Metric | Value | Source / Basis |
|--------|-------|----------------|
| Target paid users | 5,000 | Given |
| Price | ¥1,980/mo or ¥14,800/yr | Recommended above |
| Blended ARPU/month | ASSUMPTION: ¥1,500 (60% annual plan mix) | Conservative |
| 12-mo LTV | ASSUMPTION: ¥9,000 (6mo avg retention monthly; annual ≈ full year) | Adapty edu ≈$45; JP premium higher for exam-outcome product |
| App Store take | 15% (Small Business Program, <$1M) | Apple/Google confirmed |
| Net ARPU after store | ¥1,275/mo blended | — |
| Net LTV | ¥7,650 | — |
| Break-even CAC | < ¥7,650 | — |
| CAC target | ≤ ¥2,000 (to hit 3:1 LTV:CAC) | — |
| Installs needed @ 2.5% conversion | 200,000 | 5,000 ÷ 0.025 |
| Installs needed @ 3.5% conversion | 143,000 | With opt-out trial |

**Key lever: Opt-out free trial lifts conversion 2.7× (48.8% vs 18.2%). Use opt-out. Always.**

---

## 2. Trial Structure

**Structure: 14-day opt-out free trial → ¥1,980/month or ¥14,800/year**

| Element | Decision | Reason |
|---------|----------|--------|
| Trial length | 14 days | Covers one full study week + weekend review; long enough to feel FSRS habit forming |
| Opt-in vs opt-out | Opt-out (card required at signup) | 48.8% conversion vs 18.2% — 2.7× difference |
| Trial gate | After onboarding complete (grade selected, first battle done) | Activate before asking for payment |
| Paywall trigger | Day 0: grade 3級+ locks; 5級/4級 free forever | Free tier creates installs; paid tier has clear upgrade path |
| Cancellation | Apple/Google native; no dark patterns | Trust signal for parents; COPPA context |
| Email reminder | Day 11 (3 days before charge): "試験まで◯日" | ASSUMPTION: reduces churn vs no reminder |

**Free Tier (永久無料):** 英検5級 + 4級 full access. This is the top-of-funnel engine. 英検5級 target is 小学生 375,991 — largest growth segment.

---

## 3. Channel Evaluation

| Channel | Realistic JP CAC | Time to Volume | Scalability | Verdict |
|---------|-----------------|----------------|-------------|---------|
| **ASO (App Store / Play Store JP)** | ¥0–500 (organic) | 3–6 months | High | **DOMINATE FIRST** |
| **英検試験日キャンペーン** | ¥200–800 | Immediate (3 exam dates/year) | Medium | **DOMINATE FIRST** |
| 保護者向けSNS (Instagram/X) | ¥1,500–4,000 | 1–3 months | Medium | Phase 2 |
| 塾・学校 B2B2C | ¥0–500/user (bulk) | 6–12 months | Very High | Phase 3 |
| 教育系YouTube/インフルエンサー | ¥500–2,000 | 1–2 months | Medium | Phase 2 |
| LINE公式アカウント | ¥300–1,000 | 2–4 months | High | Phase 2 |
| PR (教育メディア) | ¥0 (earned) | Unpredictable | Low | Ongoing |

**Lead channels: ASO + 試験日キャンペーン. Zero external ad spend required in Phase 1.**

---

## 4. Channel Playbook (Detail)

### Channel 1: ASO — App Store JP / Google Play JP

**Why first:** Zero CAC, compounds over time, leverages already-built mobile app.

Execution:
- Title: `英検対策RPG A-KEN Quest — 単語・過去問・AI会話`
- Subtitle/Short description: `5級〜準1級 FSRS間隔反復 + AIキャラ対話`
- Keywords to own: 英検 単語, 英検 アプリ, 英検 対策, 英検5級, 英検4級, 英検3級, 英語 RPG, 小学生 英語, 英語 ゲーム 英検
- Screenshots: RPG battle UI → grade selector → FSRS streak calendar → exam score prediction
- Ratings velocity: seed with 50 reviews in first 2 weeks (beta users, family, team)
- Update cadence: monthly (試験前月にコンテンツ追加) — signals active app to stores

ASSUMPTION: ASO alone delivers 500–1,500 organic installs/month at steady state (12+ months in). Early months: 100–300.

### Channel 2: 英検試験日カレンダー連動キャンペーン

**Why dominant:** 英検 has 3 primary exam windows (June, October, January). Each creates a predictable demand spike. 449万人/年志願者 = 1.5M per window. This is the highest-intent cohort in Japan for this product.

英検 2026 Primary Dates (approximate; verify against 英検協会):
- 一次試験: 2026年6月, 10月, 2027年1月

Campaign structure per exam window:

| Timing | Action | Cost |
|--------|--------|------|
| T-60 days | ASO keyword boost; update screenshots with "◯月試験対策" | ¥0 |
| T-45 days | PR pitch to 教育新聞, ReseMom, マイナビ学習 | ¥0 |
| T-30 days | In-app "試験まで30日チャレンジ" push notification to free users | ¥0 (Firebase) |
| T-14 days | Trial activation push: "14日無料で過去問モード解放" | ¥0 |
| T-7 days | LINE/SNS organic post: "直前対策チェックリスト" | ¥0 |
| Exam week | In-app encouragement; post-exam "次の試験に向けて" drip | ¥0 |

This entire campaign runs on existing paid infrastructure (Firebase, VPS, Claude Max). External spend = ¥0.

### Channel 3 (Phase 2): 保護者向けInstagram/X

Target: 小中学生の保護者, particularly mothers in 30-40s who manage 習い事 decisions.

- Content: 子どもの英検合格体験談 (UGC first; then produced)
- Format: before/after progress screenshots, FSRS streak visualizations
- ASSUMPTION: ¥1,500–3,000 CAC with modest ¥50,000–100,000/month spend
- Do not start until ASO + trial funnel is proven (conversion rate > 2%)

### Channel 4 (Phase 3): 塾・学校 B2B2C

**The 5,000-user unlock:** Individual CAC is manageable but slow. B2B2C can deliver cohorts.

Model:
- 塾向け: ¥500/生徒/月 (institutional rate, no trial friction) or free access for 塾 teachers + paid for students
- School pilot: free for 1 class → proof of results → expand
- Target: 学習塾 (全国54,000教室) — focus on 英検対策塾 (英検準会場: 17,000+ 準会場)
- 英検準会場 = 塾・学校が英検を自校で実施できる資格; operators are highly aligned with our product

ASSUMPTION: 10 塾 partnerships × 30 students avg = 300 users; 50 partnerships = 1,500 users. Pipeline takes 6–9 months to close.

---

## 5. Activation Funnel

```
Install
  → Onboarding (grade selector + avatar) ← target: 80% completion
    → First battle (5級 free) ← target: 70% same-session
      → FSRS streak day 2 ← target: 40% D1 retention
        → Trial start (14-day opt-out) ← target: 30% of installs
          → Day 7 engagement (3+ sessions) ← target: 60% of trials
            → Trial conversion (paid) ← target: 50% of trials = 15% of installs
              → 30-day retention ← target: 65%
                → 6-month retention ← ASSUMPTION: 45% (exam cycle loyalty)
```

**North Star Metric: D7 retained users** (strongest predictor of trial conversion in education apps)

Key activation actions to instrument (Firebase Analytics, already wired):
1. `onboarding_complete` — grade + avatar set
2. `first_battle_won` — FSRS card reviewed
3. `streak_day_2` — returned next day
4. `trial_started` — payment method added
5. `exam_mode_accessed` — engaged with premium content

**Activation fix required before launch:** Verify Google TTS audio playback path. CLAUDE.md notes "未配線の疑い." Audio is core to the English learning loop; broken audio = broken retention. This is a launch blocker.

---

## 6. Phase-by-Phase Growth Playbook

### Phase 0 — Launch Prep (Month 0, current)

| Action | Owner | Blocker? |
|--------|-------|----------|
| Fix Google TTS audio playback | Dev | YES — retention blocker |
| Confirm price at ¥1,980/month + ¥14,800/year | CEO | YES — Stripe config depends on this |
| App Store / Play Store submission | Dev | Need screenshots, privacy policy |
| ASO keyword research + metadata | Growth | — |
| Set up Firebase Analytics event tracking (5 events above) | Dev | — |
| Beta: 50 users (family, Twitter followers, 塾 contacts) | CEO | — |
| Collect 30+ App Store reviews from beta | Growth | — |

### Phase 1 — Traction (Month 1–3)

Target: 2,000 installs, 60 paid users

| Month | Install Target | Paid Target | Key Action |
|-------|---------------|-------------|------------|
| 1 | 400 | 12 | App Store live; ASO baseline |
| 2 | 700 | 25 | 6月英検キャンペーン launch (T-30 to T-0) |
| 3 | 900 | 23 | Post-exam "次の試験" drip; iterate onboarding |

Channel: ASO only. Zero paid acquisition.
Conversion assumption: 3% of installs (opt-out trial, good activation).

Revenue Month 3: ~60 paid × ¥1,500 blended ARPU = ¥90,000 MRR

### Phase 2 — Growth (Month 4–9)

Target: 20,000 cumulative installs, 600 paid users

| Month | Install Target | Paid Target (cumulative) | Key Action |
|-------|---------------|--------------------------|------------|
| 4 | 1,500 | 100 | Instagram organic; 教育YouTube 1 collaboration |
| 5 | 2,500 | 175 | 10月英検キャンペーン (T-60 prep) |
| 6 | 3,000 | 265 | 10月英検 T-0; PR pitch 教育メディア |
| 7 | 2,000 | 340 | Retention drip; referral feature (保護者シェア) |
| 8 | 2,500 | 430 | LINE公式アカウント launch |
| 9 | 3,500 | 600 | 1月英検キャンペーン prep; first 塾 pilots |

Revenue Month 9: ~600 × ¥1,500 = ¥900,000 MRR

Spend budget: ASSUMPTION ¥100,000–200,000/month max (influencer fees, LINE ads if needed). Mostly earned/organic.

### Phase 3 — Scale (Month 10–18)

Target: 5,000 paid users

| Month | Install Target | Paid Target (cumulative) | Key Action |
|-------|---------------|--------------------------|------------|
| 10 | 4,000 | 850 | 1月英検 peak; 塾 B2B2C pipeline active |
| 11 | 3,000 | 1,050 | Post-exam upsell to next grade level |
| 12 | 3,500 | 1,300 | Year 1 annual renewal cohort (churn mgmt) |
| 13–15 | 4,000/mo | 2,200 | 6月英検cycle 2; 塾 partnerships closing |
| 16–18 | 5,000/mo | 5,000 | 10月英検cycle 2; B2B2C cohorts closing |

Revenue at 5,000 paid: ¥7,500,000 MRR (¥90M ARR)

Critical assumption: 45% 6-month retention holds. If retention < 35%, add AI-driven streak recovery (Claude haiku, already paid) and in-app 試験日countdown personalization.

---

## 7. Top 3 Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Audio playback broken at launch | HIGH (CLAUDE.md flags it) | HIGH — kills D1 retention | Fix before any public launch; test on iOS + Android + Chrome |
| Firebase free tier exceeded early | MEDIUM (5万read/日) | MEDIUM — sudden cost spike | Instrument Firestore reads now; add client-side FSRS cache (cards already local) |
| スタディサプリ responds with price cut | LOW | MEDIUM | Differentiation: RPG engagement + FSRS vs. passive video; not direct substitute |

---

## 8. The 1-2 Channels to Dominate

**1. ASO (App Store JP / Google Play JP)**
Zero CAC, compounding, leverages existing mobile build. Own the keyword cluster around 英検 + RPG + 小学生英語. This is the base layer everything else sits on.

**2. 英検試験日キャンペーン (3× per year)**
Highest-intent cohort, zero marginal cost, predictable timing. Build a playbook for each exam window and execute it mechanically. Each exam cycle = a mini-launch with natural PR hooks ("英検まで◯日" is a news peg 教育メディア will run).

These two channels alone, executed with discipline, can deliver Phase 1 and Phase 2 targets. Add influencers and LINE in Phase 2 only after conversion funnel is proven. Add B2B2C in Phase 3 for the jump from 1,000 to 5,000.

---

## CPO
# A-KEN Quest — CPO Product Strategy

## 1. Price Point Decision

The ¥999 vs ¥3,000 discrepancy must be resolved before launch. Here is the analysis:

| Option | Rationale | Risk |
|---|---|---|
| ¥999/月 | Competes with mikan Premium; low barrier; needs volume | mikan is feature-inferior; we undercharge |
| ¥1,980/月 | Below スタサプ (¥2,178); "AI + RPG" justifies premium | Middle position, easy to explain |
| ¥2,980/月 | Near スタサプ; "合格保証" positioning; annual = ¥28,000 | Requires strong social proof at launch |
| ¥3,000/月 | Original target; round number but odd vs market | Marginally worse than ¥2,980 psychologically |

**Decision: ¥1,980/月 (月次) / ¥16,800/年 (年次 = 29%割引)**

Rationale: スタサプより¥198安い → "AIで合格まで伴走、でも安い"が売り文句になる。年次は教育カテゴリで売上52%が週次・22%が年次 (月次9%) なので年次誘導が必須。年次プランはStripe課金でLTV直接最大化。

---

## 2. Freemium Boundary (What Is Free vs Gated)

**Core principle**: 子どもが毎日触る機能は無料。合格に直結する機能と英検全グレードはPaid。親が見る成績可視化はPaid（購買決定フック）。

| Feature | Free (全員) | Paid (¥1,980/月) |
|---|---|---|
| 英検グレード | 5級のみ (600語) | 4級〜準1級 (5,300語) |
| FSRS毎日復習 | 5級カードのみ | 全グレード |
| 試験対策モード (Part 1-4) | Part 1 のみ (10問/日上限) | 全Part, 無制限 |
| Claude AI ダイアログ | 3ターン/日 | 無制限 |
| 合格可能性スコア | 非表示 | 可視化 (親Dashboardに表示) |
| 親ダッシュボード | 今日の学習時間のみ | 合格スコア・弱点分析・学習カレンダー全部 |
| ストリーク・バッジ | 全開放 | — |
| 音声 (Google TTS) | 5級bundled MP3 | 全グレードTTS (APIキー経由) |

**Paywall配置**: グレード選択画面で4級以上をタップした瞬間 → Paywall。"今日5級を3問やる" → 合格可能性スコアが親Dashboardに出ない → 親への通知メール "お子さんの合格確率を確認しませんか" → Purchase。

---

## 3. Onboarding — Dual User Flow (Child Uses, Parent Pays)

現状: 匿名Auth (COPPA準拠) + 親ダッシュボードあり。これを購買フローに直結させる。

```
[子どもの端末]                    [親の端末/メール]
    │                                    │
START: 年齢選択 → グレード自動提案         │
    │                                    │
学習 Day 1-3 (5級無料体験)               │
    │                                    │
Day 1 夜 → 親メール自動送信:             │
"今日○○ちゃんは英単語15個覚えました"     ←──┤
                                         │  (親がリンクをクリック)
                                    親Dashboard (無料プレビュー)
                                    "合格可能性スコアは有料プランで"
                                         │
                                    Stripe Checkout (親がPay)
                                         │
[子どもの端末]                           │
全グレード解放 ←──────────────────────────┘
```

**実装で必要なもの (現状のGapから)**:
1. 親メールアドレス登録 (T04は実装済) → Day1完了後の自動メール送信 (Firebase Functions + SendGrid or Resend, ASSUMPTION: 月$0〜$20範囲)
2. 親Dashboard「合格可能性スコア」のPaid gate (現状dashboardはある、gateが未実装)
3. Stripe Checkoutから子どものFirestoreドキュメントへのpremium_until書き込み (T30実装済のプロキシを活用)

---

## 4. Retention Loops

### 毎日の引力 (Daily Pull)

| Loop | 仕組み | KPI |
|---|---|---|
| FSRSデイリーレビュー | 「今日の復習: 12枚」カード数を起動画面に表示。やらないと "借金" が積み上がる視覚化 | D7 retention |
| ストリーク | 連続学習日数 + 7日/30日バッジ。1日でもやれば維持 (超低ハードル) | D30 retention |
| 合格可能性スコア | 毎日上下する% → 子どもが親に見せたがる → 親が継続課金を正当化 | 解約率 |
| 英検試験日カウントダウン | 次回英検試験日まで○日。毎朝プッシュ通知 (Web: バナー, Mobile: native) | WAU |

### 合格可能性スコアの設計 (最重要・差別化)

FSRS既存データから算出可能。計算式 (ASSUMPTION: 要チューニング):

```
合格可能性(%) = 
  グレード別語彙習得率 × 0.4
  + 試験Part別正答率 × 0.4  
  + 学習継続率(直近14日) × 0.2
```

表示: 親Dashboardのヒーローメトリクスとして大きく。"英検3級 合格可能性 **67%**" → 来月の試験まで毎日続けると **82%** になります。

これが解約抑止の最強フック。親が "もう少しで受かりそう" と感じる間は課金継続。

---

## 5. Ruthless Prioritization

### MVP Launch (今すぐ、1-2週間)

これがないとローンチ不可:

| Task | Why Critical | Effort |
|---|---|---|
| Google TTS 音声配線修正 (疑い) | 音が出ないアプリは子どもが離脱する | S (1日) |
| Paywall実装 (グレードgate) | 課金できなければ売上ゼロ | S (1日) |
| 親メール Day1自動送信 | 親への購買フック。無ければ転換率ゼロ | M (2日) |
| 合格可能性スコア (Paid gate付き) | 親Dashboardの購買決定フック | M (2日) |
| 本番デプロイ (VPS+nginx) | gitには入っているが未デプロイ | S (半日) |
| App Store / Play Store提出 | T03は実装済だが提出が必要 | M (審査待ち含め1週間) |

### P1 (ローンチ後30日、転換率改善)

| Task | Revenue/Retention KPI |
|---|---|
| opt-out 無料トライアル 7日 | 転換率 2.6%→推定5-8%。Stripeトライアル機能で実装 |
| 年次プラン ¥16,800 の強調 | LTV最大化。月次の初回表示より年次を先に |
| 英検試験日カウントダウン通知 | WAU維持 |
| 親向けWeeklyメールレポート | 解約抑止 (親が "投資している" を実感) |

### P2 (60-90日、リテンション強化)

| Task | 理由 |
|---|---|
| 弱点分析レポート (親Dashboard) | 解約率低下。"何が足りないか" が見えると継続 |
| グレード間の連続性強化 (3級→準2級の橋渡し) | アップグレード時の離脱防止 |
| 合格後フロー ("3級合格おめでとう" → 2級へ) | LTV延長 |

### CUT (今は作らない)

| 削除対象 | 理由 |
|---|---|
| T09 Crafting module (grammar) | MVP範囲外、FSRS+試験対策で十分 |
| T10 Guild module (discourse) | COPPA環境でUGC管理が重い、ROI低 |
| T31 AI character generation | 外部コスト高、ゲームアートはストックで代替 |
| T13 Performance profiling | ローンチ前に最適化は時期尚早 |
| T14 Accessibility | スコープ拡大リスク大、v2 |
| T15 Localization framework | 日本市場のみで5,000ユーザー達成可能 |

---

## 6. Revenue Model to 5,000 Paid Users

**Conversion funnel (保守的、日本市場)**

| ステージ | 数値 | ASSUMPTION注記 |
|---|---|---|
| 月間DL | 10,000 | ASSUMPTION: App Store最適化後 |
| Free→Paid転換率 | 4% (opt-outトライアル込み) | 業界中央2.6%、トライアルで上振れ |
| 月次新規有料ユーザー | 400 |  |
| 月次解約率 | 12% (月次プラン主体) | 業界15-40%の下限、合格スコアで抑制想定 |
| 定常有料ユーザー数 | ~3,300 | 400÷0.12 |
| **5,000達成月** | **Month 13-15** | DL増加・紹介込み |

**月次売上 (5,000ユーザー時)**

| 項目 | 計算 | 金額 |
|---|---|---|
| 月次プラン (60%) | 3,000ユーザー × ¥1,980 | ¥5,940,000 |
| 年次プラン (40%) | 2,000ユーザー × ¥16,800÷12 | ¥2,800,000 |
| Gross Revenue | | ¥8,740,000 |
| Apple/Google手数料 (15%) | ¥8,740,000 × 15% | -¥1,311,000 |
| **Net Revenue** | | **¥7,429,000/月** |

**変動コスト (5,000ユーザー時)**

| 項目 | 月次コスト | 備考 |
|---|---|---|
| Claude API (haiku) | ~¥15,000 | 5,000ユーザー×30日×10ターン×$0.0001 = ~$150 |
| Firebase (Firestore) | ~¥5,000 | 無料枠超過分。ASSUMPTION |
| Google TTS | ~¥8,000 | 5,000ユーザー×新規音声リクエスト分。ASSUMPTION |
| Hetzner VPS | ¥0増分 | 既支払済 |
| Stripe手数料 | ~¥50,000 | Web直販分 (3.6%) |
| **合計変動費** | **~¥78,000** | Gross Marginは99%超 |

---

## 7. 今週の最優先アクション (順番通りに実行)

1. **TTS音声配線を確認・修正** — 音が出るかどうかをまず検証 (`/Users/openclaw/dev/engquest-flutter/lib/core/audio/` を確認)
2. **本番デプロイ** — VPS+nginx。gitに入っているコードを即公開
3. **Paywallを実装** — グレード選択で4級以上をtap→Stripe Checkout
4. **合格可能性スコア計算ロジック** — FSRSデータから算出、親Dashboardに表示
5. **Day1親メール** — Firebase FunctionsかVPS上のworker (既存プロキシサーバーを流用)
6. **App Store/Play Store提出** (審査1週間を逆算して今週出す)

---

**Bottom line**: 音声が出る・グレードgateがある・親が合格スコアを見てカードを出す。この3点が揃えば¥1,980/月のプロダクトとして成立する。それ以外は全部後回し。

---

## CTO
# A-KEN Quest — CTO Launch & Scale Brief

## 0. Mandate Restatements (Constraints First)

| Constraint | Binding Rule |
|---|---|
| External metered spend | Minimize to near-zero at 5,000 MAU |
| Google TTS | Pre-generate MP3s only; zero runtime TTS calls |
| Claude API tokens | Route via backend proxy; haiku only; cap per-user |
| Firebase | Stay on Spark free tier as long as possible |
| Paid assets | Hetzner VPS + Claude Max flat-rate are already-paid |
| Store readiness | iOS + Android must pass review before launch |

---

## 1. Audio / TTS: Near-Zero-Cost Design

**Current state:** Google TTS wired to an API key, real-time call path suspected broken; 300 MP3s bundled for A1 vocab.

**Target architecture:** Pre-generate all vocab MP3s offline (one-time batch), bundle or serve statically. Zero runtime TTS calls at any user count.

### Word counts and storage estimate

| Grade | Words | MP3 @ ~15 KB avg | Total |
|---|---|---|---|
| 5級 | 600 | ~9 MB | — |
| 4級 | 700 | ~10.5 MB | — |
| 3級 | 1,300 | ~19.5 MB | — |
| 準2級 | 1,500 | ~22.5 MB | — |
| 2級 | 800 | ~12 MB | — |
| 準1級 | 3,000 | ~45 MB | — |
| **Total** | **7,900** | — | **~119 MB** |

ASSUMPTION: average TTS MP3 per word = 15 KB (single word + short example sentence, 128 kbps MP3). Conservative.

119 MB static files → serve from Hetzner VPS nginx, already paid, zero marginal cost. Do NOT bundle in Flutter app (would bloat install size). Lazy-load per grade on first unlock.

### Implementation plan

1. Write a one-time batch script (Python + `google-cloud-texttospeech`, Neural2-C, `en-US-Neural2-C`) against all 7,900 vocab JSON entries.
2. Output to `assets/audio/{grade}/{word_id}.mp3` on VPS.
3. Flutter client fetches from `https://178.105.113.79/audio/{grade}/{word_id}.mp3` with a local in-memory cache (no `path_provider` needed).
4. Remove all runtime `TtsService` API key calls. `WordAudioPlayerService` becomes a simple HTTP fetch + `audioplayers` play.
5. One-time Google TTS batch cost estimate: 7,900 words × ~100 chars avg = ~790,000 chars. Neural2 pricing = $16/1M chars → **~$12.64 one-time**. Acceptable. Run once on dev machine using Claude Max-funded dev time.

**Result: recurring TTS cost = $0/month forever.**

---

## 2. Firebase Free Tier — User Count Limits

Spark plan limits (2025):

| Resource | Spark Limit | Per-DAU estimate (ASSUMPTION) | Free ceiling |
|---|---|---|---|
| Firestore reads/day | 50,000 | ~20 reads/session (FSRS fetch + progress) | ~2,500 DAU |
| Firestore writes/day | 20,000 | ~8 writes/session (card reviews, XP) | ~2,500 DAU |
| Auth verifications | Unlimited (anonymous) | — | — |
| Hosting bandwidth | 360 MB/day | Flutter web ~2 MB first load | ~180 cold loads/day |
| Storage | 1 GB | Not used (audio on VPS) | — |
| Functions invocations | 125,000/month | Not used (proxy on VPS) | — |

ASSUMPTION: DAU/MAU ratio = 30% (education apps, conservative per Adapty benchmarks).

At 5,000 MAU → ~1,500 DAU. **Well within Spark limits at target user count.** Firestore ceiling is ~2,500 DAU before hitting read limits; that is ~8,300 MAU. Upgrade to Blaze pay-as-you-go only when MAU > 8,000. Blaze cost at 10,000 MAU / 1,500 DAU: ~¥1,500/month.

### Mitigation to stretch free tier further

- Batch FSRS card fetches (one read returns all due cards for session, not per-card reads).
- Client-side cache session data in SharedPreferences; only write to Firestore at session end.
- Anonymous auth is already implemented (zero auth cost).

---

## 3. Backend Proxy — Key Security & Claude Cost Cap

Already implemented per T32. Verify these are in place before launch:

| Control | Must-ship | Notes |
|---|---|---|
| Claude API key never in client | YES | Proxy on VPS validates requests |
| Per-user turn rate limit | YES | Max 20 turns/day per anonymous UID |
| Stripe secret key server-only | YES | Never in Flutter build |
| CORS whitelist | YES | Only allow your domains + app bundle ID |
| Request auth | YES | Firebase anonymous UID passed in header; proxy verifies via Firebase Admin SDK |
| Cost cap | YES | Set Anthropic account hard limit ($50/month) as emergency brake |

Claude haiku cost at 5,000 MAU with 20 turns/day cap and 30% DAU: 1,500 DAU × 20 turns × $0.0001 = **$3/day = ~$90/month** worst case (all users maxing dialog). Realistic (50% dialog engagement, 5 turns avg): **~$11/month**. Both under Claude Max flat-rate if routed through the Max account's API. Confirm with Anthropic that Max plan allows API proxying for a commercial app — if not, this is a $11-90/month line item on pay-as-you-go haiku pricing.

---

## 4. Price Strategy — Resolve the ¥999 vs ¥3,000 Contradiction

The CLAUDE.md has two prices. This must be decided before App Store submission (price tier is baked into store metadata).

### Market context (verified data)

| Competitor | Price | Scope |
|---|---|---|
| スタディサプリ英語 | ¥2,178/month | Lecture video + exercises, 3級〜2級 |
| mikan Premium | ¥1,000/month | Vocab cards only |
| Santa | ¥4,900+/week | TOEIC AI, high-end |

### Recommendation

**Launch at ¥980/month (Apple Tier 6 = ¥980 post-tax) with a 7-day opt-in free trial.**

Rationale:
- Undercuts スタディサプリ (¥2,178) by 55% — easier first-mover acquisition
- Premium above mikan (vocab-only) — justified by full RPG + AI dialog + full exam simulation
- Opt-in free trial: lower conversion (18% vs 48% for opt-out) but healthier retention; avoids refund chargebacks at launch scale
- Upgrade path to ¥1,980 "family plan" (2 children) once 1,000 paid users reached

ASSUMPTION: Japanese conversion rate 1.5% (conservative vs NA 5.5% upper quartile per Adapty; Japan historically lower).

At 1.5% conversion, 5,000 paid users requires **333,000 installs** — aggressive. More realistic target: 2,000 paid users from 50,000 installs at 4% conversion among trial starters. Validate assumption with first 500 installs.

---

## 5. iOS/Android Store Readiness Checklist

### Must-ship before submission

| Item | Status (inferred) | Action |
|---|---|---|
| iOS Firebase packages compatible | Resolved (T01) | Verify `flutter analyze` clean on iOS |
| COPPA compliance | Anonymous auth, no PII | Add privacy nutrition label: no data collected |
| App Store privacy manifest | Required since iOS 17 | Add `PrivacyInfo.xcprivacy`; declare no tracking |
| Age rating | 4+ (educational) | Set in App Store Connect |
| Screenshots (6.7", 5.5", iPad 12.9") | Not done | Generate 3 sizes × 3 screens minimum |
| App description (Japanese) | Not done | Write 4,000-char JP description |
| Google Play target SDK | API 34+ required 2025 | Confirm `compileSdkVersion 34` in `android/app/build.gradle` |
| Play Store content rating | Education / Everyone | Complete IARC questionnaire |
| Stripe StoreKit compliance | CRITICAL | In-app purchases via Stripe are **prohibited** on iOS. Use Apple IAP (StoreKit 2) for iOS, Google Play Billing for Android. Stripe is web-only. |

The Stripe-on-mobile issue is critical. Apple and Google reject apps using external payment for digital content. Resolution:

- **Web app**: keep Stripe (already works on `178.105.113.79`)
- **iOS**: implement StoreKit 2 (`in_app_purchase` Flutter package); Apple takes 15% (Small Business Program, <$1M revenue)
- **Android**: implement Google Play Billing; Google takes 15%
- **Backend proxy**: unify entitlement check — after any payment (Stripe/StoreKit/PlayBilling), write a `subscriptions/{uid}` Firestore document that the app reads

### Store submission timeline (ASSUMPTION: 2 weeks dev + review)

| Week | Work |
|---|---|
| W1 | StoreKit 2 + Play Billing integration; remove Stripe from mobile payment path |
| W2 | Privacy manifest, screenshots, store listings, TestFlight beta |
| W3 | App Store review (1-3 day typical); Play Store review (1-7 day) |

---

## 6. Deploy Pipeline (Hetzner VPS, Already Paid)

Current: nginx on `178.105.113.79`, manual rsync. Need a repeatable pipeline.

### Minimal CI/CD (no new paid tools)

```
GitHub Actions (free for public / 2,000 min/month private)
  └── on push to main:
        1. flutter build web --release --web-renderer canvaskit
        2. rsync build/web/ → VPS /srv/engquest-web/
        3. ssh "nginx -t && systemctl reload nginx"
        4. Health check: curl https://178.105.113.79 → assert 200
```

Backend proxy (Node/Express or Python FastAPI) runs as a systemd service on the same VPS. No Docker needed (reduces RAM).

| Service | RAM target |
|---|---|
| nginx | ~10 MB |
| Backend proxy (Node) | ~60 MB |
| Firebase Admin SDK (in proxy) | included above |
| **Total VPS footprint** | **~70 MB** |

Hetzner CX11 (2 GB RAM, already paid) is more than sufficient for 5,000 MAU given that Flutter web is static files served by nginx.

---

## 7. Reliability & Monitoring (Zero Additional Cost)

| Concern | Solution | Cost |
|---|---|---|
| VPS uptime | UptimeRobot free (50 monitors, 5-min interval) | $0 |
| Error tracking | Firebase Crashlytics (free) | $0 |
| Proxy logs | systemd journald + logrotate on VPS | $0 |
| Firebase quota alerts | Firebase console budget alert at 80% | $0 |
| Claude API cost spike | Anthropic account hard limit $50/month | $0 |
| Stripe webhook failures | Stripe dashboard retry + email alert | $0 |

No Datadog, no Sentry paid tier, no New Relic. These are post-1,000-user problems.

---

## 8. Launch Phasing — Must-Ship vs Later

### Phase 1: Launch (ship before first paid user)

| # | Item | Effort |
|---|---|---|
| L1 | Pre-generate all 7,900 MP3s and serve from VPS | 1 day (batch script) |
| L2 | Fix `WordAudioPlayerService` to fetch from VPS URL, not TTS API | 2 hours |
| L3 | StoreKit 2 + Play Billing on mobile (replace Stripe on native) | 3-4 days |
| L4 | `PrivacyInfo.xcprivacy` + App Store privacy nutrition label | 2 hours |
| L5 | Backend proxy: rate limit + Firebase UID auth + Claude hard cap | 1 day (verify T32 covers this) |
| L6 | GitHub Actions deploy pipeline | 2 hours |
| L7 | UptimeRobot + Firebase budget alert | 30 min |
| L8 | Fix price to ¥980; decide trial type (recommend opt-in 7-day) | 30 min (product decision) |
| L9 | App Store / Play Store listings (JP copy + screenshots) | 1 day |

**Total: ~8-9 engineering days to launch-ready.**

### Phase 2: Post-launch (first 500 users)

| Item | Trigger |
|---|---|
| T31 AI character generation | After revenue covers cost |
| Crafting / Guild modules (T09, T10) | After 30-day retention data |
| Multi-device sync (T11) | After family plan launch |
| Firebase Blaze upgrade | MAU > 8,000 |
| Analytics dashboard (T16) | After 1,000 paid users |

---

## 9. Recurring External Cost Summary (at 5,000 MAU)

| Item | Monthly Cost | Notes |
|---|---|---|
| Hetzner VPS | Already paid | Static + proxy |
| Google TTS | $0 | Pre-generated MP3s, one-time $12.64 batch |
| Firebase Spark | $0 | Under DAU ceiling at 5,000 MAU |
| Claude API (haiku) | ~$11-90 | Realistic ~$11; hard cap $50 |
| Apple IAP fee | 15% of iOS revenue | Small Business Program |
| Google Play fee | 15% of Android revenue | Small Business Program |
| Stripe (web) | 3.6% of web revenue | Minimal (most revenue via stores) |
| UptimeRobot | $0 | Free tier |
| GitHub Actions | $0 | Free tier |
| **New external cash out** | **~$11-90/month + store % of revenue** | |

At 2,000 paid users × ¥980 = ¥1,960,000 MRR (~$13,000): store fees ~$1,950/month, Claude ~$50 hard-capped. Margin is healthy.

---

## 10. Single Most Important Next Action

**Resolve StoreKit 2 / Play Billing before any other work.** Everything else (audio, monitoring, pipeline) can be fixed post-launch. Submitting to App Store with Stripe as the payment method will result in rejection and a 1-3 week delay. This is the critical path item.

---

## Market
# A-KEN Quest — Market Strategy Brief

## Beachhead Segment Recommendation

**Target: 小学4年〜中学2年生 / 英検5級〜3級 / 保護者が課金意思決定者**

| Dimension | Data |
|---|---|
| 小学生受験者 | 375,991人/年（10年で1.5倍、最速成長層） |
| 中学生受験者 | 主力層、3級合格が高校入試内申に直結 |
| 合格ニーズの切実度 | 3級＝高校推薦入試の必須条件化が進行中 |
| 保護者支払い意欲 | 習い事平均月額¥5,000〜¥12,000（学習塾比較で高い許容額） |
| 競合の空白 | スタサプは中高生向け講師動画、mikanは大人向け単語帳、Santaは TOEIC 大人。**小学生向け英検RPGは競合不在** |

---

## 価格戦略（不一致を解消）

¥999と¥3,000の不一致を今すぐ確定する必要がある。

| プラン | 価格 | 根拠 |
|---|---|---|
| **月額** | **¥1,480/月** | スタサプ(¥2,178)を下回り、mikan Premium(¥1,000)を上回る。保護者が「英検特化の専用アプリ」に払える上限の中間点 |
| **年額** | **¥9,800/年** | 月換算¥817。年払い比率を上げる（解約率低下）。RevenueCat: 教育LTV ≈¥7,000 → 年額でLTV一括回収 |
| **無料トライアル** | **7日間 opt-out** | opt-out 48.8% vs opt-in 18.2%の差は約2.7倍。小学生保護者はリスク回避型 → opt-outが必須 |

ASSUMPTION: 日本教育アプリのfree→paid転換率は北米P50(2.6%)より低く、**1.5%**で保守的試算。

---

## 5,000有料ユーザー到達の算数

| 指標 | 数値 |
|---|---|
| 英検5〜3級年間受験者（小中生推計） | ≈ 250万人 |
| アプリ認知→インストール率（ASSUMPTION: 0.5%） | 12,500人 |
| free→paid転換（1.5%） | 188人 — **1サイクルでは届かない** |
| 必要な認知到達数（5,000÷1.5%） | **333,000インストール** |

**結論: 5,000有料ユーザーはコールドスタートでは非現実的。口コミ・学校・保護者コミュニティ経由の有機増殖が必須。** 最初の100人は手動で獲得（英検塾、PTAコミュニティへの直接アプローチ）。

---

## 守れる堀（Defensible Moat）

| 堀 | 具体的内容 | 強度 |
|---|---|---|
| **FSRS × 英検コンテンツの結合** | 単語の出現頻度×試験配点×FSRS最適スケジュールを一体設計。後発が再現するには英検協会公式データ解析＋アルゴリズム開発で1年以上かかる | 高（技術的参入障壁） |
| **子供向けRPGのUX蓄積** | 4〜18歳のエンゲージメントデータ（どのゾーン・キャラ・報酬で継続するか）はプレイ時間の蓄積でのみ得られる。Recruitは大人向けで子供UXノウハウがない | 中〜高（データ護城河、時間依存） |
| **保護者信頼ブランド** | COPPA準拠匿名認証、広告なし、PII非収集。保護者向けダッシュボードで進捗可視化。一度信頼を得たら切り替えコストが高い（子供が慣れた環境を変えたくない） | 中（ブランド護城河、構築に時間） |

---

## 3 Reasons We Win

**1. 競合が取りに行っていない層を先に占有する**
スタサプは大学受験層、mikanは大学生・社会人、Santaは TOEIC ビジネスパーソン。小学生〜中学生の英検合格ニーズに正面から向き合ったアプリは現時点で存在しない。先行者利益を取れる時間は12〜18ヶ月。

**2. RPGゲーミフィケーションは離脱率を構造的に下げる**
教育アプリの最大課題は継続率。月次プラン初回更新の離脱15〜40%に対して、RPGの「セーブデータ」「レベルアップ」「次のボス」は離脱抑止として機能する。mikanに単語帳を超えるゲームループはない。スタサプに子供が毎日ログインしたくなる仕掛けはない。

**3. コスト構造が競合優位**
Claude Max定額（AI推論コスト≈$0）＋Hetzner既存VPS＋Firebase無料枠で、ユーザー1人あたりの限界コストはほぼ音声API費用のみ。スタサプは講師動画制作・配信コストが固定費として重い。A-KENは変動費が極小なので低価格でも黒字になれる。

---

## 3 Things Most Likely to Kill Us

**1. Google/Recruitが子供向けに参入する（最大脅威）**
スタサプはRecruit（時価総額≈10兆円）が運営。「英検×小学生」の市場が証明された瞬間に資本投下してくる。対抗策: 参入前に保護者コミュニティとデータ護城河を築く。到達まで18ヶ月が勝負。

**2. TTS音声の配線問題が未解決のままローンチする**
CLAUDE.mdに「Google TTS再生経路に未配線の疑い」と明記されている。音が出ないアプリで子供はday1に離脱する。App Storeレビューで「音が鳴らない」が並んだ時点でCVRが崩壊する。**ローンチ前の最優先技術タスク。**

**3. 価格と価値の認知ギャップ**
保護者は「英検合格保証」を期待する。アプリは学習ツールであり合格保証ではない。合格できなかった保護者のレビュー「お金の無駄」1件はインストール数百件分の損失。対抗策: KPIを「合格率」ではなく「試験スコア向上」「学習継続日数」に設定し、ストア説明文で期待値をコントロールする。

---

## 即時アクション（優先順）

| 順 | アクション | 理由 |
|---|---|---|
| 1 | Google TTS再生経路のデバッグ＋検証 | 音なし = day1離脱 = 全施策が無効 |
| 2 | 価格を¥1,480/月・¥9,800/年に確定し実装 | 不一致は投資家・ユーザー双方への信頼毀損 |
| 3 | 7日opt-outトライアル実装 | 転換率2.7倍の差は定量的に証明済み |
| 4 | 英検塾・PTAグループへの直接アプローチ（最初の100人） | 有機的口コミなしで333Kインストールは非現実的 |
| 5 | App Store説明文で「小学生・英検・RPG」を全面に出す | 競合不在の検索キーワードを先に取る |