// Locks the pre-reader contract (flaw-hunt 2026-06-13): a young child (age ≤7)
// is NOT forced through the English-text placement quiz — they're placed at the
// 5級 floor and sent straight to avatar select. (The full-flow widget render can't
// be asserted here because the avatar step's ScrollSafe/IntrinsicHeight trips the
// test viewport; this locks the decision threshold + the floor placement, which
// is the substance of the fix.)

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';

void main() {
  test('pre-reader threshold is age ≤7', () {
    expect(kPreReaderMaxAge, 7);
  });

  test('onboarding age floor is 6 (CEO 1889: target 6+, not 4-5)', () {
    // The picker offers 6..18 (decrement guarded by `age > kMinSelectableAge`).
    // Drift guard: if this reverts to 4, we are over-accommodating a low age
    // that shrinks the 母数. The pre-reader quiz-skip stays separate (≤7).
    expect(kMinSelectableAge, 6);
  });

  test('pre-reader is placed at the 5級 floor (honest, level-up later)', () {
    expect(kPreReaderPlacement.grade, 0);
    expect(kPreReaderPlacement.eikenLevel, '5');
    expect(kPreReaderPlacement.theta, 0.0);
  });
}
