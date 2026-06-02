# A-KEN Quest — CEO専用アクションマニュアル

**目的:** AIでは絶対にできない、CEOの手動操作が必要な全項目の完全実行手順書
**対象:** 素人でも確実に実行できるレベルの詳細さ
**作成日:** 2026-06-02

---

## 実行順序（推奨）

| 順番 | 項目 | 所要時間 | 費用 | 依存関係 |
|------|------|----------|------|----------|
| 1 | DUNS番号取得 | 5-7営業日 | 無料 | なし（最初に着手） |
| 2 | Apple Developer Program登録 | DUNS取得後 即日 | ¥11,800/年 | DUNS番号 |
| 3 | Google Play Developer登録 | 即日 | $25（一回のみ） | DUNS番号 |
| 4 | Firebaseプロジェクト作成 | 30分 | 無料 | Googleアカウント |
| 5 | RevenueCatアカウント作成 | 30分 | 無料（$2,500 MTR未満） | Apple/Google登録完了 |
| 6 | Backendシークレット取得 | 15分 | 各サービスの料金 | Firebase完了 |

**合計最短所要時間:** DUNS取得5-7日 + 各作業合計約2時間
**合計費用:** ¥11,800 + $25 ≈ ¥15,700

---

## 1. DUNS番号の取得（Apple/Google共通の前提条件）

### なぜCEOが必要？
DUNS番号は法人の代表者本人が申請する必要がある。AIには法人を代表する権限がない。

### 手順

1. **ブラウザで開く:** https://developer.apple.com/enroll/duns-lookup/
2. **「Look up your D-U-N-S Number」をクリック**
3. **法人情報を入力:**
   - Legal Entity Name: `Aesthetic Inc.`（登記名と完全一致させる）
   - Headquarters Address: 横浜市都筑区茅ヶ崎中央9-3（英語表記で入力）
     - Street: `9-3 Chigasakichuo`
     - City: `Yokohama`
     - State: `Kanagawa`
     - Postal Code: `224-0032`（確認すること）
     - Country: `Japan`
   - Phone: 会社の電話番号
   - Contact Name: CEO本名
   - Email: CEO業務用メールアドレス
4. **検索結果を確認:**
   - **見つかった場合** → DUNS番号をメモ（9桁の数字）→ 手順2へ
   - **見つからない場合** → 「Submit」で新規申請 → 5-7営業日で発行
5. **メールを待つ:** Dun & Bradstreetからメールで番号が届く
6. **届いたDUNS番号をメモ:** 例 `12-345-6789`

### 完了条件
- [ ] 9桁のDUNS番号を取得した

### hermes-engquestに渡すもの
DUNS番号（Telegramで「DUNS: XXXXXXXXX」と送信すればOK）

---

## 2. Apple Developer Program 登録

### なぜCEOが必要？
法人を代表してAppleとの契約に署名する権限が必要。年間ライセンス料の支払いもCEO。

### 手順

1. **ブラウザで開く:** https://developer.apple.com/programs/enroll/
2. **「Start Your Enrollment」をクリック**
3. **Apple IDでサインイン**
   - 既存のApple IDを使用（会社用を推奨）
   - ない場合: https://appleid.apple.com/ で新規作成
4. **Entity Type選択:** `Organization` を選択（Individual ではない）
5. **法人情報入力:**
   - Legal Entity Name: `Aesthetic Inc.`（DUNS登録と完全一致）
   - D-U-N-S Number: 手順1で取得した番号
   - Website: 会社のウェブサイト（あれば）
   - Headquarters Phone: 会社の電話番号
   - Jurisdiction: `Japan`
6. **本人確認:**
   - Appleから電話が来る場合あり（英語）
   - 2FA（二段階認証）が有効であること確認
7. **支払い:** ¥11,800/年（クレジットカード）
8. **待つ:** Apple審査 → 通常48時間以内に承認メール

### 承認後にやること（CEOがやる）

#### A. App ID作成
1. **開く:** https://developer.apple.com/account/resources/identifiers/list
2. **「+」ボタン → 「App IDs」→ 「App」**
3. **入力:**
   - Description: `A-KEN Quest`
   - Bundle ID: `Explicit` を選択
   - Bundle ID値: `jp.co.aesthetic.akenquest`
