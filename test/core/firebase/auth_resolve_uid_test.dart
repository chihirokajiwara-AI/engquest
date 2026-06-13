// Identity-stability gate (#14, flaw-hunt 2026-06-13): the durable FSRS deck is
// keyed per-uid, so the offline fallback uid MUST be stable across sessions or a
// child's progress forks. resolveUid(), when Firebase is unavailable (the case in
// this test harness — Firebase is never initialized), must reuse the last
// persisted real uid rather than blindly forking to the 'offline_user' sentinel.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/core/firebase/auth_service.dart';
import 'package:engquest/core/storage/preferences_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
  });

  test('with no persisted uid, falls back to the shared offline sentinel',
      () async {
    final uid = await AuthService().resolveUid();
    expect(uid, AuthService.offlineUid);
  });

  test('reuses a previously persisted real uid instead of forking', () async {
    // A prior good session persisted the real anon uid.
    SharedPreferences.setMockInitialValues({PrefKeys.uid: 'real_anon_abc123'});
    PreferencesService.resetInstance();

    // A later session where Firebase init flakes must keep the SAME uid,
    // so it writes to the same fsrs_deck_<uid> rather than fsrs_deck_offline_user.
    final uid = await AuthService().resolveUid();
    expect(uid, 'real_anon_abc123');
    expect(uid, isNot(AuthService.offlineUid));
  });

  test('an empty persisted uid is treated as absent', () async {
    SharedPreferences.setMockInitialValues({PrefKeys.uid: ''});
    PreferencesService.resetInstance();
    final uid = await AuthService().resolveUid();
    expect(uid, AuthService.offlineUid);
  });
}
