// Offline 英検 writing readiness checker (#100).
//
// HONESTY CONTRACT — read before changing:
//   This does NOT grade writing quality. Quality (the 語彙/文法 axes of the
//   official 内容/構成/語彙/文法 rubric) cannot be honestly judged on-device
//   without a trained model — 2026 AES research shows rule-based systems pass
//   QWK yet fail validity on real text, and fabricating a quality score is the
//   launch-blocker lie #100 was escalated for. So this engine measures ONLY what
//   surface analysis can assert truthfully, and every check is tagged with how
//   much we can trust it:
//     • HARD  — machine-certain, objective fact (word count, empty, gibberish).
//               The 英検 word-count rule is a real hard gate: out of range →
//               every 観点 scores 0 (verified eiken.or.jp / 旺文社 2025-26).
//     • HINT  — heuristic 目安 (did you answer the question, give 2 reasons,
//               use connectives, copy verbatim, capitalize). Helpful and honest
//               ONLY when surfaced as advisory, never as a grade.
//   Nothing here feeds the 合格率 quality axis; that stays AI-graded (honest
//   未測定 offline). This output drives concrete, actionable offline practice.
//
// Web-safe: pure Dart, no dart:io.

import 'writing_practice_screen.dart' show WritingPrompt, WritingTaskType;

/// How much trust a check's verdict carries — see the honesty contract above.
enum WritingCheckKind {
  /// Machine-certain objective fact.
  hard,

  /// Heuristic 目安 — advisory only.
  hint,
}

enum WritingCheckStatus { ok, warn, fail }

/// One objective/advisory observation about a submission.
class WritingCheck {
  final String id;
  final WritingCheckKind kind;
  final WritingCheckStatus status;

  /// Short label (Japanese, learner-facing).
  final String labelJa;

  /// Concrete, actionable detail (what was found / what to do).
  final String detailJa;

  const WritingCheck({
    required this.id,
    required this.kind,
    required this.status,
    required this.labelJa,
    required this.detailJa,
  });
}

/// The result of an offline readiness pass over one submission.
class WritingReadiness {
  final int wordCount;
  final int wordMin;
  final int wordMax;
  final WritingTaskType taskType;
  final List<WritingCheck> checks;

  const WritingReadiness({
    required this.wordCount,
    required this.wordMin,
    required this.wordMax,
    required this.taskType,
    required this.checks,
  });

  bool get isEmpty => wordCount == 0;

  /// True when a HARD check failed — at minimum these MUST be fixed or the
  /// real exam scores the whole task 0 (word count) or it isn't a valid English
  /// attempt (gibberish).
  bool get hasHardViolation => checks.any((c) =>
      c.kind == WritingCheckKind.hard && c.status == WritingCheckStatus.fail);

  /// Word-count specifically out of the official range (the all-観点-0 trap).
  bool get wordCountOutOfRange =>
      wordCount > 0 && (wordCount < wordMin || wordCount > wordMax);

  /// All objective gates clear AND no advisory warning — the submission is
  /// well-formed and complete to the extent a machine can tell. This is NOT a
  /// quality verdict; it never claims the writing is *good*, only *valid and
  /// complete in form*.
  bool get formComplete =>
      !isEmpty &&
      !hasHardViolation &&
      !checks.any((c) => c.status == WritingCheckStatus.warn);

  /// Honest one-line headline for the learner — never a score.
  String get headlineJa {
    if (isEmpty) return 'まだ なにも 書かれていません。';
    if (wordCountOutOfRange) {
      return wordCount < wordMin
          ? '語数が たりません（本番では これで 0点）。'
          : '語数が 多すぎます（本番では これで 0点）。';
    }
    if (hasHardViolation) return 'まず 英文の 形を ととのえましょう。';
    if (formComplete) {
      return '提出の 形は OK。中身の 質は AI採点（接続後）で 確認します。';
    }
    return 'あと すこし。下の めやすを 直すと より良くなります。';
  }
}

// ── Lexicon ──────────────────────────────────────────────────────────────────

