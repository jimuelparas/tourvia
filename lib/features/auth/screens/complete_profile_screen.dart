import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/gemini_vision_service.dart';
import '../../../core/services/lockout_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../tour_guide/screens/tour_guide_dashboard_screen.dart';
import '../widgets/custom_text_field.dart';

/// [NEW] Complete Profile Screen — REV-001 Steps 12, 13, 14, 15, 16.
///
/// Shown immediately after a first-time Google Sign-In.
/// Dashboard access is strictly prevented until this form is fully completed
/// and the uploaded ID has been verified by Gemini AI.
///
/// Flow: Google Sign-Up → Authenticate → [THIS SCREEN] → Save Profile → Dashboard
class CompleteProfileScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String photoUrl;

  const CompleteProfileScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.photoUrl,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ─────────────────────────────────────────
  late final TextEditingController _firstNameCtrl;
  final _middleNameCtrl = TextEditingController();
  late final TextEditingController _lastNameCtrl;
  final _contactCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  // Birthday state — Steps 1-4
  DateTime? _selectedBirthday;
  int? _calculatedAge;

  // ID Type — Step 8
  String? _selectedIdType;

  // ID Photo — Step 7
  XFile? _selectedIdImage;
  Uint8List? _selectedIdImageBytes;

  bool _isSubmitting = false;
  bool _isVerifying = false;
  String? _submitError;

  LockoutStatus? _lockoutStatus;
  Timer? _lockoutTimer;

  // ── Animations ──────────────────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.firstName);
    _lastNameCtrl = TextEditingController(text: widget.lastName);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _checkLockout();
  }

  Future<void> _checkLockout() async {
    final status =
        await LockoutService.checkLockout(LockoutType.guideRegistration);
    if (!mounted) return;
    setState(() => _lockoutStatus = status);
    if (status.isLocked) _startLockoutCountdown();
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      final status =
          await LockoutService.checkLockout(LockoutType.guideRegistration);
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _lockoutStatus = status);
      if (!status.isLocked) timer.cancel();
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _fadeController.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    return null;
  }

  // Step 17: Granular Philippine phone validator
  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.phoneRequired;
    final raw = value.trim();
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(raw)) {
      return AppStrings.phoneInvalidChars;
    }
    String digits = raw;
    if (digits.startsWith('+63')) {
      digits = '0${digits.substring(3)}';
    }
    if (!digits.startsWith('09') && !raw.startsWith('+639')) {
      return AppStrings.phoneInvalidPrefix;
    }
    final normalizedLen = digits.length;
    if (normalizedLen < 11) return AppStrings.phoneTooShort;
    if (normalizedLen > 11) return AppStrings.phoneTooLong;
    return null;
  }

  // Step 2: Auto age calculation
  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  // ── Image Picker ────────────────────────────────────────

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

  // ── Submit ──────────────────────────────────────────────

  Future<void> _onSubmit() async {
    setState(() => _submitError = null);

    // Step 4: Birthday validation
    if (_selectedBirthday == null) {
      setState(() => _submitError = AppStrings.birthdayRequired);
      return;
    }
    if ((_calculatedAge ?? 0) < 18) {
      setState(() => _submitError = AppStrings.ageTooYoung);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final lockoutStatus =
        await LockoutService.checkLockout(LockoutType.guideRegistration);
    if (lockoutStatus.isLocked) {
      setState(() => _lockoutStatus = lockoutStatus);
      _startLockoutCountdown();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isVerifying = _selectedIdImageBytes != null;
    });

    try {
      // If ID photo is provided, verify with Gemini AI
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
          final failStatus = await LockoutService.recordFailure(
              LockoutType.guideRegistration);
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
            _lockoutStatus = failStatus;
            _submitError = result.failureReason ??
                'ID verification failed. Please try again with a clear photo.';
          });
          if (failStatus.isLocked) _startLockoutCountdown();
          return;
        }
      }

      // Save complete profile — sets isProfileComplete: true
      await AuthService.completeGoogleProfile(
        uid: widget.uid,
        firstName: _firstNameCtrl.text,
        middleName: _middleNameCtrl.text,
        lastName: _lastNameCtrl.text,
        age: _calculatedAge!,
        birthDate: _selectedBirthday!,
        email: widget.email,
        contactNumber: _contactCtrl.text,
        address: _addressCtrl.text,
        username: _usernameCtrl.text,
        idType: _selectedIdType ?? '',
        photoUrl: widget.photoUrl.isNotEmpty ? widget.photoUrl : null,
      );

      if (!mounted) return;
      await LockoutService.resetAttempts(LockoutType.guideRegistration);
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Step 12/16: Unlock Dashboard
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const TourGuideDashboardScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isVerifying = false;
        _submitError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isVerifying = false;
        _submitError = 'Something went wrong. Please try again.';
      });
    }
  }

  // Step 15: Cancel / Sign Out — clears Firebase Auth session
  Future<void> _onCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Cancel Registration?'),
        content: const Text(
          'Your Google account will be signed out and no profile will be saved. '
          'You can sign in again at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.signOutGoogle();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Step 14: Route guard — cannot be dismissed via hardware back
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onCancel();
      },
      child: Scaffold(
        body: Container(
          decoration:
              BoxDecoration(gradient: AppColors.getBackgroundGradient(context)),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      MediaQuery.of(context).viewInsets.bottom > 0
                          ? MediaQuery.of(context).viewInsets.bottom
                          : 32,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeader(),
                        const SizedBox(height: 8),
                        _buildGoogleInfoBanner(),
                        const SizedBox(height: 24),
                        if (_submitError != null) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 16),
                        ],
                        _buildForm(),
                        const SizedBox(height: 28),
                        _buildSubmitButton(),
                        const SizedBox(height: 16),
                        _buildCancelButton(),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.photoUrl.isNotEmpty)
          CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(widget.photoUrl),
            onBackgroundImageError: (_, __) {},
          )
        else
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 30),
          ),
        const SizedBox(height: 16),
        Text(
          AppStrings.completeProfileTitle,
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.completeProfileSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildGoogleInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.completeProfileNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _submitError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                    height: 1.4,
                  ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _submitError = null),
            child: Icon(Icons.close_rounded,
                size: 16, color: AppColors.error.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          CustomTextField(
            controller: _firstNameCtrl,
            label: AppStrings.firstName,
            hint: AppStrings.firstNameHint,
            helperText: 'Pre-filled from Google — you may edit',
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 18),

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

          CustomTextField(
            controller: _lastNameCtrl,
            label: AppStrings.lastName,
            hint: AppStrings.lastNameHint,
            helperText: 'Pre-filled from Google — you may edit',
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 18),

          _buildReadOnlyField(
            label: AppStrings.email,
            value: widget.email,
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: 18),

          _buildBirthdayPicker(),
          const SizedBox(height: 18),

          if (_calculatedAge != null) ...[
            _buildAgeBadge(),
            const SizedBox(height: 18),
          ],

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

          CustomTextField(
            controller: _usernameCtrl,
            label: AppStrings.username,
            hint: AppStrings.usernameHint,
            helperText: 'Create a unique username for TourVia',
            prefixIcon: Icons.alternate_email_rounded,
            textInputAction: TextInputAction.done,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 18),

          _buildIdTypeDropdown(),
          const SizedBox(height: 18),

          _buildIdPhotoUpload(),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              const Icon(Icons.lock_outline_rounded,
                  color: AppColors.textSecondary, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBirthdayPicker() {
    final maxDate = DateTime(
      DateTime.now().year - 18,
      DateTime.now().month,
      DateTime.now().day,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.birthday,
            style: Theme.of(context).textTheme.labelMedium),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          Expanded(
            child: Text(
              isUnder18
                  ? '${AppStrings.calculatedAge}: $_calculatedAge ${AppStrings.ageDisplay} — ${AppStrings.ageTooYoung}'
                  : '${AppStrings.calculatedAge}: $_calculatedAge ${AppStrings.ageDisplay}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUnder18 ? AppColors.error : AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.idTypeLabel,
            style: Theme.of(context).textTheme.labelMedium),
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

  Widget _buildIdPhotoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.idPhotoLabel,
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          'Upload a clear, complete photo of your selected ID.',
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
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedIdImageBytes != null
                    ? AppColors.success.withValues(alpha: 0.5)
                    : AppColors.primary.withValues(alpha: 0.3),
                width: _selectedIdImageBytes != null ? 2 : 1,
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
                          color: AppColors.primary.withValues(alpha: 0.7),
                          size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload your ID photo',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Optional for identity verification',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isLocked = _lockoutStatus?.isLocked ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient:
            (_isSubmitting || isLocked) ? null : AppColors.primaryGradient,
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
                      'Verifying ID...',
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
                      Text(AppStrings.saveProfileButton),
                    ],
                  ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Center(
      child: TextButton(
        onPressed: _isSubmitting ? null : _onCancel,
        child: Text(
          'Cancel & Sign Out',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
