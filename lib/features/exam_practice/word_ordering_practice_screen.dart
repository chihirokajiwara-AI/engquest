// lib/features/exam_practice/word_ordering_practice_screen.dart
// A-KEN Quest — Eiken Part 3 (5級/4級): Word Ordering (語句の並びかえ)
//
// Given a Japanese sentence and scrambled English words,
// the user drags/taps words into correct order.
//
// Example:
//   日本語: 「私は毎日学校に歩いて行きます。」
//   Words: [school / I / to / every / walk / day]
//   Answer: I walk to school every day.

import 'dart:math';

import 'package:flutter/material.dart';
import 'eiken_exam_config.dart';
import 'pass/cse_model.dart';
import 'pass/skill_accuracy_store.dart';
import '../home/streak_service.dart';

/// A 語句整序 (word-ordering) problem in the authentic 英検 大問3 form: a Japanese
/// sentence plus exactly FIVE 語句 (chunks ①–⑤) that combine into one correct
/// English sentence. The real exam then asks for the combination at the 2nd and
/// 4th positions — [secondChunk] / [fourthChunk] expose that so the screen can
/// teach the actual question format. (Spec: eiken.or.jp 4級 大問3, verified
/// 2026-06-07; 2025–2026 format unchanged.)
class _OrderingProblem {
  final String jpSentence;

  /// The five 語句 in the single correct order.
  final List<String> correctOrder;
  final List<String> scrambled;

  /// Post-answer grammar rule (#103-line teach-why): why THIS word order is
  /// correct, in child-facing 日本語. The 語句整序 skill is knowing the rule (be
  /// 動詞の文型, want to do, 比較級+than, make+人+原形…), so the reveal teaches the
  /// rule, not just the answer. Optional — items without it omit the line.
  final String? whyExplanation;

  _OrderingProblem({
    required this.jpSentence,
    required this.correctOrder,
    this.whyExplanation,
  })  : assert(correctOrder.length == 5,
            '英検 大問3 語句整序 is exactly 5 chunks: $correctOrder'),
        scrambled = List.from(correctOrder)..shuffle(Random());

  /// The 語句 at the 2nd position (what the real exam asks for).
  String get secondChunk => correctOrder[1];

  /// The 語句 at the 4th position (what the real exam asks for).
  String get fourthChunk => correctOrder[3];
}

/// Circled position markers for the answer slots (①②③④⑤).
const List<String> _kCircled = ['①', '②', '③', '④', '⑤'];

class WordOrderingPracticeScreen extends StatefulWidget {
  const WordOrderingPracticeScreen({
    super.key,
    required this.eikenGrade,
    required this.section,
  });

  final String eikenGrade;
  final ExamSection section;

  @override
  State<WordOrderingPracticeScreen> createState() =>
      _WordOrderingPracticeScreenState();
}

