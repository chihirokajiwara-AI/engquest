// HintCoinService — coins must be FINITE (flaw-hunt R9).
//
// The old balance() returned the seed (10) whenever the stored value read 0,
// and getInt returns 0 for BOTH "never initialised" and "spent to 0" — so a
// child who spent all their coins, left, and returned got 10 back every time,
// making the hint scaffold unlimited. A persisted "seeded" flag now distinguishes
// first-ever-init from a legitimate 0 balance.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/core/gamification/hint_coin_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
  });

  test('first access seeds 10; spending to 0 stays 0 across new instances', () async {
    final svc = HintCoinService();
    expect(await svc.balance(), 10, reason: 'first access seeds the wallet');

    final r = await svc.spend(10); // spend everything
    expect(r.ok, isTrue);
    expect(r.balance, 0);
    expect(await svc.balance(), 0, reason: 'same instance must read the real 0');

    // A fresh instance (e.g. navigating to a new screen) must NOT reseed to 10.
    final svc2 = HintCoinService();
    expect(await svc2.balance(), 0,
        reason: 'spent-to-0 must persist — no infinite hint coins');
  });

  test('a legitimate non-zero balance is preserved across instances', () async {
    final svc = HintCoinService();
    await svc.balance(); // seed 10
    await svc.spend(3); // → 7
    final svc2 = HintCoinService();
    expect(await svc2.balance(), 7);
  });

  test('cannot spend more than the balance', () async {
    final svc = HintCoinService();
    await svc.balance(); // seed 10
    final r = await svc.spend(99);
    expect(r.ok, isFalse);
    expect(r.balance, 10, reason: 'failed spend leaves the balance intact');
  });
}
