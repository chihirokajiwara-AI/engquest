import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Typed keys available through PreferencesService
// ---------------------------------------------------------------------------
abstract class PrefKeys {
  static const String onboardingComplete = 'onboarding_complete';
  static const String uid = 'uid';
  static const String avatarId = 'avatar_id';
  static const String ageYears = 'age_years';
  static const String dailyGoalMinutes = 'daily_goal_minutes';
  static const String cefrPlacement = 'cefr_placement';

  // Daily review reminder preferences (P2.10).
  // [remindersOptedOut] is stored inverted so the default (false) == opted-in,
  // i.e. reminders are ON by default for new users (retention-first).
  static const String remindersOptedOut = 'reminders_opted_out';
  static const String reminderHour = 'reminder_hour';
  static const String reminderMinute = 'reminder_minute';
  // True once a parent has explicitly chosen a reminder time (getInt can't
  // distinguish "unset" from 0:00, so we gate restore on this flag). #122.
  static const String reminderConfigured = 'reminder_configured';

  // Sound preferences
  static const String soundMuted = 'sound_muted'; // SFX channel (effects)
  static const String voiceMuted = 'voice_muted'; // Voice channel (word audio)

  // Parental analytics consent (#120, COPPA privacy-by-default). Default FALSE
  // → no analytics collection until a parent explicitly consents. Set true only
  // when the parental consent gate is passed (gate-wiring is a separate task).
  static const String analyticsConsentGranted = 'analytics_consent_granted';

  // Legacy keys kept for backward-compat with OnboardingStorage
  static const String onboardingAge = 'onboarding_age';
  static const String onboardingCefr = 'onboarding_cefr';
  static const String onboardingAvatar = 'onboarding_avatar';
  static const String onboardingGoalMinutes = 'onboarding_goal_minutes';
}

// ---------------------------------------------------------------------------
// In-memory fallback (identical API, used when SharedPreferences unavailable)
// ---------------------------------------------------------------------------
class _MemFallback {
  final Map<String, dynamic> _data = {};

  bool getBool(String k) => (_data[k] as bool?) ?? false;
  String? getString(String k) => _data[k] as String?;
  int getInt(String k) => (_data[k] as int?) ?? 0;
  void setBool(String k, bool v) => _data[k] = v;
  void setString(String k, String v) => _data[k] = v;
  void setInt(String k, int v) => _data[k] = v;
}

// ---------------------------------------------------------------------------
// PreferencesService — wraps SharedPreferences with graceful fallback
// ---------------------------------------------------------------------------

/// Singleton persistence service.
///
/// Usage:
/// ```dart
/// final prefs = await PreferencesService.getInstance();
/// prefs.setBool('onboarding_complete', true);
/// final done = prefs.getBool('onboarding_complete');
/// ```
///
/// If [SharedPreferences] is unavailable (unit-test environment or platform
/// channel not wired up) the service transparently falls back to an in-memory
/// store — same values survive the lifetime of the process but are not
/// persisted across restarts.
class PreferencesService {
  PreferencesService._internal(this._prefs);

  final SharedPreferences? _prefs;
  final _MemFallback _mem = _MemFallback();

  static PreferencesService? _instance;

  // ── Lazy singleton factory ──────────────────────────────────────────────

  /// Returns the singleton instance, initialising [SharedPreferences] on
  /// first call.  Subsequent calls return the cached instance immediately.
  static Future<PreferencesService> getInstance() async {
    if (_instance != null) return _instance!;
    try {
      final sp = await SharedPreferences.getInstance();
      _instance = PreferencesService._internal(sp);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PreferencesService] SharedPreferences unavailable, '
            'falling back to in-memory store: $e');
      }
      _instance = PreferencesService._internal(null);
    }
    return _instance!;
  }

  /// Clears the cached singleton.  Call this in tests to reset state.
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  // ── Boolean ─────────────────────────────────────────────────────────────

  bool getBool(String key) {
    if (_prefs != null) return _prefs!.getBool(key) ?? false;
    return _mem.getBool(key);
  }

  Future<void> setBool(String key, bool value) async {
    if (_prefs != null) {
      await _prefs!.setBool(key, value);
    } else {
      _mem.setBool(key, value);
    }
  }

  // ── String ──────────────────────────────────────────────────────────────

  String? getString(String key) {
    if (_prefs != null) return _prefs!.getString(key);
    return _mem.getString(key);
  }

  Future<void> setString(String key, String value) async {
    if (_prefs != null) {
      await _prefs!.setString(key, value);
    } else {
      _mem.setString(key, value);
    }
  }

  // ── Integer ─────────────────────────────────────────────────────────────

  int getInt(String key) {
    if (_prefs != null) return _prefs!.getInt(key) ?? 0;
    return _mem.getInt(key);
  }

  Future<void> setInt(String key, int value) async {
    if (_prefs != null) {
      await _prefs!.setInt(key, value);
    } else {
      _mem.setInt(key, value);
    }
  }

  // ── Utility ─────────────────────────────────────────────────────────────

  Future<void> remove(String key) async {
    if (_prefs != null) {
      await _prefs!.remove(key);
    } else {
      _mem._data.remove(key);
    }
  }

  Future<void> clear() async {
    if (_prefs != null) {
      await _prefs!.clear();
    } else {
      _mem._data.clear();
    }
  }

  /// Whether the underlying real SharedPreferences is active (vs in-memory).
  bool get isRealStorage => _prefs != null;
}
