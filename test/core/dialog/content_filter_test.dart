// test/core/dialog/content_filter_test.dart
//
// Locks the 2026-06-08 product decision (CEO): the app does NOT react to
// individual words a child types. Profanity / self-harm phrasing in INPUT is
// neither scolded nor blocked — only length-capped and stripped of personal
// info. The model's OUTPUT is still filtered (protecting the child from the AI),
// and a child's personal info is still kept out of the external request.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/dialog/content_filter.dart';

void main() {
  group('sanitize — no word-policing of the child (CEO 2026-06-08)', () {
    test('profanity is NOT rejected — passes through unchanged', () {
      expect(
          ContentFilter.sanitize('you are stupid'), equals('you are stupid'));
    });

    test('self-harm phrasing is NOT scolded/blocked — passes through (#62)',
        () {
      // The whole reason this decision exists: a child must never be scolded for
      // expressing distress. The app simply does not react to the words.
      expect(ContentFilter.sanitize('I want to die'), equals('I want to die'));
      expect(ContentFilter.sanitize('しにたい'), equals('しにたい'));
    });

    test('ordinary input passes through', () {
      expect(ContentFilter.sanitize('Hello! I like dogs.'),
          equals('Hello! I like dogs.'));
    });

    test('empty / whitespace-only → null (nothing to send)', () {
      expect(ContentFilter.sanitize('   '), isNull);
    });

    test('length is capped, not rejected', () {
      final long = 'a' * 500;
      final out = ContentFilter.sanitize(long);
      expect(out, isNotNull);
      expect(out!.length, equals(ContentFilter.maxLength));
    });

    test(
        'personal info is kept out of the request (privacy, not word-policing)',
        () {
      expect(ContentFilter.sanitize('call me at 090-1234-5678'), isNull);
      expect(ContentFilter.sanitize('email me@example.com'), isNull);
    });
  });

  group('filterResponse — the AI OUTPUT is still kept child-safe', () {
    test('inappropriate model output is replaced with a safe fallback', () {
      final filtered = ContentFilter.filterResponse('you are stupid');
      expect(filtered, isNot(contains('stupid')));
      expect(filtered, isNotEmpty);
    });

    test('clean model output passes through unchanged', () {
      const clean = 'Great job! Dogs are fun. What else do you like?';
      expect(ContentFilter.filterResponse(clean), equals(clean));
    });
  });
}
