import 'package:firebase_auth/firebase_auth.dart';

import '../storage/preferences_service.dart';

/// Anonymous authentication for MVP.
/// Users are identified by UID — no PII collected (COPPA compliant).
class AuthService {
  /// Shared sentinel for a session that has NEVER successfully authenticated.
  /// Only used on a true offline cold-start before any real uid was ever seen.
  static const String offlineUid = 'offline_user';
  // Lazily + safely resolved. FirebaseAuth.instance throws when Firebase
  // failed to initialize (offline/placeholder keys, e.g. the demo build).
  // Resolving in a field initializer crashed every screen that constructed an
  // AuthService at build time (Battle etc.) to a blank grey page. Returning
  // null here lets those screens render their offline/loading state instead.
  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// Returns the current user UID, signing in anonymously if needed.
  /// Throws if Firebase is unavailable — callers wrap in try/catch.
  Future<String> getOrCreateUid() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase Auth unavailable (offline / not initialized)');
    }
    User? user = auth.currentUser;
    if (user == null) {
      final credential = await auth.signInAnonymously();
      user = credential.user!;
    }
    return user.uid;
  }

  /// Resolves a STABLE user id that survives flaky Firebase initialization.
  ///
  /// [getOrCreateUid] throws whenever Firebase itself fails to init (placeholder
  /// keys / SDK load failure / offline cold start). Callers used to fall back to
  /// the literal '$offlineUid', which forks the child's durable, per-uid-keyed
  /// FSRS deck: a flaky-Firebase session writes to fsrs_deck_offline_user while a
  /// good session writes to `fsrs_deck_<realuid>`, splitting progress (#14).
  ///
  /// This centralizes the fallback so there is ONE identity across sessions:
  ///  - success → return the real anon uid AND persist it ([PrefKeys.uid]);
  ///  - failure → reuse the last persisted real uid if we ever had one, so a
  ///    later degraded session keeps writing to the SAME deck; only a device that
  ///    has never once authenticated falls back to the shared [offlineUid].
  Future<String> resolveUid() async {
    final prefs = await PreferencesService.getInstance();
    try {
      final uid = await getOrCreateUid();
      await prefs.setString(PrefKeys.uid, uid);
      return uid;
    } catch (_) {
      final saved = prefs.getString(PrefKeys.uid);
      return (saved != null && saved.isNotEmpty) ? saved : offlineUid;
    }
  }

  /// Returns a fresh Firebase ID token for server-side verification.
  /// Returns null if not signed in or Firebase is unavailable.
  Future<String?> getIdToken() async {
    final user = _auth?.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  /// Stream of auth state changes (empty stream if Firebase is unavailable).
  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? const Stream<User?>.empty();

  /// Current user (null if not signed in or Firebase is unavailable)
  User? get currentUser => _auth?.currentUser;

  /// Signs out the current user. No-op if Firebase is unavailable or no user
  /// is signed in. Used by the data-deletion flow (#67) — always safe to call.
  Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (_) {
      // Ignore: Firebase offline or not initialized.
    }
  }
}
