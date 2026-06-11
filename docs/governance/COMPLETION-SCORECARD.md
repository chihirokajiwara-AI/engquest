# Completion Scorecard — drive every item to 100 (CEO 1245, 2026-06-11)

The autonomous loop's measurable target. Each cycle: advance the lowest **BUILD**
items toward 100, re-audit super-strictly (measure, never assume), update the
score here, and surface **GATE** items to the CEO with decision material. Honesty
is non-negotiable: a score only rises on verified, gated, shipped work.

**Headline reframe (CEO 1244):** as a *game* the product is ~5%. The 英検 drill
core is decent but the 本格 コトバ探偵 RPG — the reason a child pays ¥999 — is
barely built. The loop's TOP priority is the GAME layer (items 48–60), almost all
self-BUILDABLE; only art *generation* is gated.

Legend — **type**: `BUILD` = self-buildable now (loop does it) · `GATE:<what>` =
needs CEO go (spend / secret / prod / legal / art-gen).

## A. 英検 content
| # | item | now | type | next action |
|---|------|----|------|-------------|
|1|5級語彙|88|BUILD|polish glosses/IPA coverage|
|2|4級語彙|86|BUILD|same|
|3|3級語彙|85|BUILD|same|
|4|準2/準2+語彙|84|BUILD|same|
|5|2級語彙|84|BUILD|same|
|6|準1語彙|80|BUILD|C1 review, collocations|
|7|Reading項目量|45|BUILD|author passages to ~30/grade (thin: ~140 total)|
|8|Listening項目量|40|BUILD|author items + fill missing audio (110 total)|
|9|Writing課題量|50|BUILD|expand prompt bank per grade|
|10|distractor意味品質|65|GATE:backend|runtime same-POS now; semantic uniqueness = LLM|
|11|例文品質|72|BUILD|tighten cloze-clean sentences|
|12|大問構造再現|86|BUILD|準1大問3=7 etc. residual fixes|

## B. ペダゴジー
| # | item | now | type | next action |
|---|------|----|------|-------------|
|13|FSRS|75|BUILD|tune params|
|14|適応難易度|20|BUILD|per-child difficulty (T12) — SELF-BUILDABLE|
|15|teach-why|78|BUILD|reading in mock-review, grammar 解説|
|16|hint scaffold|82|BUILD|extend to all screens|
|17|音声強化|65|GATE:backend|TTS coverage needs backend/static gen|
|18|連続ミス励まし|85|BUILD|done 4 screens; tune copy|
|19|メタ認知/calibration|25|BUILD|"how sure are you?" + calibration — SELF-BUILDABLE|
|20|合格率誠実性|90|BUILD|hold; keep honest|
|21|mastery追跡|70|BUILD|surface per-skill mastery|
|22|再来訪/通知|58|BUILD|web push / streak reminders|

## C. アセスメント
|23|模試組立採点|82|BUILD|residual fidelity|
|24|模試review|80|BUILD|reading explanation in review|
|25|Writing採点|35|GATE:backend|AI rubric design done; needs backend|
|26|Speaking採点|35|BUILD|on-device scorer depth (pronunciation_scorer)|
|27|未測定honest|88|BUILD|hold|
|28|gaming耐性|72|BUILD|more shuffle/anti-pattern locks|

## D. AI (mostly GATE:backend/secret)
|29|NPC対話|25|GATE:backend+secret|client done; api.akenquest.jp HTTP000|
|30|jailbreak耐性|30|GATE:backend|prompt-prefix only; needs server guard + tests|
|31|offline fallback|55|BUILD|richer canned variety|
|32|Writing AI採点|30|GATE:backend|same as 25|
|33|動的生成|15|GATE:backend|all dynamic AI needs the proxy|

## E. 収益化 (GATE)
|34|課金実装|15|GATE:secret+prod|RevenueCat SDK wired; needs real keys + store products|
|35|paywall UI|60|BUILD|polish gating UX|
|36|サブスク管理|15|GATE:secret|RevenueCat entitlement flow needs keys|
|37|IAP receipt検証|10|GATE:secret|server validation via RevenueCat dashboard|
|38|flavor分離|65|BUILD|edilab/aken split refinement|