const Set<String> _stopwords = {
  'the',
  'a',
  'an',
  'and',
  'or',
  'but',
  'if',
  'so',
  'as',
  'of',
  'to',
  'in',
  'on',
  'at',
  'for',
  'with',
  'by',
  'from',
  'about',
  'into',
  'is',
  'am',
  'are',
  'was',
  'were',
  'be',
  'been',
  'being',
  'do',
  'does',
  'did',
  'have',
  'has',
  'had',
  'will',
  'would',
  'can',
  'could',
  'should',
  'shall',
  'may',
  'might',
  'must',
  'i',
  'you',
  'he',
  'she',
  'it',
  'we',
  'they',
  'me',
  'him',
  'her',
  'us',
  'them',
  'my',
  'your',
  'his',
  'its',
  'our',
  'their',
  'this',
  'that',
  'these',
  'those',
  'what',
  'when',
  'where',
  'who',
  'why',
  'how',
  'not',
  'no',
  'yes',
  'there',
  'here',
  'too',
  'very',
  'just',
  'than',
  'then',
};

/// Common English function words used to tell a real English attempt from
/// random characters / romaji spam.
const Set<String> _commonEnglish = {
  'the',
  'a',
  'is',
  'are',
  'to',
  'and',
  'i',
  'it',
  'you',
  'my',
  'we',
  'they',
  'in',
  'of',
  'for',
  'have',
  'like',
  'this',
  'that',
  'because',
  'so',
  'but',
  'with',
  'do',
  'can',
  'will',
  'think',
  'want',
  'go',
  'good',
};

const List<String> _opinionMarkers = [
  'i think',
  'i believe',
  'in my opinion',
  'i agree',
  'i disagree',
  'i feel',
  'i would',
  'should',
  'i like',
  'i want',
  'i prefer',
];

const List<String> _reasonMarkers = [
  'because',
  'first',
  'second',
  'firstly',
  'secondly',
  'one reason',
  'another reason',
  'also',
  'for example',
  'since',
  'the reason',
];

const List<String> _conclusionMarkers = [
  'in conclusion',
  'therefore',
  'that is why',
  "that's why",
  'to sum up',
  'for these reasons',
  'in summary',
  'so i',
  'so,',
];

const List<String> _connectives = [
  'first',
  'second',
  'also',
  'however',
  'therefore',
  'because',
  'so',
  'for example',
  'in conclusion',
  'and',
  'but',
  'then',
  'next',
];

// ── Tokenisation helpers ─────────────────────────────────────────────────────

