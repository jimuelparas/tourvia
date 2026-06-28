import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Centralized service for all Tour Guide authentication operations.
/// Handles registration, login, password reset, and account status checks.
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Current User ────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Registration (US-01) ─────────────────────────────────

  /// Registers a new tour guide with Firebase Auth + Firestore profile.
  /// Account is saved with status "pending" — admin must approve before login.
  static Future<void> registerTourGuide({
    required String fullName,
    required int age,
    required String email,
    required String contactNumber,
    required String tourGuideId,
    required String password,
  }) async {
    // 1. Create Firebase Auth user
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    // 2. Update display name
    await credential.user!.updateDisplayName(fullName.trim());

    // 3. Save profile to Firestore with status "pending"
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'fullName': fullName.trim(),
      'age': age,
      'email': email.trim(),
      'contactNumber': contactNumber.trim(),
      'tourGuideId': tourGuideId.trim(),
      'status': 'pending', // pending | approved | rejected
      'role': 'tour_guide',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 4. Sign out immediately — must be approved before login
    await _auth.signOut();
  }

  // ── Login (US-02) ────────────────────────────────────────

  /// Logs in a tour guide and checks account status.
  /// Throws [AuthException] with a specific code if account is pending/rejected.
  static Future<void> loginTourGuide({
    required String email,
    required String password,
  }) async {
    // 1. Sign in with Firebase Auth
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    // 2. Fetch Firestore profile to check status
    final doc = await _db.collection('users').doc(uid).get();

    if (!doc.exists) {
      await _auth.signOut();
      throw AuthException('account-not-found');
    }

    final status = doc.data()?['status'] as String? ?? 'pending';

    if (status == 'pending') {
      await _auth.signOut();
      throw AuthException('account-pending');
    }

    if (status == 'rejected') {
      await _auth.signOut();
      throw AuthException('account-rejected');
    }

    // status == 'approved' → login successful
  }

  // ── Forgot Password (US-03) ──────────────────────────────

  /// Sends a password reset email via Firebase Auth.
  static Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Sign Out ─────────────────────────────────────────────

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}

/// Custom exception for Tourvia auth errors.
class AuthException implements Exception {
  final String code;
  AuthException(this.code);

  String get message {
    switch (code) {
      case 'account-pending':
        return 'Your account is pending approval. Please wait for admin confirmation.';
      case 'account-rejected':
        return 'Your account has been rejected. Please contact support.';
      case 'account-not-found':
        return 'Account not found. Please register first.';
      case 'invalid-credential':
        return 'Incorrect username or password. Please try again.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please log in instead.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
