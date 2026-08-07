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

  // Session ID derived from the logged-in guide's UID for data isolation
  late final String _sessionId;

  // SOS live monitoring
  StreamSubscription<List<SosAlert>>? _sosSubscription;
  List<SosAlert> _activeAlerts = [];

  @override
  void initState() {
    super.initState();
    _sessionId = AuthService.currentUser!.uid;

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
        _sessionId,
        guide.uid,
        guide.displayName ?? 'Guide',
      );
    }

    // Listen for live SOS alerts from tourists
    _sosSubscription = SosService.watchActiveAlerts(_sessionId)
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
                  builder: (_) => SosScreen(
                      sessionId: _sessionId),
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
          builder: (_) => SosScreen(sessionId: _sessionId),
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
                    color: AppColors.primary,
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
      stream: TourSessionService.watchSession(_sessionId),
      builder: (context, sessionSnapshot) {
        final session = sessionSnapshot.data;
        final tourName = session?.tourName ?? 'Unnamed Tour';
        final isEnded = session?.isEnded ?? false;
        final dayStr = session != null
            ? 'Day ${session.currentDay} of ${session.totalDays}'
            : 'Day 1 of 3';

        return StreamBuilder<List<TouristRecord>>(
          stream: AttendanceService.watchRoster(_sessionId),
          builder: (context, rosterSnapshot) {
            final touristCount = rosterSnapshot.data?.length ?? 0;
            final countStr =
                '$touristCount ${touristCount == 1 ? 'tourist' : 'tourists'}';

            return GestureDetector(
              onTap: isEnded
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TourGuideItineraryScreen(
                            sessionId: _sessionId,
                          ),
                        ),
                      ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isEnded
                      ? const LinearGradient(
                          colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isEnded
                          ? const Color(0xFF94A3B8).withValues(alpha: 0.15)
                          : const Color(0xFF2196F3).withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEnded ? 'Tour Ended' : 'Current Tour',
                          style: const TextStyle(
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
                          child: Text(
                            isEnded ? 'Ended' : 'Active',
                            style: const TextStyle(
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
                      isEnded
                          ? 'This tour has been completed.'
                          : '$countStr • $dayStr',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    // End Tour button — only visible when tour is active
                    if (!isEnded) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmEndTour(),
                          icon: const Icon(Icons.stop_circle_rounded,
                              size: 18),
                          label: const Text('End Tour'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color:
                                    Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmEndTour() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        final confirmController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final textMatches =
                confirmController.text.trim().toUpperCase() == 'END';
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stop_circle_rounded,
                        color: AppColors.error, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('End This Tour?'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action will:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _endTourBullet('Invalidate all access codes'),
                  _endTourBullet(
                      'Remove all participants & attendance records'),
                  _endTourBullet(
                      'Delete live tracking data & chat messages'),
                  _endTourBullet('Delete SOS alerts'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your account, profile, and itinerary will be preserved.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Type END to confirm:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmController,
                    onChanged: (_) => setDialogState(() {}),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'END',
                      hintStyle:
                          const TextStyle(color: AppColors.textHint),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: textMatches
                      ? () => Navigator.pop(context, true)
                      : null,
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('End Tour'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.error.withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white60,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await TourSessionService.endTour(_sessionId);
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                    'Tour ended successfully. All temporary data cleared.'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to end tour: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _endTourBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 5, color: AppColors.error),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        _buildModuleCard(
          title: 'Itinerary',
          subtitle: 'View & manage',
          iconAsset: 'assets/icons/itinerary.png',
          color: const Color(0xFF0EA5E9),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TourGuideItineraryScreen(
                sessionId: _sessionId,
              ),
            ),
          ),
        ),
        _buildModuleCard(
          title: 'Attendance',
          subtitle: 'Check-in guests',
          iconAsset: 'assets/icons/attendance.png',
          color: AppColors.primary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TourGuideAttendanceScreen(
                sessionId: _sessionId,
              ),
            ),
          ),
        ),
        _buildModuleCard(
          title: 'Tracking',
          subtitle: 'Live location',
          iconAsset: 'assets/icons/location.png',
          color: AppColors.accentTeal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TourGuideMapScreen(sessionId: _sessionId)),
          ),
        ),
        _buildModuleCard(
          title: 'Messages',
          subtitle: 'Group chat',
          iconAsset: 'assets/icons/groupchat.png',
          color: AppColors.accent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupChatScreen(
                isCurrentUserGuide: true,
                sessionId: _sessionId,
              ),
            ),
          ),
        ),
        _buildModuleCard(
          title: 'Weather',
          subtitle: 'Current forecast',
          iconAsset: 'assets/icons/weather.png',
          color: AppColors.success,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WeatherScreen()),
          ),
        ),
        _buildModuleCard(
          title: 'SOS Log',
          subtitle: 'Emergency logs',
          iconAsset: 'assets/icons/sos.png',
          color: AppColors.error,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SosScreen(
                sessionId: _sessionId,
              ),
            ),
          ),
        ),
        _buildModuleCard(
          title: 'AI Assistant',
          subtitle: 'Smart help',
          iconAsset: 'assets/icons/ai.png',
          color: AppColors.accentTeal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          ),
        ),
        _buildModuleCard(
          title: 'Access Code',
          subtitle: 'Manage codes',
          iconAsset: 'assets/icons/accesscode.png',
          color: AppColors.primaryActive,
          onTap: () => Navigator.push(
            context,
            // TODO (Step 4+): Replace _sessionId with the real active
            // session ID from the session management feature once built.
            MaterialPageRoute(
              builder: (_) => TourGuideAccessLogScreen(
                sessionId: _sessionId,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required String iconAsset,
    required Color color,
    required VoidCallback onTap,
  }) {
    // ── Icon container constants (8px grid) ──
    const double containerSize = 56;
    const double iconSize = 32;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icon: fixed container, perfectly centered image ──
              SizedBox(
                width: containerSize,
                height: containerSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Image.asset(
                      iconAsset,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Title ──
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              // ── Subtitle ──
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

