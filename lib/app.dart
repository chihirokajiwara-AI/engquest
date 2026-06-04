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
import 'package:engquest/features/quest/quest_data.dart';
import 'package:engquest/features/exam_practice/exam_practice_screen.dart';
import 'package:engquest/features/achievements/achievements_screen.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';
import 'package:engquest/features/home/daily_home_screen.dart';
import 'package:engquest/core/storage/preferences_service.dart';

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
    final primaryColor = Color(flavor.primaryColor);

    return MaterialApp(
      title: flavor.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: const Color(0xFFFFB74D), // warm orange/gold
          surface: const Color(0xFFFFFFFF), // white
          error: const Color(0xFFEF5350), // error red
          onPrimary: Colors.white,
          onSecondary: Colors.black87,
          onSurface: const Color(0xFF263238), // dark blue-gray
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        useMaterial3: true,
        // Noto Sans JP — supports all Japanese kana/kanji used in child UI.
        // Falls back to system font offline; google_fonts caches after first load.
        textTheme: GoogleFonts.notoSansJpTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
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
    case 'quest':
      return QuestScreen(town: kQuestTowns.first);
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
  bool _loading = true;
  bool _started = false; // title screen shows until the player taps はじめる

  /// The age to route into [WorldMapScreen] with.  Sourced either from
  /// persisted prefs (returning user) or directly from the just-completed
  /// [OnboardingResult] (new user) to avoid any read-after-write race on the
  /// storage layer.  Defaults to 8 until prefs are loaded.
  int _childAge = 8;

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
        // For returning users, read the persisted age now that prefs are warm.
        if (complete) _childAge = OnboardingStorage.ageYears;
        _loading = false;
      });
    }
  }

  Future<void> _handleOnboardingComplete(OnboardingResult result) async {
    // Persist the result, then transition.  We must await the write so the
    // synchronous [OnboardingStorage.ageYears] getter (and any later route
    // rebuild) reflects the chosen age — otherwise the WorldMap/Battle vocab
    // filter falls back to the default age 8 on the very first session, which
    // is exactly when age-appropriate filtering matters most. We also pass the
    // age directly from [result] so the first render is correct regardless of
    // storage timing.
    await OnboardingStorage.save(result);
    if (!mounted) return;
    setState(() {
      _childAge = result.ageYears;
      _onboardingComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Minimal splash while SharedPreferences warms up (<100 ms typically).
      // Uses flavor branding so each variant shows its own identity.
      final flavor = EngQuestApp._flavor;
      final primaryColor = Color(flavor.primaryColor);
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              Text(
                flavor.splashText,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!_started) {
      return QuestTitleScreen(onStart: () => setState(() => _started = true));
    }
    if (_onboardingComplete) {
      return DailyHomeScreen(childAge: _childAge);
    }
    return OnboardingFlow(onComplete: _handleOnboardingComplete);
  }
}
