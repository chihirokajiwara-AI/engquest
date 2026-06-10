// test/features/parent_dashboard/reminder_persist_test.dart
// #122: the parent reminder time used to be discarded on close (a fake setting).
// It is now persisted, gated on a `reminderConfigured` flag because getInt can't
// distinguish "unset" from 0:00. Locks that contract.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/core/storage/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
  });

  test('unconfigured → restore must NOT fire (default time kept, not 0:00)',
      () async {
    final prefs = await PreferencesService.getInstance();
    expect(prefs.getBool(PrefKeys.reminderConfigured), isFalse,
        reason: 'a fresh user has not set a reminder');
  });

  test('a chosen reminder time round-trips and is flagged configured',
      () async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setInt(PrefKeys.reminderHour, 7);
    await prefs.setInt(PrefKeys.reminderMinute, 30);
    await prefs.setBool(PrefKeys.reminderConfigured, true);

    PreferencesService.resetInstance(); // simulate a fresh launch
    final reloaded = await PreferencesService.getInstance();
    expect(reloaded.getBool(PrefKeys.reminderConfigured), isTrue);
    expect(reloaded.getInt(PrefKeys.reminderHour), equals(7));
    expect(reloaded.getInt(PrefKeys.reminderMinute), equals(30));
  });
}
