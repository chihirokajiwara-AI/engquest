import 'package:firebase_auth/firebase_auth.dart';

/// Anonymous authentication for MVP.
/// Users are identified by UID — no PII collected (COPPA compliant).
class AuthService {
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
