# Closed Alpha Gating Checklist

> **Purpose**: All items must be ✅ before distributing ENG Quest to family testers via Firebase App Distribution.  
> **Owner**: CEO + Lead Developer  
> **Target date**: TBD (after Firebase project creation)

---

## How to Use This Checklist

1. Work through items top-to-bottom — earlier items are prerequisites for later ones
2. Test on both iOS (iPhone) and Android (if applicable)
3. For each item: check the box, add tester name + date
4. If any item fails: open a GitHub issue with label `alpha-blocker`
5. All items must pass before sending invite emails to families

---

## Category 1: Firebase Infrastructure

- [ ] **Firebase project `engquest-mvp` created** in Firebase Console
  - Project ID confirmed: `engquest-mvp`
  - Region: `asia-northeast1` (Tokyo)

- [ ] **Anonymous Authentication enabled**
  - Verified: app signs in automatically on launch
  - User appears in Firebase Console → Authentication → Users
  - UID is stable across app restarts (same device = same UID)

- [ ] **Firestore database created and accessible**
  - Region: Tokyo (`asia-northeast1`)
  - Test write + read from app succeeds
  - No permission denied errors in console

- [ ] **Security rules published**
  - Users can only access their own `users/{uid}/` documents
  - Vocabulary content is read-only
  - Rules tested with Firebase Rules Playground

- [ ] **`GoogleService-Info.plist` in place** (`ios/Runner/`)
  - No placeholder values remaining
  - Added to Xcode project navigator

- [ ] **`google-services.json` in place** (`android/app/`)
  - No placeholder values remaining

- [ ] **All placeholder API keys replaced** in `lib/core/firebase/firebase_config.dart`
  - `REPLACE_WITH_ACTUAL_API_KEY` → real web API key
  - `REPLACE_WITH_ACTUAL_APP_ID` → real app ID
  - `REPLACE_WITH_ACTUAL_MESSAGING_SENDER_ID` → real sender ID

---

## Category 2: Core App Functionality

### 2a. Onboarding Flow

- [ ] **Step 1 — Age/grade input**: UI renders, value saves correctly
- [ ] **Step 2 — CEFR placement test**: 10 questions display, answers recorded
- [ ] **Step 3 — Learning goals**: selection saves to Firestore
- [ ] **Step 4 — Notification time**: picker works, preference saved
- [ ] **Onboarding completion**: result written to `users/{uid}/profile`
- [ ] **Re-launch after onboarding**: app goes directly to World Map (not onboarding again)
- [ ] **CEFR level assigned correctly**: A1 for beginner, higher for advanced input

### 2b. Battle Module

- [ ] **Card displays correctly**: English word + image/hint visible
- [ ] **Card flip animation**: tapping card reveals Japanese meaning smoothly
- [ ] **FSRS grade buttons**: all 4 buttons (Again / Hard / Good / Easy) are tappable
- [ ] **Grade records to Firestore**: `users/{uid}/cards/{cardId}` updated after each grade
- [ ] **FSRS next review interval**: varies correctly by grade (Again = soon, Easy = far)
- [ ] **Session progress**: X/10 counter increments correctly
- [ ] **Session completion screen**: shows after 10 cards, displays score/summary
- [ ] **Progress persists across restarts**: 
  - Complete 5 cards → force-quit app → reopen → same 5 cards marked as reviewed
  - Due cards list reflects completed cards

### 2c. Push Notifications

- [ ] **Daily reminder fires at configured time** (set during onboarding step 4)
  - Test: set time to 2 minutes from now → notification arrives
