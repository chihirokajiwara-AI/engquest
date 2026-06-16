// lib/features/battle/battle_screen.dart
// ENG Quest — C05 Battle Module: FSRS-4.5 Retrieval Loop (UI Polish v2 + P0.2 + P2-7)
//
// Game flow:
//   1. Build a deck of FSRSCards — loaded from Firestore (FirestoreFsrsCardRepository)
//      Falls back to InMemory on first launch / offline
//   2. Show the English word face-up ("cat")
//   3. Tap to flip card → Japanese translation + example sentence
//   4. Rate with 4 buttons: Again / Hard / Good / Easy
//   5. FSRSAlgorithm.schedule() computes next due date
//   6. Card state saved to Firestore immediately after grading
//   7. Cycle through due cards; show session summary when done
//   Progress persists across app restarts (Firestore offline cache)
//
// P2-7 XP System additions:
//   - Grade-aware XP (Again=0, Hard=5, Good=10, Easy=15) via XpService
//   - Level-up detection + celebratory dialog (レベルアップ！🎉)
//   - XP popup shows correct per-grade amount (not constant 10)
//   - Session summary shows XP earned this session
//
// UI Polish sprint additions:
//   - 3D perspective card flip (400 ms, easeInOut)
//   - Scale-bounce grade buttons (0.95→1.0, 150 ms)
//   - Golden shimmer overlay on correct answer (300 ms)
//   - Streak counter with fire emoji (🔥 × N) when streak ≥ 3
//   - +XP floating text animation (TweenAnimationBuilder, 800 ms)
//   - Animated star-burst on session complete (CustomPainter)
//   - SoundService stubs + HapticFeedback

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/analytics/firestore_progress_repository.dart';
import '../../core/analytics/progress_service.dart';
import '../../core/content/vocab_age_filter.dart';
import '../../core/firebase/auth_service.dart';
import '../../core/fsrs/firestore_card_repository.dart';
import '../../core/fsrs/fsrs_algorithm.dart';
import '../../core/fsrs/fsrs_card.dart';
import '../../core/fsrs/fsrs_card_repository.dart';
import '../../core/gamification/achievement_service.dart';
import '../../core/gamification/xp_service.dart';
import '../../core/gamification/xp_profile.dart';
import '../../core/audio/word_audio_player_service.dart';
import '../../core/sound/sound_service.dart';
import '../../core/data/vocab_repository.dart';
import '../../core/models/vocab_item.dart';
import '../exam_practice/pass/cse_model.dart';
import '../exam_practice/pass/skill_accuracy_store.dart';
import '../exam_practice/pass/pass_progress_card.dart';
import '../home/streak_service.dart';
import '../quest/ui/dq_ui.dart';

// ── Bilingual + interval labels for the Grade enum (DQ command-window tiles) ──
String _gradeJp(Grade g) {
  switch (g) {
    case Grade.again:
      return 'もういちど';
    case Grade.hard:
      return 'むずかしい';
    case Grade.good:
      return 'できた';
    case Grade.easy:
      return 'かんたん';
  }
}

/// #85 (game-studio #4): the diegetic サイレント word-rescue frame on the battle
/// card front. Ties every flashcard review to the world's premise ("the Silence
/// stole the words") instead of "Anki with a gold border", and varies by
/// part-of-speech so it never reads as one repeated stock line. Pure kana → no
/// glyph risk; child-register.
String silentRescueLineJa(PartOfSpeech pos) {
  final what = switch (pos) {
    PartOfSpeech.verb => 'うごきの ことば',
    PartOfSpeech.adjective || PartOfSpeech.adverb => 'ようすの ことば',
    PartOfSpeech.number => 'かずの ことば',
    PartOfSpeech.properNoun => 'なまえ',
    PartOfSpeech.noun => 'ものの なまえ',
    _ => 'ことば',
  };
  return 'この $what、サイレントに うばわれた。';
}

// ── Cumulative deck stats (achievement / progress inputs) ─────────────────────
//
// The deck merges every grade vocab id with the child's PERSISTED FSRS state, so
// these counts are cumulative across sessions (not this session only). Feeding a
// per-session count to the achievement check made practice_50/200/500 unreachable;
// feeding the whole deck length over-reported. Pure + public so the invariant is
// unit-tested. INVARIANT: masteredCardCount <= practicedCardCount (review ⊂ not-new).

/// Cumulative mastered = cards in the FSRS review state.
int masteredCardCount(Iterable<FSRSCard> deck) =>
    deck.where((c) => c.state == CardState.review).length;

/// Cumulative practiced = cards that have LEFT the new state (studied ≥ once).
int practicedCardCount(Iterable<FSRSCard> deck) =>
    deck.where((c) => c.state != CardState.newCard).length;

/// Split [sentence] into spans with each whole-word, case-insensitive occurrence
/// of [word] emphasised, so the target word stands OUT in its example instead of
/// being buried — the child sees it in use (acquisition aid; parity with the
/// vocab-cloze in-context highlight). Underscore storage keys ("ice_cream") match
/// the spaced display form. Always graceful: when the word is absent (e.g. it
/// appears inflected — "run" vs "running"), the whole sentence is one plain span,
/// so nothing breaks. Pure + public for unit tests.
List<TextSpan> exampleHighlightSpans(
  String sentence,
  String word, {
  required TextStyle base,
  required TextStyle emphasis,
}) {
  final target = word.replaceAll('_', ' ').trim();
  if (target.isEmpty) return [TextSpan(text: sentence, style: base)];
  final re = RegExp('\\b${RegExp.escape(target)}\\b', caseSensitive: false);
  final spans = <TextSpan>[];
  var i = 0;
  for (final m in re.allMatches(sentence)) {
    if (m.start > i) {
      spans.add(TextSpan(text: sentence.substring(i, m.start), style: base));
    }
    spans.add(
        TextSpan(text: sentence.substring(m.start, m.end), style: emphasis));
    i = m.end;
  }
  if (i < sentence.length) {
    spans.add(TextSpan(text: sentence.substring(i), style: base));
  }
  if (spans.isEmpty) spans.add(TextSpan(text: sentence, style: base));
  return spans;
}

