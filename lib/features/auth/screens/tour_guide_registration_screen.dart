import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/gemini_vision_service.dart';
import '../../../core/services/lockout_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/custom_text_field.dart';
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
  final _ageCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _tourGuideIdCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

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
    _ageCtrl.dispose();
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

  String? _ageValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    final age = int.tryParse(value.trim());
    if (age == null || age < 18 || age > 100) return AppStrings.invalidAge;
    return null;
  }

  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    // Accept Philippine numbers: 09XX, +639XX, or formatted versions
    final phoneRegex = RegExp(r'^(\+?63|0)\d{10}$');
    final cleaned = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!phoneRegex.hasMatch(cleaned)) return AppStrings.invalidPhone;
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

    setState(() {
      _isSubmitting = true;
      _isVerifying = _selectedIdImageBytes != null;
    });

    try {
      String status = 'approved'; // Default if no ID photo

      // Step 1: If ID photo is provided, verify with Gemini Vision AI
      if (_selectedIdImageBytes != null) {
        final mimeType = _selectedIdImage?.mimeType ?? 'image/jpeg';
        final result = await GeminiVisionService.verifyTourGuideId(
          _selectedIdImageBytes!,
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

        status = 'approved'; // Auto-approved via AI verification
      }

      // Step 2: Register
      await AuthService.registerTourGuide(
        firstName: _firstNameCtrl.text,
        middleName: _middleNameCtrl.text,
        lastName: _lastNameCtrl.text,
        age: int.parse(_ageCtrl.text.trim()),
        email: _emailCtrl.text,
        contactNumber: _contactCtrl.text,
        address: _addressCtrl.text,
        tourGuideId: _tourGuideIdCtrl.text,
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
                        const SizedBox(height: 32),
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

  Widget _buildIdPhotoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tour Guide ID Photo (Optional)',
          style: Theme.of(context).textTheme.labelMedium,
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
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: AppColors.primary),
                      Text('Upload ID Photo'),
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
            label: '${AppStrings.middleName} (Optional)',
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

          // Age
          CustomTextField(
            controller: _ageCtrl,
            label: AppStrings.age,
            hint: AppStrings.ageHint,
            helperText: 'Must be 18 years or older',
            prefixIcon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            validator: _ageValidator,
          ),
          const SizedBox(height: 18),

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

          // Contact Number
          CustomTextField(
            controller: _contactCtrl,
            label: AppStrings.contactNumber,
            hint: AppStrings.contactNumberHint,
            helperText: 'Philippine format: +63 or 09...',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: _phoneValidator,
          ),
          const SizedBox(height: 18),

          // Address (Optional)
          CustomTextField(
            controller: _addressCtrl,
            label: '${AppStrings.address} (Optional)',
            hint: AppStrings.addressHint,
            helperText: 'Enter your current address',
            prefixIcon: Icons.location_on_outlined,
            keyboardType: TextInputType.streetAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // DOT Tour Guide ID (Optional)
          CustomTextField(
            controller: _tourGuideIdCtrl,
            label: '${AppStrings.tourGuideId} (Optional)',
            hint: AppStrings.tourGuideIdHint,
            helperText: 'Enter your DOT ID number',
            prefixIcon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // DOT Tour Guide ID Photo Upload (Optional)
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
