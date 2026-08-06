import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import 'tour_guide_login_screen.dart';
import 'tourist_login_screen.dart';

/// Welcome / Role Selection screen (User Roles Module).
///
/// The very first screen users see when opening the app.
/// Allows them to choose between the **Tour Guide** or
/// **Tourist** role, routing them to the appropriate login flow.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  // ── Animations ──────────────────────────────────────────
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;

  late final AnimationController _contentController;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  late final AnimationController _cardsController;
  late final Animation<double> _cardsFade;
  late final Animation<Offset> _cardsSlide;

  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    // Logo bounce-in
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );

    // Title + subtitle fade-in
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(_contentFade);

    // Role cards slide-in
    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardsFade = CurvedAnimation(
      parent: _cardsController,
      curve: Curves.easeOut,
    );
    _cardsSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_cardsFade);

    // Subtle shimmer for the logo glow
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Stagger entrance animations
    _logoController.forward().then((_) {
      _contentController.forward().then((_) {
        _cardsController.forward();
      });
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    _cardsController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────

  void _onTourGuideSelected() {
    Navigator.of(context).push(
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
    );
  }

  void _onTouristSelected() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const TouristLoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppColors.getBackgroundGradient(context)),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 60),
                _buildLogo(),
                const SizedBox(height: 36),
                _buildTitleSection(),
                const SizedBox(height: 48),
                _buildRoleCards(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo ────────────────────────────────────────────────

  Widget _buildLogo() {
    return ScaleTransition(
      scale: _logoScale,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          final pulseValue =
              math.sin(_shimmerController.value * math.pi * 2) * 0.5 + 0.5;
          return Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: 0.15 + 0.08 * pulseValue,
                  ),
                  blurRadius: 20 + 8 * pulseValue,
                  offset: const Offset(0, 4),
                  spreadRadius: 1 * pulseValue,
                ),
              ],
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: Colors.white,
              size: 50,
            ),
          );
        },
      ),
    );
  }

  // ── Title Section ──────────────────────────────────────

  Widget _buildTitleSection() {
    return FadeTransition(
      opacity: _contentFade,
      child: SlideTransition(
        position: _contentSlide,
        child: Column(
          children: [
            Text(
              AppStrings.welcomeTitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.welcomeSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.6, fontSize: 15),
            ),
            const SizedBox(height: 32),
            // Divider with label
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.border.withValues(alpha: 0),
                          AppColors.border,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    AppStrings.selectRole,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.border,
                          AppColors.border.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Role Cards ─────────────────────────────────────────

  Widget _buildRoleCards() {
    return FadeTransition(
      opacity: _cardsFade,
      child: SlideTransition(
        position: _cardsSlide,
        child: Column(
          children: [
            _RoleCard(
              icon: Icons.badge_rounded,
              title: AppStrings.tourGuideRole,
              description: AppStrings.tourGuideRoleDesc,
              gradient: AppColors.primaryGradient,
              shadowColor: AppColors.primary,
              onTap: _onTourGuideSelected,
            ),
            const SizedBox(height: 20),
            _RoleCard(
              icon: Icons.hiking_rounded,
              title: AppStrings.touristRole,
              description: AppStrings.touristRoleDesc,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
              ),
              shadowColor: const Color(0xFFF59E0B),
              onTap: _onTouristSelected,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Role Card Widget ────────────────────────────────────

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.shadowColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final LinearGradient gradient;
  final Color shadowColor;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverController;
  late final Animation<double> _hoverScale;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _hoverScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _hoverController.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _hoverController.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _hoverController.reverse();
      },
      child: ScaleTransition(
        scale: _hoverScale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isPressed
                  ? widget.shadowColor.withValues(alpha: 0.4)
                  : AppColors.border,
              width: _isPressed ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? widget.shadowColor.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: _isPressed ? 12 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.shadowColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 18),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Arrow
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.shadowColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: widget.shadowColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
