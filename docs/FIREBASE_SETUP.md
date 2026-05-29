# Firebase Setup Guide — ENG Quest

> **CEO Action Required**: This guide must be completed by the project owner before closed alpha testing can begin. Estimated time: 45 minutes.

---

## Prerequisites

- Google account with billing enabled (Firebase Spark plan is free for MVP scale)
- Firebase CLI installed: `npm install -g firebase-tools`
- Logged in: `firebase login`

---

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Project name: **`engquest-mvp`**
4. Project ID: **`engquest-mvp`** (or `engquest-mvp-XXXX` if taken)
5. Enable Google Analytics: **Yes** (required for A/B testing)
6. Analytics account: create new → **"ENG Quest Analytics"**
7. Click **"Create project"** → wait ~30 seconds

---

## Step 2: Enable Authentication

1. In Firebase Console → **Authentication** → **Get started**
2. **Sign-in method** tab → **Anonymous** → **Enable** → Save

> ℹ️ Anonymous auth is used for COPPA compliance — no PII collected from children under 13. Parents can optionally link an email account later.

---

## Step 3: Enable Firestore

1. **Firestore Database** → **Create database**
2. Start in **production mode** (we'll set rules in Step 7)
3. Location: **`asia-northeast1`** (Tokyo) — lowest latency for Japanese users
4. Click **Enable**

---

## Step 4: Enable Analytics

Already enabled in Step 1. Verify:

1. **Analytics** → **Dashboard** → should show "Data collection active"
2. Enable **Google Analytics for Firebase** if prompted

---

## Step 5: Enable Cloud Messaging (FCM)

1. **Project Settings** (gear icon) → **Cloud Messaging** tab
2. FCM is enabled by default — verify **Firebase Cloud Messaging API (V1)** shows **Enabled**
3. Note the **Sender ID** (needed for Android config)

---

## Step 6: Add iOS App

1. **Project Overview** → **Add app** → iOS icon
2. **iOS bundle ID**: `co.aesthetic.engquest` *(confirm with developer)*
3. **App nickname**: `ENG Quest iOS`
4. **App Store ID**: leave blank (not on App Store yet)
5. Click **Register app**
6. **Download `GoogleService-Info.plist`**
7. Move file to: **`ios/Runner/GoogleService-Info.plist`**

```bash
cp ~/Downloads/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
```

8. Open `ios/Runner.xcworkspace` in Xcode
9. Drag `GoogleService-Info.plist` into the **Runner** group in the project navigator
10. Ensure **"Copy items if needed"** is checked → **Finish**
11. Skip the "Add Firebase SDK" step (already in `pubspec.yaml`)
12. Click **Continue to console**

---

## Step 7: Add Android App

1. **Project Overview** → **Add app** → Android icon
2. **Android package name**: `co.aesthetic.engquest` *(confirm with developer)*
3. **App nickname**: `ENG Quest Android`
4. **Debug signing certificate SHA-1**: run:

```bash
cd android
./gradlew signingReport
# Copy the SHA1 from "Variant: debug" → "Store: ~/.android/debug.keystore"
```

5. Click **Register app**
6. **Download `google-services.json`**
7. Move file to: **`android/app/google-services.json`**

```bash
cp ~/Downloads/google-services.json android/app/google-services.json
```

8. Skip SDK addition steps (already configured)
9. Click **Continue to console**

---

## Step 8: Update Firebase Config in Code

Replace all placeholder values in `lib/core/firebase/firebase_config.dart`:

```dart
// lib/core/firebase/firebase_config.dart
// Replace REPLACE_WITH_ACTUAL_* values with values from:
// Firebase Console → Project Settings → General → Your apps → SDK setup
```

Find your config values:
1. **Project Settings** (gear icon) → **General** tab
2. Scroll to **"Your apps"** section
3. Select the iOS or Android app
4. Copy each value from the **Firebase SDK snippet**

Values to replace:

| Placeholder | Where to find |
|-------------|---------------|
| `REPLACE_WITH_ACTUAL_API_KEY` | Project Settings → General → Web API key |
| `REPLACE_WITH_ACTUAL_APP_ID` | Project Settings → Your apps → App ID |
| `REPLACE_WITH_ACTUAL_MESSAGING_SENDER_ID` | Project Settings → Cloud Messaging → Sender ID |
| `REPLACE_WITH_ACTUAL_PROJECT_ID` | `engquest-mvp` (or your chosen project ID) |
| `REPLACE_WITH_ACTUAL_STORAGE_BUCKET` | `engquest-mvp.appspot.com` |

---

## Step 9: Firestore Security Rules

In **Firestore** → **Rules** tab, paste these rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only read/write their own data
    // Anonymous auth UID is stable per device install
    match /users/{userId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;

      // Child progress data — only owner can access (COPPA)
      match /progress/{document=**} {
        allow read, write: if request.auth != null
                           && request.auth.uid == userId;
      }

      // FSRS card state — per-user, per-card
      match /cards/{cardId} {
        allow read, write: if request.auth != null
                           && request.auth.uid == userId;
      }

      // Session logs — append-only for analytics
      match /sessions/{sessionId} {
        allow read: if request.auth != null
                    && request.auth.uid == userId;
        allow create: if request.auth != null
                      && request.auth.uid == userId;
        allow update, delete: if false; // Immutable audit log
      }
    }

    // Vocabulary content — read-only for authenticated users
    match /vocabulary/{document=**} {
      allow read: if request.auth != null;
      allow write: if false; // Admin SDK only
    }

    // A/B test assignments — read-only for assigned user
    match /ab_assignments/{userId} {
      allow read: if request.auth != null
                  && request.auth.uid == userId;
      allow write: if false; // Server-side assignment only
    }

    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

Click **Publish**.

### COPPA Compliance Notes

- No email, name, or PII stored in Firestore
- Anonymous UID is Firebase-generated (not linked to real identity)
- All child data scoped to `users/{uid}/` — no cross-user queries
- Session logs are append-only (forensic integrity for compliance audit)
- If user deletes app, UID is lost — data effectively orphaned (acceptable for minors)

---

## Step 10: FCM APNs Certificate Setup (iOS Push Notifications)

### Option A: APNs Authentication Key (Recommended)

1. Go to [Apple Developer Portal](https://developer.apple.com/) → **Certificates, Identifiers & Profiles**
2. **Keys** → **"+"** → Create new key
3. Name: `ENG Quest FCM Key`
4. Enable **Apple Push Notifications service (APNs)**
5. Click **Continue** → **Register** → **Download** the `.p8` file
6. Note your **Key ID** and **Team ID** (top-right of dev portal)

In Firebase Console:
1. **Project Settings** → **Cloud Messaging** → **Apple app configuration**
2. **APNs Authentication Key** → **Upload**
3. Upload the `.p8` file
4. Enter **Key ID** and **Team ID**
5. Click **Upload**

### Option B: APNs Certificate (Legacy)

> Only use if Option A is unavailable.

1. Apple Developer Portal → **Certificates** → **"+"**
2. Select **Apple Push Notification service SSL (Sandbox & Production)**
3. Select App ID: `co.aesthetic.engquest`
4. Follow CSR instructions → Download `.cer` file
5. Double-click to install in Keychain → Export as `.p12`
6. Upload `.p12` to Firebase Console → **Cloud Messaging** → **APNs Certificates**

---

## Step 11: Verify Setup

```bash
# Clean build to pick up new config files
flutter clean
flutter pub get
cd ios && pod install && cd ..

# Run on iOS simulator (no push notifs, but Firebase connects)
flutter run -d iPhone

# Expected console output:
# [Firebase] Configuring the default app.
# [FirebaseAuth] Successfully signed in anonymously. UID: XXXX
```

Check Firebase Console → **Authentication** → **Users** — you should see one anonymous user appear within 30 seconds of app launch.

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| `GoogleService-Info.plist not found` | Ensure file is in `ios/Runner/` AND added to Xcode project |
| `google-services.json not found` | Ensure file is at `android/app/google-services.json` |
| `FirebaseApp named "[DEFAULT]" already exists` | Call `Firebase.initializeApp()` only once in `main.dart` |
| Anonymous sign-in fails | Check Authentication is enabled in Firebase Console |
| Firestore permission denied | Verify security rules published and user is authenticated |
| APNs token not registering | Verify APNs key uploaded, bundle ID matches exactly |

---

## Post-Setup Checklist

After completing this guide, verify each item before proceeding to alpha:

- [ ] Firebase project `engquest-mvp` created
- [ ] Anonymous Authentication enabled
- [ ] Firestore database created (Tokyo region)
- [ ] `GoogleService-Info.plist` in `ios/Runner/`
- [ ] `google-services.json` in `android/app/`
- [ ] Placeholder API keys replaced in `firebase_config.dart`
- [ ] Firestore security rules published
- [ ] APNs key uploaded to FCM
- [ ] App launches and anonymous user appears in Firebase Console
- [ ] Share Firebase project ID with developer: `engquest-mvp`

→ Next step: [CLOSED_ALPHA_CHECKLIST.md](CLOSED_ALPHA_CHECKLIST.md)
