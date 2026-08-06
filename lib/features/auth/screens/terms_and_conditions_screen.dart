import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// Terms and Conditions Acceptance Screen (US-05).
///
/// Displays the terms and conditions of the Tourvia application.
/// Users must explicitly check "I Agree" to proceed.
class TermsAndConditionsScreen extends StatefulWidget {
  final VoidCallback? onAccepted;
  final bool isReadOnly;

  const TermsAndConditionsScreen({super.key, this.onAccepted, this.isReadOnly = false});

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen>
    with SingleTickerProviderStateMixin {
  bool _hasAgreed = false;

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _onAccept() {
    if (_hasAgreed && widget.onAccepted != null) {
      widget.onAccepted!();
    }
  }

  void _onDecline() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text(AppStrings.termsDeclinedMessage)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
    // Pop back to login or previous screen if declined
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.termsTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: _onDecline,
        ),
      ),
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Content Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtitle
                      Text(
                        AppStrings.termsSubtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Terms Text Box
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          AppStrings.termsContent,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                height: 1.6,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Area
              if (!widget.isReadOnly)
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Checkbox
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _hasAgreed = !_hasAgreed;
                          });
                        },
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _hasAgreed,
                                onChanged: (val) {
                                  setState(() {
                                    _hasAgreed = val ?? false;
                                  });
                                },
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppStrings.agreeToTerms,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: _hasAgreed
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextButton(
                              onPressed: _onDecline,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(AppStrings.declineButton),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _hasAgreed ? _onAccept : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                disabledBackgroundColor: AppColors.surfaceVariant,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: _hasAgreed ? 2 : 0,
                              ),
                              child: const Text(AppStrings.acceptButton),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
