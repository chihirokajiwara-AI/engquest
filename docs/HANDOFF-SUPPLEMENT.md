# A-KEN Quest — 補足引き継ぎドキュメント（全領域網羅版）

**From:** charsiu-ai-claude (司令塔)
**To:** hermes-engquest (@hermes_engquest_bot)
**Date:** 2026-06-02 13:20 JST
**Purpose:** HANDOFF-2026-06-02.md / HANDOFF-HERMES-VOCAB-AUDIO.md では不足していた全領域の引き継ぎ

---

## 1. 音声ファイルのgit追跡方針（CRITICAL — 未決定）

### 現状
- 9,575 MP3ファイル（約113MB）が `assets/audio/` に存在するが **git未追跡**
- `.gitkeep` のみコミット済み
- `scripts/verify_audio_assets.py` がCI内で音声ファイルの存在を検証 → クリーンクローンではCI失敗
- Flutter は `pubspec.yaml` に宣言されたアセットをビルド時にバンドルする → アセットがないとビルド成功するが音声再生不可

### 選択肢
| 方式 | メリット | デメリット |
|------|---------|-----------|
| A: git に直接コミット | シンプル、クローン即使える | repo 113MB増、push/clone遅い |
| B: Git LFS | 大ファイル向け設計、GitHub対応 | LFS設定必要、無料枠1GB/月 |
| C: CI時にKokoroで再生成 | repoクリーン | CIに60-90分追加、Mac環境必要 |
| D: Firebase Storage から DL | repoクリーン、CDN配信 | ランタイムDL必要、オフライン非対応 |

### 推奨（hermes-engquestで判断して良い）
**方式A（git直接コミット）** が現実的。113MBはモバイルアプリrepoとして許容範囲。
実行する場合:
```bash
git add assets/audio/eiken*/
git commit -m "chore: track Kokoro TTS audio assets (9,575 MP3s, 113MB)"
```

### CI修正
`scripts/verify_audio_assets.py` が `assets/audio/a1/` と `web/audio/` を参照している可能性あり。
音声を方式Aでコミットした後、このスクリプトを新しいディレクトリ構造に合わせて修正すること。

---

## 2. Firebase 設定（CRITICAL — CEO操作必要）

