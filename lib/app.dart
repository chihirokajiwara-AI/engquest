import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:engquest/core/gamification/xp_service.dart';
import 'package:engquest/core/gamification/xp_profile.dart';
import 'package:engquest/core/gamification/achievement_service.dart';
import 'package:engquest/core/gamification/achievement.dart';
import 'package:engquest/core/sound/sound_service.dart';
import 'package:engquest/core/ui/app_fonts.dart';
import 'package:engquest/core/ui/readability_scale.dart';
import 'package:engquest/core/config/flavor_config.dart';
import 'package:engquest/features/character/progress_tinted_character.dart';
import 'package:engquest/features/world_map/world_map_screen.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/features/voice/voice_screen.dart';
import 'package:engquest/features/dialog/dialog_screen.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';
import 'package:engquest/core/fsrs/firestore_card_repository.dart';
import 'package:engquest/features/quest/quest_title_screen.dart';
import 'package:engquest/features/quest/quest_screen.dart';
import 'package:engquest/features/quest/quest_map_screen.dart';
import 'package:engquest/features/quest/prologue_screen.dart';
import 'package:engquest/features/quest/battle/quest_town_battle_flow.dart';
import 'package:engquest/features/quest/quest_data.dart';
import 'package:engquest/features/exam_practice/exam_practice_screen.dart';
import 'package:engquest/features/exam_practice/mock_exam_screen.dart';
import 'package:engquest/features/exam_practice/listening_practice_screen.dart';
import 'package:engquest/features/exam_practice/writing_practice_screen.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';
import 'package:engquest/features/exam_practice/word_ordering_practice_screen.dart';
import 'package:engquest/features/exam_practice/vocab_grammar_practice_screen.dart';
import 'package:engquest/features/exam_practice/conversation_practice_screen.dart';
import 'package:engquest/features/exam_practice/reading_practice_screen.dart';
import 'package:engquest/features/settings/settings_screen.dart';
import 'package:engquest/features/achievements/achievements_screen.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';
import 'package:engquest/features/parent_dashboard/parent_login_screen.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';
import 'package:engquest/features/explore/scene_view.dart';
import 'package:engquest/features/explore/chapter.dart';
import 'package:engquest/features/explore/chapter_map_screen.dart';
import 'package:engquest/features/explore/case_log_screen.dart';
import 'package:engquest/features/home/kotoba_home_screen.dart';
import 'package:engquest/features/exam_practice/pass/pass_meter_screen.dart';
import 'package:engquest/features/exam_practice/pass/pass_progress_card.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/speaking/speaking_consent_notice.dart';
import 'package:engquest/features/speaking/speaking_screen.dart';

// ---------------------------------------------------------------------------
// Onboarding state management
// ---------------------------------------------------------------------------

/// Persists and loads [OnboardingResult] to/from device storage via
/// [PreferencesService] (backed by SharedPreferences with in-memory fallback).
class OnboardingStorage {
  static const _kComplete = 'onboarding_complete';
  static const _kAge = 'onboarding_age';
  // _kCefr was used by the old 3-level placement — no longer written on new
  // installs but the key is retained as a named constant so old prefs
  // (SharedPreferences) remain readable if ever needed for migration.
  // ignore: unused_field
  static const _kCefr = 'onboarding_cefr';
  static const _kAvatar = 'onboarding_avatar';
  static const _kGoal = 'onboarding_goal_minutes';
  static const _kPrologueSeen = 'prologue_seen';
  static const _kStartLevel = 'onboarding_start_level'; // new: persists英検 level
  static const _kPlacementTheta = 'onboarding_placement_theta'; // T12 hook

  // Cached instance — populated by [init()] or [_lazyPrefs()].
  static PreferencesService? _prefs;

  // ── Lazy initialisation ──────────────────────────────────────────────────

  /// Preloads the [PreferencesService] singleton.  Call this in [main] (or
  /// early in [initState]) to avoid the first async hop at render time.
  static Future<void> init() async {
    _prefs = await PreferencesService.getInstance();
  }

  /// Returns the already-cached prefs, or blocks until they are ready.
  static Future<PreferencesService> _lazyPrefs() async {
    _prefs ??= await PreferencesService.getInstance();
    return _prefs!;
  }

  // ── Synchronous read (uses cached instance) ──────────────────────────────

  /// Returns true if onboarding has been completed.
  ///
  /// This is synchronous so [_AppEntryPointState.initState] can read it
  /// without async scaffolding.  If [init()] has not been called yet the
  /// value comes from the in-memory fallback (false) — the async [loadAsync]
  /// path will re-check once prefs are loaded.
  static bool get isComplete {
    if (_prefs == null) return false;
    return _prefs!.getBool(_kComplete);
  }

  /// Returns the stored child age (years). Defaults to 8 if not set.
  static int get ageYears {
    if (_prefs == null) return 8;
    final age = _prefs!.getInt(_kAge);
    return age > 0 ? age : 8;
  }

  /// Returns the stored 英検 start level.  Defaults to '5' (safe fallback).
  /// One of: '5' | '4' | '3' | 'pre2' | 'pre2plus' | '2' | 'pre1'
  static String get startEikenLevel {
    if (_prefs == null) return '5';
    return _prefs!.getString(_kStartLevel) ?? '5';
  }

  /// Whether the opening prologue has already played (it plays once-ever).
  static bool get prologueSeen {
    if (_prefs == null) return false;
    return _prefs!.getBool(_kPrologueSeen);
  }

  static Future<void> markPrologueSeen() async {
    final p = await _lazyPrefs();
    await p.setBool(_kPrologueSeen, true);
  }

  // ── Async save / load ────────────────────────────────────────────────────

  static Future<void> save(OnboardingResult result) async {
    final p = await _lazyPrefs();
    await p.setBool(_kComplete, true);
    await p.setInt(_kAge, result.ageYears);
    await p.setString(_kStartLevel, result.startEikenLevel);
    await p.setString(_kAvatar, result.avatarId);
    await p.setInt(_kGoal, result.dailyGoalMinutes);
    // Persist θ̂ for T12 adaptive difficulty hook.
    await p.setString(_kPlacementTheta, result.placementTheta.toString());
    HeroChoice.fromAvatarId =
        result.avatarId; // #110 reflect the chosen main now
  }

