import 'package:flutter/material.dart';
import 'package:engquest/features/world_map/world_map_screen.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/features/voice/voice_screen.dart';
import 'package:engquest/features/dialog/dialog_screen.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';

// ---------------------------------------------------------------------------
// Onboarding state management
// ---------------------------------------------------------------------------

/// Key names written to SharedPreferences (real) or an in-memory store (test).
///
/// NOTE: In production, this class uses SharedPreferences via a platform channel.
/// For now we use a static in-memory store so the app compiles and runs
/// without requiring the shared_preferences native plugin wired up.
/// Replace [_MemStore] with a SharedPreferences adapter in the next sprint.

class _MemStore {
  static final Map<String, dynamic> _data = {};
  static bool getBool(String k) => (_data[k] as bool?) ?? false;
  static String? getString(String k) => _data[k] as String?;
  static int getInt(String k) => (_data[k] as int?) ?? 0;
  static void setBool(String k, bool v) => _data[k] = v;
  static void setString(String k, String v) => _data[k] = v;
  static void setInt(String k, int v) => _data[k] = v;
}

/// Persists and loads [OnboardingResult] to/from device storage.
///
/// API mirrors what a SharedPreferences implementation will provide so
/// the calling code can swap the implementation without changes.
class OnboardingStorage {
  static const _kComplete = 'onboarding_complete';
  static const _kAge = 'onboarding_age';
  static const _kCefr = 'onboarding_cefr';
  static const _kAvatar = 'onboarding_avatar';
  static const _kGoal = 'onboarding_goal_minutes';

  static bool get isComplete => _MemStore.getBool(_kComplete);

  static void save(OnboardingResult result) {
    _MemStore.setBool(_kComplete, true);
    _MemStore.setInt(_kAge, result.ageYears);
    _MemStore.setString(_kCefr, result.cefrPlacement.name);
    _MemStore.setString(_kAvatar, result.avatarId);
    _MemStore.setInt(_kGoal, result.dailyGoalMinutes);
  }

  static OnboardingResult? load() {
    if (!isComplete) return null;
    return OnboardingResult(
      ageYears: _MemStore.getInt(_kAge),
      cefrPlacement: CefrPlacement.values.firstWhere(
        (e) => e.name == _MemStore.getString(_kCefr),
        orElse: () => CefrPlacement.a1,
      ),
      avatarId: _MemStore.getString(_kAvatar) ?? 'knight',
      dailyGoalMinutes: _MemStore.getInt(_kGoal),
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
      routes: {
        '/battle': (context) => const BattleScreen(),
        '/voice': (context) => const VoiceScreen(),
        '/dialog': (context) => const DialogScenariosScreen(),
        '/world': (context) => const WorldMapScreen(),
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
  // Track whether we've completed onboarding in this session.
  // Initialised from persisted storage.
  late bool _onboardingComplete;

  @override
  void initState() {
    super.initState();
    // Read persisted flag (synchronous in-memory store; replace with
    // `await SharedPreferences.getInstance()` in the next sprint).
    _onboardingComplete = OnboardingStorage.isComplete;
  }

  void _handleOnboardingComplete(OnboardingResult result) {
    // Persist the result
    OnboardingStorage.save(result);
    // Transition to world map
    setState(() {
      _onboardingComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete) {
      return const WorldMapScreen();
    }
    return OnboardingFlow(onComplete: _handleOnboardingComplete);
  }
}