4. **Capabilities:**
   - [x] In-App Purchase（チェック必須）
   - [x] Push Notifications（チェック推奨）
5. **「Register」をクリック**
6. **edilab用も同様に作成:**
   - Description: `ENG Quest EDILAB`
   - Bundle ID: `jp.co.aesthetic.engquest.edilab`

#### B. 証明書作成
1. **開く:** https://developer.apple.com/account/resources/certificates/list
2. **「+」ボタン → 「Apple Distribution」を選択 → 「Continue」**
3. **CSR（Certificate Signing Request）の作成:**
   - Macの「キーチェーンアクセス」アプリを開く
   - メニュー → 証明書アシスタント → 認証局に証明書を要求
   - メールアドレス: CEO業務用メール
   - 通称: `Aesthetic Inc Distribution`
   - 「ディスクに保存」を選択
   - デスクトップに `.certSigningRequest` ファイルが保存される
4. **Appleのページに戻り、CSRファイルをアップロード**
5. **「Download」で .cer ファイルをダウンロード**
6. **ダブルクリックでキーチェーンにインストール**

#### C. プロビジョニングプロファイル作成
1. **開く:** https://developer.apple.com/account/resources/profiles/list
2. **「+」ボタン → 「App Store Connect」を選択**
3. **App ID: `jp.co.aesthetic.akenquest` を選択**
4. **Certificate: 上で作成した Distribution証明書を選択**
5. **Profile Name: `A-KEN Quest App Store`**
6. **「Generate」→ 「Download」**
7. **ダウンロードした .mobileprovision ファイルをダブルクリック（Xcodeに登録される）**

### 完了条件
- [ ] Apple Developer Programに法人登録完了
- [ ] App ID `jp.co.aesthetic.akenquest` 作成完了
- [ ] App ID `jp.co.aesthetic.engquest.edilab` 作成完了
- [ ] Distribution証明書 作成・インストール完了
- [ ] プロビジョニングプロファイル 作成・インストール完了

### hermes-engquestに渡すもの
- Team ID（Apple Developer画面右上の「Team ID」10桁英数字）→ Telegramで送信
- .mobileprovision ファイル → 不要（Xcode自動検出）

---

## 3. Google Play Developer 登録

### なぜCEOが必要？
法人アカウントの作成には代表者の本人確認と法人書類の提出が必要。

### 手順

1. **ブラウザで開く:** https://play.google.com/console/signup
2. **Googleアカウントでサインイン**（会社用を推奨）
   - 2段階認証が有効であること確認
3. **アカウント種類:** `Organization` を選択
4. **法人情報入力:**
   - Organization name: `Aesthetic Inc.`
   - Organization type: `Company`
   - Organization size: 該当するもの
   - D-U-N-S Number: 手順1で取得した番号
   - Website: 会社のウェブサイト
   - Contact email: CEO業務用メール
   - Contact phone: 会社電話番号
5. **Developer Account Details:**
   - Developer name: `Aesthetic Inc.`（ストアに表示される名前）
6. **身分証明書のアップロード:**
   - 代表者のパスポートまたは運転免許証の写真
7. **法人書類のアップロード:**
   - 登記事項証明書（法務局で取得、オンライン申請可）
   - または法人税確定申告書の写し
8. **支払い:** $25（約¥3,900）クレジットカード
9. **審査:** 通常3-5営業日

### 完了条件
- [ ] Google Play Console にログインできる
- [ ] Organization アカウントとして承認済み

### hermes-engquestに渡すもの
特になし（hermes-engquestがPlay Consoleにアプリを登録する際、CEOのGoogleアカウントでのログインが必要になる場合あり）

---

## 4. Firebase プロジェクト作成 + 設定ファイル取得

### なぜCEOが必要？
プロジェクトオーナー権限でのConsole操作。設定ファイルにはAPIキーが含まれ、CEO管理が安全。

### 手順

#### A. プロジェクト作成
1. **ブラウザで開く:** https://console.firebase.google.com/
2. **Googleアカウントでサインイン**
3. **「プロジェクトを追加」をクリック**
4. **プロジェクト名:** `engquest-mvp`
5. **Google Analytics:** 有効にする → デフォルトアカウントを選択
6. **「プロジェクトを作成」→ 完了まで30秒待つ**