/// Mid-session momentum pulse decision (studio build): returns (shouldShow,
/// remaining) for the 「あと N問で きょうの目標！」 nudge. Fires on every 5th answer
/// (5/10/15…) ONLY while the daily goal is still unmet (so the "あと N問" message
/// is honest). Pure + public so the cadence/honesty is unit-tested.
(bool shouldShow, int remaining) shouldShowMomentumPulse(
  int answersThisSession,
  int remainingToGoal,
  bool goalMet,
) {
  final every5th = answersThisSession % 5 == 0 && answersThisSession > 0;
  final goalUnmet = !goalMet && remainingToGoal > 0;
  return (every5th && goalUnmet, remainingToGoal);
}

// ── Session result per card ───────────────────────────────────────────────────
class _CardResult {
  final String word;
  final Grade grade;
  const _CardResult(this.word, this.grade);
}

/// Bounded reading-skill contribution from a daily vocab Battle session, so the
/// daily practice loop actually moves the 合格率 (#35).
///
/// - Vocab Battle = 大問1-type vocabulary knowledge → [EikenSkill.reading] (the
///   SAME mapping exam vocabGrammar practice already uses). It does not invent a
///   new signal — it makes the daily loop consistent with exam practice.
/// - Correct = Good|Easy (matches Battle's own `isCorrect`; CONSERVATIVE — a
///   'Hard' recall is treated as not-yet-mastered, so 合格率 never inflates upward).
/// - CAPPED per session ([cap]) so a long FSRS review binge of easy cards cannot
///   swamp the reading bucket and overstate comprehension; one session contributes
///   at most ~one 大問1's worth of evidence, accruing steadily like exam practice.
({int correct, int total}) battleReadingContribution(
  Iterable<Grade> grades, {
  int cap = 10,
}) {
  final list = grades.toList();
  final total = list.length;
  if (total == 0) return (correct: 0, total: 0);
  final correct = list.where((g) => g == Grade.good || g == Grade.easy).length;
  if (total <= cap) return (correct: correct, total: total);
  final scaled = (correct * cap / total).round().clamp(0, cap);
  return (correct: scaled, total: cap);
}

// ── XP floating label data ────────────────────────────────────────────────────
class _XpPopup {
  final int xp;
  final int id; // unique key to allow overlapping popups
  const _XpPopup(this.xp, this.id);
}

// ── BattleScreen ─────────────────────────────────────────────────────────────

/// FSRS-based vocabulary flashcard battle screen — UI Polish v2 + Firestore persistence.
///
/// [repository] — injectable for testing; defaults to FirestoreFsrsCardRepository.
/// [childAge]   — filters vocabulary by age (age < 8 → animals/colors/food/family only).
class BattleScreen extends StatefulWidget {
  final FsrsCardRepository? repository;

  /// Vocab source — injected in tests with a pre-seeded repo so the widget is
  /// pumpable (the production VocabRepository does rootBundle asset I/O in init,
  /// which never completes under flutter_test's FakeAsync clock). Null →
  /// production VocabRepository.
  final VocabRepository? vocabRepo;

  /// Child's age in years (from OnboardingResult). Defaults to 8 (full A1 deck).
  final int childAge;

  /// Eiken grade to study (e.g. "5", "4", "3", "pre2"). Defaults to "5".
  final String eikenGrade;

  const BattleScreen({
    super.key,
    this.repository,
    this.vocabRepo,
    this.childAge = 8,
    this.eikenGrade = '5',
  });

