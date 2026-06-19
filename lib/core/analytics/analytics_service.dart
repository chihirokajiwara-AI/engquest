/// ENG Quest — Analytics + A/B Framework (C09)
///
/// Responsibilities:
///   1. Firebase Analytics event logging (battle, dialog, voice, session)
///   2. A/B test assignment (deterministic hash-based, no server required)
///   3. Custom event schema for 30-day Anki comparison trial
///
/// Firebase Analytics is stubbed behind an interface so tests can inject
/// a no-op implementation without depending on native Firebase plugins.
library;

import 'package:firebase_analytics/firebase_analytics.dart';

// ---------------------------------------------------------------------------
// Event constants
// ---------------------------------------------------------------------------

/// All custom event names used in ENG Quest.
/// Named to match Firebase Analytics naming rules (snake_case, ≤40 chars).
class EngQuestEvent {
  EngQuestEvent._();

  // Session lifecycle
  static const String sessionStart = 'eq_session_start';
  static const String sessionEnd = 'eq_session_end';

  // Battle module
  static const String battleCardShown = 'eq_battle_card_shown';
  static const String battleCardAnswered = 'eq_battle_card_answered';
  static const String battleSessionComplete = 'eq_battle_session_complete';
  // Generic practice-session completion (battle + every exam type) — the core
  // retention signal. No accuracy param: the shared completion chokepoint
  // (recordExamHabitAndGet) doesn't have it, and a 1.0 placeholder would be
  // dishonest data. Accuracy stays on battleSessionComplete where it is real.
  static const String practiceSessionComplete = 'eq_practice_session_complete';

  // Voice module
  static const String voiceAttemptStart = 'eq_voice_attempt_start';
  static const String voiceAttemptResult = 'eq_voice_attempt_result';

  // Dialog module
  static const String dialogTurnSent = 'eq_dialog_turn_sent';
  static const String dialogScenarioComplete = 'eq_dialog_scenario_complete';

  // Onboarding
  static const String onboardingStepComplete = 'eq_onboarding_step_complete';
  static const String onboardingComplete = 'eq_onboarding_complete';

  // A/B trial
  static const String abGroupAssigned = 'eq_ab_group_assigned';
  static const String abRetentionTest = 'eq_ab_retention_test';
}

/// Parameter key names (Firebase Analytics custom params, ≤40 chars).
class EngQuestParam {
  EngQuestParam._();

  static const String wordId = 'word_id';
  static const String cefrLevel = 'cefr_level';
  static const String grade = 'grade'; // 1=Again,2=Hard,3=Good,4=Easy
  static const String accuracy = 'accuracy'; // 0.0–1.0
  static const String latencyMs = 'latency_ms';
  static const String moduleType = 'module_type'; // battle|voice|dialog
  static const String scenarioId = 'scenario_id';
  static const String sessionDurationSec = 'session_duration_sec';
  static const String wordsPracticed = 'words_practiced';
  static const String abGroup = 'ab_group'; // treatment|control
  static const String retentionScore = 'retention_score'; // 0.0–1.0
  static const String stepName = 'step_name';
}

// ---------------------------------------------------------------------------
// Analytics interface (injectable / testable)
// ---------------------------------------------------------------------------

/// Abstract analytics sink. Swap [FirebaseAnalyticsAdapter] for
/// [NoOpAnalytics] in tests.
abstract class AnalyticsSink {
  Future<void> logEvent(String name, {Map<String, Object>? parameters});
  Future<void> setUserId(String uid);
  Future<void> setUserProperty(String name, String value);
}

/// No-op implementation for unit tests and offline debug builds.
class NoOpAnalytics implements AnalyticsSink {
  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {}

  @override
  Future<void> setUserId(String uid) async {}

  @override
  Future<void> setUserProperty(String name, String value) async {}
}