#### B. iOS アプリ登録（aken flavor）
1. **プロジェクト画面で「iOS+」アイコンをクリック**
2. **入力:**
   - Apple Bundle ID: `jp.co.aesthetic.akenquest`
   - アプリのニックネーム: `A-KEN Quest iOS`
   - App Store ID: （空欄でOK、後で追加可）
3. **「アプリを登録」をクリック**
4. **「GoogleService-Info.plist をダウンロード」をクリック**
5. **ダウンロードしたファイルを保存**
   - ファイル名は変更しない: `GoogleService-Info.plist`
   - 保存場所: デスクトップでOK

#### C. Android アプリ登録（aken flavor）
1. **プロジェクト画面で「Android」アイコンをクリック**
2. **入力:**
   - Android パッケージ名: `jp.co.aesthetic.akenquest`
   - アプリのニックネーム: `A-KEN Quest Android`
   - デバッグ用の署名証明書 SHA-1: （空欄でOK）
3. **「アプリを登録」をクリック**
4. **「google-services.json をダウンロード」をクリック**
5. **ダウンロードしたファイルを保存**
   - ファイル名は変更しない: `google-services.json`
   - 保存場所: デスクトップでOK

#### D. edilab flavor用にも同じ手順を繰り返す
- iOS Bundle ID: `jp.co.aesthetic.engquest.edilab`
- Android パッケージ名: `jp.co.aesthetic.engquest.edilab`
- ニックネーム: `ENG Quest EDILAB iOS` / `ENG Quest EDILAB Android`
- 各設定ファイルも別途ダウンロード

#### E. Authentication 設定
1. **左メニュー → 「構築」→ 「Authentication」**
2. **「始める」をクリック**
3. **「匿名」をクリック → トグルを「有効」にする → 「保存」**

#### F. Firestore Database 設定
1. **左メニュー → 「構築」→ 「Firestore Database」**
2. **「データベースを作成」**
3. **ロケーション:** `asia-northeast1`（東京）を選択
4. **セキュリティルール:** 「テストモードで開始」→ 後でhermes-engquestがルールをデプロイ
5. **「作成」**

### 完了条件
- [ ] Firebase Console に `engquest-mvp` プロジェクトが存在する
- [ ] iOS (aken) `GoogleService-Info.plist` をダウンロード済み
- [ ] Android (aken) `google-services.json` をダウンロード済み
- [ ] iOS (edilab) `GoogleService-Info.plist` をダウンロード済み
- [ ] Android (edilab) `google-services.json` をダウンロード済み
- [ ] Anonymous Authentication が有効
- [ ] Firestore Database が作成済み（asia-northeast1）

### hermes-engquestに渡すもの
以下の4ファイルをTelegramで送信（ファイル添付）:
1. `GoogleService-Info.plist`（aken用）→ 「aken iOS」とメッセージ付き
2. `google-services.json`（aken用）→ 「aken Android」とメッセージ付き
3. `GoogleService-Info.plist`（edilab用）→ 「edilab iOS」とメッセージ付き
4. `google-services.json`（edilab用）→ 「edilab Android」とメッセージ付き

---

## 5. RevenueCat アカウント作成 + 商品設定

### なぜCEOが必要？
課金商品の価格設定と、App Store Connect / Google Play Consoleとの接続にはストアオーナー権限が必要。

### 前提条件
- Apple Developer Program 登録完了（手順2）
- Google Play Developer 登録完了（手順3）

### 手順

#### A. RevenueCat アカウント作成
1. **ブラウザで開く:** https://app.revenuecat.com/signup
2. **サインアップ:** Googleアカウントまたはメール+パスワード
3. **プロジェクト作成:**
   - Project Name: `A-KEN Quest`
   - 「Create Project」

