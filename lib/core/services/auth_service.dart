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
    required String firstName,
    required String lastName,
    String middleName = '',
    required int age,
    required String email,
    required String contactNumber,
    String address = '',
    String tourGuideId = '',
    required String username,
    required String password,
    String status = 'pending',
    String? idPhotoUrl,
  }) async {
    // Build a display-friendly full name
    final fullName = middleName.trim().isNotEmpty
        ? '${firstName.trim()} ${middleName.trim()} ${lastName.trim()}'
        : '${firstName.trim()} ${lastName.trim()}';

    // 1. Create Firebase Auth user
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    // 2. Update display name
    await credential.user!.updateDisplayName(fullName);

    // 3. Save profile to Firestore with provided status
    final profileData = <String, dynamic>{
      'uid': uid,
      'firstName': firstName.trim(),
      'middleName': middleName.trim(),
      'lastName': lastName.trim(),
      'fullName': fullName,
      'age': age,
      'email': email.trim(),
      'contactNumber': contactNumber.trim(),
      'address': address.trim(),
      'tourGuideId': tourGuideId.trim(),
      'username': username.trim(),
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

  /// Logs in a tour guide by [identifier] (username or email) and password.
  /// Checks account status and throws [AuthException] for pending/rejected/invalid accounts.
  static Future<void> loginTourGuide({
    required String identifier,
    required String password,
  }) async {
    final trimmedIdentifier = identifier.trim();
    String emailToUse = trimmedIdentifier;

    // 1. If identifier is NOT an email (no '@'), resolve it from Firestore by username
    if (!trimmedIdentifier.contains('@')) {
      final query = await _db
          .collection('users')
          .where('username', isEqualTo: trimmedIdentifier)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        // Fallback: search case-insensitively across users
        final allUsers = await _db.collection('users').get();
        final match = allUsers.docs.where((doc) {
          final u = doc.data()['username'] as String?;
          return u != null &&
              u.toLowerCase() == trimmedIdentifier.toLowerCase();
        }).firstOrNull;

        if (match == null) {
          throw AuthException('user-not-found');
        }
        emailToUse = match.data()['email'] as String? ?? '';
      } else {
        emailToUse = query.docs.first.data()['email'] as String? ?? '';
      }

      if (emailToUse.isEmpty) {
        throw AuthException('account-not-found');
      }
    }

    try {
      // 2. Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: emailToUse.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      // 3. Fetch Firestore profile to check status
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
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    }
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

  /// Fetches any user's profile by their UID (used by tourists to view guide info).
  static Future<Map<String, dynamic>?> getGuideProfile(String guideUid) async {
    final doc = await _db.collection('users').doc(guideUid).get();
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
    required String firstName,
    required String lastName,
    String middleName = '',
    required String email,
    required String contactNumber,
    String? address,
    String? profilePhotoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('account-not-found');

    // Build full name from parts
    final fullName = middleName.trim().isNotEmpty
        ? '${firstName.trim()} ${middleName.trim()} ${lastName.trim()}'
        : '${firstName.trim()} ${lastName.trim()}';

    // Update Auth display name
    await user.updateDisplayName(fullName);

    // Update Auth email if changed
    if (user.email != email.trim()) {
      await user.verifyBeforeUpdateEmail(email.trim());
    }

    // Update Firestore profile
    final updateData = <String, dynamic>{
      'firstName': firstName.trim(),
      'middleName': middleName.trim(),
      'lastName': lastName.trim(),
      'fullName': fullName,
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

  // ── Delete Account ───────────────────────────────────────

  /// Permanently deletes the current user's account after re-authentication.
  /// Removes the Firestore profile document and then the Firebase Auth user.
  static Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthException('account-not-found');
    }

    // Re-authenticate to confirm identity
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    // Delete Firestore profile
    await _db.collection('users').doc(user.uid).delete();

    // Delete Firebase Auth account
    await user.delete();
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
        return 'Incorrect username/email or password. Please try again.';
      case 'user-not-found':
        return 'No account found with this username or email.';
      case 'username-already-in-use':
        return 'This username is already taken. Please choose another one.';
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
