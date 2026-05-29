# Firebase App Distribution — Closed Alpha Testing Guide

> **Firebase App Distribution** is the TestFlight-equivalent for cross-platform apps.  
> This guide sets up a closed alpha with 5–10 Japanese families before public launch.

---

## Overview

| | Firebase App Distribution | Apple TestFlight |
|--|--------------------------|-----------------|
| Platform | iOS + Android | iOS only |
| Cost | Free | Free |
| Max testers | 1,000 | 10,000 |
| Review required | ❌ None | ❌ None (internal) |
| Install method | Email link | TestFlight app |
| Expiry | 90 days | 90 days |

---

## Prerequisites

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login
firebase login

# Install App Distribution plugin
firebase experiments:enable webframeworks  # optional, for web preview
```

---

## Part 1: iOS Build

### 1.1 Configure Signing

1. Open `ios/Runner.xcworkspace` in Xcode
2. **Signing & Capabilities** → Team: select your Apple Developer account
3. Bundle Identifier: `co.aesthetic.engquest`
4. Ensure **Automatically manage signing** is checked

### 1.2 Create Ad Hoc / Development Provisioning Profile

For Firebase App Distribution (not App Store):
1. Apple Developer Portal → **Profiles** → **"+"**
2. Select **Ad Hoc** (for named device testing)
3. Select App ID: `co.aesthetic.engquest`
4. Select certificate → select tester devices (register family iPhones first)
5. Name: `ENG Quest Alpha` → **Generate** → **Download**
6. Double-click to install in Xcode

### 1.3 Build IPA

```bash
# Clean build
flutter clean
flutter pub get
cd ios && pod install && cd ..

# Build release IPA (ad hoc signing)
flutter build ipa --release \
  --export-options-plist ios/ExportOptions.plist

# Output: build/ios/ipa/engquest.ipa
```

#### ExportOptions.plist template

Create `ios/ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>ad-hoc</string>
  <key>teamID</key>
  <string>YOUR_TEAM_ID</string>
  <key>uploadBitcode</key>
  <false/>
  <key>compileBitcode</key>
  <false/>
  <key>thinning</key>
  <string>&lt;none&gt;</string>
</dict>
</plist>
```

Replace `YOUR_TEAM_ID` with your 10-character Apple Team ID.

---

## Part 2: Android Build

### 2.1 Create Keystore (first time only)

```bash
keytool -genkey -v \
  -keystore android/app/engquest-release.jks \
  -alias engquest \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD
```

Add to `android/key.properties` (git-ignored):

```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=engquest
storeFile=engquest-release.jks
```

### 2.2 Build APK

```bash
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Part 3: Upload to Firebase App Distribution

### 3.1 Enable App Distribution in Firebase Console

1. Firebase Console → **App Distribution** → **Get started**
2. Select your iOS app → **Enable**
3. Repeat for Android app

### 3.2 Create Tester Group

```bash
# Create the family-alpha group via Firebase CLI
firebase appdistribution:testers:add \
  --project engquest-mvp \
  --group family-alpha \
  family1@example.com family2@example.com family3@example.com
```

Or via Firebase Console:
1. **App Distribution** → **Testers & Groups** → **Add group**
2. Group alias: **`family-alpha`**
3. Add parent email addresses (5–10 families)
4. Click **Save**

### 3.3 Upload iOS Build

```bash
firebase appdistribution:distribute \
  build/ios/ipa/engquest.ipa \
  --app YOUR_IOS_APP_ID \
  --groups family-alpha \
  --release-notes "ENG Quest クローズドアルファ v0.1.0 — バトルモジュール + オンボーディング"
```

Find `YOUR_IOS_APP_ID` in Firebase Console → Project Settings → Your apps → App ID  
Format: `1:123456789:ios:abcdef123456`

### 3.4 Upload Android Build

```bash
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_ANDROID_APP_ID \
  --groups family-alpha \
  --release-notes "ENG Quest クローズドアルファ v0.1.0 — バトルモジュール + オンボーディング"
```

### 3.5 Automate with Makefile

Create `Makefile` in project root for convenience:

```makefile
.PHONY: alpha-ios alpha-android alpha-all

FIREBASE_IOS_APP_ID := 1:XXXX:ios:XXXX
FIREBASE_ANDROID_APP_ID := 1:XXXX:android:XXXX
VERSION := $(shell grep 'version:' pubspec.yaml | awk '{print $$2}')

alpha-ios:
	flutter clean && flutter pub get
	cd ios && pod install && cd ..
	flutter build ipa --release --export-options-plist ios/ExportOptions.plist
	firebase appdistribution:distribute build/ios/ipa/engquest.ipa \
	  --app $(FIREBASE_IOS_APP_ID) \
	  --groups family-alpha \
	  --release-notes "v$(VERSION) alpha"

alpha-android:
	flutter build apk --release
	firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
	  --app $(FIREBASE_ANDROID_APP_ID) \
	  --groups family-alpha \
	  --release-notes "v$(VERSION) alpha"

alpha-all: alpha-ios alpha-android
```

---

