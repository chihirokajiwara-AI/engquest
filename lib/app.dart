import 'package:flutter/material.dart';
import 'package:engquest/features/world_map/world_map_screen.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/features/voice/voice_screen.dart';
import 'package:engquest/features/dialog/dialog_screen.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';
import 'package:engquest/features/legal/parental_consent_gate.dart';
import 'package:engquest/features/legal/privacy_policy_screen.dart';
import 'package:engquest/core/storage/preferences_service.dart';

// ---------------------------------------------------------------------------
// Onboarding state management
// ---------------------------------------------------------------------------

/// Persists and loads [OnboardingResult] to/from device storage via
/// [PreferencesService] (backed by SharedPreferences with in-memory fallback).
class OnboardingStorage {
  static const _kComplete = 'onboarding_complete';
  static const _kConsent = 'parental_consent';
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

  /// Returns true if parental consent has been given.
  static bool get hasConsent {
    if (_prefs == null) return false;
    return _prefs!.getBool(_kConsent);
  }

  /// Persists that parental consent was given.
  static Future<void> saveConsent() async {
    final p = await _lazyPrefs();
    await p.setBool(_kConsent, true);
  }

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ENG Quest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // RPG forest green
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // Entry point: check onboarding flag and route accordingly
      home: const _AppEntryPoint(),
      // NOTE: Named routes for Battle must carry childAge.
      // WorldMapScreen uses Navigator.push (not named route) to pass childAge.
      // The named '/battle' route is a fallback for direct navigation (childAge=8 default).
      routes: {
        '/battle': (context) => BattleScreen(childAge: OnboardingStorage.ageYears),
        '/voice': (context) => const VoiceScreen(),
        '/dialog': (context) => const DialogScenariosScreen(),
        '/world': (context) => WorldMapScreen(childAge: OnboardingStorage.ageYears),
        '/privacy': (context) => const PrivacyPolicyScreen(),
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
class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  bool _hasConsent = false;
  bool _onboardingComplete = false;
  bool _loading = true;

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
    final consent = OnboardingStorage.hasConsent;
    final complete = OnboardingStorage.isComplete;
    if (mounted) {
      setState(() {
        _hasConsent = consent;
        _onboardingComplete = complete;
        // For returning users, read the persisted age now that prefs are warm.
        if (complete) _childAge = OnboardingStorage.ageYears;
        _loading = false;
      });
    }
  }

  Future<void> _handleConsent() async {
    await OnboardingStorage.saveConsent();
    if (!mounted) return;
    setState(() => _hasConsent = true);
  }

  Future<void> _handleOnboardingComplete(OnboardingResult result) async {
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
      return const Scaffold(
        backgroundColor: Color(0xFF1B2838),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_onboardingComplete) {
      return WorldMapScreen(childAge: _childAge);
    }
    if (!_hasConsent) {
      return ParentalConsentGate(onConsented: _handleConsent);
    }
    return OnboardingFlow(onComplete: _handleOnboardingComplete);
  }
}