  static Future<OnboardingResult?> loadAsync() async {
    final p = await _lazyPrefs();
    if (!p.getBool(_kComplete)) return null;
    final thetaStr = p.getString(_kPlacementTheta);
    final theta = thetaStr != null ? (double.tryParse(thetaStr) ?? 0.0) : 0.0;
    // Legacy saves carry old fantasy avatarIds (knight/mage/…); heroAssetForChoice
    // maps those to the default M5, so no migration is needed.
    final avatarId = p.getString(_kAvatar) ?? 'm5';
    HeroChoice.fromAvatarId = avatarId; // #110 restore chosen main at startup
    return OnboardingResult(
      ageYears: p.getInt(_kAge),
      startEikenLevel: p.getString(_kStartLevel) ?? '5',
      placementGrade: 0, // not stored separately; theta is the T12 signal
      placementTheta: theta,
      avatarId: avatarId,
      dailyGoalMinutes: p.getInt(_kGoal),
    );
  }
}

// ---------------------------------------------------------------------------
// Root app widget
// ---------------------------------------------------------------------------

class EngQuestApp extends StatelessWidget {
  const EngQuestApp({super.key});

  // Returns the active flavor config, or a safe edilab default when the
  // flavor has not been explicitly set (e.g. running lib/main.dart directly).
  static FlavorConfig get _flavor {
    try {
      return FlavorConfig.instance;
    } catch (_) {
      // Default to edilab when no flavor entry point was used.
      FlavorConfig.setFlavor(Flavor.edilab);
      return FlavorConfig.instance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavor = _flavor;

    return MaterialApp(
      title: flavor.appName,
      debugShowCheckedModeBanner: false,
      theme: _dqTheme(),
      // Global responsive wrapper: the game is authored portrait. On tablet /
      // desktop we centre it inside a max-480 column over the deep-night field
      // rather than stretching the UI across a wide viewport. The flanks show
      // the dqNight0 backdrop so the framed game reads as one focused window.
      builder: (context, child) {
        // Readability (#114): apply the opt-in text-size on TOP of any OS
        // text-scaling, clamped so an enlarged size aids legibility without
        // shattering layouts. Listens to the global notifier so the Settings
        // control updates everything live. Default 1.0 = unchanged.
        return ColoredBox(
          color: dqNight0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ValueListenableBuilder<double>(
                valueListenable: ReadabilityScale.notifier,
                builder: (ctx, appScale, inner) {
                  final mq = MediaQuery.of(ctx);
                  final osFactor =
                      mq.textScaler.scale(10) / 10; // ~OS multiplier
                  // Text-scale ceiling = WCAG 2.2 SC 1.4.4 (200% = 2.0x). Raised
                  // 1.6→2.0 only AFTER measuring (text_scale_overflow_test, #114):
                  // all 12 high-traffic screens — home, onboarding, pass-meter, exam-
                  // practice + its 5 sub-screens, reading, battle, scene-view — now
                  // lay out clean at textScaler 2.0 (layout fixes hardened the home
                  // ring, exam chips, and mock/battle headers). The flaw-hunt's
                  // "just raise the cap" assumption became real, measured, hardened.
                  final combined = (osFactor * appScale).clamp(0.85, 2.0);
                  return MediaQuery(
                    data: mq.copyWith(textScaler: TextScaler.linear(combined)),
                    child: inner ?? const SizedBox.shrink(),
                  );
                },
                // Wrap the whole app so a level-up OR an achievement unlock from
                // ANY source (battle, every 英検 exam section, scene ナゾ) is
                // celebrated by the app-root listeners below — not just inside
                // BattleScreen.
                child: LevelUpCelebrationHost(
                  child: AchievementUnlockHost(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      // Entry point: check onboarding flag and route accordingly.
      // ?preview=<name> renders a single screen for design audit/screenshots.
      home: _previewFor(Uri.base.queryParameters['preview']),
      // NOTE: Named routes for Battle must carry childAge.
      // WorldMapScreen uses Navigator.push (not named route) to pass childAge.
      // The named '/battle' route is a fallback for direct navigation (childAge=8 default).
      routes: {
        '/battle': (context) =>
            BattleScreen(childAge: OnboardingStorage.ageYears),
        '/voice': (context) => const VoiceScreen(),
        '/dialog': (context) => const DialogScenariosScreen(),
        '/world': (context) =>
            WorldMapScreen(childAge: OnboardingStorage.ageYears),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 本格 (Dragon-Quest-grade) dark theme
// ---------------------------------------------------------------------------

/// Builds the app-wide dark RPG theme. Deep-night scaffold, gold/cream
/// ColorScheme, serif (Noto Serif JP) typography rendered in cream ink, dark
/// app bars and cards. Replaces the former bright pastel ThemeData. Individual
/// quest scenes still compose [DqScene]/[DqDialogBox]/etc. for full atmosphere;
/// this theme governs default Material chrome (dialogs, app bars, snackbars).
ThemeData _dqTheme() {
  const scheme = ColorScheme.dark(
    primary: dqGold,
    onPrimary: Color(0xFF2A1C00), // dark ink on gold buttons
    secondary: dqGold,
    onSecondary: Color(0xFF2A1C00),
    surface: dqBox, // navy command-window fill
    onSurface: dqInk, // cream ink
    surfaceContainerHighest: dqNight1,
    error: Color(0xFFE89090),
    onError: Color(0xFF2A1C00),
    outline: dqGoldDeep,
  );

  // Noto Serif JP applied over the dark base text theme, recoloured to cream
  // ink so default Material text (dialogs, tooltips) reads on the night field.
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = notoSerifJpTextTheme(base.textTheme).apply(
    bodyColor: dqInk,
    displayColor: dqInk,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: dqNight0,
    canvasColor: dqNight0,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: dqNight1,
      foregroundColor: dqInk,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: dqBox,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: dqBorder, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dqBox,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: dqBorder, width: 2),
      ),
    ),
    iconTheme: const IconThemeData(color: dqGold),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: dqGold),
    dividerTheme: const DividerThemeData(color: dqGoldDeep, thickness: 1),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: dqGold,
        foregroundColor: const Color(0xFF2A1C00),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: dqBorder, width: 1.5),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// App entry point — onboarding gate
// ---------------------------------------------------------------------------

/// Checks SharedPreferences (via [OnboardingStorage]) on first render:
/// - [OnboardingStorage.isComplete] == false → show [OnboardingFlow]
/// - [OnboardingStorage.isComplete] == true  → show [WorldMapScreen]
///
/// On onboarding completion, [OnboardingResult] is persisted via
/// [OnboardingStorage.save] and the user is forwarded to the world map.
/// Every `?preview=<name>` route name, in switch order. Kept beside
/// [_previewFor] so the offline-render smoke test (test/smoke/preview_routes_
/// offline_test.dart) can assert EVERY route renders without Firebase — the
/// structural guard against the blank-grey-screen defect class (task #24).
@visibleForTesting
const List<String> kPreviewRouteNames = [
  'title',
  'onboarding',
  'placement',
  'worldmap',
  'home',
  'questmap',
  'silentbattle',
  'silentbattle4',
  'prologue',
  'prologue1',
  'prologue2',
  'prologue3',
  'prologue4',
  'prologue5',
  'explore',
  'exploresolved',
  'chaptermap',
  'explore4',
  'explore3',
  'explorepre2',
  'explorepre2plus',
  'explore2',
  'explorepre1',
  'mock',
  'mockpre2plus',
  'quest',
  'quest5t',
  'quest5',
  'quest5q',
  'quest5c',
  'quest4',
  'quest3',
  'quest2',
  'battle',
  'dialog',
  'voice',
  'exam',
  'exam3',
  'exam4',
  'exampre1',
  'vocab',
  'writing',
  'writing2',
  'writingp1',
  'listening',
  'listening4',
  'listening3',
  'listeningp2',
  'kotobahome',
  'passmeter',
  'passmetermissing',
  'passprogress',
  'speaking',
  'speakingconsent',
  'listening2',
  'achievements',
  'parent',
  'parentlogin',
  'caselog',
  'wordorder',
  'conversation',
  'conversation5',
  'conversation4',
  'conversationpre2',
  'reading',
  'reading3',
  'readingpre2',
  'reading2',
  'reading2fill',
  'readingpre1',
  'readingpre1fill',
  'settings',
  'listeningpp',
  'listeningp1',
];

/// Test-visible wrapper for the private preview harness.
@visibleForTesting
Widget previewWidgetForTest(String? name) => _previewFor(name);

/// Design-audit harness: `?preview=<name>` renders one screen in isolation so
/// every page can be screenshotted. Returns the normal entry point otherwise.
Widget _previewFor(String? name) {
  switch (name) {
    case 'title':
      return QuestTitleScreen(onStart: () {});
    case 'onboarding':
      return OnboardingFlow(onComplete: (_) {});
    case 'placement':
      // Preview route: renders the full OnboardingFlow starting at the
      // placement step (age pre-set to 13 so the engine seeds at 準2級).
      return OnboardingFlow(onComplete: (_) {});
    case 'worldmap':
      return const WorldMapScreen(childAge: 8);
    case 'home':
      // 'home' now previews the LIVE home (KotobaHomeScreen), same as the
      // running app — the old DailyHomeScreen was vestigial and made render
      // -proofs of "home" misleading (#74).
      return const KotobaHomeScreen();
    case 'questmap':
      return const QuestMapScreen();
    case 'silentbattle': // Wave 1 — サイレント word-battle (skip intro, open in battle)
      return QuestTownBattleFlow(
          town: kQuestTowns[0], previewStraightToBattle: true);
    case 'silentbattle4':
      return QuestTownBattleFlow(
          town: kQuestTowns[1], previewStraightToBattle: true);
    case 'prologue':
      return PrologueScreen(onDone: () {});
    case 'prologue1': // colour-is-born scene panel (design/quality audit)
      return PrologueScreen(onDone: () {}, startIndex: 1);
    case 'prologue2': // silence-drains-colour scene panel (design/quality audit)
      return PrologueScreen(onDone: () {}, startIndex: 2);
    case 'prologue3':
      return PrologueScreen(onDone: () {}, startIndex: 3);
    case 'prologue4':
      return PrologueScreen(onDone: () {}, startIndex: 4);
    case 'prologue5':
      return PrologueScreen(onDone: () {}, startIndex: 5);
    case 'explore':
      // Wave 1 — Layton-style SceneView for the 英検5級 town.
      return SceneView(scene: kTown5Scene, eikenLevel: '5');
    case 'exploresolved':
      // Design-audit: the 5級 scene fully restored (colour + 探偵メモ re-read badges).
      return SceneView(
          scene: kTown5Scene, eikenLevel: '5', previewAllSolved: true);
    case 'chaptermap':
      // Design-audit: the 案内図 with a SYNTHETIC 2-location chapter so the
      // reveal-1-ahead states (cleared → current → locked) + the trail render
      // before real 2nd locations land. #92 world-depth.
      return ChapterMapScreen(
        chapter: Chapter(
          grade: '5',
          titleJa: 'ことばを失（うしな）った村（むら）',
          locations: [
            Location(
                scene: kTown5Scene,
                gate: const MasteryGate(requiredFirstTryNazo: 3)),
            Location(
                scene: kTown4Scene,
                gate: const MasteryGate(requiredFirstTryNazo: 3)),
          ],
          map: const ChapterMap(nodes: [
            MapNode(locationIndex: 0, x: 0.30, y: 0.64),
            MapNode(locationIndex: 1, x: 0.72, y: 0.34),
          ]),
          beats: const [],
        ),
        firstTryCorrectPerLocation: const [3, 1], // loc0 cleared, loc1 current
      );
    case 'explore4':
      // Wave 2 — Layton-style SceneView for the 英検4級 harbour town.
      return SceneView(scene: kTown4Scene, eikenLevel: '4');
    case 'explore3':
      // Wave 2 — Layton-style SceneView for the 英検3級 academy town.
      return SceneView(scene: kTown3Scene, eikenLevel: '3');
    case 'explorepre2':
      // Wave 2 — Layton-style SceneView for the 英検準2級 trade-port city.
      return SceneView(scene: kTownPre2Scene, eikenLevel: 'pre2');
    case 'explorepre2plus':
      // Wave 2 — 英検準2級プラス bridge district.
      return SceneView(scene: kTownPre2PlusScene, eikenLevel: 'pre2plus');
    case 'explore2':
      // Wave 2 — 英検2級 castle town.
      return SceneView(scene: kTown2Scene, eikenLevel: '2');
    case 'explorepre1':
      // Wave 2 — 英検準1級 climax: The Grey Square.
      return SceneView(scene: kTownPre1Scene, eikenLevel: 'pre1');
    case 'mock':
      // Playable timed フル模試 (seed fixed for a reproducible preview).
      return const MockExamScreen(eikenGrade: '5', seed: 1);
    case 'mockpre2plus':
      // 準2級プラス mock — render-proof of the new pre2plus reading content.
      return const MockExamScreen(eikenGrade: 'pre2plus', seed: 1);
    case 'quest':
      return QuestScreen(town: kQuestTowns.first);
    case 'quest5t': // 英検5級 Phase A — first TeachSound (/s/) step
      return QuestScreen(town: kQuestTowns[0], previewEncounterIndex: 0);
    case 'quest5':
      return QuestScreen(town: kQuestTowns[0], previewEncounterIndex: 3);
    case 'quest5q': // 英検5級 — first voiced 応答型 quiz (Phase C, 🔊 line audio)
      return QuestScreen(
        town: kQuestTowns[0],
        previewEncounterIndex: kQuestTowns[0]
            .encounters
            .indexWhere((s) => s is QuestEncounter && s.autoPlayAudio != null),
      );
    case 'quest5c': // 英検5級 — a cloze (穴埋め) quiz: question 🔊 + self-voicing options
      return QuestScreen(
        town: kQuestTowns[0],
        previewEncounterIndex: kQuestTowns[0].encounters.indexWhere(
            (s) => s is QuestEncounter && s.npcLine.contains('___')),
      );
    case 'quest4':
      return QuestScreen(town: kQuestTowns[1], previewEncounterIndex: 9);
    case 'quest3':
      return QuestScreen(town: kQuestTowns[2], previewEncounterIndex: 12);
    case 'quest2':
      return QuestScreen(town: kQuestTowns[5], previewEncounterIndex: 12);
    case 'battle':
      // Inject an in-memory repo so the preview renders OFFLINE (R4). With the
      // default FirestoreFsrsCardRepository the deck load never resolves without
      // Firebase → a perpetual loading spinner (caught by the render-integrity
      // test). #40.
      return BattleScreen(
        childAge: 8,
        repository: InMemoryFsrsCardRepository(),
      );
    case 'dialog':
      return const DialogScenariosScreen();
    case 'voice':
      return const VoiceScreen();
    case 'exam':
      return const ExamPracticeScreen(eikenGrade: '5');
    case 'exam3':
      // 3級 = highest-enrollment grade; preview route for render-proofing its
      // section list (e.g. the 2-task writing section, #60).
      return const ExamPracticeScreen(eikenGrade: '3');
    case 'exam4':
      // 4級 hub — render-proof the 大問4 = 10問 reading structure (#60).
      return const ExamPracticeScreen(eikenGrade: '4');
    case 'exampre1':
      // 準1 hub — verifies the listening tile is present (#75) for the flagship grade.
      return const ExamPracticeScreen(eikenGrade: 'pre1');
    case 'settings':
      return const SettingsScreen();
    case 'conversation':
      // 英検3級 大問2 会話文の文空所補充 — render-proofs the 3級 会話 解説 (#103,
      // highest-enrollment grade). Tap a choice → 💡かいせつ teaches the reply skill.
      return const ConversationPracticeScreen(
        eikenGrade: '3',
        section: ExamSection(
          id: '3_p2',
          nameJa: '筆記2: 会話文の文空所補充',
          nameEn: 'Conversation Completion',
          type: ExamSectionType.conversationComplete,
          questionCount: 8,
          timeLimitMinutes: 8,
          description: 'Preview',
        ),
      );
    case 'conversation5':
      // 英検5級 大問2 — render-proofs the post-answer 解説 (#7). Tap a choice to
      // reveal the 💡かいせつ panel.
      return const ConversationPracticeScreen(
        eikenGrade: '5',
        section: ExamSection(
          id: '5_p2',
          nameJa: '筆記2: 会話文の文空所補充',
          nameEn: 'Conversation Completion',
          type: ExamSectionType.conversationComplete,
          questionCount: 5,
          timeLimitMinutes: 8,
          description: 'Preview',
        ),
      );
    case 'conversation4':
      // 英検4級 大問2 — render-proofs the 4級 会話 解説 (#7). Tap a choice to
      // reveal the 💡かいせつ that teaches the functional reply skill.
      return const ConversationPracticeScreen(
        eikenGrade: '4',
        section: ExamSection(
          id: '4_p2',
          nameJa: '筆記2: 会話文の文空所補充',
          nameEn: 'Conversation Completion',
          type: ExamSectionType.conversationComplete,
          questionCount: 5,
          timeLimitMinutes: 8,
          description: 'Preview',
        ),
      );
    case 'conversationpre2':
      // 英検準2級 大問2 — render-proofs the 準2 会話 解説 (#104, completes the
      // conversation teach-why pillar). Tap a choice → 💡かいせつ teaches the reply.
      return const ConversationPracticeScreen(
        eikenGrade: 'pre2',
        section: ExamSection(
          id: 'p2_r2',
          nameJa: '筆記2: 会話文の文空所補充',
          nameEn: 'Conversation Completion',
          type: ExamSectionType.conversationComplete,
          questionCount: 8,
          timeLimitMinutes: 8,
          description: 'Preview',
        ),
      );
    case 'reading':
      // 英検5級 大問3 長文読解 — render-proofs the dark dq-themed reading flow
      // (passage + shuffled MCQ). Unifies the visual system (#67).
      return const ReadingPracticeScreen(
        eikenGrade: '5',
        section: ExamSection(
          id: '5_r3',
          nameJa: '筆記3: 長文読解',
          nameEn: 'Reading Comprehension',
          type: ExamSectionType.readingComprehension,
          questionCount: 4,
          timeLimitMinutes: 10,
          description: 'Preview',
        ),
      );
    case 'reading3':
      // 英検3級 大問3 長文の内容一致選択 — render-proofs the 3級 解説 (#5) on the
      // highest-enrollment grade. Tap a choice → 💡かいせつ quotes the evidence.
      return const ReadingPracticeScreen(
        eikenGrade: '3',
        section: ExamSection(
          id: '3_r3',
          nameJa: '筆記3: 長文の内容一致選択',
          nameEn: 'Reading Comprehension',
          type: ExamSectionType.readingComprehension,
          questionCount: 10,
          timeLimitMinutes: 15,
          description: 'Preview',
        ),
      );
    case 'reading2fill':
      // 英検2級 (B1-B2) 長文の語句空所補充 (大問2) — render-proofs the 2級 fill-in
      // cohesion 解説 (#105). Tap a choice → 💡かいせつ explains the discourse logic.
      return const ReadingPracticeScreen(
        eikenGrade: '2',
        section: ExamSection(
          id: '2_r2',
          nameJa: '筆記2: 長文の語句空所補充',
          nameEn: 'Reading 2: Passage Fill-in',
          type: ExamSectionType.readingComprehension,
          questionCount: 6,
          timeLimitMinutes: 15,
          description: 'Preview',
        ),
      );
    case 'readingpre1fill':
      // 英検準1級 (B2) 長文の語句空所補充 (大問2) — render-proofs the 準1 fill-in
      // cohesion 解説 (#102). Tap a choice → 💡かいせつ explains the discourse logic.
      return const ReadingPracticeScreen(
        eikenGrade: 'pre1',
        section: ExamSection(
          id: 'p1_r2',
          nameJa: '筆記2: 長文の語句空所補充',
          nameEn: 'Reading 2: Passage Fill-in',
          type: ExamSectionType.readingComprehension,
          questionCount: 6,
          timeLimitMinutes: 15,
          description: 'Preview',
        ),
      );
    case 'readingpre1':
      // 英検準1級 (B2) 長文の内容一致選択 — render-proofs the 準1 解説 (#5/#101) on the
      // marquee grade. Tap a choice → 💡かいせつ quotes the passage evidence.
      return const ReadingPracticeScreen(
        eikenGrade: 'pre1',
        section: ExamSection(
          id: 'p1_r3',
          nameJa: '筆記3: 長文の内容一致選択',
          nameEn: 'Reading Comprehension',
          type: ExamSectionType.readingComprehension,
          questionCount: 10,
          timeLimitMinutes: 25,
          description: 'Preview',
        ),
      );
    case 'reading2':
      // 英検2級 (B1-B2) 長文の内容一致選択 — render-proofs the 2級 解説 (#5/#98) on the
      // highest-enrollment upper paying grade. Tap a choice → 💡かいせつ quotes evidence.
      return const ReadingPracticeScreen(
        eikenGrade: '2',
        section: ExamSection(
          id: '2_r3',
          nameJa: '筆記3: 長文の内容一致選択',
          nameEn: 'Reading Comprehension',
          type: ExamSectionType.readingComprehension,
          questionCount: 12,
          timeLimitMinutes: 25,
          description: 'Preview',
        ),
      );
    case 'readingpre2':
      // 英検準2級 (B1) 長文の内容一致選択 — render-proofs the 準2 解説 (#5) on the
      // upper paying grade. Tap a choice → 💡かいせつ quotes the passage evidence.
      return const ReadingPracticeScreen(
        eikenGrade: 'pre2',
        section: ExamSection(
          id: 'p2_r3',
          nameJa: '長文の内容一致選択',
          nameEn: 'Reading Comprehension',
          type: ExamSectionType.readingComprehension,
          questionCount: 7,
          timeLimitMinutes: 20,
          description: 'Preview',
        ),
      );
    case 'vocab':
      // 英検5級 大問1 語句空所補充 — render-proofs the post-answer explanation
      // (word in context, #77). Tap a choice to reveal the れい: example.
      return const VocabGrammarPracticeScreen(
        eikenGrade: '5',
        section: ExamSection(
          id: '5_vg',
          nameJa: '筆記1: 短文の語句空所補充',
          nameEn: 'Vocabulary & Grammar',
          type: ExamSectionType.vocabGrammar,
          questionCount: 10,
          timeLimitMinutes: 10,
          description: 'Preview',
        ),
      );
    case 'wordorder':
      // 英検4級 大問3 語句整序 — authentic 5-chunk ordering practice.
      return const WordOrderingPracticeScreen(
        eikenGrade: '4',
        section: ExamSection(
          id: '4_p3',
          nameJa: '筆記3: 語句の並びかえ',
          nameEn: 'Word Ordering',
          type: ExamSectionType.wordOrdering,
          questionCount: 10,
          timeLimitMinutes: 10,
          description: 'Preview',
        ),
      );
    case 'writing':
      // Preview: 英検3級 Eメール返信 — the simplest task type.
      return WritingPracticeScreen(
        eikenGrade: '3',
        section: const ExamSection(
          id: '3_w1',
          nameJa: '筆記4: ライティング（Eメール）',
          nameEn: 'Writing: Email Reply',
          type: ExamSectionType.writing,
          questionCount: 1,
          timeLimitMinutes: 15,
          description: 'Preview',
        ),
      );
    case 'writing2':
      // Preview: 英検2級 要約
      return WritingPracticeScreen(
        eikenGrade: '2',
        section: const ExamSection(
          id: '2_w1',
          nameJa: '筆記4: ライティング（要約＋意見）',
          nameEn: 'Writing: Summary + Opinion',
          type: ExamSectionType.writing,
          questionCount: 2,
          timeLimitMinutes: 30,
          description: 'Preview',
        ),
      );
    case 'writingp1':
      // Preview: 英検準1級 要約
      return WritingPracticeScreen(
        eikenGrade: 'pre1',
        section: const ExamSection(
          id: 'p1_w1',
          nameJa: '筆記4: ライティング（要約＋意見）',
          nameEn: 'Writing: Summary + Opinion',
          type: ExamSectionType.writing,
          questionCount: 2,
          timeLimitMinutes: 30,
          description: 'Preview',
        ),
      );
    case 'listening':
      // Preview: 英検5級 リスニング (all 3 parts)
      return ListeningPracticeScreen(
        eikenGrade: '5',
        section: const ExamSection(
          id: '5_l',
          nameJa: 'リスニング (第1部〜第3部)',
          nameEn: 'Listening (Parts 1–3)',
          type: ExamSectionType.listening,
          questionCount: 25,
          timeLimitMinutes: 20,
          description: 'Preview',
        ),
      );
    case 'listening4':
      // Preview: 英検4級 リスニング
      return ListeningPracticeScreen(
        eikenGrade: '4',
        section: const ExamSection(
          id: '4_l',
          nameJa: 'リスニング (第1部〜第3部)',
          nameEn: 'Listening (Parts 1–3)',
          type: ExamSectionType.listening,
          questionCount: 30,
          timeLimitMinutes: 30,
          description: 'Preview',
        ),
      );
    case 'listening3':
      // Preview: 英検3級 リスニング
      return ListeningPracticeScreen(
        eikenGrade: '3',
        section: const ExamSection(
          id: '3_l',
          nameJa: 'リスニング (第1部〜第3部)',
          nameEn: 'Listening (Parts 1–3)',
          type: ExamSectionType.listening,
          questionCount: 30,
          timeLimitMinutes: 25,
          description: 'Preview',
        ),
      );
    case 'listeningp2':
      // Preview: 英検準2級 リスニング
      return ListeningPracticeScreen(
        eikenGrade: 'pre2',
        section: const ExamSection(
          id: 'p2_l',
          nameJa: 'リスニング (第1部〜第2部)',
          nameEn: 'Listening (Parts 1–2)',
          type: ExamSectionType.listening,
          questionCount: 30,
          timeLimitMinutes: 25,
          description: 'Preview',
        ),
      );
    case 'kotobahome':
      return const KotobaHomeScreen();
    case 'passmeter':
      return const PassMeterScreen();
    case 'passmetermissing':
      // 3級 with reading+listening data but NO writing practice → writing shows
      // 未測定 (not a failed 0). Render-proof for the #17 honesty fix.
      return PassMeterScreen(
        estimate: CseEstimator.estimate(
          grade: '3',
          accuracies: const [
            SkillAccuracy(
                skill: EikenSkill.reading, accuracy: 0.72, itemsAttempted: 20),
            SkillAccuracy(
                skill: EikenSkill.listening,
                accuracy: 0.61,
                itemsAttempted: 18),
          ],
        ),
      );
    case 'passprogress':
      // Session-end 合格率 progress moment (gain state): readiness rose this
      // session, so the card shows a +delta badge + gauge.
      return Scaffold(
        backgroundColor: dqNight0,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: PassProgressCard(
              pre: CseEstimator.estimate(
                grade: '5',
                accuracies: const [
                  SkillAccuracy(
                      skill: EikenSkill.reading,
                      accuracy: 0.58,
                      itemsAttempted: 30),
                ],
              ),
              post: CseEstimator.estimate(
                grade: '5',
                accuracies: const [
                  SkillAccuracy(
                      skill: EikenSkill.reading,
                      accuracy: 0.74,
                      itemsAttempted: 48),
                ],
              )!,
            ),
          ),
        ),
      );
    case 'speaking':
      return const SpeakingScreen(eikenGrade: '3');
    case 'speakingconsent':
      return SpeakingConsentNotice(eikenGrade: '3', onConsent: () {});
    case 'listeningp1':
      // Preview: 英検準1級 リスニング (newly seeded, 第1部〜第3部, B2)
      return ListeningPracticeScreen(
        eikenGrade: 'pre1',
        section: const ExamSection(
          id: 'p1_l',
          nameJa: 'リスニング (第1部〜第3部)',
          nameEn: 'Listening (Parts 1–3)',
          type: ExamSectionType.listening,
          questionCount: 29,
          timeLimitMinutes: 30,
          description: 'Preview',
        ),
      );
    case 'listeningpp':
      // Preview: 英検準2級プラス リスニング (newly seeded, 第1部〜第2部)
      return ListeningPracticeScreen(
        eikenGrade: 'pre2plus',
        section: const ExamSection(
          id: 'pp_l',
          nameJa: 'リスニング (第1部〜第2部)',
          nameEn: 'Listening (Parts 1–2)',
          type: ExamSectionType.listening,
          questionCount: 30,
          timeLimitMinutes: 25,
          description: 'Preview',
        ),
      );
    case 'listening2':
      // Preview: 英検2級 リスニング
      return ListeningPracticeScreen(
        eikenGrade: '2',
        section: const ExamSection(
          id: '2_l',
          nameJa: 'リスニング (第1部〜第2部)',
          nameEn: 'Listening (Parts 1–2)',
          type: ExamSectionType.listening,
          questionCount: 30,
          timeLimitMinutes: 25,
          description: 'Preview',
        ),
      );
    case 'achievements':
      return const AchievementsScreen();
    case 'parent':
      return const ParentDashboardScreen();
    case 'parentlogin':
      return const ParentLoginScreen();
    case 'caselog':
      return const CaseLogScreen();
    default:
      return const _AppEntryPoint();
  }
}

class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  bool _onboardingComplete = false;
  bool _prologueSeen = false;
  bool _loading = true;
  bool _started = false; // title screen shows until the player taps はじめる

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    // Ensure PreferencesService is initialised (real SharedPreferences).
    await OnboardingStorage.init();
    final complete = OnboardingStorage.isComplete;
    if (mounted) {
      setState(() {
        _onboardingComplete = complete;
        _prologueSeen = OnboardingStorage.prologueSeen;
        // #53 (CEO P0): a returning player must boot straight back INTO the app,
        // not be dumped on the title screen on every web refresh. A web refresh
        // restarts the Dart app, resetting in-memory _started → previously every
        // refresh bounced an already-onboarded child back to はじめる. We restore
        // to the top-level home hub (the safe nav location) by treating an
        // onboarded session as already-started. Deep mid-quest/mid-exam state is
        // intentionally NOT restored — it would need args the boot path lacks and
        // could bypass the onboarding/prologue gates. First-run users (onboarding
        // incomplete) still get the 本格 title as their first impression.
        _started = complete;
        _loading = false;
      });
    }
  }

  Future<void> _handlePrologueDone() async {
    await OnboardingStorage.markPrologueSeen();
    if (!mounted) return;
    setState(() => _prologueSeen = true);
  }

  Future<void> _handleOnboardingComplete(OnboardingResult result) async {
    // Persist the result (await the write so the WorldMap/Battle vocab filter,
    // which reads OnboardingStorage.ageYears later, sees the chosen age rather
    // than the age-8 default on the very first session), then enter the quest.
    await OnboardingStorage.save(result);
    if (!mounted) return;
    setState(() => _onboardingComplete = true);
  }

  // Builds the current top-level phase, each wrapped in a unique ValueKey so the
  // [AnimatedSwitcher] in [build] cross-fades between them. Same key = no
  // transition, so the keys are what make the seam animate.
  Widget _buildPhase() {
    if (_loading) {
      // Minimal splash while SharedPreferences warms up (<100 ms typically).
      // Deep-night field with gold spinner so the first frame is already 本格.
      final flavor = EngQuestApp._flavor;
      return KeyedSubtree(
        key: const ValueKey('phase-loading'),
        child: Scaffold(
          backgroundColor: dqNight0,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [dqNight0, dqNight1, dqNight0],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: dqGold),
                  const SizedBox(height: 16),
                  Text(flavor.splashText,
                      style: dqText(size: 14, color: dqInk)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (!_started) {
      return KeyedSubtree(
        key: const ValueKey('phase-title'),
        child: QuestTitleScreen(onStart: () => setState(() => _started = true)),
      );
    }
    // HOOK BEFORE CONFIGURE (CEO 1363 + 2026 onboarding research): the opening
    // STORY plays FIRST — the interactive 🔊 c·a·t blend + the サイレント world
    // establish コトバ探偵 BEFORE any form. The old order led with a dry
    // age→placement-quiz→avatar→goal form and buried the story behind it — the
    // textbook Day-1 anti-pattern (a child had to pass a test before meeting the
    // game). The prologue is generic (hero.png silhouette, NO avatar dependency on
    // onboarding — verified), so it needs nothing from the form. Once-ever.
    if (!_prologueSeen) {
      return KeyedSubtree(
        key: const ValueKey('phase-prologue'),
        child: PrologueScreen(onDone: _handlePrologueDone),
      );
    }
    // Now the child is bought-in by the story → configure (age/level/avatar/goal).
    if (!_onboardingComplete) {
      return KeyedSubtree(
        key: const ValueKey('phase-onboarding'),
        child: OnboardingFlow(onComplete: _handleOnboardingComplete),
      );
    }
    // Then LAND on the painted コトバ探偵 daily-return home (streak case-log + 今日の
    // ナゾ from FSRS-due → into the painted scene) — the landing, not a menu.
    return KeyedSubtree(
      key: const ValueKey('phase-home'),
      // #134: the LIVE home reads the child's REAL FSRS due-count from Firestore
      // (battle persists there) instead of an empty per-screen InMemory store, so
      // a returning child sees their actual 「きょうの ナゾ」, not a false 0. Preview
      // routes + tests keep InMemory (offline-safe). The home's getDueCards is
      // already guarded (falls to 0 on offline/failure).
      child: KotobaHomeScreen(cardRepository: FirestoreFsrsCardRepository()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cross-fade between top-level phases (loading → title → onboarding →
    // prologue → home) so entering the game is a composed transition, not a
    // single-frame teleport — the「はじめる→いきなりコトバ探偵」seam the CEO flagged
    // (構成 audit #50; agent-team decision 2026-06-07; Professor Layton-grade
    // polish reference). Spec-safe: the painted コトバ探偵 home is still the landing
    // — only the seam between phases changes. A dark-to-dark dissolve, no new
    // assets. AnimatedSwitcher is self-managing (no AnimationController); the
    // full-screen Stack layoutBuilder prevents reflow while the outgoing and
    // incoming screens overlap during the fade.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      child: _buildPhase(),
    );
  }
}

// ---------------------------------------------------------------------------
// Global level-up celebration
// ---------------------------------------------------------------------------

/// Pop-in scale factor (0..1) for the celebration banners over the controller's
/// time [t]. Under reduce-motion it returns 1.0 immediately — the easeOutBack
/// overshoot (a scale-bounce) is the vestibular trigger, so motion-sensitive
/// users get a plain opacity fade instead of a bouncing pop-in. Pure + public so
/// the reduce-motion invariant is unit-tested. Shared by both celebration hosts.
double celebrationBannerAppear(double t, {required bool reduceMotion}) =>
    reduceMotion
        ? 1.0
        : Curves.easeOutBack.transform((t / 0.12).clamp(0.0, 1.0));

/// Overlays a celebratory banner whenever ANY XP source crosses a level
/// threshold — the vocab battle, every 英検 exam-practice section, scene ナゾ, and
/// any future source. [XpService.awardXp] / [XpService.awardXpAmount] publish
/// each level-up to the static [XpService.levelUpEvents]; the problem was that
/// only [BattleScreen] reacted (via its own award result), so an exam-focused
/// child (the primary 英検 path) levelled up silently. Mounting one listener at
/// the app root makes the level-up moment universal and removes per-screen wiring.
class LevelUpCelebrationHost extends StatefulWidget {
  const LevelUpCelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  State<LevelUpCelebrationHost> createState() => _LevelUpCelebrationHostState();
}

class _LevelUpCelebrationHostState extends State<LevelUpCelebrationHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  final SoundService _sound = SoundService();
  XpProfile? _profile;

  @override
  void initState() {
    super.initState();
    // 2.8s total — pop-in → hold → fade-out, all driven by the controller's
    // value via Interval maths in [_banner], so there is no separate Timer
    // (Timers leak into widget tests). On completion we clear the banner and
    // reset the notifier so the next level-up — even to the same level — fires.
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _profile = null);
          XpService.levelUpEvents.value = null;
        }
      });
    XpService.levelUpEvents.addListener(_onLevelUp);
  }

  void _onLevelUp() {
    final result = XpService.levelUpEvents.value;
    if (result == null || !mounted) return;
    setState(() => _profile = result.after);
    _sound.playLevelUp();
    HapticFeedback.heavyImpact();
    _ctl.forward(from: 0);
  }

  @override
  void dispose() {
    XpService.levelUpEvents.removeListener(_onLevelUp);
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Positioned.fill keeps the app's Navigator filling exactly as before; the
    // banner is a cosmetic, input-transparent overlay above it.
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_profile != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (context, _) => _banner(
                    _profile!, _ctl.value, prefersReducedMotion(context)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _banner(XpProfile profile, double t, bool reduceMotion) {
    // t runs 0→1 over 2.8s: pop-in 0–0.12, hold to 0.82, fade-out 0.82–1.0.
    final appear = celebrationBannerAppear(t, reduceMotion: reduceMotion);
    final fade = t < 0.82 ? 1.0 : (1.0 - (t - 0.82) / 0.18).clamp(0.0, 1.0);
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Opacity(
          opacity: fade,
          child: Transform.scale(
            scale: 0.8 + 0.2 * appear,
            child: DqPanel(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('🌟', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  Center(
                    child: dqBilingual(
                      'レベルアップ！',
                      'LEVEL UP',
                      jpSize: 26,
                      jpColor: dqGold,
                      stacked: true,
                      align: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Lv.${profile.level} に到達！',
                      style: dqText(size: 19, color: dqInk)),
                  const SizedBox(height: 4),
                  Text('合計 ${profile.totalXp} XP',
                      style: dqText(size: 13, color: dqGoldDeep)),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: profile.levelProgress,
                      backgroundColor: dqNight0,
                      valueColor: const AlwaysStoppedAnimation<Color>(dqGold),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${profile.currentLevelXp} / ${profile.levelXpSpan} XP',
                      style: dqText(size: 12, color: dqGoldDeep)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Global achievement-unlock celebration
// ---------------------------------------------------------------------------

/// Overlays a「バッジ獲得！」banner whenever an achievement unlocks from ANY
/// source. [AchievementService.checkAndUpdate] publishes unlocked IDs to the
/// static [AchievementService.unlockEvents]; the problem was that the unlock
/// popup lived only inside [BattleScreen] and checkAndUpdate was never called
/// from exam practice, so an exam-focused child's streak/level unlocks were
/// silent until they happened to open the achievements screen. One app-root
/// listener makes the badge celebration universal. Mirrors
/// [LevelUpCelebrationHost].
class AchievementUnlockHost extends StatefulWidget {
  const AchievementUnlockHost({super.key, required this.child});

  final Widget child;

  @override
  State<AchievementUnlockHost> createState() => _AchievementUnlockHostState();
}

class _AchievementUnlockHostState extends State<AchievementUnlockHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  final SoundService _sound = SoundService();
  List<String> _ids = const [];

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _ids = const []);
          AchievementService.unlockEvents.value = const [];
        }
      });
    AchievementService.unlockEvents.addListener(_onUnlock);
  }

  void _onUnlock() {
    final ids = AchievementService.unlockEvents.value;
    if (ids.isEmpty || !mounted) return;
    if (achievementDefById(ids.first) == null) return; // unknown id → ignore
    setState(() => _ids = ids);
    _sound.playAchievement();
    HapticFeedback.heavyImpact();
    _ctl.forward(from: 0);
  }

  @override
  void dispose() {
    AchievementService.unlockEvents.removeListener(_onUnlock);
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = _ids.isEmpty ? null : achievementDefById(_ids.first);
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (def != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (context, _) => _banner(def, _ids.length, _ctl.value,
                    prefersReducedMotion(context)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _banner(AchievementDef def, int count, double t, bool reduceMotion) {
    final appear = celebrationBannerAppear(t, reduceMotion: reduceMotion);
    final fade = t < 0.82 ? 1.0 : (1.0 - (t - 0.82) / 0.18).clamp(0.0, 1.0);
    // Proportional reward: a capstone (the top tier a learner works toward last —
    // 30-day streak, 500 words) FEELS bigger than an early badge, instead of
    // every unlock landing identically. Bigger badge + a distinct「だいきろく」
    // header + a special subline; an early badge keeps the calm default.
    final isCapstone = isCapstoneAchievement(def);
    final badgeSize = isCapstone ? 80.0 : 64.0;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Opacity(
          opacity: fade,
          child: Transform.scale(
            scale: 0.8 + 0.2 * appear,
            child: DqPanel(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: dqBilingual(
                      isCapstone ? '✨ だいきろく たっせい！' : 'バッジ獲得！',
                      isCapstone ? 'MAJOR MILESTONE' : 'BADGE EARNED',
                      jpSize: isCapstone ? 22 : 20,
                      jpColor: dqGold,
                      stacked: true,
                      align: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: def.gradient),
                      border: Border.all(
                          color: isCapstone ? dqGold : dqBorder,
                          width: isCapstone ? 3 : 2),
                    ),
                    child: Icon(def.icon,
                        color: Colors.white, size: isCapstone ? 40 : 32),
                  ),
                  const SizedBox(height: 14),
                  Text(def.titleJa,
                      textAlign: TextAlign.center,
                      style:
                          dqText(size: 18, w: FontWeight.w800, color: dqInk)),
                  const SizedBox(height: 6),
                  Text(def.descriptionJa,
                      textAlign: TextAlign.center,
                      style: dqText(size: 14, color: dqInk)),
                  if (isCapstone) ...[
                    const SizedBox(height: 8),
                    Text('とくべつな バッジを てにいれた！',
                        textAlign: TextAlign.center,
                        style: dqText(
                            size: 12, w: FontWeight.w700, color: dqGoldDeep)),
                  ],
                  if (count > 1) ...[
                    const SizedBox(height: 8),
                    Text('+${count - 1}個のバッジも獲得！',
                        style: dqText(size: 12, color: dqGoldDeep)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Child-safe error fallback
// ---------------------------------------------------------------------------

/// Replaces Flutter's default error box — a bare grey container in release — with
/// a calm, child-safe screen, so an uncaught build error never shows a child a
/// scary or blank screen. Wired in [bootstrapApp] for RELEASE builds only (debug
/// keeps Flutter's detailed red error for developers). Self-contained: it renders
/// in place of whatever failed, so it assumes no inherited widgets are available.
Widget friendlyErrorWidget(FlutterErrorDetails details) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Material(
      color: dqNight0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sentiment_dissatisfied_rounded,
                  color: dqGold, size: 48),
              const SizedBox(height: 16),
              Text(
                'あれ？ ちょっと うまく いかなかったみたい。',
                textAlign: TextAlign.center,
                style: dqText(size: 16, w: FontWeight.w700, color: dqInk),
              ),
              const SizedBox(height: 8),
              Text(
                'まえの がめんに もどってみてね。',
                textAlign: TextAlign.center,
                style: dqText(size: 13, color: dqInk),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