## Part 4: Tester Onboarding Instructions (Japanese)

Send the following email/message to parent testers:

---

### テスターへの案内メール

**件名**: 【ENG Quest】クローズドアルファ テスト参加のご案内

---

保護者の方へ

この度は ENG Quest クローズドアルファテストにご参加いただきありがとうございます。  
以下の手順に従って、アプリをインストールしてください。

---

#### 📱 アプリの起動方法

**iPhoneの場合:**

1. 招待メール内の「View Release」ボタンをタップ
2. Firebase App Distribution のページが開きます
3. 「Download」→ 画面の指示に従ってインストール
4. **設定 → 一般 → VPNとデバイス管理** を開く
5. 「Aesthetic AI K.K.」→「信頼する」をタップ
6. ホーム画面の「ENG Quest」アイコンをタップして起動

**Androidの場合:**

1. 招待メール内のリンクをタップ
2. APKファイルをダウンロード
3. 「不明なアプリのインストール」を許可
4. インストール完了後、アプリを起動

---

#### ⚔️ バトルモジュールのテスト手順

1. アプリを起動し、**オンボーディング**（4ステップ）を完了させてください
   - お子さんの年齢・学年を入力
   - 簡単な英語レベルチェック（10問）
   - 学習目標の設定
   - 通知時間の設定

2. **ワールドマップ**が表示されたら、「A1 ワールド」をタップ

3. **バトル**を開始:
   - 英単語カードが表示されます
   - カードをタップしてフリップ
   - 意味を確認したら、難易度ボタンをタップ:
     - 「また」(もう一度) / 「むずかしい」/ 「よかった」/ 「かんたん」
   - 10問セット終了まで続ける

4. **確認事項**:
   - [ ] カードが正しくフリップするか
   - [ ] 評価ボタンが反応するか
   - [ ] セット終了後に「結果画面」が表示されるか
   - [ ] アプリを一度終了して再起動→進捗が保存されているか

---

#### 📊 フィードバック提出方法

**テスト期間**: 2週間（毎日10〜15分程度）

**フィードバック方法**:

1. **アプリ内フィードバック** (推奨):
   - 設定画面 → 「フィードバックを送る」
   - 気になった点・良かった点を日本語で入力してください

2. **問題報告**:
   - アプリが落ちた場合: スクリーンショットと「どの操作をしたか」をメモして送信
   - 送信先: engquest-alpha@aesthetic.co.jp

3. **週次アンケート**:
   - 毎週金曜日にGoogleフォームのリンクをメールで送付します
   - 5分程度で回答できる内容です

**特に教えてほしいこと**:
- お子さんが楽しんで使えているか
- わかりにくい操作はあるか
- どのくらいの頻度で使用したか

ご協力よろしくお願いいたします。

Aesthetic AI K.K.  
engquest-alpha@aesthetic.co.jp

---

## Part 5: Success Criteria for Closed Alpha

### Primary KPIs (2-week alpha period)

| Metric | Target | Measurement |
|--------|--------|-------------|
| **DAU / MAU ratio** | > **70%** | Firebase Analytics → Audience |
| **3-day retention** | > **60%** | Firebase Analytics → Retention |
| **Session length** | > 8 min | Analytics → Engagement |
| **Battle completion rate** | > 80% | Custom event `battle_session_complete` |
| **Crash-free sessions** | > 99% | Firebase Crashlytics |
| **App size (iOS IPA)** | < 50 MB | `ls -lh build/ios/ipa/engquest.ipa` |

### Secondary KPIs

| Metric | Target |
|--------|--------|
| Onboarding completion rate | > 90% |
| Parent dashboard views per week | ≥ 3 |
| Push notification open rate | > 30% |
| Parent NPS score | ≥ 7/10 |

### Go / No-Go Decision

**Go to broader beta** (50+ families) if after 2 weeks:
- ✅ DAU > 70%
- ✅ 3-day retention > 60%
- ✅ Zero P0 crashes (app-killing bugs)
- ✅ ≥ 4/5 parent satisfaction score

**No-Go** triggers (pause and fix):
- ❌ Any crash that prevents battle module from working
- ❌ Data loss (progress not persisting across restarts)
- ❌ < 50% onboarding completion

---

## Part 6: Monitoring During Alpha

### Firebase Console Dashboards

1. **Analytics** → **Events** — track custom events:
   - `battle_session_start` / `battle_session_complete`
   - `card_graded` (with grade param: again/hard/good/easy)
   - `onboarding_step_complete` (with step param: 1–4)
   - `parent_dashboard_viewed`

2. **Crashlytics** → monitor crash rate daily

3. **App Distribution** → **Feedback** — in-app screenshots from testers

### Weekly Check-in Template

```
Week N Alpha Report — ENG Quest
================================
Active testers: X / Y
DAU avg: X%
3-day retention: X%
Crashes: X (P0: X, P1: X)
Top feedback themes:
  1. ...
  2. ...
  3. ...
Action items:
  - ...
```

---

→ See also: [CLOSED_ALPHA_CHECKLIST.md](CLOSED_ALPHA_CHECKLIST.md)
