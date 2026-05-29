// lib/features/battle/battle_screen.dart
// ENG Quest — C05 Battle Module: FSRS-4.5 Retrieval Loop (UI Polish v2)
//
// Game flow:
//   1. Build a deck of FSRSCards from kVocabA1 (all new cards are due on first run)
//   2. Show the English word face-up ("cat")
//   3. Tap to flip card → Japanese translation + example sentence
//   4. Rate with 4 buttons: Again / Hard / Good / Easy
//   5. FSRSAlgorithm.schedule() computes next due date
//   6. Cycle through due cards; show session summary when done
//
// UI Polish sprint additions:
//   - 3D perspective card flip (400 ms, easeInOut)
//   - Scale-bounce grade buttons (0.95→1.0, 150 ms)
//   - Golden shimmer overlay on correct answer (300 ms)
//   - Streak counter with fire emoji (🔥 × N) when streak ≥ 3
//   - +XP floating text animation (TweenAnimationBuilder, 800 ms)
//   - Animated star-burst on session complete (CustomPainter)
//   - SoundService stubs + HapticFeedback

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/fsrs/fsrs_algorithm.dart';
import '../../core/fsrs/fsrs_card.dart';
import '../../core/sound/sound_service.dart';
import '../../data/models/vocab_item.dart';