  /// Computes elapsed session time in whole minutes, rounded to the nearest
  /// minute with a floor of 1 (a completed session always counts as ≥ 1 min,
  /// so study-time analytics never record a zero-minute session).
  ///
  /// Exposed as a static pure function so the rounding logic is unit-testable
  /// without constructing the full widget/animation stack.
  ///   - [start] null            → 1 (defensive fallback)
  ///   - non-positive duration   → 1 (clock skew / instant complete)
  ///   - otherwise               → round to nearest minute, floor of 1
  static int elapsedMinutes(DateTime? start, DateTime end) {
    if (start == null) return 1;
    final seconds = end.difference(start).inSeconds;
    if (seconds <= 0) return 1;
    final minutes = (seconds + 30) ~/ 60;
    return minutes < 1 ? 1 : minutes;
  }

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with TickerProviderStateMixin {
  // ── FSRS engine + persistence ──────────────────────────────────────────────
  final FSRSAlgorithm _fsrs = FSRSAlgorithm();
  final _sound = SoundService();
  final _wordAudio = WordAudioPlayerService();
  late final FsrsCardRepository _repository;
  final _auth = AuthService();
  late final VocabRepository _vocabRepo;
  final _xpService = XpService();
  final _achievementService = AchievementService();
  String? _userId;
  bool _repoLoading = true; // true while we await uid + loadDeck

  // ── Deck state ─────────────────────────────────────────────────────────────
  List<VocabItem> _vocab = const [];
  List<FSRSCard> _deck = const [];
  List<int> _queue = const [];
  int _queueIdx = 0;

  // ── Session stats ──────────────────────────────────────────────────────────
  final List<_CardResult> _sessionResults = [];
  bool _sessionDone = false;

  // 合格率 before this session (baseline) and after (for the session-end progress
  // moment). Null until computed / when the grade has no estimate yet.
  CseEstimate? _preEstimate;
  CseEstimate? _postEstimate;

  // ── Session timer (P0.1) ────────────────────────────────────────────────────
  /// Wall-clock timestamp captured when the deck finishes loading and the first
  /// card becomes visible. Used to compute real elapsed minutes on completion.
  DateTime? _sessionStartTime;

  // ── Streak ─────────────────────────────────────────────────────────────────
  int _streak = 0; // consecutive Good/Easy answers
  int _totalXp = 0;
  int _answersThisSession = 0; // track answers for mid-session momentum pulse

  // Daily-return snapshot, loaded AFTER this session is recorded, so the summary
  // can surface the day-streak + 「きょうの目標」 progress at peak engagement
  // (CEO 1320 fun→volume loop / CEO 951 daily-return spine). Null until loaded.
  StreakState? _streakSnapshot;

  // ── Card flip animation ────────────────────────────────────────────────────
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;
  bool _isFlipped = false;

  // ── Shimmer overlay (correct answer) ──────────────────────────────────────
  bool _showShimmer = false;

  // ── XP popup list ──────────────────────────────────────────────────────────
  final List<_XpPopup> _xpPopups = [];
  int _xpPopupIdCounter = 0;

  // ── Session-complete star burst animation ──────────────────────────────────
  late AnimationController _starsCtrl;
  late Animation<double> _starsAnim;

  // ── Colours ────────────────────────────────────────────────────────────────
  // Muted accents for the four grades — used only as small icon-medallion / dot
  // tints inside the dq palette (never as candy-bright fills).
  static const _gradeColors = {
    Grade.again: Color(0xFFC76B6B), // dusty red
    Grade.hard: Color(0xFFCB9A4E), // dim amber
    Grade.good: Color(0xFF7FB87F), // sage green
    Grade.easy: Color(0xFF6FA8C9), // slate blue
  };

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Resolve repository: injected (tests) or production Firestore
    _repository = widget.repository ?? FirestoreFsrsCardRepository();
    _vocabRepo = widget.vocabRepo ?? VocabRepository();
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
    _sound.loadPreferences().then((_) {
      if (mounted) setState(() {});
    });
    _initDeckAsync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect OS reduce-motion: make the card flip + stars instant (they still
    // happen — the answer reveals, stars appear — just without the transition).
    // Vestibular/seizure-safe. (#76)
    if (prefersReducedMotion(context)) {
      _flipCtrl.duration = Duration.zero;
      _starsCtrl.duration = Duration.zero;
    }
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    _starsCtrl.dispose();
    _wordAudio.dispose();
    super.dispose();
  }

  // ── Deck initialisation (async — loads from Firestore) ────────────────────

  Future<void> _initDeckAsync() async {
    // 1. Resolve a STABLE uid (persists the real uid; reuses it when Firebase
    //    init flakes, so the durable per-uid FSRS deck never forks — #14).
    final uid = await _auth.resolveUid();
    if (!mounted) return;
    _userId = uid;

    // 2. Load vocab list from repository — filtered by child's age
    await _vocabRepo.initialize(eikenGrade: widget.eikenGrade);
    _vocab = filterVocabByAge(_vocabRepo.getAll().toList(), widget.childAge);
    final vocabIds = _vocab.map((v) => v.id).toList();

    // 2.5. Prefetch word audio for this session (fire-and-forget)
    _wordAudio.initialize().then((_) {
      final audioWords = _vocab
          .map((v) => (id: v.id, word: v.word))
          .take(20) // prefetch first 20 to avoid blocking
          .toList();
      _wordAudio.prefetchSession(audioWords);
    }).catchError((_) {});

    // 3. Load persisted cards from Firestore (or InMemory fallback)
    List<FSRSCard> persistedCards;
    try {
      persistedCards = await _repository.loadDeck(uid);
    } catch (_) {
      persistedCards = [];
    }

    // 4. Merge: use persisted state for known words, new card for unknowns
    final cardMap = {for (final c in persistedCards) c.vocabId: c};
    final deck =
        vocabIds.map((id) => cardMap[id] ?? FSRSCard(vocabId: id)).toList();

    // 5. Seed missing new cards to Firestore in batch (first launch)
    final newCards =
        deck.where((c) => !cardMap.containsKey(c.vocabId)).toList();
    if (newCards.isNotEmpty) {
      try {
        await _repository.saveCards(uid, newCards);
      } catch (_) {
        // Non-fatal: will retry on next save
      }
    }

    // 6. Compute due queue. Guarded: a Firestore error here must not leave the
    // child stuck on the loading spinner — fall back to "everything is due" so
    // the deck still opens (#40 render integrity).
    if (!mounted) return;
    final now = DateTime.now();
    List<FSRSCard> dueCards;
    try {
      dueCards = await _repository.getDueCards(uid, now);
    } catch (_) {
      dueCards = const [];
    }
    final dueIds = dueCards.map((c) => c.vocabId).toSet();

    final queue = <int>[];
    for (var i = 0; i < deck.length; i++) {
      if (dueIds.contains(deck[i].vocabId)) queue.add(i);
    }
    queue.shuffle(math.Random());

    // Re-check: getDueCards above is an await AFTER the line-317 mounted check,
    // so a child navigating away mid-load could otherwise setState on a disposed
    // State (a "setState after dispose" crash). Guard right before the mutation.
    if (!mounted) return;
    setState(() {
      _deck = deck;
      _queue = queue.isNotEmpty ? queue : List.generate(deck.length, (i) => i)
        ..shuffle(math.Random());
      _queueIdx = 0;
      _sessionResults.clear();
      _sessionDone = false;
      _isFlipped = false;
      _streak = 0;
      _totalXp = 0;
      _answersThisSession = 0;
      _xpPopups.clear();
      _starsCtrl.reset();
      _repoLoading = false;
      // Session begins now — first card is visible. Capture start timestamp
      // so we can compute real elapsed minutes when the session completes.
      _sessionStartTime = DateTime.now();
      // Clear last session's progress snapshot so the summary recomputes fresh.
      _preEstimate = null;
      _postEstimate = null;
    });
  }

  // ── Current card helpers ───────────────────────────────────────────────────

  int get _currentDeckIdx => _queue[_queueIdx];
  VocabItem get _currentVocab => _vocab[_currentDeckIdx];
  FSRSCard get _currentCard => _deck[_currentDeckIdx];

  int get _totalCards => _queue.length;
  int get _doneCards => _queueIdx;

  // ── Flip ───────────────────────────────────────────────────────────────────

  void _flipCard() {
    if (_isFlipped) return;
    HapticFeedback.lightImpact();
    _sound.playFlip();
    // Auto-play word pronunciation on flip
    WordAudioAutoPlay.trigger(
      player: _wordAudio,
      vocabId: _currentVocab.id,
      word: _currentVocab.word,
    );
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

    // ── Grade-aware XP (P2-7) ─────────────────────────────────────────────
    // XP per grade: Again=0, Hard=5, Good=10, Easy=15
    final xpGain = kGradeXp[grade.name.toLowerCase()] ?? 0;
    _totalXp += xpGain;
    final popupId = ++_xpPopupIdCounter;

    // Show popup only when XP > 0 (Again gives no XP — no popup)
    if (xpGain > 0) {
      _sound.playXpGain();
      setState(() => _xpPopups.add(_XpPopup(xpGain, popupId)));
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() => _xpPopups.removeWhere((p) => p.id == popupId));
        }
      });
    }

    // Persist XP to Firestore (fire-and-forget); check for level-up
    final uid = _userId;
    if (uid != null) {
      // XP persists to Firestore; a level-up sets XpService.levelUpNotifier,
      // which the app-root LevelUpCelebrationHost (app.dart) celebrates for
      // EVERY XP source — battle AND exam practice alike — so the level-up
      // moment is no longer battle-only (it was silent for exam-focused kids).
      _xpService.awardXp(uid, grade).then((_) {}).catchError((_) {
        // Non-fatal: XP syncs later via Firestore offline cache
      });
    }

    final now = DateTime.now();
    final updated = _fsrs.schedule(_currentCard, grade, now);
    _deck[_currentDeckIdx] = updated;
    _sessionResults.add(_CardResult(_currentVocab.word, grade));
    _answersThisSession++;

    // Persist updated card to Firestore (fire-and-forget; offline cache handles it)
    if (uid != null) {
      _repository.saveCard(uid, updated).catchError((_) {
        // Non-fatal: offline writes are cached by Firestore SDK and synced later
      });
    }

    if (updated.state == CardState.learning ||
        updated.state == CardState.relearning) {
      final insertAt = math.min(_queueIdx + 3, _queue.length);
      _queue.insert(insertAt, _currentDeckIdx);
    }

    final nextIdx = _queueIdx + 1;
    if (nextIdx >= _queue.length) {
      _sound.playSessionComplete();
      HapticFeedback.heavyImpact();
      setState(() => _sessionDone = true);
      _starsCtrl.forward();
      _recordSessionToFirestore();
      _recordSkillAccuracy();
      _recordDailyHabit();
      return;
    }

    // ── Mid-session momentum pulse: every 5th answer, if goal not met, show pulse
    _showMomentumPulseIfReady();

    setState(() => _queueIdx = nextIdx);
    _resetFlip();
  }

  // ── Session persistence ────────────────────────────────────────────────────

  /// Bridges the daily vocab Battle into the 合格率 (#35): records this session's
  /// vocab accuracy into [SkillAccuracyStore] as reading-skill evidence, so daily
  /// practice actually moves the pass-probability (it previously did not). Bounded
  /// + conservative — see [battleReadingContribution]. Then recomputes the live
  /// 合格率 so the session-end [PassProgressCard] shows the child their movement
  /// toward 合格. Fire-and-forget; storage errors are swallowed by the store's
  /// guarded in-memory fallback.
  void _recordSkillAccuracy() {
    unawaited(() async {
      // Capture the baseline BEFORE recording this session — deterministically,
      // in the same closure, so the +delta can never be collapsed by a race with
      // an async pre-capture (the pre always reflects prior sessions only).
      final pre = await liveCseEstimate(widget.eikenGrade);

      final c = battleReadingContribution(_sessionResults.map((r) => r.grade));
      if (c.total > 0) {
        try {
          final store = await SkillAccuracyStore.getInstance();
          await store.record(
            grade: widget.eikenGrade,
            skill: EikenSkill.reading,
            correct: c.correct,
            total: c.total,
          );
        } catch (_) {
          // Non-fatal: in-memory fallback handles store errors.
        }
      }
      // Recompute AFTER recording so the summary reflects this session.
      final post = await liveCseEstimate(widget.eikenGrade);
      if (mounted) {
        setState(() {
          _preEstimate = pre;
          _postEstimate = post;
        });
      }
    }());
  }

  /// Shows the momentum pulse SnackBar if conditions are met. Checks current
  /// StreakState snapshot to decide whether to display. Display-only: no
  /// Firestore, no new storage. 1.5s duration matches a typical message reveal.
  void _showMomentumPulseIfReady() {
    if (_streakSnapshot == null) return;

    final (shouldShow, remaining) = shouldShowMomentumPulse(
      _answersThisSession,
      _streakSnapshot!.remainingToGoal,
      _streakSnapshot!.goalMet,
    );

    if (!shouldShow) return;

    if (!mounted) return;
    // Replace any still-visible pulse so a fast answerer (5 cards in <7.5s)
    // never sees a backlog of stale 「あと N問」 nudges queue up.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'あと $remaining 問 で きょうの目標！',
            style: dqText(size: 16, w: FontWeight.w700, color: dqInk),
            textAlign: TextAlign.center,
          ),
          backgroundColor: dqGold.withAlpha(220),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
  }

  /// Records the daily-return habit: counts this review toward today's streak
  /// and the「きょうの目標」daily-goal ring (one per card answered). The primary
  /// FSRS review previously did NOT touch the day-streak/goal — only the quest
  /// サイレント battle did — so a child who only did vocab review saw the home
  /// streak/goal never move. Fire-and-forget; prefs failures are swallowed.
  void _recordDailyHabit() {
    final answered = _sessionResults.length;
    if (answered <= 0) return;
    unawaited(() async {
      final streak = StreakService();
      try {
        await streak.recordStudySession();
        await streak.recordProgress(answered);
        // Surface the resulting streak/goal on the summary (peak engagement).
        final snapshot = await streak.load();
        if (mounted) setState(() => _streakSnapshot = snapshot);
      } catch (_) {
        // Non-fatal: SharedPreferences failure is rare.
      }
    }());
  }

  /// Writes session stats to Firestore after session completes.
  /// Fire-and-forget — offline Firestore cache will sync when connection returns.
  void _recordSessionToFirestore() {
    final uid = _userId;
    if (uid == null) return;

    final total = _sessionResults.length;
    if (total == 0) return;

    final gradeSum =
        _sessionResults.fold(0.0, (sum, r) => sum + r.grade.index1.toDouble());
    final avgScore = gradeSum / total;

    // Cumulative mastered/practiced across all sessions (the deck merges
    // persisted FSRS state). The achievement check previously received `total`
    // (THIS session's size, ~10-20), so the monotonic practice progress never
    // reached practice_50/200/500's targets and those badges could never unlock
    // — even after the child had practiced hundreds of words. The Firestore
    // record used `_deck.length` (the WHOLE grade vocab), over-reporting the
    // opposite way. Both now use the same honest cumulative count.
    final masteredCount = masteredCardCount(_deck);
    final practicedCount = practicedCardCount(_deck);

    // Real elapsed study time (P0.1) — computed from session start timestamp.
    final minutes =
        BattleScreen.elapsedMinutes(_sessionStartTime, DateTime.now());

    final progressService = ProgressService(
      repository: FirestoreProgressRepository(),
    );

    progressService
        .recordSession(
      uid: uid,
      wordsPracticed: total,
      minutes: minutes,
      avgScore: avgScore,
      totalMastered: masteredCount,
      totalPracticed: practicedCount,
      streak: 1, // server will recalculate from session history
    )
        .catchError((_) {
      // Non-fatal: offline writes queued by Firestore SDK
    });

    // Check achievements after session (T06). Use the CUMULATIVE practiced count,
    // not `total` (this session only) — else practice_50/200/500 never unlock.
    _checkAchievements(uid, masteredCount, practicedCount);
  }

  // ── Achievement check (T06) ───────────────────────────────────────────────

  Future<void> _checkAchievements(
      String uid, int masteredCount, int totalPracticed) async {
    final profile = _xpService.currentProfile(uid);
    // Load the REAL streak so the streak_3/7/10 milestones can actually unlock.
    // Was hard-coded to 1 ("server-side best-effort"), but the server isn't
    // deployed (#7) → those achievements never fired even for a genuine 7-day
    // streak. A failed load falls back to 0 and never blocks the other unlocks.
    int currentStreak = 0;
    try {
      currentStreak = (await StreakService().load()).currentStreak;
    } catch (_) {}
    if (!mounted) return;
    try {
      await _achievementService.checkAndUpdate(
        uid: uid,
        totalMastered: masteredCount,
        currentStreak: currentStreak,
        totalPracticed: totalPracticed,
        level: profile?.level ?? 1,
      );
      // The unlock is broadcast via AchievementService.unlockEvents (set inside
      // checkAndUpdate) and celebrated by the app-root AchievementUnlockHost
      // (app.dart), so EVERY source — battle AND exam practice — shows the same
      // バッジ獲得 banner. No per-screen popup here anymore.
    } catch (_) {}
  }

  // ── Level-up dialog (P2-7) ────────────────────────────────────────────────

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Key changes when the body state changes, triggering AnimatedSwitcher.
    // Empty-deck guard (defense-in-depth): if the load produced no cards (a grade
    // with no vocab at all), _queue is empty and _buildCardSession would deref
    // _vocab[_queue[0]] → RangeError. Show a calm empty state instead of crashing
    // the core review screen. (The usual age-filter-empties-a-grade cause is fixed
    // at the root in filterVocabByAge; this guards the remaining truly-empty case.)
    final isEmpty = !_repoLoading && !_sessionDone && _queue.isEmpty;
    final bodyKey = _repoLoading
        ? const ValueKey('loading')
        : _sessionDone
            ? const ValueKey('summary')
            : isEmpty
                ? const ValueKey('empty')
                : const ValueKey('session');
    final body = _repoLoading
        ? _buildLoadingSpinner()
        : _sessionDone
            ? _buildSummary()
            : isEmpty
                ? _buildEmptyDeck()
                : _buildCardSession();

    return DqScene(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(key: bodyKey, child: body),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSpinner() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: dqGold, strokeWidth: 3),
          const SizedBox(height: 16),
          Text('カードを読み込んでいます…', style: dqText(size: 14, color: dqInk)),
        ],
      ),
    );
  }

  /// Calm empty state when this grade has no cards to review (never crash).
  Widget _buildEmptyDeck() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🃏', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 14),
            Text(
              'このグレードの カードは、まだ じゅんびちゅう。\n'
              'ほかの グレードで れんしゅう してみよう！',
              textAlign: TextAlign.center,
              style: dqText(size: 14, color: dqInk).copyWith(height: 1.6),
            ),
            const SizedBox(height: 20),
            DqButton(
              label: 'もどる',
              onTap: () => Navigator.maybePop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dark header (replaces the bright AppBar): back arrow + gold serif title,
  // streak badge, mute toggle, and the N / total counter. ──────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'もどる / Back',
            icon: const Icon(Icons.arrow_back, color: dqInk),
            onPressed: () => Navigator.maybePop(context),
          ),
          const Icon(Icons.style_rounded, color: dqGold, size: 22),
          const SizedBox(width: 8),
          // #114/WCAG SC 1.4.4: Flexible so the title wraps/shrinks at large text
          // scales instead of pushing the header Row into a ~57px overflow.
          Flexible(
            child: dqBilingual('たんごバトル', 'Word Battle',
                jpSize: 17, jpColor: dqGold, stacked: true),
          ),
          if (_streak >= 3) ...[
            const SizedBox(width: 10),
            _StreakBadge(streak: _streak),
          ],
          const Spacer(),
          // Live XP ring (game-feel, CEO 1320): a bar filling toward the next
          // level, visible while answering, so the child sees momentum and
          // chooses "one more problem". Reactive to XP awards via profileNotifier.
          ValueListenableBuilder<XpProfile?>(
            valueListenable: _xpService.profileNotifier,
            builder: (_, profile, __) => profile == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _XpRing(profile: profile),
                  ),
          ),
          IconButton(
            icon: Icon(
              _sound.muted ? Icons.volume_off : Icons.volume_up,
              color: dqInk,
              size: 22,
            ),
            tooltip: _sound.muted ? 'サウンドON' : 'サウンドOFF',
            onPressed: () => setState(() => _sound.muted = !_sound.muted),
          ),
          if (!_repoLoading && !_sessionDone)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text('${_doneCards + 1} / $_totalCards',
                  style: dqText(size: 14, color: dqGoldDeep)),
            ),
        ],
      ),
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
    // HP-style bar: cream-bordered navy track with a gold fill.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: dqNight0,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: dqBorder, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.transparent,
            valueColor: const AlwaysStoppedAnimation<Color>(dqGold),
          ),
        ),
      ),
    );
  }

  Widget _buildFlipCardWithShimmer() {
    // #72: the card sat in an Expanded with width:infinity, so it stretched to
    // fill ALL vertical space — the word floated in a huge dead void. Cap it to a
    // proper flashcard proportion and CENTRE it in the available space, so the
    // dark scene reads above/below the card instead of an empty navy panel.
    // (The card's own content drives its height ~320-460; flip + shimmer stay
    // consistent front/back since both faces use _cardContainer.)
    return Center(
      child: ConstrainedBox(
        // 480 (was 460): the #65 active-recall cue added ~2 lines to the front
        // face, which overflowed the 460 cap by ~2px on some layout frames (an
        // intermittent RenderFlex overflow). 480 keeps the tight flashcard
        // proportion (#72 — not the old full-height void) with real headroom.
        constraints: const BoxConstraints(maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Stack(
            children: [
              // a11y: flipping the card to reveal the meaning is the core battle
              // action — without Semantics a screen-reader child can't do it and the
              // loop is unplayable for them. Front = ONE button announcing the word +
              // "flip to reveal" (excludeSemantics collapses the raw Texts into the
              // action); once flipped it is not a button and the back's word / meaning
              // / example are read normally.
              _isFlipped
                  ? GestureDetector(onTap: null, child: _buildFlipCard())
                  : Semantics(
                      button: true,
                      label: '${_currentVocab.word}。'
                          'いみを 思い出してから、カードを めくって かくにん / '
                          'Recall the meaning, then flip to check',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: _flipCard,
                        child: _buildFlipCard(),
                      ),
                    ),
              // Golden shimmer overlay on correct answer
              if (_showShimmer)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _showShimmer ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: RadialGradient(
                          colors: [
                            dqGold.withAlpha(110),
                            dqGold.withAlpha(0),
                          ],
                          radius: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            vocab.word,
            style: dqText(
              size: 48,
              w: FontWeight.w800,
              color: dqInk,
              spacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Speaker icon — tap to hear pronunciation
          IconButton(
            icon: const Icon(Icons.volume_up_rounded),
            iconSize: 28,
            color: dqGold,
            tooltip: '発音を聞く',
            onPressed: () {
              WordAudioAutoPlay.trigger(
                player: _wordAudio,
                vocabId: vocab.id,
                word: vocab.word,
              );
            },
          ),
          const SizedBox(height: 4),
          Text(vocab.reading, style: dqText(size: 18, color: dqGoldDeep)),
          const SizedBox(height: 10),
          if (vocab.pos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: dqGold.withAlpha(150), width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(vocab.pos.first.name,
                  style: dqText(size: 12, color: dqGold)),
            ),
          const SizedBox(height: 14),
          // #85 (game-studio #4): a per-POS サイレント word-rescue frame ties this
          // review to the world's premise — the flashcard is a word you're bringing
          // BACK from the Silence, not a context-free Anki card. The active-recall
          // cue (#65) follows so retrieval is still cued (Karpicke testing effect).
          dqBilingual(
              silentRescueLineJa(vocab.pos.isNotEmpty
                  ? vocab.pos.first
                  : PartOfSpeech.unknown),
              'The Silence took this word.',
              jpSize: 12,
              jpColor: dqGold,
              enColor: dqGold),
          const SizedBox(height: 6),
          dqBilingual('こころの中（なか）で おもいだして、タップ', 'Recall it, then tap to check',
              jpSize: 13, jpColor: dqGoldDeep, enColor: dqGoldDeep),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    final vocab = _currentVocab;
    final example =
        vocab.exampleSentences.isNotEmpty ? vocab.exampleSentences.first : '';
    return _cardContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(vocab.word, style: dqText(size: 22, color: dqGoldDeep)),
          const SizedBox(height: 16),
          Text(
            vocab.jpTranslation,
            style: dqText(size: 42, w: FontWeight.w800, color: dqInk),
            textAlign: TextAlign.center,
          ),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: dqNight0.withAlpha(160),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dqGoldDeep.withAlpha(120)),
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: exampleHighlightSpans(
                    example,
                    vocab.word,
                    base: dqText(size: 15, w: FontWeight.w500, color: dqInk),
                    emphasis:
                        dqText(size: 15, w: FontWeight.w800, color: dqGold),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // The flashcard rendered as a DQ command/dialogue window: navy fill, cream
  // double-border, deep shadow. (Both faces share this frame.)
  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      decoration: BoxDecoration(
        color: dqBox.withAlpha(238),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dqBorder, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: child,
    );
  }

  Widget _buildTapHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: dqBilingual(
          'いみを 思（おも）い出（だ）してから タップ', 'Recall the meaning, then tap to check',
          jpSize: 13, jpColor: dqGoldDeep, enColor: dqGoldDeep),
    );
  }

  // ── Grade buttons ──────────────────────────────────────────────────────────

  Widget _buildGradeButtons() {
    // #84 (game-studio director #3): TWO child-facing choices, not four FSRS
    // grades. 2026 SRS-for-kids evidence (Migaku/Mathbuilders) + FSRS-6 (which
    // TRUSTS grades): a young child can't honestly self-grade Again/Hard/Good/Easy,
    // so the noise pollutes the model and the 8yo freezes & picks randomly (the
    // playtest complaint). わからなかった→Again, わかった！→Good, auto-upgraded to Easy
    // on a 3rd+ consecutive correct (a BEHAVIOURAL fluency signal — a child on a
    // roll clearly knows these — not another self-assessment the child can't make).
    final knewGrade = _streak >= 2 ? Grade.easy : Grade.good;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _GradeButton(
                grade: Grade.again,
                accent: _gradeColors[Grade.again]!,
                fsrs: _fsrs,
                card: _currentCard,
                labelJpOverride: '？ わからなかった',
                labelEnOverride: 'Didn’t know',
                onTap: () => _gradeCard(Grade.again),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _GradeButton(
                grade: knewGrade,
                // Fixed green regardless of the auto-easy upgrade, so わかった！ never
                // changes colour mid-session (the upgrade is invisible to the child).
                accent: _gradeColors[Grade.good]!,
                fsrs: _fsrs,
                card: _currentCard,
                labelJpOverride: '✓ わかった！',
                labelEnOverride: 'Knew it!',
                onTap: () => _gradeCard(knewGrade),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Session summary ────────────────────────────────────────────────────────

  Widget _buildSummary() {
    final total = _sessionResults.length;
    final counts = <Grade, int>{for (final g in Grade.values) g: 0};
    for (final r in _sessionResults) {
      counts[r.grade] = (counts[r.grade] ?? 0) + 1;
    }
    final gradeSum =
        _sessionResults.fold(0.0, (sum, r) => sum + r.grade.index1.toDouble());
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
                const Icon(Icons.military_tech_rounded,
                    color: dqGold, size: 64),
                const SizedBox(height: 12),
                dqBilingual(
                  'セッション完了！',
                  'BATTLE CLEARED',
                  jpSize: 26,
                  jpColor: dqGold,
                  stacked: true,
                  align: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text('$total 枚 完了 / $total cards',
                    style: dqText(size: 16, color: dqInk)),
                // XP earned
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: dqNight0.withAlpha(180),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: dqGold.withAlpha(160), width: 1.5),
                  ),
                  child: Text('✨ +$_totalXp XP 獲得！',
                      style:
                          dqText(size: 16, w: FontWeight.w800, color: dqGold)),
                ),
                // Daily-return hook — day-streak + 「きょうの目標」 progress at the
                // peak-engagement moment, so the child feels the habit building
                // and is pulled to「あと N問」 (CEO 1320 fun→volume→合格 loop;
                // CEO 951 daily-return spine). Honest: real StreakService data.
                if (_streakSnapshot != null) ...[
                  const SizedBox(height: 12),
                  _DailyReturnCard(snapshot: _streakSnapshot!),
                ],
                // 合格率 progress moment — the in-context "I'm closer to 合格"
                // signal at peak engagement (the daily-return spine, CEO 951).
                // Skipped when there's no estimate yet (never fabricate).
                if (_postEstimate != null) ...[
                  const SizedBox(height: 22),
                  PassProgressCard(pre: _preEstimate, post: _postEstimate!),
                ],
                const SizedBox(height: 28),
                _SummaryCard(
                  title: 'けっか / Results',
                  children: Grade.values.map((g) {
                    return _SummaryRow(
                      label: '${_gradeJp(g)} / ${g.label}',
                      color: _gradeColors[g]!,
                      count: counts[g] ?? 0,
                      total: total,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _SummaryCard(
                  title: 'スタッツ / Stats',
                  children: [
                    _StatTile(
                      label: '平均評価 / Avg. grade',
                      value: avgGrade.toStringAsFixed(2),
                      icon: Icons.grade_rounded,
                    ),
                    const Divider(color: dqGoldDeep, height: 18),
                    _StatTile(
                      label: '正確さ / Accuracy',
                      value: total > 0
                          ? '${(((counts[Grade.good]! + counts[Grade.easy]!) / total) * 100).round()}%'
                          : '—',
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF8BE08B),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                DqButton(
                  label: 'もういちど / Again',
                  onTap: () => setState(() {
                    _initDeckAsync();
                  }),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: dqBilingual('ホームへ戻る', 'Back to town',
                        jpSize: 14, jpColor: dqInk, enColor: dqGoldDeep),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dqBorder, width: 1.5),
        boxShadow: [BoxShadow(color: dqGoldDeep.withAlpha(110), blurRadius: 8)],
      ),
      child: Text(
        '🔥 × $streak',
        style: dqText(
          size: 13,
          w: FontWeight.w800,
          color: const Color(0xFF2A1C00),
        ),
      ),
    );
  }
}

// ── Daily-return hook (summary) ────────────────────────────────────────────────
//
// Shown on the session-complete summary: the day-streak the child just extended
// plus how close they are to today's 目標. This is the daily-return spine made
// visible at peak engagement (CEO 951/1320) — and it is honest, reading real
// StreakService state, never fabricating a streak.
class _DailyReturnCard extends StatelessWidget {
  final StreakState snapshot;
  const _DailyReturnCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final streak = snapshot.currentStreak;
    final goalLine = snapshot.goalMet
        ? '🎉 きょうの目標 たっせい！'
        : 'あと ${snapshot.remainingToGoal}問 で きょうの目標！';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: dqNight0.withAlpha(180),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dqGold.withAlpha(120), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (streak >= 1)
            Text('🔥 $streak日 れんぞく！',
                style: dqText(size: 16, w: FontWeight.w800, color: dqGold)),
          if (streak >= 1) const SizedBox(height: 4),
          Text(goalLine,
              style: dqText(
                  size: 13,
                  w: FontWeight.w700,
                  color: snapshot.goalMet ? const Color(0xFF8BE08B) : dqInk)),
        ],
      ),
    );
  }
}

// ── Live XP progress ring ──────────────────────────────────────────────────────
//
// Game-feel (CEO 1320): a small ring in the battle header that fills toward the
// next level as the child answers, so they *see* momentum and choose "one more
// problem" — the fun→volume→英検合格 loop. Pulses gently when within ~2 answers
// of levelling up to pull them over the line. Reduced-motion respected; no new
// backend, no network. Reactive to XP awards via XpService.profileNotifier.
class _XpRing extends StatefulWidget {
  final XpProfile profile;
  const _XpRing({required this.profile});

  @override
  State<_XpRing> createState() => _XpRingState();
}

class _XpRingState extends State<_XpRing> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  // Within ~2 "easy" answers of the next level (and not already maxed).
  bool get _close {
    final p = widget.profile;
    if (p.levelXpSpan == 0 || p.levelXpSpan == 9999) return false;
    return (p.levelXpSpan - p.currentLevelXp) <= (kGradeXp['easy']! * 2);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _XpRing old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  void _syncPulse() {
    final on = _close && !prefersReducedMotion(context);
    if (on && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!on && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final maxed = p.levelXpSpan == 9999;
    final remaining =
        maxed ? 0 : (p.levelXpSpan - p.currentLevelXp).clamp(0, 9999);
    return Tooltip(
      message: maxed ? 'さいこうレベル！' : 'つぎのレベルまで あと $remaining',
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Opacity(
          opacity: _close ? 0.62 + _pulse.value * 0.38 : 1.0,
          child: child,
        ),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: maxed ? 1.0 : p.levelProgress,
                  strokeWidth: 3,
                  backgroundColor: dqGold.withAlpha(38),
                  valueColor: const AlwaysStoppedAnimation<Color>(dqGold),
                ),
              ),
              Text(
                'Lv${p.level}',
                style: dqText(size: 10, w: FontWeight.w800, color: dqGold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grade button widget (with scale-bounce) ────────────────────────────────────

class _GradeButton extends StatefulWidget {
  final Grade grade;
  final Color accent;
  final FSRSAlgorithm fsrs;
  final FSRSCard card;
  final VoidCallback onTap;

  /// Child-facing label overrides (#84): the recall UI presents 2 plain choices
  /// (わからなかった / わかった！) instead of the 4 FSRS grades a young child can't
  /// self-assess. When set, these replace the grade's JP/EN label.
  final String? labelJpOverride;
  final String? labelEnOverride;

  const _GradeButton({
    required this.grade,
    required this.accent,
    required this.fsrs,
    required this.card,
    required this.onTap,
    this.labelJpOverride,
    this.labelEnOverride,
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
    final simCard =
        widget.fsrs.schedule(widget.card, widget.grade, DateTime.now());
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
    // A DQ command-window tile: cream-bordered navy fill, an accent dot for the
    // grade, bilingual JP/EN label, and the FSRS next-interval underneath.
    // a11y: the recall-grade buttons are how the child completes a card — without
    // Semantics a screen-reader child can flip the card but can't RATE it, so the
    // loop is still blocked. Expose each as a button announcing the grade + the
    // FSRS next-interval; onTap gives assistive tech the activation path.
    return Semantics(
      button: true,
      label: widget.labelJpOverride != null
          ? '${widget.labelJpOverride}。つぎは $interval'
          : '${_gradeJp(widget.grade)} ${widget.grade.label}。つぎは $interval',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
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
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: dqBox.withAlpha(225),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dqBorder, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: widget.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: dqBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                          color: widget.accent.withAlpha(120), blurRadius: 6)
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.labelJpOverride ?? _gradeJp(widget.grade),
                  style: dqText(
                      size: widget.labelJpOverride != null ? 15 : 12,
                      w: FontWeight.w800,
                      color: dqInk),
                  textAlign: TextAlign.center,
                ),
                Text(
                  widget.labelEnOverride ?? widget.grade.label,
                  style: dqText(
                      size: 9, w: FontWeight.w600, color: dqGold, spacing: 0.8),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Text(
                  interval,
                  style: dqText(size: 9, color: dqGoldDeep),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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
                  style: dqText(size: 22, w: FontWeight.w800, color: dqGold),
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
      size: 6 + _rng.nextDouble() * 10,
      // Muted gold/cream sparks — stays within the DQ palette.
      color: [
        dqGold,
        dqGoldDeep,
        dqInk,
        const Color(0xFFD9B25A),
        const Color(0xFFEED9A0),
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
  final String? title;
  const _SummaryCard({required this.children, this.title});

  @override
  Widget build(BuildContext context) {
    return DqPanel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  final int total;

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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: dqBorder, width: 1),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: dqText(size: 11, w: FontWeight.w600, color: dqInk),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: dqNight0,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: dqGoldDeep.withAlpha(120), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 7,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: dqText(size: 13, color: dqInk)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor = dqGold,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: dqText(size: 13, color: dqInk)),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: dqText(size: 15, w: FontWeight.w800, color: dqGold)),
        ],
      ),
    );
  }
}
