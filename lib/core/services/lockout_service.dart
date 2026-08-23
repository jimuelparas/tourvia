import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Categories of operations subject to lockout rate limiting.
enum LockoutType {
  guideLogin('lockout_guide_login'),
  touristCode('lockout_tourist_code'),
  guideRegistration('lockout_guide_registration');

  final String keyPrefix;
  const LockoutType(this.keyPrefix);
}

/// Represents the current lockout status for an operation.
class LockoutStatus {
  final bool isLocked;
  final int failedAttempts;
  final int maxAttempts;
  final Duration? remainingTime;

  const LockoutStatus({
    required this.isLocked,
    required this.failedAttempts,
    required this.maxAttempts,
    this.remainingTime,
  });

  /// Number of attempts remaining before a lockout occurs.
  int get remainingAttempts => (maxAttempts - failedAttempts).clamp(0, maxAttempts);

  /// Human-readable time remaining string (e.g., "14:59" or "15 mins").
  String get formattedRemainingTime {
    if (remainingTime == null || remainingTime!.isNegative) return '0:00';
    final minutes = remainingTime!.inMinutes;
    final seconds = remainingTime!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Centralized security service for brute-force rate-limiting and temporary lockouts.
class LockoutService {
  LockoutService._();

  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);

  /// Checks the current lockout status for [type].
  /// If an existing lockout has expired, it automatically resets the counter.
  static Future<LockoutStatus> checkLockout(LockoutType type) async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt('${type.keyPrefix}_attempts') ?? 0;
    final lockoutUntilMillis = prefs.getInt('${type.keyPrefix}_until');

    if (lockoutUntilMillis != null) {
      final lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockoutUntilMillis);
      final now = DateTime.now();

      if (now.isBefore(lockoutUntil)) {
        // Still locked out
        final remaining = lockoutUntil.difference(now);
        return LockoutStatus(
          isLocked: true,
          failedAttempts: attempts,
          maxAttempts: maxAttempts,
          remainingTime: remaining,
        );
      } else {
        // Lockout expired -> automatically reset
        await resetAttempts(type);
        return const LockoutStatus(
          isLocked: false,
          failedAttempts: 0,
          maxAttempts: maxAttempts,
        );
      }
    }

    return LockoutStatus(
      isLocked: false,
      failedAttempts: attempts,
      maxAttempts: maxAttempts,
    );
  }

  /// Records a failed attempt for [type].
  /// If the failure count reaches [maxAttempts], sets a lockout for [lockoutDuration].
  static Future<LockoutStatus> recordFailure(LockoutType type) async {
    final prefs = await SharedPreferences.getInstance();
    final currentAttempts = (prefs.getInt('${type.keyPrefix}_attempts') ?? 0) + 1;
    await prefs.setInt('${type.keyPrefix}_attempts', currentAttempts);

    if (currentAttempts >= maxAttempts) {
      final lockoutUntil = DateTime.now().add(lockoutDuration);
      await prefs.setInt('${type.keyPrefix}_until', lockoutUntil.millisecondsSinceEpoch);

      return LockoutStatus(
        isLocked: true,
        failedAttempts: currentAttempts,
        maxAttempts: maxAttempts,
        remainingTime: lockoutDuration,
      );
    }

    return LockoutStatus(
      isLocked: false,
      failedAttempts: currentAttempts,
      maxAttempts: maxAttempts,
    );
  }

  /// Resets the failure counter and clears any lockout timestamp upon successful action.
  static Future<void> resetAttempts(LockoutType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${type.keyPrefix}_attempts');
    await prefs.remove('${type.keyPrefix}_until');
  }
}
