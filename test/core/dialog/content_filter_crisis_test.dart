// Verifies the child-safety crisis path: self-harm / suicidal-ideation input is
// detected and routed to a supportive message with crisis lines — NEVER scolded
// like profanity. (Fix 2026-06-02: a child typing "しにたい" must be supported.)

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/dialog/content_filter.dart';

void main() {
  group('ContentFilter crisis detection', () {
    test('detects Japanese self-harm signals', () {
      for (final s in ['しにたい', '死にたい', '消えたい', '自殺したい', 'リスカ']) {
        expect(ContentFilter.isCrisisSignal(s), isTrue, reason: s);
      }
    });

    test('detects English self-harm signals (case-insensitive)', () {
      for (final s in ['I want to die', 'kill myself', 'I hate myself', 'SUICIDE']) {
        expect(ContentFilter.isCrisisSignal(s), isTrue, reason: s);
      }
    });

    test('does NOT flag ordinary or merely rude input as crisis', () {
      for (final s in ['hello cat', 'I like apples', 'ばか', 'うざい']) {
        expect(ContentFilter.isCrisisSignal(s), isFalse, reason: s);
      }
    });

    test('crisis message is supportive — has a crisis line, never the scold', () {
      final m = ContentFilter.crisisMessage();
      expect(m, contains('チャイルドライン'));
      expect(m, contains('0120'));
      expect(m, isNot(contains('使えない'))); // not the profanity rejection
    });

    test('self-harm phrase no longer triggers the profanity rejection path', () {
      // sanitize() still rejects profanity, but self-harm is handled upstream
      // by isCrisisSignal; ensure profanity rejection still works for actual swears.
      expect(ContentFilter.sanitize('ばか'), isNull);
      expect(ContentFilter.rejectionMessage(), isNot(contains('チャイルドライン')));
    });
  });
}
