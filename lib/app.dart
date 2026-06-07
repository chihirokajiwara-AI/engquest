import 'package:flutter/material.dart';
import 'package:engquest/core/ui/app_fonts.dart';
import 'package:engquest/core/config/flavor_config.dart';
import 'package:engquest/features/world_map/world_map_screen.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/features/voice/voice_screen.dart';
import 'package:engquest/features/dialog/dialog_screen.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';
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
import 'package:engquest/features/exam_practice/conversation_practice_screen.dart';
import 'package:engquest/features/settings/settings_screen.dart';
import 'package:engquest/features/achievements/achievements_screen.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';
import 'package:engquest/features/parent_dashboard/parent_login_screen.dart';
import 'package:engquest/features/home/daily_home_screen.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';
import 'package:engquest/features/explore/scene_view.dart';
import 'package:engquest/features/home/kotoba_home_screen.dart';
import 'package:engquest/features/exam_practice/pass/pass_meter_screen.dart';
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
    await p.setString(
        _kPlacementTheta, result.placementTheta.toString());
  }

  static Future<OnboardingResult?> loadAsync() async {
    final p = await _lazyPrefs();
    if (!p.getBool(_kComplete)) return null;
    final thetaStr = p.getString(_kPlacementTheta);
    final theta = thetaStr != null ? (double.tryParse(thetaStr) ?? 0.0) : 0.0;
    return OnboardingResult(
      ageYears: p.getInt(_kAge),
      startEikenLevel: p.getString(_kStartLevel) ?? '5',
      placementGrade: 0, // not stored separately; theta is the T12 signal
      placementTheta: theta,
      avatarId: p.getString(_kAvatar) ?? 'knight',
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
        return ColoredBox(
          color: dqNight0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child ?? const SizedBox.shrink(),
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
  'title', 'onboarding', 'placement', 'worldmap', 'home', 'questmap',
  'silentbattle', 'silentbattle4', 'prologue', 'prologue3', 'prologue4',
  'prologue5', 'explore', 'explore4', 'explore3', 'explorepre2',
  'explorepre2plus', 'explore2', 'explorepre1', 'mock', 'mockpre2plus',
  'quest', 'quest5t', 'quest5', 'quest5q', 'quest5c', 'quest4', 'quest3',
  'quest2', 'battle', 'dialog', 'voice', 'exam', 'writing', 'writing2',
  'writingp1', 'listening', 'listening4', 'listening3', 'listeningp2',
  'kotobahome', 'passmeter', 'passmetermissing', 'speaking', 'speakingconsent',
  'listening2', 'achievements', 'parent', 'parentlogin', 'wordorder',
  'conversation', 'settings', 'listeningpp', 'listeningp1',
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
      return const DailyHomeScreen(childAge: 8);
    case 'questmap':
      return const QuestMapScreen();
    case 'silentbattle': // Wave 1 — サイレント word-battle (skip intro, open in battle)
      return QuestTownBattleFlow(town: kQuestTowns[0], previewStraightToBattle: true);
    case 'silentbattle4':
      return QuestTownBattleFlow(town: kQuestTowns[1], previewStraightToBattle: true);
    case 'prologue':
      return PrologueScreen(onDone: () {});
    case 'prologue3':
      return PrologueScreen(onDone: () {}, startIndex: 3);
    case 'prologue4':
      return PrologueScreen(onDone: () {}, startIndex: 4);
    case 'prologue5':
      return PrologueScreen(onDone: () {}, startIndex: 5);
    case 'explore':
      // Wave 1 — Layton-style SceneView for the 英検5級 town.
      return SceneView(scene: kTown5Scene, eikenLevel: '5');
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
        previewEncounterIndex:
            kQuestTowns[0].encounters.indexWhere((s) => s is QuestEncounter && s.autoPlayAudio != null),
      );
    case 'quest5c': // 英検5級 — a cloze (穴埋め) quiz: question 🔊 + self-voicing options
      return QuestScreen(
        town: kQuestTowns[0],
        previewEncounterIndex:
            kQuestTowns[0].encounters.indexWhere((s) => s is QuestEncounter && s.npcLine.contains('___')),
      );
    case 'quest4':
      return QuestScreen(town: kQuestTowns[1], previewEncounterIndex: 9);
    case 'quest3':
      return QuestScreen(town: kQuestTowns[2], previewEncounterIndex: 12);
    case 'quest2':
      return QuestScreen(town: kQuestTowns[5], previewEncounterIndex: 12);
    case 'battle':
      return const BattleScreen(childAge: 8);
    case 'dialog':
      return const DialogScenariosScreen();
    case 'voice':
      return const VoiceScreen();
    case 'exam':
      return const ExamPracticeScreen(eikenGrade: '5');
    case 'settings':
      return const SettingsScreen();
    case 'conversation':
      // 英検3級 大問2 会話文の文空所補充 — grade-differentiated dialogue practice.
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
                skill: EikenSkill.listening, accuracy: 0.61, itemsAttempted: 18),
          ],
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Minimal splash while SharedPreferences warms up (<100 ms typically).
      // Deep-night field with gold spinner so the first frame is already 本格.
      final flavor = EngQuestApp._flavor;
      return Scaffold(
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
                Text(flavor.splashText, style: dqText(size: 14, color: dqInk)),
              ],
            ),
          ),
        ),
      );
    }
    if (!_started) {
      return QuestTitleScreen(onStart: () => setState(() => _started = true));
    }
    if (_onboardingComplete) {
      // First time into the adventure: the opening PROLOGUE plays once, then the
      // child LANDS on the コトバ探偵 daily-return home (streak case-log + 今日のナゾ
      // from FSRS-due → into the painted scene). This is the retention spine + the
      // fix for the buried-soul seam (Opus review 2026-06-06): the painted world is
      // the landing, not a level-select menu. The map stays reachable from the home.
      if (!_prologueSeen) {
        return PrologueScreen(onDone: _handlePrologueDone);
      }
      return const KotobaHomeScreen();
    }
    return OnboardingFlow(onComplete: _handleOnboardingComplete);
  }
}
