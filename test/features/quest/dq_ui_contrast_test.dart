// WCAG 2.2 AA contrast gate for the dq_ui palette (a11y, flaw-hunt 2026-06-14).
//
// The dark 本格 theme is light-text-on-dark (high contrast) with dark text on the
// gold action buttons — verified compliant. But the contrast holds only by
// CONVENTION: nothing stops a future palette tweak (darkening dqInk, lightening
// dqBox) from silently dropping a core text pairing below the AA threshold (4.5:1
// for normal text, 3.0:1 for large/bold ≥18.66px). This locks the key pairings.
// Pure colour math — no rendering needed.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

// [s] is a 0..1 linear channel (Flutter 3.44 Color.r/.g/.b are 0..1 doubles).
double _channel(double s) =>
    s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // The dark brown used for text on gold action buttons (home CTA / battle badge
  // / parent selectors). Keep in sync with those call sites.
  const goldButtonText = Color(0xFF2A1C00);

  group('dq_ui WCAG-AA contrast', () {
    test('sanity: pure black on white is ~21:1', () {
      expect(contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
          closeTo(21, 0.5));
    });

    // Normal text (4.5:1): the body/label pairings on dark surfaces.
    final normal = <String, List<Color>>{
      'ink on panel (dqBox)': [dqInk, dqBox],
      'ink on bg (dqNight0)': [dqInk, dqNight0],
      'gold heading on panel': [dqGold, dqBox],
      'gold on bg': [dqGold, dqNight0],
      'deep-gold caption on panel': [dqGoldDeep, dqBox],
      'dark text on a gold button': [goldButtonText, dqGold],
    };
    normal.forEach((name, pair) {
      test('$name meets AA normal (>=4.5:1)', () {
        final r = contrast(pair[0], pair[1]);
        expect(r, greaterThanOrEqualTo(4.5),
            reason: '$name is ${r.toStringAsFixed(2)}:1 — below WCAG-AA 4.5');
      });
    });

    // The dark-on-gold convention exists BECAUSE the inverse fails. Document it so
    // nobody "fixes" a gold button by switching its text to cream (2.3:1).
    test('cream text on gold would FAIL — gold buttons must use dark text', () {
      expect(contrast(dqInk, dqGold), lessThan(4.5),
          reason:
              'cream-on-gold is low contrast; the convention is dark-on-gold');
    });
  });
}
