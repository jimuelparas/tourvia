import 'package:flutter/material.dart';

/// Tourvia color palette — Direction A: Ocean Breeze 🌊
///
/// Light-first, crisp white canvas. Sky-blue primary with
/// navy accents. Clean, professional, travel-app aesthetic.
class AppColors {
  AppColors._();

  // ── Primary (Sky Blue) ───────────────────────────────────
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryActive = Color(0xFF1976D2);
  static const Color primaryDisabled = Color(0xFFBBDEFB);

  // ── Accent ───────────────────────────────────────────────
  static const Color accent = Color(0xFFF59E0B);       // Warm amber
  static const Color accentTeal = Color(0xFF0891B2);    // Deep cyan

  // ── Surfaces (Light-first) ──────────────────────────────
  static const Color background = Color(0xFFF8FAFC);    // Cool off-white
  static const Color surface = Color(0xFFFFFFFF);        // Pure white
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Slate-50
  static const Color canvas = Color(0xFFF8FAFC);         // Same as background

  // ── Dark Surfaces (for dark mode) ───────────────────────
  static const Color surfaceDark = Color(0xFF0F172A);        // Slate-900
  static const Color surfaceDarkSoft = Color(0xFF1E293B);    // Slate-800
  static const Color surfaceDarkElevated = Color(0xFF334155); // Slate-700

  // ── Light Surface Extras ────────────────────────────────
  static const Color surfaceSoft = Color(0xFFE0F2FE);    // Sky-100 (blue tint)
  static const Color surfaceCard = Color(0xFFFFFFFF);    // White cards
  static const Color surfaceCreamStrong = Color(0xFFE2E8F0); // Slate-200

  // ── Borders / Hairlines ─────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);        // Slate-200
  static const Color borderFocused = Color(0xFF2196F3);  // Primary blue
  static const Color hairline = Color(0xFFF1F5F9);       // Slate-50
  static const Color hairlineSoft = Color(0xFFF8FAFC);

  // ── Text (Light mode — default) ─────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);    // Slate-900
  static const Color textSecondary = Color(0xFF64748B);  // Slate-500
  static const Color textHint = Color(0xFF94A3B8);       // Slate-400
  static const Color textOnPrimary = Color(0xFFFFFFFF);  // White

  // ── Text (Dark mode) ────────────────────────────────────
  static const Color ink = Color(0xFF0F172A);
  static const Color bodyColor = Color(0xFF475569);      // Slate-600
  static const Color bodyStrong = Color(0xFF1E293B);     // Slate-800
  static const Color muted = Color(0xFF64748B);          // Slate-500
  static const Color mutedSoft = Color(0xFF94A3B8);      // Slate-400

  // ── Semantic ─────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);        // Emerald-500
  static const Color error = Color(0xFFEF4444);          // Red-500
  static const Color errorLight = Color(0x33EF4444);
  static const Color warning = Color(0xFFF59E0B);        // Amber-500
  static const Color info = Color(0xFF0891B2);           // Cyan-600

  // ── Primary Surface (icon bg tint) ──────────────────────
  static const Color primarySurface = Color(0xFFE0F2FE); // Sky-100

  // ── Gradients ───────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8FAFC), Color(0xFFE0F2FE)],
  );

  static LinearGradient getBackgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFE0F2FE)],
          );
  }

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF0891B2)],
  );
}