class _WordOrderingPracticeScreenState
    extends State<WordOrderingPracticeScreen> {
  late List<_OrderingProblem> _problems;
  int _currentIdx = 0;
  List<String> _selectedWords = [];
  List<String> _remainingWords = [];
  bool _answered = false;
  bool _correct = false;
  int _correctCount = 0;
  bool _sessionDone = false;

  @override
  void initState() {
    super.initState();
    _problems = _generateProblems(widget.eikenGrade);
    _resetProblem();
  }

  void _resetProblem() {
    final p = _problems[_currentIdx];
    _selectedWords = [];
    _remainingWords = List.from(p.scrambled);
    _answered = false;
    _correct = false;
  }

  void _tapWord(String word) {
    if (_answered) return;
    setState(() {
      _remainingWords.remove(word);
      _selectedWords.add(word);
    });
  }

  void _removeWord(int idx) {
    if (_answered) return;
    setState(() {
      final word = _selectedWords.removeAt(idx);
      _remainingWords.add(word);
    });
  }

  void _checkAnswer() {
    final p = _problems[_currentIdx];
    final isCorrect = _selectedWords.join(' ').toLowerCase() ==
        p.correctOrder.join(' ').toLowerCase();
    setState(() {
      _answered = true;
      _correct = isCorrect;
      if (isCorrect) _correctCount++;
    });
  }

  /// Records the completed session result into [SkillAccuracyStore].
  /// wordOrdering → EikenSkill.reading (Part 3 = Reading大問, 5/4級).
  Future<void> _recordSessionResult() async {
    if (_problems.isEmpty) return;
    recordExamHabit(_problems.length); // streak + daily-goal, not just 合格率
    try {
      final store = await SkillAccuracyStore.getInstance();
      await store.record(
        grade: widget.eikenGrade,
        skill: EikenSkill.reading,
        correct: _correctCount,
        total: _problems.length,
      );
    } catch (_) {
      // Store errors are non-fatal — never interrupt the learner.
    }
  }

  void _nextProblem() {
    if (_currentIdx >= _problems.length - 1) {
      _recordSessionResult(); // fire-and-forget; UI does not wait
      setState(() => _sessionDone = true);
    } else {
      setState(() {
        _currentIdx++;
        _resetProblem();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '語句の並びかえ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _sessionDone ? _buildResults() : _buildProblem(),
      ),
    );
  }

  Widget _buildProblem() {
    final p = _problems[_currentIdx];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scrollable content so the answered-state panels (exam-format +
          // grammar rule) never overflow on short viewports; the action button
          // stays pinned below.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress
                  Row(
                    children: [
                      Text(
                        '問${_currentIdx + 1} / ${_problems.length}',
                        style: const TextStyle(
                          color: Color(0xFF263238),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '正答: $_correctCount',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentIdx + 1) / _problems.length,
                    backgroundColor: Colors.grey[200],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF4FC3F7)),
                  ),
                  const SizedBox(height: 24),
                  // Japanese sentence
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF4FC3F7).withAlpha(60)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '日本文の意味になるように、語句を並べかえましょう：',
                          style:
                              TextStyle(color: Color(0xFF607D8B), fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.jpSentence,
                          style: const TextStyle(
                            color: Color(0xFF263238),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Answer area (selected words)
                  Container(
                    constraints: const BoxConstraints(minHeight: 60),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _answered
                          ? (_correct
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE))
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _answered
                            ? (_correct
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFF44336))
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: _selectedWords.isEmpty
                        ? Center(
                            child: Text(
                              '下の単語をタップして並べましょう',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 14),
                            ),
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: List.generate(_selectedWords.length, (i) {
                              return GestureDetector(
                                onTap: () => _removeWord(i),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Position marker ①②③④⑤ — the slots the real exam
                                    // counts ("2番目と4番目").
                                    Text(
                                      i < _kCircled.length
                                          ? _kCircled[i]
                                          : '${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF0288D1),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _WordChip(
                                      word: _selectedWords[i],
                                      selected: true,
                                      removable: !_answered,
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                  ),
                  // Show correct answer if wrong
                  if (_answered && !_correct) ...[
                    const SizedBox(height: 8),
                    Text(
                      '正解: ${p.correctOrder.join(" ")}',
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  // Exam-format teach: connect the arrangement to how 英検 actually asks
                  // the question (the combination at the 2nd & 4th positions). Guarded
                  // on length so a malformed (<5-chunk) item can never RangeError in
                  // release mode, where the constructor assert is stripped.
                  if (_answered && p.correctOrder.length >= 4) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1F5FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF4FC3F7).withAlpha(110)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📝 本番（英検）の問い方',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0277BD),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '2番目と4番目にくる語句の組み合わせを答えます。',
                            style: TextStyle(
                                fontSize: 12.5, color: Color(0xFF37474F)),
                          ),
                          const SizedBox(height: 8),
                          // Wrap (not Row) so long chunks ("to this party", "old
                          // photo") reflow instead of overflowing on narrow phones.
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _posPill('2番目', p.secondChunk),
                              _posPill('4番目', p.fourthChunk),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Grammar-rule teach: the 語句整序 skill is knowing WHY the order is
                  // correct, so reveal the rule (be動詞の文型 / want to do / 比較級+than …),
                  // not just the answer. (Panel uses the screen's current bright theme;
                  // the dark-dq migration is tracked separately as #67.)
                  if (_answered && p.whyExplanation != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFFB300).withAlpha(110)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '💡 ルール / なぜこの順番？',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.whyExplanation!,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF37474F),
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Word bank (remaining words)
                  if (!_answered || _remainingWords.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _remainingWords.map((word) {
                        return GestureDetector(
                          onTap: () => _tapWord(word),
                          child: _WordChip(word: word, selected: false),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Check / Next button
          if (!_answered && _remainingWords.isEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checkAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '答え合わせ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (_answered)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextProblem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentIdx < _problems.length - 1 ? '次の問題へ' : '結果を見る',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _posPill(String label, String chunk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4FC3F7)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF0288D1),
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: chunk,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF263238),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final pct = _problems.isEmpty
        ? 0
        : (_correctCount / _problems.length * 100).round();
    final passed = pct >= 60;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              passed ? Icons.emoji_events : Icons.refresh,
              size: 72,
              color: passed ? const Color(0xFFFFD700) : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              passed ? '合格ライン到達！' : 'もう少し！',
              style: const TextStyle(
                color: Color(0xFF263238),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_correctCount / ${_problems.length} 正解 ($pct%)',
              style: TextStyle(color: Colors.grey[700], fontSize: 18),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '戻る',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Static problem bank ─────────────────────────────────────────────────

  static List<_OrderingProblem> _generateProblems(String grade) {
    // Authentic 英検 大問3 語句整序: every item is exactly FIVE 語句 (chunks) that
    // form ONE correct English sentence matching the Japanese. Chunks are chosen
    // so there is a SINGLE valid arrangement (the exact-match grader would
    // wrongly fail a synonymous alternative order). Content-QA + 英検-spec
    // audited 2026-06-07.
    // INVARIANT (content-QA 2026-06-07): every item must have exactly ONE
    // grammatical order of its 5 chunks matching the Japanese, because the
    // grader is exact-match. To guarantee that, NONE of these use a
    // sentence-frontable adverbial/PP ("In the future…", "For five years…"),
    // a mobile sentence-adverb ("now"), reversible coordination ("dogs and
    // cats"), or dative alternation ("wrote him a letter"/"…to him"). Adjuncts
    // appear only as position-locked manner units ("very well", "faster than
    // me") or not at all.
    switch (grade) {
      case '5':
        // CEFR A1 — present simple, be, can, have; pure SVO / SVC, wh-question.
        return [
          _OrderingProblem(
            jpSentence: 'これは私の新しいかばんです。',
            correctOrder: ['This', 'is', 'my', 'new', 'bag'],
            whyExplanation:
                'be動詞の文：主語(This)＋is＋〈my new bag〉。ものの説明は「持ち主→様子→もの」の順で my new bag。',
          ),
          _OrderingProblem(
            jpSentence: '彼女は青いぼうしを持っています。',
            correctOrder: ['She', 'has', 'a', 'blue', 'hat'],
            whyExplanation: '主語＋has＋目的語。色を表す blue は名詞 hat の前に置く＝a blue hat。',
          ),
          _OrderingProblem(
            jpSentence: 'この本はとてもおもしろいです。',
            correctOrder: ['This', 'book', 'is', 'very', 'interesting'],
            whyExplanation:
                '主語(This book)＋be動詞＋様子(interesting)。very は形容詞を強める語なので interesting の前。',
          ),
          _OrderingProblem(
            jpSentence: '私の父は車を運転できます。',
            correctOrder: ['My father', 'can', 'drive', 'a', 'car'],
            whyExplanation: 'can のあとは動詞の原形。主語＋can＋drive＋目的語(a car)の語順。',
          ),
          _OrderingProblem(
            jpSentence: '私は犬が大好きです。',
            correctOrder: ['I', 'like', 'dogs', 'very', 'much'],
            whyExplanation: '主語＋動詞(like)＋目的語(dogs)。「とても」= very much は文の最後に置く。',
          ),
          _OrderingProblem(
            jpSentence: '彼らは音楽を聞いています。',
            correctOrder: ['They', 'are', 'listening', 'to', 'music'],
            whyExplanation:
                '現在進行形 be＋〜ing。listen は to をともなうので listening to music。',
          ),
          _OrderingProblem(
            jpSentence: 'あの男の子はとても親切です。',
            correctOrder: ['That', 'boy', 'is', 'very', 'kind'],
            whyExplanation: '主語(That boy)＋be動詞＋様子(kind)。very は kind の前に置いて強める。',
          ),
          _OrderingProblem(
            jpSentence: 'あなたは何時に起きますか。',
            correctOrder: ['What time', 'do', 'you', 'get', 'up'],
            whyExplanation:
                '疑問詞(What time)＋do＋主語＋動詞の原形。疑問文は do you get up の語順。',
          ),
        ];
      case '4':
        // CEFR A2 — to-infinitive, comparative, have to, SVOC (make), gerund
        // object, give/show double-object, ask O to do. The task's focus.
        return [
          _OrderingProblem(
            jpSentence: '彼は私に古い写真を見せてくれた。',
            correctOrder: ['He', 'showed', 'me', 'an', 'old photo'],
            whyExplanation:
                'show＋人(me)＋もの(an old photo)。「(人)に(もの)を見せる」は〈動詞＋人＋もの〉の順。',
          ),
          _OrderingProblem(
            jpSentence: '彼女は医者になりたいと思っています。',
            correctOrder: ['She', 'wants', 'to be', 'a', 'doctor'],
            whyExplanation: '「〜になりたい」は want to＋動詞の原形。want to be a doctor。',
          ),
          _OrderingProblem(
            jpSentence: '彼は私より速く走ることができます。',
            correctOrder: ['He', 'can', 'run', 'faster', 'than me'],
            whyExplanation:
                '比較級＋than＋比べる相手。「私より速く」= faster than me。canのあとは原形run。',
          ),
          _OrderingProblem(
            jpSentence: '私は宿題を終えなければなりません。',
            correctOrder: ['I', 'have to', 'finish', 'my', 'homework'],
            whyExplanation: '「〜しなければならない」は have to＋動詞の原形。have to finish。',
          ),
          _OrderingProblem(
            jpSentence: 'その映画は私を悲しい気持ちにさせました。',
            correctOrder: ['The movie', 'made', 'me', 'feel', 'sad'],
            whyExplanation: 'make＋人＋動詞の原形（使役）。「(人)を〜させる」= made me feel sad。',
          ),
          _OrderingProblem(
            jpSentence: '私は音楽を聞くのが好きです。',
            correctOrder: ['I', 'like', 'listening', 'to', 'music'],
            whyExplanation:
                '「〜するのが好き」は like＋動名詞(〜ing)。listen は to をともなう＝listening to music。',
          ),
          _OrderingProblem(
            jpSentence: '私の姉は英語をとても上手に話します。',
            correctOrder: ['My sister', 'speaks', 'English', 'very', 'well'],
            whyExplanation:
                '主語＋動詞(speaks)＋目的語(English)＋様子。「とても上手に」= very well は最後。',
          ),
          _OrderingProblem(
            jpSentence: '彼は宿題を手伝ってくれるよう私に頼みました。',
            correctOrder: ['He', 'asked', 'me', 'to help', 'him'],
            whyExplanation: '「(人)に〜するよう頼む」は ask＋人＋to do。asked me to help him。',
          ),
          _OrderingProblem(
            jpSentence: 'あなたは何になりたいですか。',
            correctOrder: ['What', 'do', 'you', 'want', 'to be'],
            whyExplanation: '疑問詞(What)＋do＋主語＋want to be。「何になりたいか」をたずねる語順。',
          ),
          _OrderingProblem(
            jpSentence: '私の母はちょうど夕食を作り終えたところです。',
            correctOrder: [
              'My mother',
              'has just',
              'finished',
              'cooking',
              'dinner'
            ],
            whyExplanation:
                '現在完了 have just＋過去分詞（〜したところ）。finish のあとは動名詞＝finished cooking。',
          ),
        ];
      default:
        // 英検3級 — CEFR A2–B1: contact relative clause, want O to do, passive
        // with by-agent, SVOC (make), gerund subject, present-perfect just.
        return [
          _OrderingProblem(
            jpSentence: '彼女が作ったケーキは本当においしかった。',
            correctOrder: ['The cake', 'she made', 'was', 'really', 'good'],
          ),
          _OrderingProblem(
            jpSentence: '私はあなたにこのパーティーに来てほしい。',
            correctOrder: ['I', 'want', 'you', 'to come', 'to this party'],
          ),
          _OrderingProblem(
            jpSentence: 'この本は多くの人々に読まれています。',
            correctOrder: ['This book', 'is', 'read', 'by', 'many people'],
          ),
          _OrderingProblem(
            jpSentence: '彼の言葉は私をとても怒らせた。',
            correctOrder: ['His words', 'made', 'me', 'very', 'angry'],
          ),
          _OrderingProblem(
            jpSentence: '英語を話すことはそんなに難しくない。',
            correctOrder: ['Speaking English', 'is', 'not', 'so', 'difficult'],
          ),
          _OrderingProblem(
            jpSentence: '彼はちょうど駅に着いたところです。',
            correctOrder: ['He', 'has just', 'arrived', 'at', 'the station'],
          ),
        ];
    }
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.selected,
    this.removable = false,
  });

  final String word;
  final bool selected;
  final bool removable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE1F5FE) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFF4FC3F7) : Colors.grey.shade300,
        ),
        boxShadow: selected
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word,
            style: TextStyle(
              color: const Color(0xFF263238),
              fontSize: 16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (removable) ...[
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: Colors.grey[500]),
          ],
        ],
      ),
    );
  }
}

/// Test-only: the correct chunk orders for a grade, so the content invariant
/// (exactly 5 chunks per item, no duplicate that could fool the exact-match
/// grader) can be asserted in CI.
@visibleForTesting
List<List<String>> wordOrderingChunksForTest(String grade) =>
    _WordOrderingPracticeScreenState._generateProblems(grade)
        .map((p) => p.correctOrder)
        .toList();
