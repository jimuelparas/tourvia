import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/gemini_vision_service.dart';
import '../../../core/services/lockout_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/google_logo.dart';
import '../widgets/custom_text_field.dart';
import 'complete_profile_screen.dart';
import 'registration_success_screen.dart';
import 'tour_guide_login_screen.dart';

/// Tour Guide registration form screen (US-01).
///
/// Collects: full name, age, email, contact number, tour guide ID,
/// password, and confirm password. All fields are required and
/// validated inline on submission.
/// Includes 5-attempt rate-limiting with a 15-minute temporary lockout.
class TourGuideRegistrationScreen extends StatefulWidget {
  const TourGuideRegistrationScreen({super.key});

  @override
  State<TourGuideRegistrationScreen> createState() =>
      _TourGuideRegistrationScreenState();
}

class _TourGuideRegistrationScreenState
    extends State<TourGuideRegistrationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ─────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  // Birthday state (Steps 1-5) — replaces age text input
  DateTime? _selectedBirthday;
  int? _calculatedAge;
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _tourGuideIdCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  // ID Type state (Step 8)
  String? _selectedIdType;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  // ID photo for Gemini AI verification
  XFile? _selectedIdImage;
  Uint8List? _selectedIdImageBytes;
  bool _isVerifying = false;

  /// Lockout status state for 5-attempt rate-limiting.
  LockoutStatus? _lockoutStatus;
  Timer? _lockoutTimer;

  // ── Animations ──────────────────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
    _checkInitialLockout();
  }

  Future<void> _checkInitialLockout() async {
    final status = await LockoutService.checkLockout(LockoutType.guideRegistration);
    if (!mounted) return;
    setState(() => _lockoutStatus = status);
    if (status.isLocked) {
      _startLockoutCountdown();
    }
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final status = await LockoutService.checkLockout(LockoutType.guideRegistration);
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _lockoutStatus = status);
      if (!status.isLocked) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    _tourGuideIdCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    final emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[\w\.\-]+$');
    if (!emailRegex.hasMatch(value.trim())) return AppStrings.invalidEmail;
    return null;
  }

  // Step 1/4: Birthday validator — enforces 18+ rule
  String? _birthdayValidator() {
    if (_selectedBirthday == null) return AppStrings.birthdayRequired;
    if ((_calculatedAge ?? 0) < 18) return AppStrings.ageTooYoung;
    return null;
  }

  // Step 2: Auto age calculation from birthday
  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  // Step 17: Granular Philippine phone validator
  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.phoneRequired;
    final raw = value.trim();
    // Check for invalid characters (only digits and a leading +)
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(raw)) {
      return AppStrings.phoneInvalidChars;
    }
    // Normalize: strip +63 prefix to check digit count
    String digits = raw;
    if (digits.startsWith('+63')) {
      digits = '0${digits.substring(3)}';
    }
    // Check prefix
    if (!digits.startsWith('09') && !raw.startsWith('+639')) {
      return AppStrings.phoneInvalidPrefix;
    }
    // Length checks (normalized to 09 format for digit counting)
    final normalizedLen = digits.length;
    if (normalizedLen < 11) return AppStrings.phoneTooShort;
    if (normalizedLen > 11) return AppStrings.phoneTooLong;
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    if (value.length < 8) return AppStrings.passwordTooShort;
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    if (value != _passwordCtrl.text) return AppStrings.passwordsDoNotMatch;
    return null;
  }

  // ── Submit ──────────────────────────────────────────────

  Future<void> _pickIdImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedIdImage = picked;
        _selectedIdImageBytes = bytes;
      });
    }
  }

  Future<void> _captureIdImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedIdImage = picked;
        _selectedIdImageBytes = bytes;
      });
    }
  }

  Future<void> _onSubmit() async {
    // Check lockout before attempting submission
    final currentStatus = await LockoutService.checkLockout(LockoutType.guideRegistration);
    if (currentStatus.isLocked) {
      setState(() => _lockoutStatus = currentStatus);
      _startLockoutCountdown();
      _showLockoutDialog(currentStatus.formattedRemainingTime);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Step 4: Extra birthday validation (not handled by Form validators since it's a date field)
    final birthdayError = _birthdayValidator();
    if (birthdayError != null) {
      _showError(birthdayError);
      return;
    }

    // ID Type and photo are optional (Barangay ID or DOT ID)
    setState(() {
      _isSubmitting = true;
      _isVerifying = _selectedIdImageBytes != null;
    });

    try {
      String status = 'approved';

      // Step 1/9: If ID photo is provided, verify with Gemini Vision AI passing idType
      if (_selectedIdImageBytes != null) {
        final mimeType = _selectedIdImage?.mimeType ?? 'image/jpeg';
        final result = await GeminiVisionService.verifyTourGuideId(
          _selectedIdImageBytes!,
          idType: _selectedIdType ?? 'Philippine Government ID',
          mimeType: mimeType,
        );

        if (!mounted) return;
        setState(() => _isVerifying = false);

        if (!result.isVerified) {
          setState(() => _isSubmitting = false);
          final lockoutStatus = await LockoutService.recordFailure(LockoutType.guideRegistration);
          if (!mounted) return;
          setState(() => _lockoutStatus = lockoutStatus);

          if (lockoutStatus.isLocked) {
            _startLockoutCountdown();
            _showLockoutDialog(lockoutStatus.formattedRemainingTime);
          } else {
            final reason = result.failureReason ?? _buildFailureReason(result);
            _showVerificationFailedDialog(
              '$reason\n\n(${lockoutStatus.remainingAttempts} attempt${lockoutStatus.remainingAttempts == 1 ? '' : 's'} remaining before 15-minute lockout)',
            );
          }
          return;
        }

        status = 'approved';
      }

      // Steps 2, 5, 18: Register with birthDate + age + idType (phone normalized in auth_service)
      await AuthService.registerTourGuide(
        firstName: _firstNameCtrl.text,
        middleName: _middleNameCtrl.text,
        lastName: _lastNameCtrl.text,
        age: _calculatedAge!,
        birthDate: _selectedBirthday!,
        email: _emailCtrl.text,
        contactNumber: _contactCtrl.text,
        address: _addressCtrl.text,
        tourGuideId: _tourGuideIdCtrl.text,
        idType: _selectedIdType ?? '',
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
        status: status,
      );

      if (!mounted) return;

      // Reset lockout counter on success
      await LockoutService.resetAttempts(LockoutType.guideRegistration);

      setState(() => _isSubmitting = false);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const RegistrationSuccessScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      await _handleRegistrationFailure(e.message);
    } catch (e) {
      if (!mounted) return;
      await _handleRegistrationFailure('Registration failed. Please try again.');
    }
  }

  Future<void> _handleRegistrationFailure(String message) async {
    final status = await LockoutService.recordFailure(LockoutType.guideRegistration);
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _isVerifying = false;
      _lockoutStatus = status;
    });

    if (status.isLocked) {
      _startLockoutCountdown();
      _showLockoutDialog(status.formattedRemainingTime);
    } else {
      _showError('$message (${status.remainingAttempts} attempt${status.remainingAttempts == 1 ? '' : 's'} remaining before 15-minute lockout)');
    }
  }

  void _showLockoutDialog(String remainingTime) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Registration Locked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Too many failed registration attempts (5/5).',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'For security purposes, registration has been temporarily locked. Please try again in $remainingTime.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _buildFailureReason(GeminiIdVerificationResult result) {
    final reasons = <String>[];
    if (!result.isOfficialDotId) {
      reasons.add(
        'The uploaded image does not appear to be an official DOT Tour Guide ID.',
      );
    }
    if (result.isExpired) {
      reasons.add(
        'The ID appears to be expired (Expiry: ${result.expiryDate ?? 'unknown'}).',
      );
    }
    if (!result.isImageClear) {
      reasons.add(
        'The uploaded image is unclear, blurry, or cropped. Please upload a clear, complete photo.',
      );
    }
    return reasons.isNotEmpty
        ? reasons.join('\n\n')
        : 'Verification failed. Please try again with a valid ID.';
  }

  void _showVerificationFailedDialog(String reason) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gpp_bad_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Verification Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Tour Guide ID could not be verified:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                reason,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.error,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      bottomInset > 0 ? bottomInset : 32,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeader(),
                        const SizedBox(height: 24),
                        // Step 10: Google Sign-In button
                        _buildGoogleSignInButton(),
                        const SizedBox(height: 20),
                        _buildOrDivider(),
                        const SizedBox(height: 20),
                        _buildForm(),
                        const SizedBox(height: 28),
                        _buildSubmitButton(),
                        const SizedBox(height: 20),
                        _buildLoginLink(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Google Sign-In Button (Step 10) ────────────────────

  Widget _buildGoogleSignInButton() {
    return OutlinedButton(
      onPressed: _isSubmitting ? null : _onGoogleSignIn,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.white.withValues(alpha: 0.05),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GoogleLogo(size: 20),
          const SizedBox(width: 12),
          Text(
            AppStrings.continueWithGoogle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            AppStrings.orDivider,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  // Step 10: Google sign-in handler for registration screen
  Future<void> _onGoogleSignIn() async {
    setState(() => _isSubmitting = true);
    try {
      final result = await AuthService.signInWithGoogle();
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (result['isNewOrIncomplete'] == true) {
        // Step 12/13: Route to Complete Profile screen (Dashboard still locked)
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => CompleteProfileScreen(
              uid: result['uid'] as String,
              email: result['email'] as String,
              firstName: result['firstName'] as String,
              lastName: result['lastName'] as String,
              photoUrl: result['photoUrl'] as String,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
      // If complete → AuthService.signInWithGoogle already signed them in → root will route to Dashboard
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(AppStrings.googleSignInError);
    }
  }

  // ── Header ──────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo / brand icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.explore_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppStrings.registerTitle,
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.registerSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  // ── Form ────────────────────────────────────────────────

  // ── ID Photo Upload (Steps 7, 8) ─────────────────────────

  Widget _buildIdPhotoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.idPhotoLabel,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Upload a clear photo of your selected ID.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('Camera'),
                      onTap: () {
                        _captureIdImage();
                        Navigator.pop(ctx);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('Gallery'),
                      onTap: () {
                        _pickIdImage();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: _selectedIdImageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _selectedIdImageBytes!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo,
                          color: AppColors.primary.withValues(alpha: 0.7)),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to upload your ID photo',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // First Name
          CustomTextField(
            controller: _firstNameCtrl,
            label: AppStrings.firstName,
            hint: AppStrings.firstNameHint,
            helperText: 'Enter your first name',
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 18),

          // Middle Name (Optional)
          CustomTextField(
            controller: _middleNameCtrl,
            label: '${AppStrings.middleName} (if applicable)',
            hint: AppStrings.middleNameHint,
            helperText: 'Enter your middle name',
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // Last Name
          CustomTextField(
            controller: _lastNameCtrl,
            label: AppStrings.lastName,
            hint: AppStrings.lastNameHint,
            helperText: 'Enter your last name',
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 18),

          // Step 1: Birthday / Date of Birth date picker
          _buildBirthdayPicker(),
          const SizedBox(height: 18),

          // Step 3: Auto-calculated age badge (read-only)
          if (_calculatedAge != null) ...[
            _buildAgeBadge(),
            const SizedBox(height: 18),
          ],

          // Email
          CustomTextField(
            controller: _emailCtrl,
            label: AppStrings.email,
            hint: AppStrings.emailHint,
            helperText: 'e.g. name@domain.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _emailValidator,
          ),
          const SizedBox(height: 18),

          // Contact Number (Step 17)
          CustomTextField(
            controller: _contactCtrl,
            label: AppStrings.contactNumber,
            hint: AppStrings.contactNumberHint,
            helperText: 'Philippine format: +639... or 09...',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: _phoneValidator,
          ),
          const SizedBox(height: 18),

          // Step 6: Address — strictly required
          CustomTextField(
            controller: _addressCtrl,
            label: AppStrings.address,
            hint: AppStrings.addressHint,
            helperText: 'Enter your complete address',
            prefixIcon: Icons.location_on_outlined,
            keyboardType: TextInputType.streetAddress,
            textInputAction: TextInputAction.next,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 18),

          // Step 8: ID Type Dropdown
          _buildIdTypeDropdown(),
          const SizedBox(height: 18),

          // ID Photo Upload (Step 7)
          _buildIdPhotoUpload(),
          const SizedBox(height: 18),

          // Username
          CustomTextField(
            controller: _usernameCtrl,
            label: AppStrings.username,
            hint: AppStrings.usernameHint,
            helperText: 'Create a username',
            prefixIcon: Icons.alternate_email_rounded,
            textInputAction: TextInputAction.next,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 18),

          // Password
          CustomTextField(
            controller: _passwordCtrl,
            label: AppStrings.password,
            hint: AppStrings.passwordHint,
            helperText: 'At least 8 characters',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            validator: _passwordValidator,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary,
                size: 22,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 18),

          // Confirm Password
          CustomTextField(
            controller: _confirmPasswordCtrl,
            label: AppStrings.confirmPassword,
            hint: AppStrings.confirmPasswordHint,
            helperText: 'Re-enter your password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            validator: _confirmPasswordValidator,
            onFieldSubmitted: (_) => _onSubmit(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary,
                size: 22,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: Birthday date picker widget
  Widget _buildBirthdayPicker() {
    final maxDate = DateTime(
      DateTime.now().year - 18,
      DateTime.now().month,
      DateTime.now().day,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.birthday,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedBirthday ?? maxDate,
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
              helpText: 'Select Birthday',
            );
            if (picked != null) {
              setState(() {
                _selectedBirthday = picked;
                _calculatedAge = _calculateAge(picked);
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedBirthday == null
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedBirthday != null
                        ? '${_selectedBirthday!.day.toString().padLeft(2, '0')} / '
                            '${_selectedBirthday!.month.toString().padLeft(2, '0')} / '
                            '${_selectedBirthday!.year}'
                        : AppStrings.birthdayHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _selectedBirthday != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_month_outlined,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Step 3: Read-only age badge
  Widget _buildAgeBadge() {
    final isUnder18 = (_calculatedAge ?? 0) < 18;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isUnder18
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnder18
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUnder18
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isUnder18 ? AppColors.error : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            isUnder18
                ? '${AppStrings.calculatedAge}: $_calculatedAge ${AppStrings.ageDisplay} — ${AppStrings.ageTooYoung}'
                : '${AppStrings.calculatedAge}: $_calculatedAge ${AppStrings.ageDisplay}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isUnder18 ? AppColors.error : AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Step 8: ID Type dropdown
  Widget _buildIdTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.idTypeLabel,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedIdType == null
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedIdType,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  AppStrings.idTypeHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              borderRadius: BorderRadius.circular(12),
              items: AppStrings.validIdTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedIdType = val),
            ),
          ),
        ),
      ],
    );
  }

  // ── Submit Button ───────────────────────────────────────

  Widget _buildSubmitButton() {
    final isLocked = _lockoutStatus?.isLocked ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: (_isSubmitting || isLocked) ? null : AppColors.primaryGradient,
        color: isLocked ? AppColors.surfaceVariant : null,
        boxShadow: (_isSubmitting || isLocked)
            ? []
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: (_isSubmitting || isLocked) ? null : _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: _isSubmitting
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                  if (_isVerifying) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Verifying Tour Guide ID...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              )
            : isLocked
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_clock_rounded,
                          size: 20, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text(
                        'Locked (${_lockoutStatus?.formattedRemainingTime})',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.how_to_reg_rounded, size: 22),
                      SizedBox(width: 10),
                      Text(AppStrings.registerButton),
                    ],
                  ),
      ),
    );
  }

  // ── Login Link ──────────────────────────────────────────

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.alreadyHaveAccount,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const TourGuideLoginScreen(),
                transitionsBuilder: (_, animation, __, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeIn,
                    ),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          },
          child: Text(
            AppStrings.login,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
