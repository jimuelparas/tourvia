import 'package:flutter/material.dart';

/// Tourvia color palette — a clean light‐blue & white scheme
/// as defined in the project design document (§ 4.3.1).
///   Primary : #00A9E0   (trust, safety, reliability)
///   Surface : #FFFFFF   (clean, minimal background)
///   Text    : #000000 / #808080
class AppColors {
  AppColors._();

  // ── Primary ──────────────────────────────────────────────
  static const Color primary = Color(0xFF00A9E0);
  static const Color primaryLight = Color(0xFF80D4F0);
  static const Color primaryDark = Color(0xFF007BAD);
  static const Color primarySurface = Color(0xFFE0F4FB);

  // ── Secondary / Accent ──────────────────────────────────
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFDE68A);

  // ── Neutrals ────────────────────────────────────────────
  static const Color background = Color(0xFFF6FBFE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocused = Color(0xFF00A9E0);

  // ── Text ────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Semantic ────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Gradients ───────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00A9E0), Color(0xFF0077B6)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE0F4FB), Color(0xFFF6FBFE)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF00A9E0)],
  );
}
