// test/features/home/kotoba_home_smoke_test.dart
// R3 smoke tests for KotobaHomeScreen.
//
// Tests:
//   1. Smoke: pumps the screen with empty/mock prefs → takeException() == null.
//   2. Streak display: shows streak count text (N にち れんぞく) when streak > 0.
//   3. Empty due-state: shows the empty ナゾ message when no cards are due.
//   4. Due items: shows the diegetic "Nつ とどいた" message when cards are due.
//   5. Primary CTA: "じけんげんばへ" button is present.
//   6. Secondary CTA: "ちずを みる" button is present.
//
// R4 compliance: no Firebase is initialized.  KotobaHomeScreen accepts injected
// StreakService / FsrsCardRepository so tests avoid all Firebase paths.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/firebase/auth_service.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/home/streak_service.dart';
import 'package:engquest/features/home/kotoba_home_screen.dart';
import 'package:engquest/features/exam_practice/exam_practice_screen.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';
import 'package:engquest/features/exam_practice/pass/pass_meter_screen.dart';

// ── Mock helpers ──────────────────────────────────────────────────────────────

/// A StreakService that returns a fixed [StreakState] without touching prefs.
class _MockStreakService extends StreakService {
  final StreakState _state;
  _MockStreakService(this._state);

  @override
  Future<StreakState> load({DateTime? now}) async => _state;
}

/// A StreakService that returns a different [StreakState] on each load() call —
/// used to prove the home RE-READS streak state when the child returns from a
/// practice screen (the daily-goal ring must not stay frozen at mount value).
class _SequenceStreakService extends StreakService {
  final List<StreakState> _states;
  int loadCount = 0;
  _SequenceStreakService(this._states);

  @override
  Future<StreakState> load({DateTime? now}) async {
    final s =
        _states[loadCount < _states.length ? loadCount : _states.length - 1];
    loadCount++;
    return s;
  }
}

/// An [InMemoryFsrsCardRepository] pre-seeded with [dueCount] cards all due now.
///
/// Returns a Future so callers can await seeding before pumping the widget.
Future<InMemoryFsrsCardRepository> _repoWithDue(int dueCount) async {
  final repo = InMemoryFsrsCardRepository();
  // Seed under the SAME id the home resolves to in a Firebase-less test:
  // resolveUid() falls back to AuthService.offlineUid (no persisted uid here).
  final userId = AuthService.offlineUid;
  final now = DateTime.now().subtract(const Duration(minutes: 1));
  for (var i = 0; i < dueCount; i++) {
    await repo.saveCard(
      userId,
      FSRSCard(
        vocabId: 'test_$i',
        state: CardState.review,
        stability: 1.0,
        difficulty: 5.0,
        reps: 1,
        lapses: 0,
        dueDate: now,
      ),
    );
  }
  return repo;
}

// ── Widget wrapper ────────────────────────────────────────────────────────────

Widget _wrap({
  StreakService? streakService,
  FsrsCardRepository? cardRepository,
  String? initialEikenLevel,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: const ColorScheme.dark(),
      useMaterial3: true,
      textTheme: GoogleFonts.notoSerifJpTextTheme(ThemeData.dark().textTheme),
    ),
    home: KotobaHomeScreen(
      streakService: streakService,
      cardRepository: cardRepository,
      initialEikenLevel: initialEikenLevel ?? '5',
    ),
  );
}

