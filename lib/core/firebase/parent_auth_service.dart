import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Parent authentication service — email/password auth + child account linking.
///
/// Children use anonymous auth (COPPA compliant). Parents optionally create
/// an email account to monitor progress from a separate device. A 6-digit
/// link code connects the parent account to the child's anonymous UID.
class ParentAuthService {
  // Null-safe lazy access — FirebaseAuth/Firestore.instance throw when Firebase
  // failed to initialize (offline/placeholder keys). Returning null here keeps
  // sync getters (used in build) from crashing the screen; the async methods
  // below throw a clear StateError that their UI call sites already catch.
  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Current Firebase user (null if not signed in or Firebase unavailable).
  User? get currentUser => _auth?.currentUser;

  /// True when the current user signed in with email (not anonymous).
  bool get isParentUser {
    final user = _auth?.currentUser;
    if (user == null) return false;
    return !user.isAnonymous && user.email != null;
  }

  /// Resolves the auth instance or throws a clear error (callers catch it).
  FirebaseAuth get _requireAuth =>
      _auth ?? (throw StateError('Firebase Auth unavailable'));

  /// Resolves the Firestore instance or throws a clear error (callers catch it).
  FirebaseFirestore get _requireDb =>
      _db ?? (throw StateError('Firestore unavailable'));

  // ── Email Auth ──────────────────────────────────────────────────────────

  /// Create a new parent account with email and password.
  Future<UserCredential> signUp(String email, String password) async {
    return _requireAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign in an existing parent with email and password.
  Future<UserCredential> signIn(String email, String password) async {
    return _requireAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign out the current user.
  Future<void> signOut() => _requireAuth.signOut();

  // ── Link Code Generation (from child's device) ─────────────────────────

  /// Generate a 6-digit link code for the given child UID.
  /// Code expires after 1 hour. Returns the code string.
  Future<String> generateLinkCode(String childUid) async {
    // Generate a 6-digit code from timestamp + uid hash
    final now = DateTime.now();
    final hash = childUid.hashCode ^ now.microsecondsSinceEpoch;
    final code = (hash.abs() % 900000 + 100000).toString();

    // Delete any existing codes for this child
    final existing = await _requireDb
        .collection('link_codes')
        .where('childUid', isEqualTo: childUid)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    // Create new code document
    await _requireDb.collection('link_codes').doc(code).set({
      'childUid': childUid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 1))),
    });

    return code;
  }

  // ── Link Code Redemption (from parent's device) ────────────────────────

  /// Redeem a 6-digit link code. Adds the child to the parent's linked
  /// children list. Returns the child UID on success.
  ///
  /// Throws [LinkCodeException] if code is invalid or expired.
  Future<String> redeemLinkCode(String code) async {
    final user = _requireAuth.currentUser;
    if (user == null || user.isAnonymous) {
      throw LinkCodeException('保護者アカウントでログインしてください');
    }

    final doc =
        await _requireDb.collection('link_codes').doc(code.trim()).get();
    if (!doc.exists) {
      throw LinkCodeException('リンクコードが見つかりません');
    }

    final data = doc.data()!;
    final childUid = data['childUid'] as String;

    // Check expiry
    final expiresAt = data['expiresAt'] as Timestamp?;
    if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
      // Clean up expired code
      await doc.reference.delete();
      throw LinkCodeException('リンクコードの有効期限が切れています');
    }

    // Add child to parent's linked children
    await _requireDb.collection('parent_links').doc(user.uid).set({
      'children': FieldValue.arrayUnion([childUid]),
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Delete the used code
    await doc.reference.delete();

    return childUid;
  }

  /// Get the list of child UIDs linked to the current parent.
  Future<List<String>> getLinkedChildren() async {
    final user = _requireAuth.currentUser;
    if (user == null) return [];

    final doc = await _requireDb.collection('parent_links').doc(user.uid).get();
    if (!doc.exists) return [];

    final data = doc.data()!;
    final children = data['children'];
    if (children is List) {
      return children.cast<String>();
    }
    return [];
  }
}

/// Exception thrown when link code operations fail.
class LinkCodeException implements Exception {
  final String message;
  const LinkCodeException(this.message);

  @override
  String toString() => message;
}
