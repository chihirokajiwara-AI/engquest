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
import '../quest/ui/dq_ui.dart';

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

  // Teach-first scaffold (CEO 1132 cont. / #111): the Japanese meaning is already
  // shown, but a child who can't yet arrange the English may be stuck. An opt-in
  // 「ルールをみる」 reveals THIS item's grammar rule (the existing whyExplanation)
  // BEFORE answering — teaching the skill instead of leaving the child to guess.
  // Because the rule materially helps, a hinted problem is recorded as 学習 and
  // EXCLUDED from the measured 合格率 (only unaided answers feed readiness).
  bool _hintShown = false; // rule revealed for the CURRENT problem
  int _assistedCount = 0; // problems answered with the rule up (session)
  int _unaidedTotal = 0; // problems answered WITHOUT the rule
  int _unaidedCorrect = 0; // correct among the unaided

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
    _hintShown = false; // each problem decides its own scaffold afresh
  }

  void _showRuleHint() {
    if (_answered || _hintShown) return;
    setState(() => _hintShown = true);
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
      // Honest measurement: a rule-assisted problem is excluded from 合格率.
      if (_hintShown) {
        _assistedCount++;
      } else {
        _unaidedTotal++;
        if (isCorrect) _unaidedCorrect++;
      }
    });
  }

  /// Records the completed session result into [SkillAccuracyStore].
  /// wordOrdering → EikenSkill.reading (Part 3 = Reading大問, 5/4級).
  Future<void> _recordSessionResult() async {
    if (_problems.isEmpty) return;
    recordExamHabit(_problems.length); // streak + daily-goal, not just 合格率
    // Honesty: feed 合格率 ONLY the unaided problems. If every one used the rule
    // hint, nothing is recorded (the skill stays honestly 未測定).
    if (_unaidedTotal == 0) return;
    try {
      final store = await SkillAccuracyStore.getInstance();
      await store.record(
        grade: widget.eikenGrade,
        skill: EikenSkill.reading,
        correct: _unaidedCorrect,
        total: _unaidedTotal,
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
    // Dark 本格 dq theme (#108 / CEO 2026-06-09): this was the last screen still
    // on the old bright sky-blue theme, clashing with the navy+gold world. Now
    // unified with the other 英検 screens (DqScene / dqBox / dqGold / dqInk).
    return DqScene(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: dqInk),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      '語句（ごく）の並（なら）びかえ',
                      style:
                          dqText(size: 15, w: FontWeight.w800, color: dqGold),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _sessionDone ? _buildResults() : _buildProblem(),
            ),
          ],
        ),
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
                        style: dqText(
                            size: 14, w: FontWeight.w700, color: dqInk),
                      ),
                      const Spacer(),
                      Text(
                        '正答: $_correctCount',
                        style: dqText(
                            size: 14,
                            w: FontWeight.w700,
                            color: const Color(0xFF8BE08B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentIdx + 1) / _problems.length,
                      backgroundColor: dqNight1,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(dqGold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Japanese sentence
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dqBox,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: dqGoldDeep.withAlpha(120), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '日本文（にほんぶん）の意味（いみ）になるように、語句（ごく）を並（なら）べかえましょう：',
                          style: dqText(size: 12, color: dqGold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.jpSentence,
                          style: dqText(
                            size: 18,
                            color: dqInk,
                            w: FontWeight.w600,
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
                              ? const Color(0xFF14301B)
                              : const Color(0xFF3A1A1A))
                          : dqBox,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _answered
                            ? (_correct
                                ? const Color(0xFF8BE08B)
                                : const Color(0xFFE0853A))
                            : dqGoldDeep.withAlpha(120),
                      ),
                    ),
                    child: _selectedWords.isEmpty
                        ? Center(
                            child: Text(
                              '下（した）の単語（たんご）をタップして並（なら）べましょう',
                              style: dqText(
                                  color: dqInk.withAlpha(140), size: 14),
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
                                      style: dqText(
                                        size: 11,
                                        color: dqGold,
                                        w: FontWeight.bold,
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
                      '正解（せいかい）: ${p.correctOrder.join(" ")}',
                      style: dqText(
                        color: const Color(0xFF8BE08B),
                        size: 14,
                        w: FontWeight.w600,
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
                        color: dqBox,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dqGold.withAlpha(110)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📝 本番（英検）の問い方',
                            style: dqText(
                              size: 12,
                              w: FontWeight.bold,
                              color: dqGold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '2番目（ばんめ）と4番目（ばんめ）にくる語句（ごく）の組（く）み合（あ）わせを答（こた）えます。',
                            style: dqText(size: 12.5, color: dqInk),
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
                  // not just the answer. Dark dq theme (#108): gold-accented panel.
                  if ((_answered || _hintShown) && p.whyExplanation != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dqBox,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dqGold.withAlpha(110)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💡 ルール / なぜこの順番？',
                            style: dqText(
                              size: 12,
                              w: FontWeight.bold,
                              color: dqGold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.whyExplanation!,
                            style: dqText(size: 12.5, color: dqInk)
                                .copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Opt-in teach-first scaffold: reveal THIS item's grammar rule
                  // before answering so a stuck beginner is taught, not left to
                  // guess. Using it excludes the problem from 合格率.
                  if (!_answered && !_hintShown && p.whyExplanation != null) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      key: const ValueKey('wo_hint'),
                      onPressed: _showRuleHint,
                      icon: const Icon(Icons.lightbulb_outline,
                          color: dqGold, size: 18),
                      label: const Text('ルールをみる（むずかしいとき）'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dqGold,
                        side: BorderSide(color: dqGold.withAlpha(160)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ルールをみた問題（もんだい）は、合格率（ごうかくりつ）に 入（はい）れません。',
                      textAlign: TextAlign.center,
                      style: dqText(size: 11, color: dqInk.withAlpha(150)),
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
            DqButton(label: '答え合わせ', onTap: _checkAnswer),
          if (_answered)
            DqButton(
              label: _currentIdx < _problems.length - 1 ? '次の問題へ' : '結果を見る',
              onTap: _nextProblem,
            ),
        ],
      ),
    );
  }

  Widget _posPill(String label, String chunk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dqNight1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dqGold.withAlpha(140)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: dqText(
                size: 11.5,
                color: dqGold,
                w: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: chunk,
              style: dqText(
                size: 13,
                color: dqInk,
                w: FontWeight.w600,
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
              color: passed ? dqGold : dqInk.withAlpha(140),
            ),
            const SizedBox(height: 16),
            Text(
              passed ? '合格（ごうかく）ライン到達（とうたつ）！' : 'もう少（すこ）し！',
              style: dqText(size: 24, w: FontWeight.bold, color: dqGold),
            ),
            const SizedBox(height: 12),
            Text(
              '$_correctCount / ${_problems.length} 正解（せいかい）（$pct%）',
              style: dqText(color: dqInk, size: 18),
            ),
            if (_assistedCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'ルールをみた $_assistedCount問（もん）は、\n合格率（ごうかくりつ）に 入（い）れていません。',
                textAlign: TextAlign.center,
                style: dqText(color: dqInk.withAlpha(160), size: 12),
              ),
            ],
            const SizedBox(height: 32),
            DqButton(
              label: '戻る',
              onTap: () => Navigator.of(context).pop(),
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
        // CEFR A2 (英検4級 文法範囲, verified eiken.or.jp + grade_3 scope, #60):
        // past/future(will), comparative, to-infinitive (名詞的・副詞的), gerund
        // object, have to / can, 文型 SVC・SVOO. GRADE-SCOPE GUARD: 現在完了・受動態・
        // 関係代名詞・SVOC・使役 are 3級+ (準2級 for 使役原形不定詞) → deliberately
        // EXCLUDED here so 4級 only drills 4級 grammar.
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
            jpSentence: '彼は写真をとるためにカメラを買いました。',
            correctOrder: ['He', 'bought', 'a camera', 'to take', 'pictures'],
            whyExplanation:
                '「〜するために」は〈to＋動詞の原形〉（不定詞の副詞的用法）。「写真をとるために」= to take pictures は文の最後に置く。',
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
            jpSentence: '彼はおいしいケーキを作りました。',
            correctOrder: ['He', 'made', 'a', 'delicious', 'cake'],
            whyExplanation:
                '過去形は動詞を過去の形にする。make→made。「おいしいケーキを作った」= made a delicious cake。',
          ),
          _OrderingProblem(
            jpSentence: 'あなたは何になりたいですか。',
            correctOrder: ['What', 'do', 'you', 'want', 'to be'],
            whyExplanation: '疑問詞(What)＋do＋主語＋want to be。「何になりたいか」をたずねる語順。',
          ),
          _OrderingProblem(
            jpSentence: '彼は試験に合格するでしょう。',
            correctOrder: ['He', 'will', 'pass', 'the', 'exam'],
            whyExplanation:
                '未来をあらわす will のあとは動詞の原形。「合格するでしょう」= will pass the exam。',
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
        color: selected ? dqNight1 : dqBox,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? dqGold : dqGoldDeep.withAlpha(120),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word,
            style: dqText(
              color: dqInk,
              size: 16,
              w: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (removable) ...[
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: dqInk.withAlpha(150)),
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
