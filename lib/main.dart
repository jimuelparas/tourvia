import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/role_selection_screen.dart';
import 'features/sos/screens/sos_screen.dart';
import 'firebase_options.dart';

/// Global navigator key — used by NotificationService to route
/// on notification tap without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (API keys)
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Cloud Messaging
  await NotificationService.initialize();

  runApp(const TourviaApp());
}

class TourviaApp extends StatefulWidget {
  const TourviaApp({super.key});

  @override
  State<TourviaApp> createState() => _TourviaAppState();
}

class _TourviaAppState extends State<TourviaApp> {
  @override
  void initState() {
    super.initState();
    _listenToNotificationTaps();
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
    final sessionId = data['sessionId'] as String? ?? 'demo-session-001';

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
      navigatorKey: navigatorKey,
      home: const RoleSelectionScreen(),
      builder: (context, child) {
        // Wrap the whole app in a foreground notification banner listener
        return _FcmBannerWrapper(child: child!);
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
        backgroundColor: const Color(0xFF00A9E0),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Route based on type
            final nav = navigatorKey.currentState;
            final type = message.data['type'] as String?;
            final sessionId =
                message.data['sessionId'] as String? ?? 'demo-session-001';

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
