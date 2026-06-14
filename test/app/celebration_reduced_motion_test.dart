// Reduce-motion invariant for the level-up / achievement celebration banners
// (a11y flaw-hunt 2026-06-14). The banners pop in with an easeOutBack scale
// overshoot (a bounce) — a vestibular trigger. With the OS reduce-motion setting
// on, the scale must stay at 1.0 (no bounce); only the opacity fade plays, which
// is motion-safe. Both hosts share celebrationBannerAppear().

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/app.dart';

void main() {
  group('celebrationBannerAppear (reduce-motion)', () {
    test('reduce-motion → 1.0 at every t (no scale-in, no overshoot)', () {
      for (final t in [0.0, 0.05, 0.12, 0.5, 1.0]) {
        expect(celebrationBannerAppear(t, reduceMotion: true), 1.0,
            reason: 'reduce-motion must not animate the scale at t=$t');
      }
    });

    test('motion ON → scales in from below 1.0 (a real pop-in)', () {
      // Early in the pop-in window the banner is smaller than full size.
      expect(celebrationBannerAppear(0.0, reduceMotion: false), lessThan(1.0));
      expect(celebrationBannerAppear(0.03, reduceMotion: false), lessThan(1.0));
    });

    test('motion ON → easeOutBack overshoots above 1.0 near the end of pop-in',
        () {
      // The bounce: just before settling, the curve exceeds 1.0. This is the
      // exact motion reduce-motion suppresses.
      final near = celebrationBannerAppear(0.11, reduceMotion: false);
      expect(near, greaterThan(1.0));
    });
  });
}
