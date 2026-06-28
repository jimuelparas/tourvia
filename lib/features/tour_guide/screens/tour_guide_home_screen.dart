import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/tour_session_service.dart';
import '../../../core/services/attendance_service.dart';
import '../../../core/services/sos_service.dart';
import 'tour_guide_attendance_screen.dart';
import 'tour_guide_itinerary_screen.dart';
import '../../chat/screens/group_chat_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../weather/screens/weather_screen.dart';
import '../../sos/screens/sos_screen.dart';
import '../../tracking/screens/tour_guide_map_screen.dart';
import '../../chatbot/screens/chatbot_screen.dart';
import 'tour_guide_access_log_screen.dart';

/// The Home screen for the Tour Guide (US-06).
///
/// Features a Grid-based navigation to all tour modules.
class TourGuideHomeScreen extends StatefulWidget {
  const TourGuideHomeScreen({super.key});

  @override
  State<TourGuideHomeScreen> createState() => _TourGuideHomeScreenState();
}

class _TourGuideHomeScreenState extends State<TourGuideHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  // SOS live monitoring
  StreamSubscription<List<SosAlert>>? _sosSubscription;
  List<SosAlert> _activeAlerts = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    // Dynamically update the guide info in the active session document
    final guide = AuthService.currentUser;
    if (guide != null) {
      TourSessionService.updateGuideInfo(
        'demo-session-001',
        guide.uid,
        guide.displayName ?? 'Guide',
      );
    }

    // Listen for live SOS alerts from tourists
    _sosSubscription = SosService.watchActiveAlerts('demo-session-001')
        .listen((alerts) {
      if (!mounted) return;
      final prevCount = _activeAlerts.length;
      setState(() => _activeAlerts = alerts);
      // Show snackbar when a new SOS arrives
      if (alerts.length > prevCount && prevCount >= 0) {
        final newest = alerts.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.emergency_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🚨 SOS from ${newest.senderName}!',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SosScreen(
                      sessionId: 'demo-session-001'),
                ),
              ),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _sosSubscription?.cancel();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                // Live SOS alert banner — shows only when there are active alerts
                if (_activeAlerts.isNotEmpty) ...[  
                  _buildSosAlertBanner(),
                  const SizedBox(height: 16),
                ],
                _buildActiveTourBanner(),
                Text(
                  'Quick Modules',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── SOS Alert Banner (shows when tourists send SOS) ─────────
  Widget _buildSosAlertBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SosScreen(sessionId: 'demo-session-001'),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚨 ${_activeAlerts.length} Active SOS Alert${_activeAlerts.length > 1 ? 's' : ''}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _activeAlerts.length == 1
                        ? '${_activeAlerts.first.senderName} needs help! Tap to respond.'
                        : '${_activeAlerts.map((a) => a.senderName).join(', ')} need help!',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Open map at SOS location
            if (_activeAlerts.first.lat != 0.0)
              IconButton(
                tooltip: 'Open location in Maps',
                icon: const Icon(Icons.map_rounded,
                    color: Colors.white, size: 22),
                onPressed: () async {
                  final a = _activeAlerts.first;
                  final url =
                      'https://www.google.com/maps/search/?api=1&query=${a.lat},${a.lng}';
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {

    final guideName = AuthService.currentUser?.displayName ?? 'Guide';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome $guideName!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textHint,
                  ),
            ),
            Text(
              'Tour Management',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
            ),
          ],
        ),
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          borderRadius: BorderRadius.circular(24),
          child: const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primarySurface,
            child: Icon(Icons.person_rounded, color: AppColors.primary),
          ),
        ),
      ],
    );
  }


  Widget _buildActiveTourBanner() {
    return StreamBuilder<TourSession>(
      stream: TourSessionService.watchSession('demo-session-001'),
      builder: (context, sessionSnapshot) {
        final session = sessionSnapshot.data;
        final tourName = session?.tourName ?? 'Unnamed Tour';
        final dayStr = session != null
            ? 'Day ${session.currentDay} of ${session.totalDays}'
            : 'Day 1 of 3';

        return StreamBuilder<List<TouristRecord>>(
          stream: AttendanceService.watchRoster('demo-session-001'),
          builder: (context, rosterSnapshot) {
            final touristCount = rosterSnapshot.data?.length ?? 0;
            final countStr =
                '$touristCount ${touristCount == 1 ? 'tourist' : 'tourists'}';

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TourGuideItineraryScreen(
                    sessionId: 'demo-session-001',
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A9E0), Color(0xFF0077B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00A9E0).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Tour',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tourName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$countStr • $dayStr',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildModuleCard(
          'Itinerary',
          Icons.map_rounded,
          const Color(0xFF0EA5E9),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TourGuideItineraryScreen(
                sessionId: 'demo-session-001',
              ),
            ),
          ),
        ),
        _buildModuleCard(
          'Attendance',
          Icons.groups_rounded,
          const Color(0xFF6366F1),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TourGuideAttendanceScreen(
                sessionId: 'demo-session-001',
              ),
            ),
          ),
        ),
        _buildModuleCard(
          'Tracking',
          Icons.location_on_rounded,
          const Color(0xFF3B82F6),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TourGuideMapScreen()),
          ),
        ),
        _buildModuleCard(
          'Messages',
          Icons.chat_bubble_rounded,
          const Color(0xFFF59E0B),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GroupChatScreen(
                isCurrentUserGuide: true,
                sessionId: 'demo-session-001',
              ),
            ),
          ),
        ),
        _buildModuleCard(
          'Weather',
          Icons.wb_sunny_rounded,
          const Color(0xFF10B981),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WeatherScreen()),
          ),
        ),
        _buildModuleCard(
          'SOS Log',
          Icons.emergency_rounded,
          AppColors.error,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SosScreen(
                sessionId: 'demo-session-001',
              ),
            ),
          ),
        ),
        _buildModuleCard(
          'AI Assistant',
          Icons.smart_toy_rounded,
          const Color(0xFF8B5CF6),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          ),
        ),
        _buildModuleCard(
          'Access Code',
          Icons.qr_code_rounded,
          AppColors.primaryDark,
          () => Navigator.push(
            context,
            // TODO (Step 4+): Replace 'demo-session-001' with the real active
            // session ID from the session management feature once built.
            MaterialPageRoute(
              builder: (_) => const TourGuideAccessLogScreen(
                sessionId: 'demo-session-001',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