#### B. iOS アプリ登録
1. **左メニュー → 「Apps」→ 「+ New App」**
2. **Platform:** `iOS`
3. **App Name:** `A-KEN Quest iOS`
4. **Bundle ID:** `jp.co.aesthetic.akenquest`
5. **App Store Connect の Shared Secret が必要:**
   - App Store Connect (https://appstoreconnect.apple.com/) にログイン
   - 「ユーザとアクセス」→ 「共有シークレット」→ 「生成」
   - 生成された32文字の文字列をコピー
6. **RevenueCatに戻り、Shared Secretを貼り付け**
7. **「Save」**
8. **表示される「Public API Key」をコピー**（`appl_` で始まる文字列）

#### C. Android アプリ登録
1. **「+ New App」→ Platform: `Android`**
2. **App Name:** `A-KEN Quest Android`
3. **Package Name:** `jp.co.aesthetic.akenquest`
4. **Google Cloud Service Account が必要:**
   - Google Cloud Console (https://console.cloud.google.com/) にログイン
   - プロジェクトを選択（またはPlay Console連携済みのプロジェクト）
   - 「IAMと管理」→ 「サービスアカウント」→ 「サービスアカウントを作成」
   - 名前: `revenuecat-service`
   - ロール: なし（後でPlay Consoleで設定）
   - 「キーを作成」→ JSON → ダウンロード
   - Play Console → 「設定」→ 「APIアクセス」→ サービスアカウントをリンク
   - 権限: 「財務データの表示」「注文の管理」を有効化
5. **RevenueCatにJSON keyをアップロード**
6. **「Save」**
7. **表示される「Public API Key」をコピー**（`goog_` で始まる文字列）

#### D. 商品（Entitlement / Offering）設定
1. **左メニュー → 「Entitlements」→ 「+ New」**
   - Identifier: `aken_premium`
   - Description: `A-KEN Quest Premium Access`
   - 「Add」

2. **左メニュー → 「Products」→ 「+ New」**
   - iOS Product:
     - App Store Product ID: `jp.co.aesthetic.akenquest.monthly`（App Store Connectで作成した商品IDと一致させる）
     - 「Add」→ Entitlement `aken_premium` を紐付け
   - Android Product:
     - Play Store Product ID: `jp.co.aesthetic.akenquest.monthly`
     - 「Add」→ Entitlement `aken_premium` を紐付け

3. **左メニュー → 「Offerings」→ 「+ New」**
   - Identifier: `default`
   - 「Add」
   - Package追加: 「+ New Package」
     - Identifier: `$rc_monthly`
     - Duration: `Monthly`
     - 上で作成したiOS/Android Productを両方紐付け

#### E. App Store Connect で課金商品を作成
1. **App Store Connect にログイン**
2. **「マイApp」→ アプリを選択（まだなければ「+」で新規作成）**
3. **左メニュー → 「サブスクリプション」→ 「サブスクリプショングループ」→ 「+」**
   - グループ名: `A-KEN Quest Premium`
4. **「サブスクリプションを作成」:**
   - 参照名: `Monthly Premium`
   - Product ID: `jp.co.aesthetic.akenquest.monthly`
   - Duration: `1ヶ月`
5. **「サブスクリプションの価格」→ 「+」**
   - 国: 日本
   - 価格: ¥999（Tier選択）
6. **「ローカリゼーション」で表示名と説明を追加:**
   - 日本語: 「A-KEN Quest プレミアム」/「全級の問題と音声にアクセス」
7. **「審査用のスクリーンショット」を後で追加（hermes-engquestが準備）**

#### F. Google Play Console でサブスクリプション作成
1. **Play Console にログイン → アプリを選択**
2. **「収益化」→ 「サブスクリプション」→ 「サブスクリプションを作成」**
3. **入力:**
   - Product ID: `jp.co.aesthetic.akenquest.monthly`
   - 名前: `A-KEN Quest プレミアム`
4. **基本プランを追加:**
   - 請求対象期間: `1ヶ月`
   - 価格: ¥999
5. **「有効にする」**

### 完了条件
- [ ] RevenueCat アカウント作成完了
- [ ] iOS API Key 取得（`appl_` で始まる文字列）
- [ ] Android API Key 取得（`goog_` で始まる文字列）
- [ ] Entitlement `aken_premium` 作成済み
- [ ] Offering `default` + Package `$rc_monthly` 作成済み
- [ ] App Store Connect にサブスクリプション商品作成済み
- [ ] Google Play Console にサブスクリプション商品作成済み

### hermes-engquestに渡すもの
以下をTelegramで送信:
```
RevenueCat iOS API Key: appl_XXXXXXXXXXXXXX
RevenueCat Android API Key: goog_XXXXXXXXXXXXXX
```

---

## 6. Backend シークレット取得

### なぜCEOが必要？
各サービスのダッシュボードへのログインとAPIキー生成にはアカウントオーナー権限が必要。

### 手順

#### A. Anthropic Claude API Key
1. **開く:** https://console.anthropic.com/settings/api-keys
2. **「Create Key」→ Name: `engquest-backend`**
3. **キーをコピー**（`sk-ant-` で始まる）
4. **即座にメモ（ページを離れると二度と表示されない）**

#### B. Stripe Keys（Web課金用）
1. **開く:** https://dashboard.stripe.com/apikeys
2. **「本番キーを表示」（テストモードからの切替時）**
3. **Secret Key をコピー**（`sk_live_` で始まる）
4. **Webhook設定:**
   - https://dashboard.stripe.com/webhooks
   - 「+ エンドポイントを追加」
   - URL: `https://api.akenquest.jp/stripe/webhook`（またはVPS IP直接）
   - イベント: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`
   - 「追加」→ Signing Secret をコピー（`whsec_` で始まる）

### 完了条件
- [ ] Claude API Key 取得
- [ ] Stripe Secret Key 取得
- [ ] Stripe Webhook Secret 取得

### hermes-engquestに渡すもの
以下をTelegramで送信:
```
Claude API Key: sk-ant-XXXXXX
Stripe Secret Key: sk_live_XXXXXX
Stripe Webhook Secret: whsec_XXXXXX
```
**注意:** これらは機密情報。送信後、Telegramのメッセージを削除することを推奨。

---

## 7. Android リリース Keystore 生成

### なぜCEOが必要？
Keystoreのパスワードは法人の重要資産。紛失するとアプリのアップデートが永久に不可能になる。CEO管理が最も安全。

### 選択肢
- **A: CEOが生成して保管** → 推奨
- **B: hermes-engquestに生成を委任** → CEOが希望する場合、Telegramで「keystore生成を任せる」と送信

### 手順（CEOが生成する場合）

1. **Macのターミナルを開く**
2. **以下のコマンドをコピー&ペーストして実行:**
```bash
keytool -genkey -v -keystore ~/Desktop/aken_release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias aken_release \
  -dname "CN=A-KEN Quest, OU=Engineering, O=Aesthetic Inc, L=Yokohama, ST=Kanagawa, C=JP"
```
3. **パスワードを聞かれる:**
   - `Enter keystore password:` → 強いパスワードを入力（16文字以上推奨）
   - `Re-enter new password:` → 同じパスワードを再入力
   - `Enter key password for <aken_release>:` → 同じパスワードでOK（Enter押すとkeystoreと同じになる）
4. **デスクトップに `aken_release.jks` が生成される**
5. **パスワードを安全な場所に記録:**
   - 1Password、Bitwarden等のパスワードマネージャーに保存
   - または紙に書いて金庫に保管
   - **絶対にSlack/Telegram/メールに書かない**

### 完了条件
- [ ] `aken_release.jks` ファイルが生成された
- [ ] パスワードを安全な場所に記録した

### hermes-engquestに渡すもの
- `aken_release.jks` ファイル → Telegramでファイル送信
- パスワード → Telegramで送信後、即メッセージ削除

---

## チェックリスト（全項目）

### 第1段階（今すぐ着手可能）
- [ ] 1. DUNS番号 申請済み
- [ ] 4. Firebase プロジェクト作成 + 設定ファイル4つ取得
- [ ] 6A. Claude API Key 取得
- [ ] 7. Keystore 生成（またはhermes-engquestに委任）

### 第2段階（DUNS取得後）
- [ ] 2. Apple Developer Program 登録
- [ ] 3. Google Play Developer 登録

### 第3段階（Apple/Google登録完了後）
- [ ] 2B. App ID + 証明書 + プロファイル 作成
- [ ] 5. RevenueCat 設定 + API Key取得
- [ ] 6B. Stripe 本番キー取得

### 全完了チェック
- [ ] Firebase設定ファイル4つをhermes-engquestに送信済み
- [ ] RevenueCat API Key 2つをhermes-engquestに送信済み
- [ ] Claude/Stripe Keyをhermes-engquestに送信済み
- [ ] Keystoreをhermes-engquestに送信済み
- [ ] Apple Team IDをhermes-engquestに送信済み
