import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../tour_guide/screens/tour_guide_dashboard_screen.dart';
import '../widgets/custom_text_field.dart';
import 'forgot_password_screen.dart';
import 'tour_guide_registration_screen.dart';

/// Tour Guide login screen (US-02).
///
/// Collects username and password. Provides:
/// - Inline validation (required fields).
/// - Status-aware error banners for pending / rejected accounts.
/// - Navigation to the registration and forgot-password flows.
class TourGuideLoginScreen extends StatefulWidget {
  const TourGuideLoginScreen({super.key});

  @override
  State<TourGuideLoginScreen> createState() => _TourGuideLoginScreenState();
}

class _TourGuideLoginScreenState extends State<TourGuideLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ─────────────────────────────────────────
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  /// Holds a general (non-field) error message from the login attempt.
  String? _loginError;

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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    return null;
  }

  // ── Submit ──────────────────────────────────────────────

  Future<void> _onSubmit() async {
    setState(() => _loginError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await AuthService.loginTourGuide(
        email: _usernameCtrl.text,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSuccessAndNavigate();
    } on AuthException catch (e) {
      if (!mounted) return;
      _setLoginError(e.message);
    } catch (e) {
      if (!mounted) return;
      _setLoginError(AppStrings.invalidCredentials);
    }
  }

  void _setLoginError(String message) {
    setState(() {
      _isSubmitting = false;
      _loginError = message;
    });
  }

  void _showSuccessAndNavigate() {
    // Save FCM token so the server can send push notifications to this guide
    final uid = AuthService.currentUser?.uid;
    if (uid != null) {
      NotificationService.saveTokenForUser(uid);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(AppStrings.loginSuccess),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    // Navigate to Dashboard and clear stack
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const TourGuideDashboardScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
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
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
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
                      delegate: SliverChildListDelegate([
                        _buildHeader(),
                        const SizedBox(height: 40),
                        if (_loginError != null) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 20),
                        ],
                        _buildForm(),
                        const SizedBox(height: 12),
                        _buildForgotPassword(),
                        const SizedBox(height: 32),
                        _buildSubmitButton(),
                        const SizedBox(height: 24),
                        _buildRegisterLink(),
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
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
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
          AppStrings.loginTitle,
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.loginSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  // ── Error Banner ────────────────────────────────────────

  Widget _buildErrorBanner() {
    // Determine icon and colour based on message type
    final bool isPending = _loginError == AppStrings.accountPending;
    final bool isRejected = _loginError == AppStrings.accountRejected;

    final Color bannerColor = isPending
        ? AppColors.warning
        : isRejected
        ? AppColors.error
        : AppColors.error;
    final Color bannerBg = isPending
        ? const Color(0xFFFFF8E1)
        : const Color(0xFFFEE2E2);
    final IconData bannerIcon = isPending
        ? Icons.hourglass_top_rounded
        : isRejected
        ? Icons.block_rounded
        : Icons.error_outline_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(bannerIcon, color: bannerColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _loginError!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: bannerColor == AppColors.warning
                    ? const Color(0xFF92400E)
                    : AppColors.error,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _loginError = null),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: bannerColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form ────────────────────────────────────────────────

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Username
          CustomTextField(
            controller: _usernameCtrl,
            label: AppStrings.username,
            hint: AppStrings.usernameHint,
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 18),

          // Password
          CustomTextField(
            controller: _passwordCtrl,
            label: AppStrings.password,
            hint: AppStrings.passwordHint,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            validator: _requiredValidator,
            onFieldSubmitted: (_) => _onSubmit(),
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
        ],
      ),
    );
  }

  // ── Forgot Password ────────────────────────────────────

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const ForgotPasswordScreen(),
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
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          AppStrings.forgotPassword,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Submit Button ───────────────────────────────────────

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: _isSubmitting ? null : AppColors.primaryGradient,
        boxShadow: _isSubmitting
            ? []
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
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
                children: const [
                  Icon(Icons.login_rounded, size: 22),
                  SizedBox(width: 10),
                  Text(AppStrings.loginButton),
                ],
              ),
      ),
    );
  }

  // ── Register Link ──────────────────────────────────────

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.noAccount,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) =>
                    const TourGuideRegistrationScreen(),
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
            AppStrings.register,
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
