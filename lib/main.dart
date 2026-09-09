import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'core/models/tourist_session.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/sos_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/screens/role_selection_screen.dart';
import 'features/auth/screens/in_app_password_reset_screen.dart';
import 'features/tour_guide/screens/tour_guide_dashboard_screen.dart';
import 'features/tourist/screens/tourist_dashboard_screen.dart';
import 'features/sos/screens/sos_screen.dart';
import 'firebase_options.dart';

/// Global navigator key — used by NotificationService to route
/// on notification tap without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global route observer — screens use this to detect visibility
/// (e.g. pause ring listeners when another screen is pushed on top).
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (API keys) — gracefully skip if missing
  try {
    await dotenv.load(fileName: 'assets/env/.env');
  } catch (_) {
    debugPrint('Warning: .env file not found. AI features will be unavailable.');
  }

  // Initialize Firebase with error handling to prevent white screen on iOS
  bool firebaseReady = false;
  String? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e, stack) {
    firebaseError = e.toString();
    debugPrint('FATAL: Firebase initialization failed: $e');
    debugPrint('$stack');
  }

  // Initialize Firebase Cloud Messaging only if Firebase succeeded
  if (firebaseReady) {
    try {
      await NotificationService.initialize();
    } catch (e, stack) {
      // Non-fatal — app continues without push notifications
      debugPrint('Warning: FCM initialization failed: $e');
      debugPrint('$stack');
    }
  }

  runApp(TourviaApp(
    firebaseReady: firebaseReady,
    firebaseError: firebaseError,
  ));
}

class TourviaApp extends StatefulWidget {
  final bool firebaseReady;
  final String? firebaseError;

  const TourviaApp({
    super.key,
    required this.firebaseReady,
    this.firebaseError,
  });

  @override
  State<TourviaApp> createState() => _TourviaAppState();
}

class _TourviaAppState extends State<TourviaApp> {
  @override
  void initState() {
    super.initState();
    if (widget.firebaseReady) {
      _listenToNotificationTaps();
    }
  }

  /// Routes the user to the correct screen when they tap a push notification.
  void _listenToNotificationTaps() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _routeToScreen(message.data);
    });
  }

  /// Simple router: reads the `type` field in the notification data payload.
  void _routeToScreen(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final sessionId = data['sessionId'] as String? ?? AuthService.currentUser?.uid ?? '';

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    switch (type) {
      case 'sos':
        nav.push(MaterialPageRoute(
          builder: (_) => SosScreen(sessionId: sessionId),
        ));
        break;
      // Additional routes (chat, tracking) can be added here as needed.
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tourvia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      onGenerateRoute: (settings) {
        // Deep link interception for Firebase Auth password reset
        if (settings.name != null && settings.name!.startsWith('/__/auth/action')) {
          final uri = Uri.parse(settings.name!);
          final mode = uri.queryParameters['mode'];
          final oobCode = uri.queryParameters['oobCode'];
          
          if (mode == 'resetPassword' && oobCode != null) {
            return MaterialPageRoute(
              builder: (_) => InAppPasswordResetScreen(oobCode: oobCode),
            );
          }
        }
        return null; // Let Flutter handle other routes normally
      },
      home: widget.firebaseReady
          ? const AuthGate()
          : _FirebaseErrorScreen(error: widget.firebaseError),
      builder: (context, child) {
        // Wrap the whole app in a foreground notification banner listener
        // only when Firebase is available
        if (widget.firebaseReady) {
          return _FcmBannerWrapper(child: child!);
        }
        return child!;
      },
    );
  }
}

/// Shows a user-friendly error screen when Firebase fails to initialize.
/// Provides a retry mechanism so the user can restart the app.
class _FirebaseErrorScreen extends StatelessWidget {
  final String? error;
  const _FirebaseErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 64, color: AppColors.error.withValues(alpha: 0.7)),
                const SizedBox(height: 20),
                const Text(
                  'Unable to Connect',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'TourVia could not connect to the server.\n'
                  'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.error.withValues(alpha: 0.8),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () {
                    // Restart the app by re-running main
                    main();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Automatically redirects to the correct dashboard if the user is already logged in.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSessions();
  }

  Future<void> _checkSessions() async {
    // Check for tourist session first
    try {
      await TouristSessionManager.loadSession();
    } catch (e) {
      debugPrint('Warning: Failed to load tourist session: $e');
    }

    if (TouristSessionManager.isLoggedIn) {
      // Start SOS monitoring for the tourist session
      try {
        SosNotificationService.instance.startFromCurrentSession();
      } catch (e) {
        debugPrint('Warning: Failed to start SOS monitoring: $e');
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TouristDashboardScreen()),
        );
      }
      return;
    }

    // If no tourist session, we just rely on Firebase auth stream for Tour Guides.
    // However, since Firebase Auth takes a moment to initialize the current user,
    // we just stop loading and let the StreamBuilder handle the rest.
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // While waiting for auth stream
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        // If a Firebase user exists, it's a Tour Guide
        if (snapshot.hasData && snapshot.data != null) {
          // Start SOS monitoring for the tour guide session
          SosNotificationService.instance.startWatching(
            sessionId: snapshot.data!.uid,
            currentUserId: snapshot.data!.uid,
          );
          return const TourGuideDashboardScreen();
        }

        // Otherwise, show Role Selection Screen
        return const RoleSelectionScreen();
      },
    );
  }
}

/// Wraps the entire app to show an in-app banner whenever a foreground
/// FCM message arrives.
class _FcmBannerWrapper extends StatefulWidget {
  final Widget child;
  const _FcmBannerWrapper({required this.child});

  @override
  State<_FcmBannerWrapper> createState() => _FcmBannerWrapperState();
}

class _FcmBannerWrapperState extends State<_FcmBannerWrapper> {
  @override
  void initState() {
    super.initState();
    NotificationService.onForegroundMessage.listen(_showBanner);
  }

  void _showBanner(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notification.title != null)
                    Text(
                      notification.title!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  if (notification.body != null)
                    Text(
                      notification.body!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Route based on type
            final nav = navigatorKey.currentState;
            final type = message.data['type'] as String?;
            final sessionId =
                message.data['sessionId'] as String? ?? AuthService.currentUser?.uid ?? '';

            if (nav == null) return;
            if (type == 'sos') {
              nav.push(MaterialPageRoute(
                builder: (_) => SosScreen(sessionId: sessionId),
              ));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
