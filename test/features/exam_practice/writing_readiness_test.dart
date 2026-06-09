import 'package:engquest/features/exam_practice/writing_practice_screen.dart';
import 'package:engquest/features/exam_practice/writing_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

// Honesty-focused tests for the offline writing readiness engine (#100).
// The engine must (a) measure objective form facts correctly and (b) NEVER
// present a quality grade — it only ever returns checks + an honest headline.

const _emailPrompt = WritingPrompt(
  id: 't_email',
  type: WritingTaskType.email,
  instructionJa: '返信メールを書いてください。',
  instructionEn: 'Write a reply.',
  stimulus: 'Hi! I heard you got a new pet. What kind of animal is it? '
      'What does it like to eat?',
  underlinedQuestions: [
    'What kind of animal is it?',
    'What does it like to eat?',
  ],
  wordCountMin: 15,
  wordCountMax: 25,
  rubricPoints: ['内容 / Content', '語彙 / Vocabulary', '文法 / Grammar'],
);

const _opinionPrompt = WritingPrompt(
  id: 't_opinion',
  type: WritingTaskType.opinion,
  instructionJa: '意見を書いてください。',
  instructionEn: 'State your opinion.',
  stimulus: 'Do you think students should study English every day?',
  wordCountMin: 25,
  wordCountMax: 35,
  rubricPoints: ['内容', '構成', '語彙', '文法'],
);

const _summaryPrompt = WritingPrompt(
  id: 't_summary',
  type: WritingTaskType.summary,
  instructionJa: '要約してください。',
  instructionEn: 'Summarize.',
  stimulus: 'Many people enjoy playing sports in their free time. '
      'Sports can keep the body healthy and help people make new friends. '
      'However, some sports can be dangerous and cause injuries.',
  wordCountMin: 15,
  wordCountMax: 25,
  rubricPoints: ['内容', '構成', '語彙', '文法'],
);

WritingCheck _check(WritingReadiness r, String id) =>
    r.checks.firstWhere((c) => c.id == id);

