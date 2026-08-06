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
  /// Account is saved with [status] — defaults to 'pending' (admin approval needed).
  /// If AI verification passes, status can be set to 'approved' for auto-activation.
  static Future<void> registerTourGuide({
    required String fullName,
    required int age,
    required String email,
    required String contactNumber,
    required String tourGuideId,
    required String password,
    String status = 'pending',
    String? idPhotoUrl,
  }) async {
    // 1. Create Firebase Auth user
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    // 2. Update display name
    await credential.user!.updateDisplayName(fullName.trim());

    // 3. Save profile to Firestore with provided status
    final profileData = <String, dynamic>{
      'uid': uid,
      'fullName': fullName.trim(),
      'age': age,
      'email': email.trim(),
      'contactNumber': contactNumber.trim(),
      'tourGuideId': tourGuideId.trim(),
      'status': status, // pending | approved | rejected
      'role': 'tour_guide',
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (idPhotoUrl != null) {
      profileData['idPhotoUrl'] = idPhotoUrl;
    }

    await _db.collection('users').doc(uid).set(profileData);

    // 4. Sign out immediately if pending — approved users can stay signed in
    if (status != 'approved') {
      await _auth.signOut();
    }
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

  // ── Profile Management ──────────────────────────────────

  /// Fetches the current user's Firestore profile document.
  static Future<Map<String, dynamic>?> getProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data();
  }

  /// Returns a real-time stream of the current user's profile document.
  static Stream<Map<String, dynamic>?> watchProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return _db.collection('users').doc(user.uid).snapshots().map(
          (doc) => doc.data(),
        );
  }

  /// Updates the current user's profile fields in both Auth and Firestore.
  static Future<void> updateProfile({
    required String fullName,
    required String email,
    required String contactNumber,
    String? address,
    String? profilePhotoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('account-not-found');

    // Update Auth display name
    await user.updateDisplayName(fullName.trim());

    // Update Auth email if changed
    if (user.email != email.trim()) {
      await user.verifyBeforeUpdateEmail(email.trim());
    }

    // Update Firestore profile
    final updateData = <String, dynamic>{
      'fullName': fullName.trim(),
      'email': email.trim(),
      'contactNumber': contactNumber.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (address != null) {
      updateData['address'] = address.trim();
    }

    if (profilePhotoUrl != null) {
      updateData['profilePhotoUrl'] = profilePhotoUrl;
    }

    await _db.collection('users').doc(user.uid).update(updateData);
  }

  /// Changes the current user's password after verifying the current one.
  static Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthException('account-not-found');
    }

    // Re-authenticate with current password
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // Update to new password
    await user.updatePassword(newPassword);
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
