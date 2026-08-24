import 'dart:async';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../features/sos/screens/sos_screen.dart';
import '../theme/app_colors.dart';
import '../models/tourist_session.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/sos_service.dart';

/// App-level singleton that manages SOS alert monitoring, ringing, and
/// notification lifecycle independently of any screen.
///
/// This ensures:
/// - Ringing persists when the app is minimized or screens are popped
/// - Ringing stops ONLY when the Tour Guide resolves all active alerts
/// - Both Tour Guide and Tourist devices stay in sync via Firestore
class SosNotificationService {
  SosNotificationService._();

  static final SosNotificationService _instance = SosNotificationService._();
  static SosNotificationService get instance => _instance;

  StreamSubscription<List<SosAlert>>? _subscription;
  String? _currentSessionId;
  String? _currentUserId;

  /// Track alerts for which we have already displayed a popup dialog
  final Set<String> _shownAlertIds = {};

  /// Broadcast stream so UI widgets can react to SOS state changes
  /// (e.g. blinking module card) without managing their own Firestore
  /// subscriptions.
  final StreamController<List<SosAlert>> _alertsController =
      StreamController<List<SosAlert>>.broadcast();

  /// Stream of active (unresolved) SOS alerts for the current session.
  Stream<List<SosAlert>> get activeAlertsStream => _alertsController.stream;

  /// The most recently emitted list of active alerts.
  List<SosAlert> _currentAlerts = [];
  List<SosAlert> get currentAlerts => _currentAlerts;

  /// Starts watching SOS alerts for the given [sessionId].
  ///
  /// [currentUserId] is used to distinguish incoming alerts (from others)
  /// from self-sent alerts — only incoming alerts trigger the ring.
  ///
  /// Safe to call multiple times — will no-op if already watching the
  /// same session, or will restart if the session changes.
  void startWatching({
    required String sessionId,
    required String currentUserId,
  }) {
    if (sessionId.isEmpty) return;

    // Already watching this exact session
    if (_currentSessionId == sessionId && _currentUserId == currentUserId) {
      return;
    }

    // Stop any existing watcher first
    stopWatching();

    _currentSessionId = sessionId;
    _currentUserId = currentUserId;

    debugPrint('[SosNotificationService] Watching session: $sessionId (user: $currentUserId)');

    _subscription = SosService.watchActiveAlerts(sessionId).listen(
      (alerts) {
        _currentAlerts = alerts;
        _alertsController.add(alerts);

        // Filter to only incoming alerts (from other users)
        final incomingAlerts =
            alerts.where((a) => a.senderId != _currentUserId).toList();

        if (incomingAlerts.isNotEmpty) {
          // Start/continue emergency ring for incoming alerts
          LocationService.startEmergencyRing();

          // Check if there are any new alerts we haven't notified about yet
          for (final alert in incomingAlerts) {
            if (!_shownAlertIds.contains(alert.id)) {
              _shownAlertIds.add(alert.id);
              // Trigger the in-app notification popup immediately
              _showNotificationDialog(alert);
            }
          }
        } else {
          // No incoming active alerts → stop ringing
          // This covers: guide resolved, or no alerts at all
          LocationService.stopEmergencyRing();
          _shownAlertIds.clear();
        }
      },
      onError: (e) {
        debugPrint('[SosNotificationService] Error watching alerts: $e');
      },
    );
  }

  /// Displays a highly visible in-app emergency dialog immediately
  /// on top of whatever screen the user is currently viewing.
  void _showNotificationDialog(SosAlert alert) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Force interaction to dismiss or resolve
      builder: (ctx) {
        final isGuide = !TouristSessionManager.isLoggedIn;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              SizedBox(width: 10),
              Text(
                'EMERGENCY SOS',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${alert.senderName} has triggered an emergency alert!',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'An alarm is ringing on your device. Please assist them immediately.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            if (isGuide)
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await SosService.resolveAlert(
                    sessionId: _currentSessionId ?? '',
                    alertId: alert.id,
                  );
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Resolve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                final nav = navigatorKey.currentState;
                if (nav != null) {
                  nav.push(MaterialPageRoute(
                    builder: (_) => SosScreen(sessionId: _currentSessionId ?? ''),
                  ));
                }
              },
              icon: const Icon(Icons.map_rounded, size: 16),
              label: const Text('View Alert Logs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Stops watching SOS alerts. Does NOT stop ringing — ringing is
  /// controlled purely by Firestore state and will resume when
  /// `startWatching` is called again if alerts are still active.
  void stopWatching() {
    _subscription?.cancel();
    _subscription = null;
    _currentSessionId = null;
    _currentUserId = null;
    _currentAlerts = [];
    _shownAlertIds.clear();
  }

  /// Call when the user logs out. Stops watching AND stops ringing.
  void onLogout() {
    stopWatching();
    LocationService.stopEmergencyRing();
    _currentAlerts = [];
    _alertsController.add([]);
  }

  /// Convenience: determines the session ID and user ID from the current
  /// auth state and starts watching automatically.
  void startFromCurrentSession() {
    final isTourist = TouristSessionManager.isLoggedIn;

    if (isTourist) {
      final session = TouristSessionManager.current;
      if (session != null) {
        startWatching(
          sessionId: session.sessionId,
          currentUserId: session.codeDocId,
        );
      }
    } else {
      final user = AuthService.currentUser;
      if (user != null) {
        startWatching(
          sessionId: user.uid,
          currentUserId: user.uid,
        );
      }
    }
  }

  /// Dispose the service (called on app shutdown).
  void dispose() {
    stopWatching();
    _alertsController.close();
  }
}