## F. 安全/法務
|39|危機対応|10|GATE:legal-signoff|client crisis net DESIGNED (#1230); verified JP resources; needs CEO content GO|
|40|COPPA匿名auth|80|BUILD|hold|
|41|privacy/ToS|70|GATE:legal|review final copy|
|42|AI出力filter|65|BUILD|extend block lists / tests|
|43|PII非収集|80|BUILD|audit any leak paths|

## G. 基盤 (GATE)
|44|backend proxy deploy|10|GATE:spend+secret+prod|backend/server.js EXISTS (29KB) + Dockerfile; needs host + Anthropic key + deploy|
|45|Firebase設定|55|GATE:secret|placeholder keys → real project|
|46|offline永続|70|BUILD|hold|
|47|error耐性|58|BUILD|error states, retries, empty states|

## H. GAME COMPOSITION (TOP PRIORITY — CEO 1244, ~5%, mostly BUILD)
|48|世界/物語実装|28|BUILD|implement STORY-BIBLE 7-case arc into quest_data (currently 英検+thin skin)|
|49|キャラ in-game|35|BUILD|cast dialogue, arcs, presence (bible→code); art-gen separate|
|50|探索の深さ|40|BUILD|scene/nazo/hotspot depth → Layton/Minecraft-grade|
|51|ゲームフィール/演出|24|BUILD|juice, transitions, feedback, reward moments|
|52|事件→英検の有機結合|32|BUILD|each case's puzzles ARE the 英検 skills, diegetic|
|53|手がかりドリップ|40|BUILD|one clue/case edge→centre per WORLD-BIBLE|
|54|視覚の本格バー|30|GATE:art-gen|dark-navy/gold look; cast+scene art (heavy job)|
|55|オープニング/掴み|28|BUILD|implement OPENING-NARRATIVE-BIBLE as playable|
|56|サウンド/音楽|35|GATE:audio|BGM/SE design+wiring (founder/paid gen escalates)|
|57|nav到達性/ハブ|72|BUILD|kill orphaned WorldMap hub remnants; clean flow|
|58|onboarding没入|72|BUILD|make CAT placement diegetic (探偵の入所試験)|

## I. perf / a11y / QA
|59|perf|55|BUILD|cold-boot 6.6s engine-bound; audio bundle #48|
|60|a11y|88|BUILD|hold; extend|
|61|test/CI/governance|85|BUILD|hold green; expand coverage|
|62|mobile store|30|GATE:prod|store listings, review, publish|

## Loop protocol (CEO 1245)
- Each tick: pick the lowest 1–2 **BUILD** items (bias to GAME §H), advance toward
  100 via §III 8-phase (BUILD→verify_quality 0→content-QA→adversarial audit→commit),
  then **re-score the touched items here** with the measured new value.
- Parallelism: when a tick's work spans independent dimensions, fan out via a
  Workflow (CEO 1245 opted into multi-agent). Otherwise rotate dimensions.
- **GATE items never self-advance** past their gate — surface to CEO with the
  decision material (what / done / GO-needs / cost / risk / recommendation).
- The score is HONEST: it rises only on verified shipped work, never on intent.

## Loop protocol v2 (CEO 1249 全て組込 / 1250 超厳格・100超)
EVERYTHING is now the autonomous loop — audits, the game-build plan, parallel
agent teams, scorecard growth — one self-sustaining engine. Each tick:
1. ORIENT: read this scorecard + GAME-BUILD-PLAN.md; pick the lowest BUILD item(s),
   **biased hard to §H GAME** (CEO 1244 all-in). GATE items → surface to CEO, never self-build.
2. RESEARCH (latest-first) where a design decision needs it; front-load agents.
3. BUILD via §III 8-phase. Independent units → fan out a Workflow (model-tiered:
   haiku=status/extract, sonnet=code/content, opus=judgment); coordination-bound
   units → sequence (wait where it yields higher quality, CEO 1247).
4. **SUPER-STRICT re-audit (CEO 1250, stricter than the drill bar)**: measure the
   real shipped result (never assume); an item's score rises ONLY on verified,
   gated, adversarially-audited, committed work. Default-REJECT the increment.
5. Re-score here with the measured value. Surface real outcomes to CEO.
6. **Aim BEYOND 100 (CEO 1250)**: 100 = "world-class sellable bar reached"; then
   keep deepening (a 100 item can still be out-classed next month → re-audit
   latest-first and push past it). Growth never stops; no "done".

## J. Launch / legal / compliance — omissions audit (CEO 1257/1259, 2026-06-12, latest-first sourced)
The 62 items above MISSED these. Added so the loop drives them too. Severity for a PAID kids launch. Sources: Apple Kids 2026 / COPPA amendment (eff. 2026-04-22) / Japan APPI 2026 / 特商法 検討会 2026-01.
| # | item | now | type | sev | action |
|---|------|----|------|-----|--------|
|63|特定商取引法 最終確認画面|5|GATE:legal|BLOCKER|dedicated 最終確認 screen pre-purchase (seller id/price/cycle/cancel) — needs corp details(legal)|
|64|COPPA2026 第三者提供の分離同意|8|GATE:legal|BLOCKER|unbundled opt-in consent for Firebase/RevenueCat third-party data (eff 2026-04-22)|
|65|同意の永続化+監査ログ|75|BUILD|MAJOR✓|persist voice/parental consent (PrefKeys + timestamp + policy version); stop re-prompting每session|
|66|アプリ内サポート/問い合わせ導線|70|BUILD|BLOCKER✓|in-app お問い合わせ/不具合報告 button (store requires working support); none today|
|67|アプリ内データ削除/消去権|65|BUILD|BLOCKER✓|in-app "データ削除" path (Apple/Play require account deletion in-app); only email today|
|68|アプリ内サブスク解約導線|15|BUILD|MAJOR|surface manage-subscription URL button in settings/parent (none wired)|
|69|年齢レーティング質問票(2026新制度)|10|GATE:prod|BLOCKER|complete Apple(由 2026-01-31)/Play new age-rating questionnaire|
|70|実機/E2Eプレイテスト|20|BUILD|MAJOR|integration_test/Patrol real-flow; today only pure-Dart/widget smoke (#49 unstarted)|
|71|クラッシュレポート|0|BUILD|MAJOR|wire Firebase Crashlytics (¥0, in tree) + FlutterError.onError; none today|
|72|ストアSS/宣材作成|10|GATE:prod+art|BLOCKER|actual screenshots + feature graphic (none exist; metadata text only)|
|73|privacy/support URL 公開ホスト|5|GATE:prod|BLOCKER|edilab.co/engquest/{privacy,support} are "(to be hosted)"; stores need live URLs|
|74|第三者SDK Kids適合監査|10|GATE:legal|BLOCKER|certify Firebase/RevenueCat vs Apple Kids 1.3 / Play DFF|
|75|データ保持期限ポリシー|10|GATE:legal|MAJOR|COPPA2026 new retention-limit req; define+enforce Firestore retention (none)|
|76|reduced-motion / a11y OS信号|30|BUILD|MINOR|respect disableAnimations/reduceMotion (none); dyslexia/tap-target audit|
|77|i18n/localization 枠組み|20|BUILD|MINOR|no intl/l10n; strings hardcoded (T15)|

### Honest re-score of OVERSTATED existing items (audit-corrected)
|60|a11y|73|BUILD|—|was 88; no reduced-motion, unverified tap-target, no dyslexia/cognitive test|
|41|privacy/ToS|50|GATE:legal|—|was 70; missing 特商法 screen + hosted URLs + COPPA2026 consent + retention|

**Buildable-now omissions the loop can take (no GO): 65,66,67,68,70,71,76,77.** Gated (legal/prod/art): 63,64,69,72,73,74,75 + the corp/legal details for 41.
