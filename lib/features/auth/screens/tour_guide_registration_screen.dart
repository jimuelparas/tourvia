import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/gemini_vision_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/custom_text_field.dart';
import 'registration_success_screen.dart';
import 'tour_guide_login_screen.dart';

/// Tour Guide registration form screen (US-01).
///
/// Collects: full name, age, email, contact number, tour guide ID,
/// password, and confirm password. All fields are required and
/// validated inline on submission.
class TourGuideRegistrationScreen extends StatefulWidget {
  const TourGuideRegistrationScreen({super.key});

  @override
  State<TourGuideRegistrationScreen> createState() =>
      _TourGuideRegistrationScreenState();
}

class _TourGuideRegistrationScreenState
    extends State<TourGuideRegistrationScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ─────────────────────────────────────────
  final _fullNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _tourGuideIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  // ID photo for Gemini AI verification
  XFile? _selectedIdImage;
  Uint8List? _selectedIdImageBytes;
  bool _isVerifying = false;

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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _fullNameCtrl.dispose();
    _ageCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _tourGuideIdCtrl.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    // Validate ID photo is selected
    if (_selectedIdImageBytes == null) {
      _showError('Please upload a photo of your DOT Tour Guide ID.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isVerifying = true;
    });

    try {
      // Step 1: Verify ID with Gemini Vision AI
      final mimeType = _selectedIdImage?.mimeType ?? 'image/jpeg';
      final result = await GeminiVisionService.verifyTourGuideId(
        _selectedIdImageBytes!,
        mimeType: mimeType,
      );

      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (!result.isVerified) {
        setState(() => _isSubmitting = false);
        // Show specific failure reason
        final reason = result.failureReason ?? _buildFailureReason(result);
        _showVerificationFailedDialog(reason);
        return;
      }

      // Step 2: Register with auto-approved status
      await AuthService.registerTourGuide(
        fullName: _fullNameCtrl.text,
        age: int.parse(_ageCtrl.text.trim()),
        email: _emailCtrl.text,
        contactNumber: _contactCtrl.text,
        tourGuideId: _tourGuideIdCtrl.text,
        password: _passwordCtrl.text,
        status: 'approved', // Auto-approved via AI verification
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

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
      setState(() {
        _isSubmitting = false;
        _isVerifying = false;
      });
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isVerifying = false;
      });
      _showError('Registration failed. Please try again.');
    }
  }

  String _buildFailureReason(GeminiIdVerificationResult result) {
    final reasons = <String>[];
    if (!result.isOfficialDotId) {
      reasons.add(
          'The uploaded image does not appear to be an official DOT Tour Guide ID.');
    }
    if (result.isExpired) {
      reasons.add(
          'The ID appears to be expired (Expiry: ${result.expiryDate ?? 'unknown'}).');
    }
    if (!result.isImageClear) {
      reasons.add(
          'The uploaded image is unclear, blurry, or cropped. Please upload a clear, complete photo.');
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
              child: const Icon(Icons.gpp_bad_rounded,
                  color: AppColors.error, size: 24),
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
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.15)),
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
                  borderRadius: BorderRadius.circular(12)),
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
        decoration: BoxDecoration(gradient: AppColors.getBackgroundGradient(context)),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        24, 16, 24, bottomInset > 0 ? bottomInset : 32),
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
        Text('Tour Guide ID Photo', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () { _captureIdImage(); Navigator.pop(ctx); }),
                    ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () { _pickIdImage(); Navigator.pop(ctx); }),
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
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: _selectedIdImageBytes != null
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_selectedIdImageBytes!, fit: BoxFit.cover))
                : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: AppColors.primary), Text('Upload ID Photo')]),
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
          // Full Name
          CustomTextField(
            controller: _fullNameCtrl,
            label: AppStrings.fullName,
            hint: AppStrings.fullNameHint,
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
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: _phoneValidator,
          ),
          const SizedBox(height: 18),

          // Tour Guide ID
          CustomTextField(
            controller: _tourGuideIdCtrl,
            label: AppStrings.tourGuideId,
            hint: AppStrings.tourGuideIdHint,
            prefixIcon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 18),

          // DOT Tour Guide ID Photo Upload
          _buildIdPhotoUpload(),
          const SizedBox(height: 18),

          // Password
          CustomTextField(
            controller: _passwordCtrl,
            label: AppStrings.password,
            hint: AppStrings.passwordHint,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: _isSubmitting ? null : AppColors.primaryGradient,
        boxShadow: _isSubmitting
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
        onPressed: _isSubmitting ? null : _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: AppColors.surfaceVariant,
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
                pageBuilder: (_, __, ___) =>
                    const TourGuideLoginScreen(),
                transitionsBuilder: (_, animation, __, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                        parent: animation, curve: Curves.easeIn),
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
