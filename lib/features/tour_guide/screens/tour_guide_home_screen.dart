import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/tour_session_service.dart';
import '../../../core/services/attendance_service.dart';
import '../../../core/services/sos_service.dart';
import '../../../core/services/sos_notification_service.dart';
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

  // SOS live monitoring — delegated to SosNotificationService
  StreamSubscription<List<SosAlert>>? _sosUiSubscription;
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

    // Start the app-level SOS notification service for this session
    SosNotificationService.instance.startWatching(
      sessionId: _sessionId,
      currentUserId: _sessionId,
    );

    // Subscribe to the service's stream for UI updates (blinking card)
    _activeAlerts = SosNotificationService.instance.currentAlerts;
    _sosUiSubscription = SosNotificationService.instance.activeAlertsStream.listen((alerts) {
      if (!mounted) return;
      setState(() => _activeAlerts = alerts);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _sosUiSubscription?.cancel();
    // Note: do NOT stop ringing or the SOS service here.
    // Ringing is managed by SosNotificationService at the app level.
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
                // SOS alert banner removed — alerts now handled via
                // SosNotificationService with persistent ringing.
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

  Widget _buildHeader() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: AuthService.watchProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final guideName = profile?['fullName'] as String? ??
            AuthService.currentUser?.displayName ??
            'Guide';
        final photoUrl = profile?['profilePhotoUrl'] as String?;

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
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primarySurface,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? const Icon(Icons.person_rounded, color: AppColors.primary)
                    : null,
              ),
            ),
          ],
        );
      },
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
                    // Start New Tour button — only visible when tour is ended
                    if (isEnded) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _startNewTour(),
                          icon: const Icon(Icons.play_circle_rounded,
                              size: 18),
                          label: const Text('Start New Tour'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.25),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color:
                                    Colors.white.withValues(alpha: 0.4),
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

  Future<void> _startNewTour() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_circle_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Start New Tour?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will reset everything and create a fresh tour:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _newTourBullet('Delete previous itinerary stops'),
            _newTourBullet('Generate a new access code'),
            _newTourBullet('Clear all previous data'),
            _newTourBullet('Set tour status to Active'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Start New Tour'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await TourSessionService.resetSession(_sessionId);

      // Re-register guide info on the new session
      final guide = AuthService.currentUser;
      if (guide != null) {
        await TourSessionService.updateGuideInfo(
          _sessionId,
          guide.uid,
          guide.displayName ?? 'Guide',
        );
      }

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
                child: Text('New tour started! Set up your itinerary.'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start new tour: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _newTourBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
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
      childAspectRatio: 0.95,
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
        _SosBlinkingModuleCard(
          isActive: _activeAlerts.isNotEmpty,
          title: 'SOS Log',
          subtitle: 'Emergency logs',
          iconAsset: 'assets/icons/sos.png',
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: containerSize,
                height: containerSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Image.asset(iconAsset,
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Self-contained SOS blinking card widget.
// Manages its OWN Timer and its OWN setState so the blink is guaranteed
// to fire independently of the parent widget's rebuild cycle.
// ─────────────────────────────────────────────────────────────────────────────
class _SosBlinkingModuleCard extends StatefulWidget {
  final bool isActive;
  final String title;
  final String subtitle;
  final String iconAsset;
  final VoidCallback onTap;

  const _SosBlinkingModuleCard({
    required this.isActive,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.onTap,
  });

  @override
  State<_SosBlinkingModuleCard> createState() => _SosBlinkingModuleCardState();
}

class _SosBlinkingModuleCardState extends State<_SosBlinkingModuleCard> {
  Timer? _timer;
  bool _lit = false; // true = red "on" frame, false = normal "off" frame

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _startBlink();
  }

  @override
  void didUpdateWidget(_SosBlinkingModuleCard old) {
    super.didUpdateWidget(old);
    if (widget.isActive == old.isActive) return;
    if (widget.isActive) {
      _startBlink();
    } else {
      _stopBlink();
    }
  }

  void _startBlink() {
    _timer?.cancel();
    // Immediately show first lit frame, then toggle every 500 ms
    setState(() => _lit = true);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _lit = !_lit);
    });
  }

  void _stopBlink() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _lit = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double containerSize = 56;
    const double iconSize = 32;

    return Material(
      // Material color drives InkWell's ink surface color
      color: _lit ? AppColors.error.withValues(alpha: 0.15) : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _lit ? AppColors.error : AppColors.border,
              width: _lit ? 3.0 : 1.0,
            ),
            boxShadow: _lit
                ? [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 3,
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container — also turns red when lit
              SizedBox(
                width: containerSize,
                height: containerSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _lit
                        ? AppColors.error.withValues(alpha: 0.22)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Image.asset(widget.iconAsset,
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _lit ? AppColors.error : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _lit ? '🚨 EMERGENCY' : widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _lit ? FontWeight.bold : FontWeight.normal,
                  color: _lit ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
