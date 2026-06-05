import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:engquest/features/achievements/achievements_screen.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';
import 'package:engquest/features/home/daily_home_screen.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';
import 'package:engquest/features/explore/scene_view.dart';

// ---------------------------------------------------------------------------
// Onboarding state management
// ---------------------------------------------------------------------------

/// Persists and loads [OnboardingResult] to/from device storage via
/// [PreferencesService] (backed by SharedPreferences with in-memory fallback).
class OnboardingStorage {
  static const _kComplete = 'onboarding_complete';
  static const _kAge = 'onboarding_age';
  static const _kCefr = 'onboarding_cefr';
  static const _kAvatar = 'onboarding_avatar';
  static const _kGoal = 'onboarding_goal_minutes';
  static const _kPrologueSeen = 'prologue_seen';

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
    await p.setString(_kCefr, result.cefrPlacement.name);
    await p.setString(_kAvatar, result.avatarId);
    await p.setInt(_kGoal, result.dailyGoalMinutes);
  }

  static Future<OnboardingResult?> loadAsync() async {
    final p = await _lazyPrefs();
    if (!p.getBool(_kComplete)) return null;
    return OnboardingResult(
      ageYears: p.getInt(_kAge),
      cefrPlacement: CefrPlacement.values.firstWhere(
        (e) => e.name == p.getString(_kCefr),
        orElse: () => CefrPlacement.a1,
      ),
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
  final textTheme = GoogleFonts.notoSerifJpTextTheme(base.textTheme).apply(
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
/// Design-audit harness: `?preview=<name>` renders one screen in isolation so
/// every page can be screenshotted. Returns the normal entry point otherwise.
Widget _previewFor(String? name) {
  switch (name) {
    case 'title':
      return QuestTitleScreen(onStart: () {});
    case 'onboarding':
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
    case 'achievements':
      return const AchievementsScreen();
    case 'parent':
      return const ParentDashboardScreen();
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
      // quest map. A child taps はじめる to PLAY (and to be pulled into the story),
      // NOT to read a status hub. (DailyHomeScreen stays a retention hub for
      // later, reachable separately.)
      if (!_prologueSeen) {
        return PrologueScreen(onDone: _handlePrologueDone);
      }
      return const QuestMapScreen();
    }
    return OnboardingFlow(onComplete: _handleOnboardingComplete);
  }
}
