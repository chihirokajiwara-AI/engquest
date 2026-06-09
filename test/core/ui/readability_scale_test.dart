// test/core/ui/readability_scale_test.dart
// #114: opt-in readability text-size — persist round-trip, clamping, labels.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/core/ui/readability_scale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReadabilityScale.notifier.value = 1.0; // reset between tests
  });

  test('default is 1.0 (unchanged) when nothing persisted', () async {
    await ReadabilityScale.load();
    expect(ReadabilityScale.value, equals(1.0));
  });

  test('set persists and load reads it back', () async {
    await ReadabilityScale.set(1.3);
    expect(ReadabilityScale.value, equals(1.3));
    ReadabilityScale.notifier.value = 1.0; // simulate a fresh launch
    await ReadabilityScale.load();
    expect(ReadabilityScale.value, equals(1.3));
  });

  test('set clamps out-of-range values to [1.0, 1.3]', () async {
    await ReadabilityScale.set(99.0);
    expect(ReadabilityScale.value, equals(1.3));
    await ReadabilityScale.set(0.1);
    expect(ReadabilityScale.value, equals(1.0));
  });

  test('the notifier fires so the app root can resize live', () async {
    double? heard;
    void listener() => heard = ReadabilityScale.value;
    ReadabilityScale.notifier.addListener(listener);
    await ReadabilityScale.set(1.15);
    ReadabilityScale.notifier.removeListener(listener);
    expect(heard, equals(1.15));
  });

  test('labels are child-facing JP', () {
    expect(ReadabilityScale.labelJa(1.0), contains('ふつう'));
    expect(ReadabilityScale.labelJa(1.15), contains('大'));
    expect(ReadabilityScale.labelJa(1.3), contains('とても'));
  });
}
