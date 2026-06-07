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

import 'package:engquest/core/fsrs/fsrs_card_repository.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/home/streak_service.dart';
import 'package:engquest/features/home/kotoba_home_screen.dart';
import 'package:engquest/features/exam_practice/exam_practice_screen.dart';

// ── Mock helpers ──────────────────────────────────────────────────────────────

/// A StreakService that returns a fixed [StreakState] without touching prefs.
class _MockStreakService extends StreakService {
  final StreakState _state;
  _MockStreakService(this._state);

  @override
  Future<StreakState> load() async => _state;
}

/// An [InMemoryFsrsCardRepository] pre-seeded with [dueCount] cards all due now.
///
/// Returns a Future so callers can await seeding before pumping the widget.
Future<InMemoryFsrsCardRepository> _repoWithDue(int dueCount) async {
  final repo = InMemoryFsrsCardRepository();
  const userId = 'local';
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
    final cta = find.byIcon(Icons.fact_check_outlined);
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.byType(ExamPracticeScreen), findsOneWidget);
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
}