/// Pump enough frames for all post-frame async work to complete.
/// Uses fixed duration steps to avoid timeout from continuously-animating widgets.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
    SkillAccuracyStore.resetInstance();

    // Suppress Firebase-not-initialized errors — KotobaHomeScreen never calls
    // Firebase directly, but some transitively imported services may.
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      if (msg.contains('Firebase') || msg.contains('No Firebase App')) return;
      FlutterError.presentError(details);
    };
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
  });

  // ── R3 smoke test ─────────────────────────────────────────────────────────

  testWidgets('KotobaHomeScreen: smoke — no exception with empty prefs',
      (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  // ── Streak display ────────────────────────────────────────────────────────

  testWidgets('KotobaHomeScreen: shows streak count text', (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(
        const StreakState(currentStreak: 7, weeklyBits: 63, todayCount: 1),
      ),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    // Should show "7" and "にち れんぞく".
    expect(find.textContaining('7'), findsWidgets);
    expect(find.textContaining('にち れんぞく'), findsOneWidget);
  });

  testWidgets('KotobaHomeScreen: zero streak shows first-case message',
      (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    expect(find.textContaining('はじめての'), findsWidgets);
  });

  testWidgets('streak with NO study today → gentle keep-going nudge (#22)',
      (tester) async {
    await tester.pumpWidget(_wrap(
      // Active streak but problemsToday == 0 → not yet studied today.
      streakService: _MockStreakService(const StreakState(
          currentStreak: 5, weeklyBits: 31, todayCount: 0, problemsToday: 0)),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    // A no-guilt invitation to continue — never a "you'll lose it" threat.
    expect(find.textContaining('つづけよう'), findsWidgets);
  });

  testWidgets('streak already studied today → celebrates, no nudge (#22)',
      (tester) async {
    await tester.pumpWidget(_wrap(
      // problemsToday > 0 → streak secured for today.
      streakService: _MockStreakService(const StreakState(
          currentStreak: 5, weeklyBits: 31, todayCount: 1, problemsToday: 8)),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    // Celebratory tier, not the keep-going nudge.
    expect(find.textContaining('つづいてる'), findsNothing);
  });

  // ── Due-count display ─────────────────────────────────────────────────────

  testWidgets('KotobaHomeScreen: empty due-state shows quiet館 message',
      (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(), // empty → 0 due
    ));
    await _settle(tester);
    // Empty state: "館は しずか……"
    expect(find.textContaining('しずか'), findsOneWidget);
  });

  testWidgets('KotobaHomeScreen: N due items shows diegetic message',
      (tester) async {
    final repo = await _repoWithDue(3);
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: repo,
    ));
    await _settle(tester);
    // Due items framing: "Nつ とどいた"
    expect(find.textContaining('とどいた'), findsWidgets);
  });

  // ── CTAs ──────────────────────────────────────────────────────────────────

  testWidgets('KotobaHomeScreen: primary CTA is present', (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    expect(find.textContaining('じけんげんばへ'), findsOneWidget);
  });

  testWidgets('KotobaHomeScreen: secondary map CTA is present', (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    expect(find.textContaining('ちずを みる'), findsOneWidget);
  });

  testWidgets(
      'KotobaHomeScreen: 英検 practice CTA navigates to ExamPracticeScreen',
      (tester) async {
    // The exam-practice hub (大問/模試/合格メーター) was previously reachable only
    // from the orphaned WorldMapScreen hub. This CTA is the live entry point —
    // tap-and-assert-navigation (not just text presence) so the core 合格 surface
    // cannot silently become unreachable again (a dropped onTap would pass a
    // text-only check).
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    // #66: 英検 practice is now the PRIMARY (gold) CTA — fact_check_rounded.
    final cta = find.byIcon(Icons.fact_check_rounded);
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.byType(ExamPracticeScreen), findsOneWidget);
  });

  testWidgets('KotobaHomeScreen: きょうの ナゾ panel navigates to FSRS review (#66)',
      (tester) async {
    // #66: the due-count panel now opens the FSRS vocabulary review
    // (BattleScreen) instead of stranding the child. Before, BattleScreen was
    // only reachable via the orphaned WorldMapScreen.
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    // The readiness card also has a chevron; the Nazo panel's is the last one
    // (it sits below the readiness card).
    final nazo = find.byIcon(Icons.chevron_right).last;
    await tester.ensureVisible(nazo);
    await tester.tap(nazo);
    await tester.pump(); // start the route push
    await tester
        .pump(const Duration(milliseconds: 500)); // advance the transition
    expect(find.byType(BattleScreen), findsOneWidget);
    // Unmount so the pushed screen's post-frame async does not leak.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
      'KotobaHomeScreen: readiness card shows live 合格率 + opens PassMeter (#66/#68)',
      (tester) async {
    // Seed practice data so the card shows a live readiness %.
    final store = await SkillAccuracyStore.getInstance();
    await store.record(
        grade: '5', skill: EikenSkill.reading, correct: 8, total: 10);
    await store.record(
        grade: '5', skill: EikenSkill.listening, correct: 7, total: 10);

    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);

    expect(find.textContaining('合格率'), findsWidgets);
    expect(find.textContaining('%'), findsWidgets); // the live readiness %

    // The readiness card sits at the top — its chevron is the first.
    final card = find.byIcon(Icons.chevron_right).first;
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(PassMeterScreen), findsOneWidget);
  });

  testWidgets(
      'KotobaHomeScreen: readiness card stays HONEST on thin data (audit fix)',
      (tester) async {
    // A few items must NOT show a confident「ごうかくけん」/pass — it would read as
    // fabricated to a paying parent. Seed only 3 answers.
    final store = await SkillAccuracyStore.getInstance();
    await store.record(
        grade: '5', skill: EikenSkill.reading, correct: 2, total: 3);

    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);

    expect(find.textContaining('しんだんちゅう'), findsOneWidget,
        reason: 'thin sample → "still diagnosing", not a confident pass');
    expect(find.textContaining('ごうかくけん'), findsNothing,
        reason: 'must not claim 合格圏 on 3 answers');
  });

  // ── Panel titles ──────────────────────────────────────────────────────────

  testWidgets('KotobaHomeScreen: streak panel title visible', (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    expect(find.textContaining('捜査日誌'), findsWidgets);
  });

  testWidgets('KotobaHomeScreen: nazo panel title visible', (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    expect(find.textContaining('きょうの'), findsWidgets);
  });

  // ── Daily-goal ring (きょうの目標) — engagement spine (CEO 951) ──────────────

  testWidgets('KotobaHomeScreen: empty daily goal shows start prompt + N/goal',
      (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    // Caption nudges the child to begin (goal default = 10).
    expect(find.textContaining('きょうの目標'), findsWidgets);
    expect(find.textContaining('さあ はじめよう'), findsOneWidget);
    // Ring centre shows the goal denominator.
    expect(find.textContaining('/10問'), findsOneWidget);
  });

  testWidgets('KotobaHomeScreen: partial daily goal shows remaining count',
      (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(
        const StreakState(
          currentStreak: 1,
          weeklyBits: 1,
          todayCount: 1,
          problemsToday: 4,
          dailyGoal: 10,
        ),
      ),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    // 10 - 4 = 6 remaining.
    expect(find.textContaining('あと 6問'), findsOneWidget);
  });

  testWidgets(
      'KotobaHomeScreen: daily goal RELOADS after returning from practice (P0)',
      (tester) async {
    // Proves the daily-return loop actually loops: the home must re-read streak
    // state when the child pops back from a practice screen, or the ring is a
    // frozen mount-time snapshot (the adversarial-audit P0 this commit fixes).
    final svc = _SequenceStreakService(const [
      // Mount: nothing done yet.
      StreakState(
          currentStreak: 0,
          weeklyBits: 0,
          todayCount: 0,
          problemsToday: 0,
          dailyGoal: 10),
      // After a session: 6 questions answered.
      StreakState(
          currentStreak: 1,
          weeklyBits: 1,
          todayCount: 1,
          problemsToday: 6,
          dailyGoal: 10),
    ]);
    await tester.pumpWidget(_wrap(
      streakService: svc,
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    expect(svc.loadCount, 1);
    expect(find.textContaining('さあ はじめよう'), findsOneWidget);

    // Open the map (uses _pushThenRefresh), then pop back as the child would.
    final mapCta = find.textContaining('ちずを みる');
    await tester.ensureVisible(mapCta);
    await tester.tap(mapCta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await _settle(tester);

    // Home re-read streak (load called again) and the ring now reflects 6/10.
    expect(svc.loadCount, greaterThanOrEqualTo(2));
    expect(find.textContaining('あと 4問'), findsOneWidget);
  });

  testWidgets('KotobaHomeScreen: met daily goal celebrates (達成)',
      (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(
        const StreakState(
          currentStreak: 3,
          weeklyBits: 7,
          todayCount: 2,
          problemsToday: 12,
          dailyGoal: 10,
        ),
      ),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    expect(find.textContaining('達成'), findsOneWidget);
    // Goal-met ring shows a check, not the numeric counter.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  // ── スラ companion (progress-reactive retention mechanic) ───────────────────

  testWidgets('KotobaHomeScreen: スラ companion celebrates a met daily goal',
      (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(
        const StreakState(
          currentStreak: 3,
          weeklyBits: 7,
          todayCount: 2,
          problemsToday: 12,
          dailyGoal: 10,
        ),
      ),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    // The companion card is present and reacts to the met-goal state.
    expect(find.byKey(const ValueKey('home_companion_sura')), findsOneWidget);
    expect(find.textContaining('きみと いると たのしいよ'), findsOneWidget);
  });

  testWidgets('KotobaHomeScreen: スラ companion warmly welcomes a returner',
      (tester) async {
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(
        const StreakState(
          currentStreak: 0,
          weeklyBits: 0,
          todayCount: 0,
          streakBroken: true,
        ),
      ),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    expect(find.byKey(const ValueKey('home_companion_sura')), findsOneWidget);
    // A lapsed returner gets a warm, non-shaming welcome — not a guilt nag.
    expect(find.textContaining('また いっしょに なぞ'), findsOneWidget);
  });

  // ── a11y (T14): the icon-only settings gear must be a labelled button ───────

  testWidgets('KotobaHomeScreen: settings gear is an a11y-labelled button',
      (tester) async {
    // The gear is the sole gateway to mute / how-to-play / Parent / Achievements
    // / Battle. As a bare icon-only GestureDetector a screen reader announced
    // nothing, so a non-visual child could not reach settings at all (flaw-hunt
    // 2026-06-13). It must expose a name + button role like the readiness card.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(
      streakService: _MockStreakService(const StreakState.zero()),
      cardRepository: InMemoryFsrsCardRepository(),
    ));
    await _settle(tester);
    expect(find.bySemanticsLabel('せってい / Settings'), findsOneWidget);
    handle.dispose();
  });
}
