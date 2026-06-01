// test/firestore/security_rules_test.dart
// ENG Quest — Firestore Security Rules: Unit Test Plan
//
// IMPORTANT: These are SPECIFICATION tests. Run them with the Firebase
// Emulator Suite (NOT against production Firestore).
//
// Setup:
//   npm install -g firebase-tools
//   firebase emulators:start --only firestore
//   dart test test/firestore/security_rules_test.dart
//
// Alternative (JavaScript): use @firebase/rules-unit-testing package
//   See: docs/spec/firestore_rules_test.js for the JS equivalent.
//
// NOTE: Dart cannot run Firebase Rules unit tests natively.
// This file documents the test matrix that must be verified manually
// or via the JS test suite (firestore_rules_test.js).

// ── TEST MATRIX ─────────────────────────────────────────────────────────────
//
// Legend:
//   ✅ = ALLOW expected
//   ❌ = DENY expected
//   uid_A = "user-alice-001" (authenticated)
//   uid_B = "user-bob-002"   (different authenticated user)
//   anon  = unauthenticated (no auth token)
//
// 1. UNAUTHENTICATED ACCESS
//   ❌ anon  → read  users/uid_A/profile
//   ❌ anon  → write users/uid_A/cards/eiken5_001
//   ❌ anon  → read  vocabulary/eiken5_001
//
// 2. CROSS-USER ACCESS (uid_B accessing uid_A's data)
//   ❌ uid_B → read  users/uid_A/profile
//   ❌ uid_B → write users/uid_A/cards/eiken5_001
//   ❌ uid_B → read  users/uid_A/sessions/2026-05-29
//
// 3. OWN DATA ACCESS (uid_A accessing own data)
//   ✅ uid_A → read  users/uid_A/profile
//   ✅ uid_A → write users/uid_A/profile {totalXp: 150, level: 2}
//   ✅ uid_A → write users/uid_A/cards/eiken5_001 {stability: 3.5, state: "review", ...}
//   ✅ uid_A → read  users/uid_A/cards/eiken5_001
//   ✅ uid_A → write users/uid_A/sessions/2026-05-29 {wordsPracticed: 10, minutes: 5}
//
// 4. VALIDATION — PROFILE
//   ❌ uid_A → write users/uid_A/profile {totalXp: -1}       // negative XP
//   ❌ uid_A → write users/uid_A/profile {totalXp: 1000000}  // > 999999
//   ❌ uid_A → write users/uid_A/profile {level: 0}          // below min
//   ❌ uid_A → write users/uid_A/profile {level: 101}        // above max
//   ✅ uid_A → write users/uid_A/profile {totalXp: 0, level: 1, streak: 7}
//
// 5. VALIDATION — CARDS
//   ❌ uid_A → write users/uid_A/cards/eiken5_001 {stability: -1.0}
//   ❌ uid_A → write users/uid_A/cards/eiken5_001 {stability: 1001.0}
//   ❌ uid_A → write users/uid_A/cards/eiken5_001 {state: "invalid_state"}
//   ❌ uid_A → write users/uid_A/cards/eiken5_001 {lapses: -1}
//   ❌ uid_A → create users/uid_A/cards/bad id! {stability: 1.0} // invalid cardId
//   ✅ uid_A → write users/uid_A/cards/eiken5_001 {stability: 3.5, difficulty: 5.0, state: "review", lapses: 0, repetitions: 3}
//
// 6. VALIDATION — SESSIONS
//   ❌ uid_A → write users/uid_A/sessions/not-a-date {wordsPracticed: 5}
//   ❌ uid_A → write users/uid_A/sessions/2026-05-29 {wordsPracticed: 1001}
//   ❌ uid_A → write users/uid_A/sessions/2026-05-29 {minutes: 481}
//   ❌ uid_A → write users/uid_A/sessions/2026-05-29 {avgScore: 4.1}
//   ✅ uid_A → write users/uid_A/sessions/2026-05-29 {wordsPracticed: 10, minutes: 5, avgScore: 3.0}
//
// 7. SHARED VOCABULARY
//   ✅ uid_A → read  vocabulary/eiken5_001
//   ❌ uid_A → write vocabulary/eiken5_001 {word: "hacked"}
//   ❌ uid_B → write vocabulary/eiken5_001 {word: "hacked"}
//
// 8. EXPERIMENTS
//   ✅ uid_A → read  experiments/ab_battle_v1
//   ❌ uid_A → write experiments/ab_battle_v1
//
// 9. UNKNOWN PATHS
//   ❌ uid_A → read  /admin/secret
//   ❌ uid_A → write /hack/data
//

void main() {
  // This file is documentation — the actual tests run in the Firebase
  // Emulator using the JS test suite at:
  //   test/firestore/firestore_rules_test.js
  //
  // To run manually:
  //   cd engquest
  //   firebase emulators:exec "node test/firestore/firestore_rules_test.js"
  // ignore: avoid_print
  print('Security rules test matrix: see comments in this file.');
  // ignore: avoid_print
  print(
      'Run JS suite: firebase emulators:exec "node test/firestore/firestore_rules_test.js"');
}