/// Word count using the 英検 convention of whitespace-separated tokens.
int countWords(String text) {
  final t = text.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

List<String> _contentWords(String text) {
  final out = <String>[];
  for (final raw in text.toLowerCase().split(RegExp(r'[^a-z]+'))) {
    if (raw.length < 3) continue;
    if (_stopwords.contains(raw)) continue;
    out.add(raw);
  }
  return out;
}

List<String> _sentences(String text) => text
    .split(RegExp(r'[.!?]+'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

bool _containsAny(String lower, List<String> needles) =>
    needles.any(lower.contains);

int _countDistinct(String lower, List<String> needles) =>
    needles.where(lower.contains).length;

// ── Engine ───────────────────────────────────────────────────────────────────

/// Evaluate [text] against [prompt] using only honest surface analysis.
WritingReadiness evaluateWritingReadiness(WritingPrompt prompt, String text) {
  final words = countWords(text);
  final lower = text.toLowerCase();
  final checks = <WritingCheck>[];

  if (words == 0) {
    return WritingReadiness(
      wordCount: 0,
      wordMin: prompt.wordCountMin,
      wordMax: prompt.wordCountMax,
      taskType: prompt.type,
      checks: const [],
    );
  }

  // 1) HARD — word count (the all-観点-0 trap).
  {
    final inRange =
        words >= prompt.wordCountMin && words <= prompt.wordCountMax;
    final detail = inRange
        ? '$words語（目安 ${prompt.wordCountMin}〜${prompt.wordCountMax}語）。OK。'
        : (words < prompt.wordCountMin
            ? '$words語。あと ${prompt.wordCountMin - words}語 たりません。'
                '本番では 語数不足で 全観点 0点になります。'
            : '$words語。${words - prompt.wordCountMax}語 多いです。'
                '本番では 語数オーバーで 全観点 0点になります。');
    checks.add(WritingCheck(
      id: 'word_count',
      kind: WritingCheckKind.hard,
      status: inRange ? WritingCheckStatus.ok : WritingCheckStatus.fail,
      labelJa: '語数（${prompt.wordCountMin}〜${prompt.wordCountMax}語）',
      detailJa: detail,
    ));
  }

  // 2) HARD — is this a real English attempt (gibberish / off-language filter)?
  {
    final letters = RegExp(r'[a-zA-Z]').allMatches(text).length;
    final nonSpace = text.replaceAll(RegExp(r'\s'), '').length;
    final letterRatio = nonSpace == 0 ? 0.0 : letters / nonSpace;
    final commonHits =
        _commonEnglish.where((w) => RegExp('\\b$w\\b').hasMatch(lower)).length;
    final looksEnglish = letterRatio >= 0.55 && (commonHits >= 2 || words >= 8);
    checks.add(WritingCheck(
      id: 'english_attempt',
      kind: WritingCheckKind.hard,
      status: looksEnglish ? WritingCheckStatus.ok : WritingCheckStatus.fail,
      labelJa: '英語で 書けているか',
      detailJa: looksEnglish
          ? '英語の 文として 認識できました。'
          : '英語の 文に 見えません。ローマ字や 記号だけに なっていないか 確認しましょう。',
    ));
  }

  // 3) HINT — on-topic (validity): overlap with the prompt's content words.
  {
    final promptWords = <String>{
      ..._contentWords(prompt.stimulus),
      for (final q in prompt.underlinedQuestions) ..._contentWords(q),
    };
    final answerWords = _contentWords(text).toSet();
    final overlap = promptWords.intersection(answerWords).length;
    final onTopic = promptWords.isEmpty || overlap >= 1;
    checks.add(WritingCheck(
      id: 'on_topic',
      kind: WritingCheckKind.hint,
      status: onTopic ? WritingCheckStatus.ok : WritingCheckStatus.warn,
      labelJa: 'お題に そっているか（目安）',
      detailJa: onTopic
          ? 'お題に 関係する 言葉が 使えています。'
          : 'お題の 言葉が 見あたりません。テーマに 合っているか 確認しましょう。',
    ));
  }

  // 4) HINT — task-specific completeness.
  switch (prompt.type) {
    case WritingTaskType.email:
      for (var i = 0; i < prompt.underlinedQuestions.length; i++) {
        final q = prompt.underlinedQuestions[i];
        final qWords = _contentWords(q).toSet();
        final answered = qWords.isEmpty ||
            qWords.intersection(_contentWords(text).toSet()).isNotEmpty;
        checks.add(WritingCheck(
          id: 'email_q${i + 1}',
          kind: WritingCheckKind.hint,
          status: answered ? WritingCheckStatus.ok : WritingCheckStatus.warn,
          labelJa: '質問${i + 1}に 答えたか（目安）',
          detailJa: answered
              ? '質問${i + 1}に 関連する 言葉が あります。'
              : '質問${i + 1}「$q」の 答えが 見あたりません。両方の 質問に 答えましょう。',
        ));
      }
      break;
    case WritingTaskType.opinion:
      final hasOpinion = _containsAny(lower, _opinionMarkers);
      checks.add(WritingCheck(
        id: 'opinion_stated',
        kind: WritingCheckKind.hint,
        status: hasOpinion ? WritingCheckStatus.ok : WritingCheckStatus.warn,
        labelJa: '意見を 述べたか（目安）',
        detailJa: hasOpinion
            ? '自分の 意見を 述べる 表現が あります。'
            : '"I think ..." など 意見を はっきり 述べる 表現を 入れましょう。',
      ));
      final reasons = _countDistinct(lower, _reasonMarkers);
      checks.add(WritingCheck(
        id: 'two_reasons',
        kind: WritingCheckKind.hint,
        status: reasons >= 2 ? WritingCheckStatus.ok : WritingCheckStatus.warn,
        labelJa: '理由を 2つ 書いたか（目安）',
        detailJa: reasons >= 2
            ? '理由を 示す 表現が $reasons か所 あります。'
            : '"First ...", "Second ...", "because ..." など 理由を 2つ 示しましょう。',
      ));
      final hasConcl = _containsAny(lower, _conclusionMarkers);
      checks.add(WritingCheck(
        id: 'conclusion',
        kind: WritingCheckKind.hint,
        status: hasConcl ? WritingCheckStatus.ok : WritingCheckStatus.warn,
        labelJa: '結論を 書いたか（目安）',
        detailJa: hasConcl
            ? 'まとめの 表現が あります。'
            : '"Therefore ...", "That is why ..." など まとめの 文を 入れましょう。',
      ));
      break;
    case WritingTaskType.summary:
      // Verbatim-copy detector: a long consecutive run shared with the source.
      final copied = _hasVerbatimRun(prompt.stimulus, text, run: 5);
      checks.add(WritingCheck(
        id: 'not_verbatim',
        kind: WritingCheckKind.hint,
        status: copied ? WritingCheckStatus.warn : WritingCheckStatus.ok,
        labelJa: '丸写しに なっていないか（目安）',
        detailJa: copied
            ? '本文と 同じ 並びの 長い 部分が あります。自分の 言葉で 言いかえましょう。'
            : '本文を そのまま 写さず 言いかえが できています。',
      ));
      break;
  }

  // 5) HINT — connectives / structure markers.
  {
    final hits = _countDistinct(lower, _connectives);
    final ok = hits >= (prompt.type == WritingTaskType.email ? 1 : 2);
    checks.add(WritingCheck(
      id: 'connectives',
      kind: WritingCheckKind.hint,
      status: ok ? WritingCheckStatus.ok : WritingCheckStatus.warn,
      labelJa: 'つなぎ言葉（目安）',
      detailJa: ok
          ? 'つなぎ言葉が 使えています。'
          : 'first / because / however など つなぎ言葉を 使うと 構成が 良くなります。',
    ));
  }

  // 6) HINT — basic mechanics (capitalization + terminal punctuation).
  {
    final sents = _sentences(text);
    final capped = sents.where((s) => RegExp(r'^[A-Z]').hasMatch(s)).length;
    final endsOk = RegExp(r'[.!?]\s*$').hasMatch(text.trim());
    final ok =
        sents.isNotEmpty && capped >= (sents.length / 2).ceil() && endsOk;
    checks.add(WritingCheck(
      id: 'mechanics',
      kind: WritingCheckKind.hint,
      status: ok ? WritingCheckStatus.ok : WritingCheckStatus.warn,
      labelJa: '大文字・ピリオド（目安）',
      detailJa: ok
          ? '文の はじめは 大文字、おわりは ピリオドに なっています。'
          : '各文を 大文字で 始め、ピリオド(.)で 終えましょう。',
    ));
  }

  return WritingReadiness(
    wordCount: words,
    wordMin: prompt.wordCountMin,
    wordMax: prompt.wordCountMax,
    taskType: prompt.type,
    checks: checks,
  );
}

/// True when [submission] shares a consecutive run of [run] tokens with
/// [source] — a verbatim-copy signal for 要約.
bool _hasVerbatimRun(String source, String submission, {int run = 5}) {
  List<String> toks(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final src = toks(source);
  final sub = toks(submission);
  if (sub.length < run || src.length < run) return false;
  final srcGrams = <String>{};
  for (var i = 0; i + run <= src.length; i++) {
    srcGrams.add(src.sublist(i, i + run).join(' '));
  }
  for (var i = 0; i + run <= sub.length; i++) {
    if (srcGrams.contains(sub.sublist(i, i + run).join(' '))) return true;
  }
  return false;
}