void main() {
  group('countWords', () {
    test('counts whitespace-separated tokens, ignores extra spaces', () {
      expect(countWords('  I have   two dogs.  '), 4);
      expect(countWords(''), 0);
      expect(countWords('   '), 0);
    });
  });

  group('empty submission', () {
    test('is flagged empty with no checks and an honest headline', () {
      final r = evaluateWritingReadiness(_emailPrompt, '   ');
      expect(r.isEmpty, isTrue);
      expect(r.checks, isEmpty);
      expect(r.formComplete, isFalse);
      expect(r.headlineJa, contains('まだ'));
    });
  });

  group('word-count HARD gate (the all-観点-0 trap)', () {
    test('too few words fails HARD and headline warns of 0点', () {
      final r = evaluateWritingReadiness(_emailPrompt, 'My pet is a cat.');
      final wc = _check(r, 'word_count');
      expect(wc.kind, WritingCheckKind.hard);
      expect(wc.status, WritingCheckStatus.fail);
      expect(r.wordCountOutOfRange, isTrue);
      expect(r.hasHardViolation, isTrue);
      expect(r.headlineJa, contains('0点'));
    });

    test('too many words fails HARD', () {
      final long = List.filled(40, 'word').join(' ');
      final r = evaluateWritingReadiness(_emailPrompt, '$long.');
      expect(_check(r, 'word_count').status, WritingCheckStatus.fail);
      expect(r.wordCountOutOfRange, isTrue);
    });

    test('in-range word count passes the HARD gate', () {
      final text = 'My new pet is a small brown dog. '
          'It loves to eat chicken and rice every single day.';
      final r = evaluateWritingReadiness(_emailPrompt, text);
      expect(_check(r, 'word_count').status, WritingCheckStatus.ok);
      expect(r.wordCountOutOfRange, isFalse);
    });
  });

  group('gibberish / off-language HARD filter', () {
    test('random characters fail the english_attempt check', () {
      final r = evaluateWritingReadiness(
          _emailPrompt, 'xqzk wprmn vbbt zzzz qqqq jklm');
      expect(_check(r, 'english_attempt').status, WritingCheckStatus.fail);
      expect(r.hasHardViolation, isTrue);
    });

    test('real English passes the english_attempt check', () {
      final r = evaluateWritingReadiness(
          _emailPrompt, 'I have a new dog and it is very cute and friendly.');
      expect(_check(r, 'english_attempt').status, WritingCheckStatus.ok);
    });
  });

  group('email completeness HINTs', () {
    test('overlap with question content words marks both ok (advisory)', () {
      // The heuristic is literal content-word overlap, so the answer must
      // actually reuse the question's words to be confirmed — true positive.
      final text = 'The animal is a friendly brown dog. '
          'It likes to eat chicken and fresh rice every day.';
      final r = evaluateWritingReadiness(_emailPrompt, text);
      expect(_check(r, 'email_q1').kind, WritingCheckKind.hint);
      expect(_check(r, 'email_q1').status, WritingCheckStatus.ok); // "animal"
      expect(_check(r, 'email_q2').status, WritingCheckStatus.ok); // "eat"
    });

    test('a synonym the heuristic cannot know only WARNs (honest advisory)',
        () {
      // "dog" does not literally match "animal/kind" — the engine must not
      // pretend to confirm it; an advisory warn (double-check) is the honest
      // outcome, never a HARD fail.
      final text = 'My pet is a friendly brown dog named Max. '
          'It loves to eat chicken, rice, and some fresh green beans daily.';
      final r = evaluateWritingReadiness(_emailPrompt, text);
      expect(_check(r, 'email_q1').status, WritingCheckStatus.warn);
      expect(_check(r, 'email_q1').kind, WritingCheckKind.hint);
    });
  });

  group('opinion completeness HINTs', () {
    test('opinion + two reasons + conclusion all detected', () {
      final text = 'I think students should study English every day. '
          'First, daily practice helps memory. '
          'Second, it builds confidence. Therefore, studying daily is best.';
      final r = evaluateWritingReadiness(_opinionPrompt, text);
      expect(_check(r, 'opinion_stated').status, WritingCheckStatus.ok);
      expect(_check(r, 'two_reasons').status, WritingCheckStatus.ok);
      expect(_check(r, 'conclusion').status, WritingCheckStatus.ok);
    });

    test('no opinion marker and one reason warn (advisory, not fail)', () {
      final text = 'English is a language. Many people use it around the world '
          'and in many different countries across the whole entire planet.';
      final r = evaluateWritingReadiness(_opinionPrompt, text);
      expect(_check(r, 'opinion_stated').status, WritingCheckStatus.warn);
      expect(_check(r, 'two_reasons').status, WritingCheckStatus.warn);
      // advisory warnings are HINT, never HARD
      expect(_check(r, 'opinion_stated').kind, WritingCheckKind.hint);
    });
  });

  group('summary verbatim-copy HINT', () {
    test('copying a long run from the source is flagged', () {
      final r = evaluateWritingReadiness(_summaryPrompt,
          'Many people enjoy playing sports in their free time for fun today.');
      expect(_check(r, 'not_verbatim').status, WritingCheckStatus.warn);
    });

    test('paraphrasing is not flagged as copy', () {
      final r = evaluateWritingReadiness(_summaryPrompt,
          'Sports keep us healthy and help us meet others, but a few are risky.');
      expect(_check(r, 'not_verbatim').status, WritingCheckStatus.ok);
    });
  });

  group('honesty invariants', () {
    test('engine never emits a numeric quality score or rubric grade', () {
      final text = 'I think English is great. First, it is fun. '
          'Second, it is useful. Therefore I study it every day with joy.';
      final r = evaluateWritingReadiness(_opinionPrompt, text);
      // No check or headline may contain a "/4", "点", or a rubric観点 verdict.
      for (final c in r.checks) {
        expect(c.detailJa.contains('/4'), isFalse,
            reason: '${c.id} must not present a 0-4 grade');
      }
      // The only place 点 may appear is the HARD word-count 0点 warning.
      final scoreMentions =
          r.checks.where((c) => c.detailJa.contains('点')).toList();
      for (final c in scoreMentions) {
        expect(c.id, 'word_count',
            reason: 'only the word-count rule may mention 点');
      }
      expect(r.headlineJa.contains('/4'), isFalse);
    });

    test('a well-formed complete submission reports formComplete but no grade',
        () {
      final text = 'I think students should study English every day. '
          'First, daily practice improves memory a lot. '
          'Second, it builds real confidence. Therefore, daily study is best.';
      final r = evaluateWritingReadiness(_opinionPrompt, text);
      expect(r.hasHardViolation, isFalse);
      expect(r.formComplete, isTrue);
      // formComplete is explicitly a FORM verdict, surfaced honestly:
      expect(r.headlineJa, contains('質は AI採点'));
    });
  });
}
