import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Centralized service for all Tour Guide authentication operations.
/// Handles registration, login, password reset, and account status checks.
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Current User ────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Registration (US-01) ─────────────────────────────────

  /// Registers a new tour guide with Firebase Auth + Firestore profile.
  /// Account is saved with [status] — defaults to 'approved' (no admin approval needed).
  static Future<void> registerTourGuide({
    required String firstName,
    required String lastName,
    String middleName = '',
    required int age,
    required DateTime birthDate,
    required String email,
    required String contactNumber,
    String address = '',
    String tourGuideId = '',
    String idType = '',
    required String username,
    required String password,
    String status = 'approved',
    String? idPhotoUrl,
  }) async {
    // Build a display-friendly full name
    final fullName = middleName.trim().isNotEmpty
        ? '${firstName.trim()} ${middleName.trim()} ${lastName.trim()}'
        : '${firstName.trim()} ${lastName.trim()}';

    // Normalize phone to E.164 (+639XXXXXXXXX) — Step 18
    final normalizedPhone = _normalizePhilippinePhone(contactNumber);

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
      'birthDate': birthDate.toIso8601String(),
      'age': age,
      'email': email.trim(),
      'contactNumber': normalizedPhone,
      'address': address.trim(),
      'tourGuideId': tourGuideId.trim(),
      'idType': idType.trim(),
      'username': username.trim(),
      'status': status,
      'role': 'tour_guide',
      'isProfileComplete': true,
      'authProvider': 'email',
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (idPhotoUrl != null) {
      profileData['idPhotoUrl'] = idPhotoUrl;
    }

    await _db.collection('users').doc(uid).set(profileData);

    // Sign out so the user goes through the login flow
    await _auth.signOut();
  }

  // ── Google Sign-In (REV-001) ─────────────────────────────

  /// Signs in or registers a user via Google OAuth.
  /// Returns a map with keys:
  ///   - 'isNewOrIncomplete' (bool): true if the user must complete their profile
  ///   - 'uid' (String): Firebase UID
  ///   - 'email', 'displayName', 'photoUrl': pre-filled data from Google
  /// Step 12 — enforces strict flow; Dashboard is locked until profile complete.
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      User user;
      String? displayName;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final userCredential = await _auth.signInWithPopup(googleProvider);
        user = userCredential.user!;
        displayName = user.displayName;
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw AuthException('google-sign-in-cancelled');
        }

        final googleAuth = await googleUser.authentication;
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential =
            await _auth.signInWithCredential(oauthCredential);
        user = userCredential.user!;
        displayName = googleUser.displayName ?? user.displayName;
      }

      // Step 16 — Check if profile already exists and is complete
      final doc = await _db.collection('users').doc(user.uid).get();
      final isComplete =
          doc.exists && (doc.data()?['isProfileComplete'] as bool? ?? false);

      final names = (displayName ?? '').trim().split(' ');
      final firstName = names.isNotEmpty ? names.first : '';
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

      return {
        'isNewOrIncomplete': !isComplete,
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': displayName ?? '',
        'photoUrl': user.photoURL ?? '',
        'firstName': firstName,
        'lastName': lastName,
      };
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled') {
        throw AuthException('google-sign-in-cancelled');
      }
      throw AuthException(e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }

  /// Step 14 & 15 — Checks whether the current user's Firestore profile is complete.
  /// If Firebase user exists but Firestore profile has [isProfileComplete == false]
  /// or the doc doesn't exist yet, returns false → force route to CompleteProfileScreen.
  static Future<bool> isProfileComplete() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;
    return doc.data()?['isProfileComplete'] as bool? ?? false;
  }

  /// Step 12 & 13 — Saves the completed Google user profile to Firestore.
  /// Called only after all required fields AND ID verification pass.
  /// Sets [isProfileComplete: true] and [status: 'approved'] to unlock Dashboard.
  static Future<void> completeGoogleProfile({
    required String uid,
    required String firstName,
    required String lastName,
    String middleName = '',
    required int age,
    required DateTime birthDate,
    required String email,
    required String contactNumber,
    required String address,
    required String username,
    required String idType,
    String? idPhotoUrl,
    String? photoUrl,
  }) async {
    final fullName = middleName.trim().isNotEmpty
        ? '${firstName.trim()} ${middleName.trim()} ${lastName.trim()}'
        : '${firstName.trim()} ${lastName.trim()}';

    final normalizedPhone = _normalizePhilippinePhone(contactNumber);

    final profileData = <String, dynamic>{
      'uid': uid,
      'firstName': firstName.trim(),
      'middleName': middleName.trim(),
      'lastName': lastName.trim(),
      'fullName': fullName,
      'birthDate': birthDate.toIso8601String(),
      'age': age,
      'email': email.trim(),
      'contactNumber': normalizedPhone,
      'address': address.trim(),
      'username': username.trim(),
      'idType': idType.trim(),
      'status': 'approved',
      'role': 'tour_guide',
      'isProfileComplete': true,
      'authProvider': 'google',
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (idPhotoUrl != null) profileData['idPhotoUrl'] = idPhotoUrl;
    if (photoUrl != null) profileData['profilePhotoUrl'] = photoUrl;

    await _db.collection('users').doc(uid).set(profileData, SetOptions(merge: true));

    // Update Firebase Auth display name
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(fullName);
    }
  }

  /// Step 15 — Signs out of both Firebase Auth and Google account.
  /// Used when the user cancels the Complete Profile flow.
  static Future<void> signOutGoogle() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // ── Phone Normalization (Step 18) ────────────────────────

  /// Normalizes a Philippine mobile number to E.164 format (+639XXXXXXXXX).
  static String _normalizePhilippinePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('+639')) return trimmed;
    if (trimmed.startsWith('09') && trimmed.length == 11) {
      return '+63${trimmed.substring(1)}';
    }
    if (trimmed.startsWith('9') && trimmed.length == 10) {
      return '+63$trimmed';
    }
    return trimmed; // Return as-is if format is unrecognized
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

      // Status check — only block rejected accounts
      final status = doc.data()?['status'] as String? ?? 'approved';

      if (status == 'rejected') {
        await _auth.signOut();
        throw AuthException('account-rejected');
      }

      // status is 'approved' or any other value → login successful
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

  /// Returns whether the currently signed-in user used Google OAuth.
  static bool get isGoogleUser {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  /// Changes the user's password (or sets one if authenticated with Google).
  static Future<void> updatePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthException('account-not-found');
    }

    final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');

    // Only require current password re-authentication for non-Google users
    if (!isGoogle) {
      if (currentPassword == null || currentPassword.isEmpty) {
        throw AuthException('invalid-credential');
      }
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
    }

    // Update to new password
    await user.updatePassword(newPassword);
  }

  // ── Delete Account ───────────────────────────────────────

  /// Permanently deletes the current user's account.
  /// Re-authenticates email/password users; Google users delete directly.
  static Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException('account-not-found');
    }

    final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');

    if (!isGoogle && password != null && user.email != null) {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    }

    // Delete Firestore profile
    await _db.collection('users').doc(user.uid).delete();

    // Delete Firebase Auth account
    await user.delete();
  }

  // ── Sign Out ─────────────────────────────────────────────

  static Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
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
      case 'google-sign-in-cancelled':
        return 'Google Sign-In was cancelled.';
      case 'google-sign-in-failed':
        return 'Google Sign-In failed. Please try again.';
      case 'profile-incomplete':
        return 'Please complete your profile before accessing the dashboard.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