- [ ] **Notification text displays correctly** in Japanese
- [ ] **Tapping notification opens app** to battle module
- [ ] **FCM APNs certificate configured** (iOS) — see [FIREBASE_SETUP.md](FIREBASE_SETUP.md#step-10)
- [ ] **Notification permission requested** on first launch (iOS)

### 2d. Parent Dashboard

- [ ] **Dashboard accessible**: navigation from main screen works
- [ ] **Real progress data shown**: not mock/hardcoded data
  - Total words learned count
  - Today's review count
  - Streak (consecutive days)
  - CEFR level progress bar
- [ ] **Charts render without errors**: no blank graphs or loading spinners stuck
- [ ] **Data refreshes**: pull-to-refresh or auto-refresh on open works

---

## Category 3: Stability & Performance

- [ ] **Crash rate: 0 crashes in 30-minute smoke test**
  - Test script: Launch → Onboarding → 3 battle sessions (10 cards each) → Parent dashboard → Settings → Background/foreground 5x
  - Check Firebase Crashlytics: 0 non-fatal errors reported

- [ ] **App size: < 50 MB** (before on-device Whisper model)
  ```bash
  flutter build ipa --release
  ls -lh build/ios/ipa/engquest.ipa
  # Must be < 50 MB
  ```

- [ ] **Cold start time: < 3 seconds** on iPhone 12 or equivalent
  - Measure: tap icon → home screen/world map appears

- [ ] **No ANR / freeze > 2 seconds** during normal navigation
  - Battle card flip, screen transitions, Firestore writes must not block UI

- [ ] **Offline graceful degradation**
  - Enable Airplane mode → app shows cached content, not blank screen
  - Returns to normal when connection restored

---

## Category 4: Data Integrity

- [ ] **FSRS scheduling is deterministic**: same grade on same card → same next review date
- [ ] **No data duplication**: reviewing same card twice in same session doesn't create duplicate Firestore documents
- [ ] **Firestore offline persistence**: SQLite local cache active (verifiable in network logs)
- [ ] **User data isolated**: signing in on Device A has no data visible on Device B (different anonymous UIDs)

---

## Category 5: Analytics & Observability

- [ ] **Firebase Analytics events firing**:
  - `battle_session_start` logged when battle begins
  - `card_graded` logged with grade parameter
  - `onboarding_complete` logged on step 4 completion
  - Verify in Firebase Console → **DebugView** (run `flutter run --debug` with `FIREBASE_DEBUG_VIEW_ENABLED=1`)

- [ ] **Crashlytics initialized**: Firebase Console → Crashlytics shows app registered
- [ ] **No sensitive PII in Analytics**: verify no names, emails, or device IDs in event params

---

## Category 6: Distribution Readiness

- [ ] **Firebase App Distribution configured**
  - `family-alpha` tester group created
  - 5–10 parent email addresses added

- [ ] **Test instructions document ready**: [TESTFLIGHT_SETUP.md](TESTFLIGHT_SETUP.md) → Part 4 (Japanese instructions)

- [ ] **Build uploaded to App Distribution**
  ```bash
  firebase appdistribution:distribute build/ios/ipa/engquest.ipa \
    --app YOUR_IOS_APP_ID \
    --groups family-alpha \
    --release-notes "クローズドアルファ v0.1.0"
  ```

- [ ] **Invite emails sent** to family testers

- [ ] **At least 1 internal tester (team member)** has completed full flow end-to-end on physical device

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| CEO / Product Owner | | | |
| Lead Developer | | | |
| QA / Tester | | | |

**Alpha distribution approved**: ☐ Yes  ☐ No

---

## Known Limitations for Alpha (Acceptable)

These items are **known gaps** that will NOT block alpha:

- 🟡 Voice module (Whisper ASR) is **stubbed** — pronunciation recording not yet functional
- 🟡 Crafting + Guild modules **not implemented** (v2 features)
- 🟡 World Map has only **A1 World** populated (300 words)
- 🟡 Dialog module (Claude haiku) requires **Anthropic API key** — may be disabled if key unavailable
- 🟡 App Store / Google Play listing **not created** (use App Distribution only)

---

→ After all items checked: follow [TESTFLIGHT_SETUP.md](TESTFLIGHT_SETUP.md) to distribute.
