import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/custom_text_field.dart';
import 'tour_guide_login_screen.dart';

/// Forgot-password screen (US-03 — Step 1).
///
/// Collects the tour guide's registered email address and
/// simulates sending a password-reset link. Transitions to
/// a confirmation state with an option to proceed to the
/// [ResetPasswordScreen] for demo purposes.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _emailSent = false;

  // ── Animations ──────────────────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  // Confirmation state animations
  late final AnimationController _confirmFadeController;
  late final Animation<double> _confirmFadeAnimation;
  late final AnimationController _pulseController;

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

    _confirmFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _confirmFadeAnimation = CurvedAnimation(
      parent: _confirmFadeController,
      curve: Curves.easeOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _confirmFadeController.dispose();
    _pulseController.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    final emailRegex = RegExp(r'^[\w\-.+]+@[\w\-]+\.[\w\-.]+$');
    if (!emailRegex.hasMatch(value.trim())) return AppStrings.invalidEmail;
    return null;
  }

  // ── Submit ──────────────────────────────────────────────

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await AuthService.sendPasswordResetEmail(_emailCtrl.text);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _emailSent = true;
      });
      _confirmFadeController.forward();
      _pulseController.repeat();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send reset email. Check if the email is correct.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onResendEmail() async {
    setState(() => _isSubmitting = true);
    try {
      await AuthService.sendPasswordResetEmail(_emailCtrl.text);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('Reset link resent! Check your inbox.')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to resend. Please wait a moment and try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _navigateBackToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const TourGuideLoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
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
                      24,
                      40,
                      24,
                      bottomInset > 0 ? bottomInset : 32,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        _emailSent
                            ? _buildConfirmationContent()
                            : _buildFormContent(),
                      ),
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

  // ── Form Content (Step 1) ──────────────────────────────

  List<Widget> _buildFormContent() {
    return [
      _buildBackArrow(),
      const SizedBox(height: 20),
      _buildHeader(),
      const SizedBox(height: 40),
      _buildForm(),
      const SizedBox(height: 32),
      _buildSubmitButton(),
      const SizedBox(height: 24),
      _buildBackToLoginLink(),
    ];
  }

  // ── Confirmation Content (Step 2) ──────────────────────

  List<Widget> _buildConfirmationContent() {
    return [
      const SizedBox(height: 60),
      _buildEmailSentIcon(),
      const SizedBox(height: 40),
      FadeTransition(
        opacity: _confirmFadeAnimation,
        child: Column(
          children: [
            Text(
              AppStrings.emailSentTitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.emailSentSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            // Show which email was used
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _emailCtrl.text.trim(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaryActive,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Steps instruction card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to reset your password:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryActive,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStep('1', 'Open the email we sent to your inbox'),
                  const SizedBox(height: 8),
                  _buildStep('2', 'Click the password reset link'),
                  const SizedBox(height: 8),
                  _buildStep('3', 'Set your new password in the browser'),
                  const SizedBox(height: 8),
                  _buildStep('4', 'Return here and log in with your new password'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Info note
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      AppStrings.emailSentNote,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.warning,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Back to Login primary button
            _buildPrimaryButton(
              label: AppStrings.backToLoginLink,
              icon: Icons.login_rounded,
              onPressed: _navigateBackToLogin,
            ),
            const SizedBox(height: 16),
            // Resend Email outline button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _onResendEmail,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  foregroundColor: AppColors.primary,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                label: Text(
                  _isSubmitting ? 'Sending…' : AppStrings.resendEmail,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ── Back Arrow ──────────────────────────────────────────

  Widget _buildBackArrow() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 22,
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
        // Icon
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
            Icons.lock_reset_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppStrings.forgotPasswordTitle,
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.forgotPasswordSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  // ── Email Sent Icon ─────────────────────────────────────

  Widget _buildEmailSentIcon() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseValue =
              math.sin(_pulseController.value * math.pi * 2) * 0.5 + 0.5;
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: 0.2 + 0.15 * pulseValue,
                  ),
                  blurRadius: 24 + 12 * pulseValue,
                  spreadRadius: 4 * pulseValue,
                ),
              ],
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: Colors.white,
              size: 56,
            ),
          );
        },
      ),
    );
  }

  // ── Form ────────────────────────────────────────────────

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: CustomTextField(
        controller: _emailCtrl,
        label: AppStrings.emailLabel,
        hint: AppStrings.emailHintForgot,
        prefixIcon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        validator: _emailValidator,
        onFieldSubmitted: (_) => _onSubmit(),
      ),
    );
  }

  // ── Submit Button ───────────────────────────────────────

  Widget _buildSubmitButton() {
    return _buildPrimaryButton(
      label: AppStrings.sendResetLink,
      icon: Icons.send_rounded,
      onPressed: _onSubmit,
      isLoading: _isSubmitting,
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: isLoading ? null : AppColors.primaryGradient,
        boxShadow: isLoading
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
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: AppColors.surfaceVariant,
          shadowColor: Colors.transparent,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: 10),
                  Text(label),
                ],
              ),
      ),
    );
  }

  // ── Back to Login ──────────────────────────────────────

  Widget _buildBackToLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.rememberPassword,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Text(
            AppStrings.backToLoginLink,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ── Step Builder ─────────────────────────────────────────

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 2, right: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.primaryActive,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