### 必要なCEO操作
1. Firebase Console (https://console.firebase.google.com/) でプロジェクト作成
   - プロジェクト名: `engquest-mvp` (既に `.firebaserc` に記載)
   - Analytics有効化
2. 2つのアプリを登録:
   - iOS: Bundle ID `jp.co.aesthetic.akenquest`
   - Android: Package Name `jp.co.aesthetic.akenquest`
3. 設定ファイルをダウンロード:
   - iOS: `GoogleService-Info.plist` → `ios/Runner/flavors/aken/GoogleService-Info.plist`
   - Android: `google-services.json` → `android/app/src/aken/google-services.json`
4. edilab flavor用にも同様に:
   - iOS: `ios/Runner/flavors/edilab/GoogleService-Info.plist`
   - Android: `android/app/src/edilab/google-services.json`

### hermes-engquestの作業
- プレースホルダファイルの場所: `ios/Runner/GoogleService-Info.plist.placeholder`, `android/app/google-services.json.placeholder`
- CEOからファイルを受け取り次第、正しいflavor別ディレクトリに配置
- `lib/core/firebase/firebase_options.dart` のプレースホルダ値を実値に更新

### Firestoreセキュリティルール
- `firestore.rules` に2,000行超の包括的ルールが既に実装済み
- ユーザー分離、COPPA準拠、匿名認証対応
- **変更不要** — デプロイのみ: `firebase deploy --only firestore:rules`

---

## 3. RevenueCat 設定（CRITICAL — CEO操作必要）

### 必要なCEO操作
1. RevenueCat (https://app.revenuecat.com/) でアカウント作成
2. プロジェクト作成: "A-KEN Quest"
3. アプリ登録:
   - iOS App: Bundle ID `jp.co.aesthetic.akenquest`
   - Android App: Package Name `jp.co.aesthetic.akenquest`
4. 商品設定:
   - Entitlement: `aken_premium`
   - Offering: `default`
   - Package: `$rc_monthly` (月額 ¥999)
5. APIキー取得（iOS/Android/Web各1つ）

### hermes-engquestの作業
- APIキー受領後、`lib/core/billing/billing_config.dart` を更新:
  ```dart
  static const _iosApiKey = 'rc_placeholder_aken_ios';      // ← 実キーに差替
  static const _androidApiKey = 'rc_placeholder_aken_android'; // ← 実キーに差替
  static const _webApiKey = 'rc_placeholder_aken_web';      // ← 実キーに差替
  ```
- edilab flavorは常に無料（BillingServiceで制御済み、RevenueCat不要）

---

## 4. Apple Developer Program（CRITICAL — CEO操作必要）

### 必要なCEO操作
1. Apple Developer Program に法人登録（年間 $99/¥12,980）
   - DUNS番号が必要（Aesthetic Inc.）
   - 登録完了まで2-6週間
2. 登録完了後:
   - App ID作成: `jp.co.aesthetic.akenquest`
   - 配布証明書作成（Development + Distribution）
   - プロビジョニングプロファイル作成

### hermes-engquestの作業（CEO登録完了後）
- Xcodeスキーム設定: edilab / aken
- iOS Xcode設定:
  - `ios/Runner.xcodeproj` でTeam IDとBundle ID設定
  - Signing & Capabilities でプロビジョニングプロファイル指定
- TestFlight配信テスト
- 参照: `docs/TESTFLIGHT_SETUP.md`（既存ドキュメント）

---

## 5. Android署名設定（CRITICAL — 即実行可能）

### hermes-engquestで即実行
1. リリースkeystore生成:
   ```bash
   keytool -genkey -v -keystore android/app/keystore/release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias aken_release \
     -dname "CN=A-KEN Quest, OU=Engineering, O=Aesthetic Inc, L=Yokohama, ST=Kanagawa, C=JP"
   ```
2. パスワードを `.env` に記録（git追跡禁止）
3. `android/app/build.gradle.kts` の signingConfig は環境変数参照済み:
   ```kotlin
   storeFile = file(System.getenv("STORE_FILE") ?: "keystore/release.jks")
   storePassword = System.getenv("STORE_PASSWORD") ?: ""
   keyAlias = System.getenv("KEY_ALIAS") ?: "aken_release"
   keyPassword = System.getenv("KEY_PASSWORD") ?: ""
   ```
4. `.gitignore` に `android/app/keystore/` は追加済み

---

## 6. Backend設定（MEDIUM）

### 構成
```
backend/
  server.js          — Express APIサーバー（Claude proxy + Stripe billing）
  package.json       — Node.js依存関係
  Dockerfile         — Dockerイメージ定義
  docker-compose.yml — Docker Compose設定
```

### 必要な環境変数
| 変数名 | 用途 | 取得元 |
|--------|------|--------|
| `STRIPE_SECRET_KEY` | Stripe決済 | Stripe Dashboard |
| `STRIPE_WEBHOOK_SECRET` | Webhook署名検証 | Stripe Dashboard |
| `CLAUDE_API_KEY` | Claude API proxy | Anthropic Console |
| `FIREBASE_PROJECT_ID` | Firebase認証 | Firebase Console |
| `PORT` | サーバーポート | デフォルト 3001 |
| `NODE_ENV` | 環境 | production |
| `ALLOWED_ORIGINS` | CORS | akenquest.jpドメイン |

### 注意
- Stripe Checkoutは **iOSアプリ内で使用禁止**（App Storeリジェクト）
- iOS/Android課金はRevenueCat経由（StoreKit 2 / GPBL）
- Stripe Checkoutは **Web版のみ**で使用
- backend/server.js のStripeルートはWeb billing用に残存

### VPSデプロイ
```bash
ssh root@178.105.113.79
cd /opt/engquest-backend  # or wherever deployed
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

---

## 7. VPS (178.105.113.79) 運用情報

### Web配信
- nginx設定: `deploy/nginx/engquest.conf`
- Web root: `/var/www/engquest` (永続的、再起動耐性あり)
- Flutter Webビルドを rsync でデプロイ:
  ```bash
  flutter build web --release --web-renderer canvaskit
  rsync -avz build/web/ root@178.105.113.79:/srv/engquest-web/
  ```

### 監視
- Watchdog: `deploy/engquest-watchdog.sh` — ヘルスチェック + 自動再起動
- cron: `@reboot` + 2分間隔で実行
- nginx検証: `deploy/test_nginx_config.py` — 37項目チェック

### 復旧
- `deploy/recover_live_demo.sh` — 障害時の完全復旧スクリプト

---

## 8. Kokoro TTS セットアップ情報

### 環境
```
Python venv: ~/.venvs/kokoro/
Kokoro version: 0.9.4
依存関係: kokoro, soundfile, numpy, torch
ffmpeg: /opt/homebrew/bin/ffmpeg (WAV→MP3変換)
```

### 有効化
```bash
source ~/.venvs/kokoro/bin/activate
# または直接:
~/.venvs/kokoro/bin/python scripts/generate_kokoro_audio.py --help
```

### 生成パラメータ（CEOテスト承認済み）
- Voice: `af_heart` (American English female)
- 上位級: speed=0.7（ゆっくり）+ speed=1.0（普通）+ 定義 + 例文、各0.5秒間隔
- 下位級: speed=0.7（ゆっくり）+ speed=1.0（普通）+ 例文、各0.5秒間隔
- Sample rate: 24000 Hz
- 出力: MP3 (libmp3lame, qscale 6)

### 注意事項
- Mac Mini ローカル専用（VPSにKokoroはインストールされていない）
- `flutter test` と Kokoro を同時実行すると、WAV→MP3 変換中の一瞬のタイミングで Flutter の asset bundler がクラッシュする可能性あり（WAV ファイルが一瞬存在して消える race condition）。テスト実行時はKokoroを停止するか、完了を待つこと

---

## 9. iOS Xcodeスキーム設定（MEDIUM）

### 現状
- Android: `build.gradle.kts` に `productFlavors` 設定済み（edilab/aken）
- iOS: Xcodeスキーム**未設定**

### hermes-engquestの作業
1. `ios/Runner.xcodeproj` を開く
2. Scheme追加: `edilab`, `aken`
3. 各SchemeのBuild Configurationを設定:
   - edilab: Bundle ID `jp.co.aesthetic.engquest.edilab`
   - aken: Bundle ID `jp.co.aesthetic.akenquest`
4. `ios/Runner/Info.plist` でBundle Identifierを `$(PRODUCT_BUNDLE_IDENTIFIER)` に
5. flavor別の `GoogleService-Info.plist` をビルドフェーズで切替

参照: `docs/HANDOFF-2026-06-02.md` 残タスク #8

---

## 10. git履歴（本セッションの全コミット）

```
21a15c4 chore: add .gitkeep for eiken audio directories
91f4a48 docs: mark CRITICAL audio items 1-2 as completed in handoff
128a9e4 feat(audio): wire bundled Kokoro TTS audio into Battle flashcards
a5b89e8 Merge branch 'worktree-agent-a070ed93'  (E13 daily home screen)
3badc86 feat(home): daily home screen with streak tracking and quick actions
6f8a7b8 feat(paywall): conversion-optimized subscription screen with social proof
bab1199 fix(content): normalize CEFR labels + security hardening + ...
... (Phase 1-3 の多数のマージコミット)
a25a7ff feat(content): expand Eiken 2級 vocabulary 800→2000 words
f71612a feat(content): expand Eiken 準1級 vocabulary 3000→3475 words
2c5adef docs: detailed handoff for vocab polish + audio regeneration
```

---

## 11. 既知の技術的問題

### flutter analyze 警告（非ブロッカー）
- `purchases_flutter` と `audioplayers_darwin` が Swift Package Manager 未対応
- Flutter の将来バージョンでエラーになる可能性
- プラグイン側の修正待ち

### pre-push quality gate の formatter drift
- ローカル Flutter 3.44 vs CI Flutter 3.22 でフォーマット差異
- 警告は出るがブロックしない（`WARN: dart format reports changes`）
- T36で CI を3.44に統一済みだが、完全同期にはCIランナー側も要確認

### web_static/ ディレクトリ
- T00eで削除済みだが、archiveに残存している可能性
- `archive/` ディレクトリがgit未追跡で存在 → 不要なら削除可

---

## 12. CEO決断待ち事項（再掲 + 追加）

| # | 事項 | 状態 | 必要なCEO操作 |
|---|------|------|--------------|
| 1 | 価格 | ¥999/月で仮決定 | 最終確認 |
| 2 | ドメイン | 後回し（名称変更の可能性） | ドメイン取得・DNS設定 |
| 3 | Apple Developer | 未登録 | 法人情報でProgram登録開始 |
| 4 | Firebase | プロジェクト未作成 | Console でアプリ登録 |
| 5 | RevenueCat | アカウント未作成 | 商品・APIキー設定 |
| 6 | Stripe | テストモードのまま | 本番キー切替（Web版のみ） |
| 7 | 特商法表記 | 未作成 | Aesthetic Inc.情報で作成 |
| 8 | 音声git追跡 | 未決定 | 方針決定（推奨: 直接コミット） |

---

## 全ドキュメント一覧

| ファイル | 内容 |
|---------|------|
| `CLAUDE.md` | プロジェクト概要・タスクキュー・エージェントルール |
| `docs/HANDOFF-2026-06-02.md` | メイン引き継ぎ（Phase 1-4実績、残タスク） |
| `docs/HANDOFF-HERMES-VOCAB-AUDIO.md` | 例文精査・音声再生成の詳細指示 |
| `docs/HANDOFF-SUPPLEMENT.md` | **本文書**（全領域網羅の補足） |
| `docs/FIREBASE_SETUP.md` | Firebase設定ガイド |
| `docs/TESTFLIGHT_SETUP.md` | TestFlight配信ガイド |
| `docs/CLOSED_ALPHA_CHECKLIST.md` | アルファ版チェックリスト |
| `docs/CONTENT_QUALITY_AUDIT.md` | コンテンツ品質監査レポート |
| `docs/spec/mvp.md` | MVP仕様書（19コンポーネント） |
| `docs/store_metadata.md` | App Store掲載メタデータ |
| `.env.example` | 環境変数テンプレート（本セッションで作成） |
| `docs/OPS-PLAYBOOK.md` | VPS/Backend運用手順書（本セッションで作成） |
| `docs/SCRIPTS-INVENTORY.md` | スクリプト一覧（本セッションで作成） |