// ── Inline vocab seed (30 representative A1 words) ──────────────────────────
const List<VocabItem> _kSeedVocab = [
  VocabItem(id: 'eiken5_001', word: 'cat',    reading: 'キャット',   jpTranslation: 'ねこ',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I have a cat.']),
  VocabItem(id: 'eiken5_002', word: 'dog',    reading: 'ドッグ',     jpTranslation: 'いぬ',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['My dog is big.']),
  VocabItem(id: 'eiken5_003', word: 'apple',  reading: 'アップル',   jpTranslation: 'りんご',     cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I eat an apple.']),
  VocabItem(id: 'eiken5_004', word: 'book',   reading: 'ブック',     jpTranslation: 'ほん',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I read a book.']),
  VocabItem(id: 'eiken5_005', word: 'school', reading: 'スクール',   jpTranslation: 'がっこう',   cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I go to school.']),
  VocabItem(id: 'eiken5_006', word: 'red',    reading: 'レッド',     jpTranslation: 'あか',       cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['The apple is red.']),
  VocabItem(id: 'eiken5_007', word: 'big',    reading: 'ビッグ',     jpTranslation: 'おおきい',   cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['That is a big dog.']),
  VocabItem(id: 'eiken5_008', word: 'run',    reading: 'ラン',       jpTranslation: 'はしる',     cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['I run every day.']),
  VocabItem(id: 'eiken5_009', word: 'eat',    reading: 'イート',     jpTranslation: 'たべる',     cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['We eat breakfast.']),
  VocabItem(id: 'eiken5_010', word: 'water',  reading: 'ウォーター', jpTranslation: 'みず',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['Drink some water.']),
  VocabItem(id: 'eiken5_011', word: 'friend', reading: 'フレンド',   jpTranslation: 'ともだち',   cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['She is my friend.']),
  VocabItem(id: 'eiken5_012', word: 'happy',  reading: 'ハッピー',   jpTranslation: 'うれしい',   cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['I am very happy.']),
  VocabItem(id: 'eiken5_013', word: 'play',   reading: 'プレイ',     jpTranslation: 'あそぶ',     cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['We play soccer.']),
  VocabItem(id: 'eiken5_014', word: 'house',  reading: 'ハウス',     jpTranslation: 'いえ',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['This is my house.']),
  VocabItem(id: 'eiken5_015', word: 'blue',   reading: 'ブルー',     jpTranslation: 'あお',       cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['The sky is blue.']),
  VocabItem(id: 'eiken5_016', word: 'mother', reading: 'マザー',     jpTranslation: 'おかあさん', cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['My mother is kind.']),
  VocabItem(id: 'eiken5_017', word: 'father', reading: 'ファーザー', jpTranslation: 'おとうさん', cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['My father works hard.']),
  VocabItem(id: 'eiken5_018', word: 'like',   reading: 'ライク',     jpTranslation: 'すき',       cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['I like music.']),
  VocabItem(id: 'eiken5_019', word: 'small',  reading: 'スモール',   jpTranslation: 'ちいさい',   cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['It is a small cat.']),
  VocabItem(id: 'eiken5_020', word: 'bird',   reading: 'バード',     jpTranslation: 'とり',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['A bird is singing.']),
  VocabItem(id: 'eiken5_021', word: 'fish',   reading: 'フィッシュ', jpTranslation: 'さかな',     cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I see a fish.']),
  VocabItem(id: 'eiken5_022', word: 'tree',   reading: 'ツリー',     jpTranslation: 'き',         cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['The tree is tall.']),
  VocabItem(id: 'eiken5_023', word: 'green',  reading: 'グリーン',   jpTranslation: 'みどり',     cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['The grass is green.']),
  VocabItem(id: 'eiken5_024', word: 'sing',   reading: 'シング',     jpTranslation: 'うたう',     cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['They sing a song.']),
  VocabItem(id: 'eiken5_025', word: 'pen',    reading: 'ペン',       jpTranslation: 'ペン',       cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['I have a pen.']),
  VocabItem(id: 'eiken5_026', word: 'desk',   reading: 'デスク',     jpTranslation: 'つくえ',     cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['Put it on the desk.']),
  VocabItem(id: 'eiken5_027', word: 'white',  reading: 'ホワイト',   jpTranslation: 'しろ',       cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'], exampleSentences: ['Snow is white.']),
  VocabItem(id: 'eiken5_028', word: 'walk',   reading: 'ウォーク',   jpTranslation: 'あるく',     cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],      exampleSentences: ['I walk to school.']),
  VocabItem(id: 'eiken5_029', word: 'milk',   reading: 'ミルク',     jpTranslation: 'ぎゅうにゅう', cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],    exampleSentences: ['I drink milk.']),
  VocabItem(id: 'eiken5_030', word: 'park',   reading: 'パーク',     jpTranslation: 'こうえん',   cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],      exampleSentences: ['Let\'s go to the park.']),
];

// ── Session result per card ───────────────────────────────────────────────────
class _CardResult {
  final String word;
  final Grade  grade;
  const _CardResult(this.word, this.grade);
}

// ── XP floating label data ────────────────────────────────────────────────────
class _XpPopup {
  final int xp;
  final int id; // unique key to allow overlapping popups
  const _XpPopup(this.xp, this.id);
}

// ── BattleScreen ─────────────────────────────────────────────────────────────

/// FSRS-based vocabulary flashcard battle screen — UI Polish v2.
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with TickerProviderStateMixin {
  // ── FSRS engine ────────────────────────────────────────────────────────────
  final FSRSAlgorithm _fsrs = FSRSAlgorithm();
  final _sound = SoundService();

  // ── Deck state ─────────────────────────────────────────────────────────────
  late List<VocabItem>  _vocab;
  late List<FSRSCard>   _deck;
  late List<int>        _queue;
  int _queueIdx = 0;

  // ── Session stats ──────────────────────────────────────────────────────────
  final List<_CardResult> _sessionResults = [];
  bool _sessionDone = false;

  // ── Streak ─────────────────────────────────────────────────────────────────
  int _streak = 0; // consecutive Good/Easy answers
  int _totalXp = 0;

  // ── Card flip animation ────────────────────────────────────────────────────
  late AnimationController _flipCtrl;
  late Animation<double>    _flipAnim;
  bool _isFlipped = false;

  // ── Shimmer overlay (correct answer) ──────────────────────────────────────
  bool _showShimmer = false;

  // ── XP popup list ──────────────────────────────────────────────────────────
  final List<_XpPopup> _xpPopups = [];
  int _xpPopupIdCounter = 0;

  // ── Session-complete star burst animation ──────────────────────────────────
  late AnimationController _starsCtrl;
  late Animation<double>    _starsAnim;

  // ── Colours ────────────────────────────────────────────────────────────────
  static const _bgColor    = Color(0xFF1A1A2E);
  static const _cardFront  = Color(0xFF16213E);
  static const _cardBack   = Color(0xFF0F3460);
  static const _accentGold = Color(0xFFFFD700);

  static const _gradeColors = {
    Grade.again: Color(0xFFE53935),
    Grade.hard:  Color(0xFFF57C00),
    Grade.good:  Color(0xFF43A047),
    Grade.easy:  Color(0xFF1E88E5),
  };

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );
    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _starsAnim = CurvedAnimation(parent: _starsCtrl, curve: Curves.easeOut);
    _initDeck();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    _starsCtrl.dispose();
    super.dispose();
  }

  // ── Deck initialisation ────────────────────────────────────────────────────

  void _initDeck() {
    _vocab = List<VocabItem>.from(_kSeedVocab);
    final now = DateTime.now();
    _deck = _vocab.map((v) => FSRSCard(vocabId: v.id)).toList();
    _queue = _fsrs
        .getDueCards(_deck, now)
        .map((c) => _deck.indexWhere((d) => d.vocabId == c.vocabId))
        .where((i) => i >= 0)
        .toList();
    _queue.shuffle(math.Random());
    _queueIdx = 0;
    _sessionResults.clear();
    _sessionDone = false;
    _isFlipped = false;
    _streak = 0;
    _totalXp = 0;
    _xpPopups.clear();
    _starsCtrl.reset();
  }

  // ── Current card helpers ───────────────────────────────────────────────────

  int get _currentDeckIdx => _queue[_queueIdx];
  VocabItem get _currentVocab  => _vocab[_currentDeckIdx];
  FSRSCard  get _currentCard   => _deck[_currentDeckIdx];

  int get _totalCards => _queue.length;
  int get _doneCards  => _queueIdx;

  // ── Flip ───────────────────────────────────────────────────────────────────

  void _flipCard() {
    if (_isFlipped) return;
    HapticFeedback.lightImpact();
    _sound.playFlip();
    setState(() => _isFlipped = true);
    _flipCtrl.forward();
  }

  void _resetFlip() {
    _flipCtrl.reset();
    setState(() => _isFlipped = false);
  }

  // ── Grade ──────────────────────────────────────────────────────────────────

  void _gradeCard(Grade grade) {
    HapticFeedback.mediumImpact();

    final isCorrect = grade == Grade.good || grade == Grade.easy;
    if (isCorrect) {
      _sound.playCorrect();
      // Shimmer
      setState(() => _showShimmer = true);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _showShimmer = false);
      });
      // Streak
      _streak++;
    } else {
      _sound.playWrong();
      _streak = 0;
    }

    // XP popup
    const xpGain = 10;
    _totalXp += xpGain;
    final popupId = ++_xpPopupIdCounter;
    setState(() => _xpPopups.add(_XpPopup(xpGain, popupId)));
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _xpPopups.removeWhere((p) => p.id == popupId));
    });

    final now = DateTime.now();
    final updated = _fsrs.schedule(_currentCard, grade, now);
    _deck[_currentDeckIdx] = updated;
    _sessionResults.add(_CardResult(_currentVocab.word, grade));

    if (updated.state == CardState.learning ||
        updated.state == CardState.relearning) {
      final insertAt = math.min(_queueIdx + 3, _queue.length);
      _queue.insert(insertAt, _currentDeckIdx);
    }

    final nextIdx = _queueIdx + 1;
    if (nextIdx >= _queue.length) {
      setState(() => _sessionDone = true);
      _starsCtrl.forward();
      return;
    }

    setState(() => _queueIdx = nextIdx);
    _resetFlip();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: _sessionDone ? _buildSummary() : _buildCardSession(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white70),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '⚔️ Battle',
            style: TextStyle(
              color: _accentGold,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          if (_streak >= 3) ...[
            const SizedBox(width: 8),
            _StreakBadge(streak: _streak),
          ],
        ],
      ),
      actions: [
        if (!_sessionDone)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              '${_doneCards + 1} / $_totalCards',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ),
      ],
    );
  }

  // ── Session screen ─────────────────────────────────────────────────────────

  Widget _buildCardSession() {
    return Stack(
      children: [
        Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: _buildFlipCardWithShimmer(),
            ),
            if (!_isFlipped) _buildTapHint(),
            if (_isFlipped) _buildGradeButtons(),
            const SizedBox(height: 24),
          ],
        ),
        // XP floating popups
        ..._xpPopups.map((popup) => _XpFloatLabel(
              key: ValueKey(popup.id),
              xp: popup.xp,
            )),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = _totalCards == 0 ? 0.0 : _doneCards / _totalCards;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation<Color>(_accentGold),
        ),
      ),
    );
  }

  Widget _buildFlipCardWithShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Stack(
        children: [
          GestureDetector(
            onTap: _isFlipped ? null : _flipCard,
            child: _buildFlipCard(),
          ),
          // Golden shimmer overlay on correct answer
          if (_showShimmer)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _showShimmer ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: RadialGradient(
                      colors: [
                        _accentGold.withAlpha(100),
                        _accentGold.withAlpha(0),
                      ],
                      radius: 1.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlipCard() {
    return AnimatedBuilder(
      animation: _flipAnim,
      builder: (context, _) {
        final angle = _flipAnim.value * math.pi;
        final isFrontVisible = angle < math.pi / 2;
        final displayAngle = isFrontVisible ? angle : math.pi - angle;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(displayAngle),
          child: isFrontVisible ? _buildCardFace() : _buildCardBack(),
        );
      },
    );
  }

  Widget _buildCardFace() {
    final vocab = _currentVocab;
    return _cardContainer(
      color: _cardFront,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            vocab.word,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            vocab.reading,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          if (vocab.pos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: _accentGold.withAlpha(128)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                vocab.pos.first,
                style: const TextStyle(
                  color: _accentGold,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 32),
          const Text(
            'タップしてめくる',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    final vocab = _currentVocab;
    final card  = _currentCard;
    final example = vocab.exampleSentences.isNotEmpty
        ? vocab.exampleSentences.first
        : '';
    return _cardContainer(
      color: _cardBack,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            vocab.word,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            vocab.jpTranslation,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                example,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (card.reps > 0)
            Text(
              'S: ${card.stability.toStringAsFixed(1)}d  '
              'D: ${card.difficulty.toStringAsFixed(1)}  '
              'reps: ${card.reps}',
              style: const TextStyle(color: Colors.white24, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _cardContainer({required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(102),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: child,
    );
  }

  Widget _buildTapHint() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '👆 カードをタップして答えを確認',
        style: TextStyle(color: Colors.white38, fontSize: 13),
      ),
    );
  }

  // ── Grade buttons ──────────────────────────────────────────────────────────

  Widget _buildGradeButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: Grade.values.map((g) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _GradeButton(
                grade: g,
                color: _gradeColors[g]!,
                fsrs: _fsrs,
                card: _currentCard,
                onTap: () => _gradeCard(g),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Session summary ────────────────────────────────────────────────────────

  Widget _buildSummary() {
    final total  = _sessionResults.length;
    final counts = <Grade, int>{for (final g in Grade.values) g: 0};
    for (final r in _sessionResults) {
      counts[r.grade] = (counts[r.grade] ?? 0) + 1;
    }
    final gradeSum = _sessionResults.fold(
        0.0, (sum, r) => sum + r.grade.index1.toDouble());
    final avgGrade = total > 0 ? gradeSum / total : 0.0;

    return Stack(
      children: [
        // Animated star burst behind content
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _starsAnim,
            builder: (context, _) => CustomPaint(
              painter: _StarBurstPainter(_starsAnim.value),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  'セッション完了！',
                  style: TextStyle(
                    color: _accentGold,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$total 枚 完了',
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                // XP earned
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accentGold.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accentGold.withAlpha(128)),
                  ),
                  child: Text(
                    '✨ +$_totalXp XP 獲得！',
                    style: const TextStyle(
                      color: _accentGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _SummaryCard(
                  children: Grade.values.map((g) {
                    return _SummaryRow(
                      label: g.label,
                      color: _gradeColors[g]!,
                      count: counts[g] ?? 0,
                      total: total,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _SummaryCard(
                  children: [
                    _StatTile(
                      label: '平均評価',
                      value: avgGrade.toStringAsFixed(2),
                      icon: '⭐',
                    ),
                    const Divider(color: Colors.white12),
                    _StatTile(
                      label: '正確さ (Good + Easy)',
                      value: total > 0
                          ? '${(((counts[Grade.good]! + counts[Grade.easy]!) / total) * 100).round()}%'
                          : '—',
                      icon: '✅',
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.replay),
                    label: const Text('もう一度'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGold,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => setState(_initDeck),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text(
                    'ホームへ戻る',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Streak badge widget ────────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6D00).withAlpha(220),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha(100),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        '🔥 × $streak',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Grade button widget (with scale-bounce) ────────────────────────────────────

class _GradeButton extends StatefulWidget {
  final Grade grade;
  final Color color;
  final FSRSAlgorithm fsrs;
  final FSRSCard card;
  final VoidCallback onTap;

  const _GradeButton({
    required this.grade,
    required this.color,
    required this.fsrs,
    required this.card,
    required this.onTap,
  });

  @override
  State<_GradeButton> createState() => _GradeButtonState();
}

class _GradeButtonState extends State<_GradeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  String _intervalLabel() {
    final simCard = widget.fsrs.schedule(widget.card, widget.grade, DateTime.now());
    final due = simCard.dueDate;
    if (due == null) return '—';
    final diff = due.difference(DateTime.now());
    final days = diff.inDays;
    if (days <= 0) return '今すぐ';
    if (days == 1) return '1日後';
    return '$days 日後';
  }

  @override
  Widget build(BuildContext context) {
    final interval = _intervalLabel();
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: widget.color.withAlpha(204),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(77),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.grade.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                interval,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── XP floating label ──────────────────────────────────────────────────────────

class _XpFloatLabel extends StatelessWidget {
  final int xp;
  const _XpFloatLabel({super.key, required this.xp});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 140,
      left: 0,
      right: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        builder: (context, t, _) {
          return Opacity(
            opacity: (1.0 - t).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -60 * t),
              child: Center(
                child: Text(
                  '+$xp XP',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 6,
                        offset: Offset(1, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Star burst painter (session complete) ─────────────────────────────────────

class _StarBurstPainter extends CustomPainter {
  final double progress; // 0..1
  _StarBurstPainter(this.progress);

  static final _rng = math.Random(42);
  static final List<_StarParticle> _particles = List.generate(
    30,
    (_) => _StarParticle(
      angle: _rng.nextDouble() * 2 * math.pi,
      speed: 150 + _rng.nextDouble() * 250,
      size:  6 + _rng.nextDouble() * 10,
      color: [
        const Color(0xFFFFD700),
        const Color(0xFFFF8F00),
        const Color(0xFFFF4081),
        const Color(0xFF40C4FF),
        const Color(0xFF69F0AE),
      ][_rng.nextInt(5)],
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final cx = size.width / 2;
    final cy = size.height * 0.35;
    final alpha = ((1 - progress) * 255).clamp(0, 255).toInt();

    for (final p in _particles) {
      final dist = p.speed * progress;
      final x = cx + math.cos(p.angle) * dist;
      final y = cy + math.sin(p.angle) * dist + 180 * progress * progress;
      final paint = Paint()
        ..color = p.color.withAlpha(alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), p.size * (1 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_StarBurstPainter old) => old.progress != progress;
}

class _StarParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  const _StarParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

// ── Summary widgets ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final List<Widget> children;
  const _SummaryCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final Color  color;
  final int    count;
  final int    total;

  const _SummaryRow({
    required this.label,
    required this.color,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
