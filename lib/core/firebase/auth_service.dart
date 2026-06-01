import 'package:firebase_auth/firebase_auth.dart';

/// Anonymous authentication for MVP.
/// Users are identified by UID — no PII collected (COPPA compliant).
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the current user UID, signing in anonymously if needed.
  Future<String> getOrCreateUid() async {
    User? user = _auth.currentUser;
    if (user == null) {
      final credential = await _auth.signInAnonymously();
      user = credential.user!;
    }
    return user.uid;
  }

  /// Returns a fresh Firebase ID token for server-side verification.
  /// Returns null if not signed in.
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current user (null if not signed in)
  User? get currentUser => _auth.currentUser;
}