/// Production Firebase Analytics implementation.
///
/// Delegates all calls to [FirebaseAnalytics.instance]. The optional
/// constructor parameter allows injecting a mock for integration tests.
///
/// COPPA compliance: ad personalization is disabled by default via
/// [setConsent] in the constructor. No ad SDKs are present, but this
/// ensures Firebase itself does not use data for ad purposes.
class FirebaseAnalyticsAdapter implements AnalyticsSink {
  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsAdapter({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance {
    _configureCoppaCompliance();
  }

  /// Disables ad personalization and ad storage for COPPA compliance.
  /// Required for children's apps on both App Store and Play Store.
  void _configureCoppaCompliance() {
    _analytics.setConsent(
      adStorageConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
      adUserDataConsentGranted: false,
      analyticsStorageConsentGranted: true,
    );
  }

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> setUserId(String uid) async {
    await _analytics.setUserId(id: uid);
  }

  @override
  Future<void> setUserProperty(String name, String value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }
}

// ---------------------------------------------------------------------------
// A/B Test Framework
// ---------------------------------------------------------------------------

/// Experiment variants.
enum AbGroup { treatment, control }

/// Result of an A/B assignment.
class AbAssignment {
  final String experimentId;
  final AbGroup group;
  final int seed; // deterministic hash input

  const AbAssignment({
    required this.experimentId,
    required this.group,
    required this.seed,
  });

  String get groupName => group == AbGroup.treatment ? 'treatment' : 'control';
}

/// Deterministic, server-free A/B assignment.
///
/// Assignment is stable for the same (uid, experimentId) pair.
/// No external server call required — suitable for offline-first MVP.
///
/// Algorithm: FNV-1a 32-bit hash of "$uid:$experimentId", mod 100.
/// Even split: hash % 100 < 50 → treatment, else → control.
class AbFramework {
  const AbFramework();

  /// Assigns the user to a variant.
  AbAssignment assign(String uid, String experimentId) {
    final input = '$uid:$experimentId';
    final hash = _fnv1a32(input);
    final bucket = hash % 100; // 0–99
    return AbAssignment(
      experimentId: experimentId,
      group: bucket < 50 ? AbGroup.treatment : AbGroup.control,
      seed: hash,
    );
  }

  /// FNV-1a 32-bit hash (non-cryptographic, deterministic).
  int _fnv1a32(String input) {
    const int fnvPrime = 16777619;
    const int offsetBasis = 2166136261;
    int hash = offsetBasis;
    for (final int byte in input.codeUnits) {
      hash ^= byte;
      // Keep within 32-bit unsigned range
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }
}

// ---------------------------------------------------------------------------
// High-level AnalyticsService (facade)
// ---------------------------------------------------------------------------

/// Single entry-point for all analytics calls in ENG Quest.
///
/// Usage:
/// ```dart
/// // In main.dart:
/// AnalyticsService.initialize(firebaseAvailable: true);
///
/// // Anywhere in the app:
/// await AnalyticsService.instance.logBattleAnswer(wordId: 'eiken5_042', grade: 3, latencyMs: 850);
/// ```
class AnalyticsService {
  final AnalyticsSink sink;
  final AbFramework _ab;

  DateTime? _sessionStart;

  /// App-wide singleton. Initialized via [initialize] in main.dart.
  static AnalyticsService? _instance;

  /// Returns the app-wide singleton. Falls back to [NoOpAnalytics] if
  /// [initialize] has not been called yet.
  static AnalyticsService get instance =>
      _instance ??= AnalyticsService(sink: NoOpAnalytics());

  /// Creates the singleton with the appropriate sink based on Firebase
  /// availability AND parental consent. Call once in main after Firebase init.
  ///
  /// PRIVACY-BY-DEFAULT (flaw-hunt #120, COPPA/APPI): a children's app must not
  /// send ANY analytics until a parent consents. So the real Firebase sink is
  /// used ONLY when Firebase is available AND [analyticsConsentGranted] is true;
  /// otherwise we wire the NoOp sink so nothing leaves the device. The
  /// app-startup paths additionally hold setAnalyticsCollectionEnabled OFF until
  /// consent, so this is belt-and-suspenders. Consent defaults to FALSE.
  static void initialize({
    required bool firebaseAvailable,
    bool analyticsConsentGranted = false,
  }) {
    _instance = AnalyticsService(
      sink: (firebaseAvailable && analyticsConsentGranted)
          ? FirebaseAnalyticsAdapter()
          : NoOpAnalytics(),
    );
  }

  /// Reset the singleton (for testing only).
  static void resetForTesting() {
    _instance = null;
  }

  AnalyticsService({
    required this.sink,
    AbFramework? ab,
  }) : _ab = ab ?? const AbFramework();

  // ---- Session -------------------------------------------------------

  Future<void> startSession(String uid) async {
    _sessionStart = DateTime.now();
    await sink.setUserId(uid);
    await sink.logEvent(EngQuestEvent.sessionStart);
  }

  Future<void> endSession(int wordsPracticed) async {
    final duration = _sessionStart == null
        ? 0
        : DateTime.now().difference(_sessionStart!).inSeconds;
    await sink.logEvent(EngQuestEvent.sessionEnd, parameters: {
      EngQuestParam.sessionDurationSec: duration,
      EngQuestParam.wordsPracticed: wordsPracticed,
    });
    _sessionStart = null;
  }

  // ---- Battle --------------------------------------------------------

  Future<void> logBattleCardShown({
    required String wordId,
    required String cefrLevel,
  }) async {
    await sink.logEvent(EngQuestEvent.battleCardShown, parameters: {
      EngQuestParam.wordId: wordId,
      EngQuestParam.cefrLevel: cefrLevel,
    });
  }

  Future<void> logBattleAnswer({
    required String wordId,
    required int grade, // 1-4
    required int latencyMs,
  }) async {
    await sink.logEvent(EngQuestEvent.battleCardAnswered, parameters: {
      EngQuestParam.wordId: wordId,
      EngQuestParam.grade: grade,
      EngQuestParam.latencyMs: latencyMs,
    });
  }

  Future<void> logBattleSessionComplete({
    required int wordsPracticed,
    required double accuracy,
  }) async {
    await sink.logEvent(EngQuestEvent.battleSessionComplete, parameters: {
      EngQuestParam.wordsPracticed: wordsPracticed,
      EngQuestParam.accuracy: accuracy,
    });
  }

  /// Generic practice-session completion — the core retention signal, fired from
  /// the single chokepoint every battle/exam completion already calls
  /// (recordExamHabitAndGet). Inert until a parent grants analytics consent.
  Future<void> logPracticeSessionComplete({required int wordsPracticed}) async {
    await sink.logEvent(EngQuestEvent.practiceSessionComplete, parameters: {
      EngQuestParam.wordsPracticed: wordsPracticed,
    });
  }

  // ---- Voice ---------------------------------------------------------

  Future<void> logVoiceAttempt({
    required String wordId,
    required double accuracy,
    required int latencyMs,
  }) async {
    await sink.logEvent(EngQuestEvent.voiceAttemptResult, parameters: {
      EngQuestParam.wordId: wordId,
      EngQuestParam.accuracy: accuracy,
      EngQuestParam.latencyMs: latencyMs,
    });
  }

  // ---- Dialog --------------------------------------------------------

  Future<void> logDialogTurn({
    required String scenarioId,
    required int latencyMs,
  }) async {
    await sink.logEvent(EngQuestEvent.dialogTurnSent, parameters: {
      EngQuestParam.scenarioId: scenarioId,
      EngQuestParam.latencyMs: latencyMs,
    });
  }

  Future<void> logDialogScenarioComplete(String scenarioId) async {
    await sink.logEvent(EngQuestEvent.dialogScenarioComplete, parameters: {
      EngQuestParam.scenarioId: scenarioId,
    });
  }

  // ---- Onboarding ----------------------------------------------------

  Future<void> logOnboardingStep(String stepName) async {
    await sink.logEvent(EngQuestEvent.onboardingStepComplete, parameters: {
      EngQuestParam.stepName: stepName,
    });
  }

  Future<void> logOnboardingComplete(String uid) async {
    await sink.logEvent(EngQuestEvent.onboardingComplete);
  }

  // ---- A/B Trial -----------------------------------------------------

  /// Returns the group assignment and logs it to analytics.
  Future<AbAssignment> assignAndLogAbGroup({
    required String uid,
    required String experimentId,
  }) async {
    final assignment = _ab.assign(uid, experimentId);
    await sink.setUserProperty('ab_$experimentId', assignment.groupName);
    await sink.logEvent(EngQuestEvent.abGroupAssigned, parameters: {
      EngQuestParam.abGroup: assignment.groupName,
    });
    return assignment;
  }

  /// Log a retention test result (day-30 A/B trial primary metric).
  Future<void> logRetentionTest({
    required String uid,
    required AbGroup group,
    required double retentionScore, // 0.0–1.0
  }) async {
    await sink.logEvent(EngQuestEvent.abRetentionTest, parameters: {
      EngQuestParam.abGroup:
          group == AbGroup.treatment ? 'treatment' : 'control',
      EngQuestParam.retentionScore: retentionScore,
    });
  }
}
