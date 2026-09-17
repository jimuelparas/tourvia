import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/tour_session_service.dart';
import '../../../core/services/sos_service.dart';
import '../../../core/services/sos_notification_service.dart';
import '../../../core/services/chat_badge_service.dart';
import '../../../core/models/tour_model.dart';
import '../../../core/models/join_request_model.dart';
import '../../../core/services/itinerary_service.dart';
import '../../../core/services/tour_service.dart';
import '../../../core/widgets/weather_panel.dart';
import '../../itinerary/models/itinerary_item.dart';
import 'add_edit_itinerary_screen.dart';
import 'tour_guide_itinerary_screen.dart';
import 'tour_hub_screen.dart';
import 'create_tour_screen.dart';
import 'tour_join_requests_screen.dart';
import 'tour_management_screen.dart';
import 'tour_guide_attendance_screen.dart';
import '../../chat/screens/group_chat_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../sos/screens/sos_screen.dart';
import '../../tracking/screens/tour_guide_map_screen.dart';
import '../../chatbot/screens/chatbot_screen.dart';

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
                const SizedBox(height: 20),
                // Weather panel at top of dashboard
                const WeatherPanel(),
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
    final guideId = AuthService.currentUser?.uid ?? _sessionId;

    return StreamBuilder<Tour?>(
      stream: TourService.watchCurrentOrUpcomingTour(guideId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('TourStatusBanner stream error: ${snapshot.error}');
          return _buildNoActiveTourCard();
        }

        final tour = snapshot.data;
        if (tour == null) {
          return _buildNoActiveTourCard();
        }
        return _buildActiveTourCard(tour);
      },
    );
  }

  Widget _buildNoActiveTourCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_busy_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'No Active Tour',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'You do not have a tour in progress today.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TourManagementScreen()),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('View Scheduled'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateTourScreen()),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create Tour'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTourCard(Tour tour) {
    final dayNumber = tour.currentScheduleDay;
    final dayStr = 'Day $dayNumber of ${tour.totalDays}';

    // Status-dependent badge text and dot color (REV-004)
    final String badgeText;
    final Color badgeDotColor;
    if (tour.isUpcoming) {
      badgeText = 'READY / UPCOMING TOUR';
      badgeDotColor = const Color(0xFFFBBF24); // Amber
    } else if (tour.isCompleted) {
      badgeText = 'COMPLETED TOUR';
      badgeDotColor = const Color(0xFF94A3B8); // Slate
    } else {
      badgeText = 'ACTIVE TOUR';
      badgeDotColor = const Color(0xFF4ADE80); // Green
    }

    final bool isCompleted = tour.isCompleted;
    final List<Color> gradientColors = isCompleted
        ? const [Color(0xFF64748B), Color(0xFF475569)]
        : const [Color(0xFF0284C7), Color(0xFF0369A1)];
    final Color shadowColor = isCompleted
        ? const Color(0xFF64748B)
        : const Color(0xFF0284C7);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: badgeDotColor, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                dayStr,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tour title
          Text(
            tour.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tour.formattedDateRange,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),

          // Access code container with Copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.key_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Code: ${tour.accessCode}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: tour.accessCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: const [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white),
                            SizedBox(width: 10),
                            Text('Access code copied to clipboard!'),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.copy_rounded,
                            size: 14, color: Color(0xFF0369A1)),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Color(0xFF0369A1),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Thin separator
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 10),
          // Automated Itinerary Destination Tracking & Quick Add
          StreamBuilder<List<ItineraryItem>>(
            stream: ItineraryService.watchItinerary(tour.id),
            builder: (context, stopSnapshot) {
              final stops = stopSnapshot.data ?? [];
              final hasStops = stops.isNotEmpty;
              final ongoingStop = stops
                  .where((s) => s.isCurrentlyOngoing)
                  .firstOrNull;
              final upcomingStop = stops
                  .where((s) => s.effectiveStatus == ItineraryStatus.upcoming)
                  .firstOrNull ??
                  (tour.isReady ? stops.firstOrNull : null);
              final isAllDone = stops.isNotEmpty &&
                  !tour.isReady &&
                  stops.every((s) => s.effectiveStatus == ItineraryStatus.completed);

              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => hasStops
                        ? TourGuideItineraryScreen(tourId: tour.id)
                        : AddEditItineraryScreen(
                            sessionId: tour.id,
                            tourId: tour.id,
                            tourStartDate: tour.startDate,
                            tourEndDate: tour.endDate,
                          ),
                  ),
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current destination row
                      if (ongoingStop != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.near_me_rounded,
                                color: Color(0xFF4ADE80), size: 14),
                            const SizedBox(width: 6),
                            const Text('Current',
                              style: TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${ongoingStop.destinationName}  ${ongoingStop.startTime} – ${ongoingStop.endTime}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ] else if (isAllDone) ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF4ADE80), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              isCompleted
                                  ? 'Tour completed'
                                  : 'All ${stops.length} stops completed today ✓',
                              style: const TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ] else if (!hasStops) ...[
                        Row(
                          children: [
                            const Icon(Icons.add_location_alt_rounded,
                                color: Color(0xFF38BDF8), size: 14),
                            const SizedBox(width: 6),
                            const Text('No itinerary stops added yet',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Upcoming destination row
                      if (upcomingStop != null && !isAllDone) ...[
                        if (ongoingStop != null)
                          const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              ongoingStop != null
                                  ? Icons.skip_next_rounded
                                  : Icons.near_me_rounded,
                              color: const Color(0xFF38BDF8),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ongoingStop != null ? 'Next' : 'Upcoming',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${upcomingStop.destinationName}  ${upcomingStop.startTime}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // View / Add action
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasStops ? 'View Itinerary' : '+ Add Stops',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right_rounded,
                                size: 16, color: Color(0xFF38BDF8)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Action buttons: Manage Tour, Itinerary & End Tour
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TourHubScreen(
                        tourId: tour.id,
                        initialTour: tour,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.dashboard_rounded, size: 16),
                  label: const Text('Manage Tour'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0369A1),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TourGuideItineraryScreen(tourId: tour.id),
                  ),
                ),
                icon: const Icon(Icons.map_rounded, size: 16),
                label: const Text('Itinerary'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              if (!isCompleted) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _confirmEndTour(tour),
                  icon: const Icon(Icons.stop_circle_rounded, color: Colors.white),
                  tooltip: 'End Tour',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmEndTour(Tour tour) async {
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
                  Text(
                    'Ending "${tour.name}" will:',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _endTourBullet('Mark this tour as Completed'),
                  _endTourBullet('Disable new tourist join requests'),
                  _endTourBullet('Set group chat to Read-Only mode'),
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
                            'All itinerary and historical data will be preserved.',
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
      await TourService.completeTour(tour.id);
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
                child: Text('Tour marked as completed. Chat is now Read-Only.'),
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
    final guideId = AuthService.currentUser?.uid ?? _sessionId;

    return StreamBuilder<Tour?>(
      stream: TourService.watchActiveTour(guideId),
      builder: (context, tourSnapshot) {
        final activeTour = tourSnapshot.data;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.95,
          children: [
            _buildModuleCard(
              title: 'Manage Tour',
              subtitle: 'View & manage',
              iconAsset: 'assets/icons/manage_tour.png',
              color: const Color(0xFF0EA5E9),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TourManagementScreen(),
                ),
              ),
            ),
            // Approvals Module next to Manage Tour
            StreamBuilder<List<JoinRequest>>(
              stream: activeTour != null
                  ? TourService.watchJoinRequests(activeTour.id,
                      statusFilter: 'pending')
                  : const Stream.empty(),
              builder: (context, reqSnapshot) {
                final pendingCount = (reqSnapshot.data ?? []).length;

                return _buildModuleCard(
                  title: 'Join Approvals',
                  subtitle: pendingCount > 0
                      ? '$pendingCount Pending'
                      : 'Tourist requests',
                  icon: Icons.person_add_alt_1_rounded,
                  badgeCount: pendingCount,
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    if (activeTour != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TourJoinRequestsScreen(
                            tourId: activeTour.id,
                            tourName: activeTour.name,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TourManagementScreen(),
                        ),
                      );
                    }
                  },
                );
              },
            ),
            _buildModuleCard(
              title: 'Attendance',
              subtitle: 'Check-in guests',
              iconAsset: 'assets/icons/attendance.png',
              color: AppColors.primary,
              onTap: () {
                if (activeTour != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TourGuideAttendanceScreen(
                        sessionId: activeTour.id,
                        tourId: activeTour.id,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TourManagementScreen(),
                    ),
                  );
                }
              },
            ),
            _buildModuleCard(
              title: 'Tracking',
              subtitle: 'Live location',
              iconAsset: 'assets/icons/location.png',
              color: AppColors.accentTeal,
              onTap: () {
                if (activeTour != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TourGuideMapScreen(sessionId: activeTour.id),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TourManagementScreen(),
                    ),
                  );
                }
              },
            ),
            // Messages module with unread badge
            StreamBuilder<int>(
              stream: activeTour != null
                  ? ChatBadgeService.watchUnreadCount(
                      activeTour.id, guideId)
                  : Stream.value(0),
              builder: (context, chatBadgeSnap) {
                final unread = chatBadgeSnap.data ?? 0;
                return _buildModuleCard(
                  title: 'Group Chat',
                  subtitle: 'Messages',
                  iconAsset: 'assets/icons/groupchat.png',
                  color: AppColors.accent,
                  badgeCount: unread,
                  onTap: () async {
                    if (activeTour != null) {
                      // Mark messages as read
                      ChatBadgeService.updateLastRead(
                          activeTour.id, guideId);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupChatScreen(
                            isCurrentUserGuide: true,
                            sessionId: activeTour.id,
                            isReadOnly: activeTour.isCompleted,
                          ),
                        ),
                      );
                      ChatBadgeService.updateLastRead(
                          activeTour.id, guideId);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TourManagementScreen(),
                        ),
                      );
                    }
                  },
                );
              },
            ),
            // Weather module removed — now shown as panel at top
            _SosBlinkingModuleCard(
              isActive: _activeAlerts.isNotEmpty,
              title: 'SOS Log',
              subtitle: 'Emergency logs',
              iconAsset: 'assets/icons/sos.png',
              onTap: () {
                if (activeTour != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SosScreen(
                        sessionId: activeTour.id,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TourManagementScreen(),
                    ),
                  );
                }
              },
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
          ],
        );
      },
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    String? iconAsset,
    IconData? icon,
    int badgeCount = 0,
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
              Stack(
                clipBehavior: Clip.none,
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
                        child: icon != null
                            ? Icon(icon, color: color, size: iconSize)
                            : Image.asset(iconAsset!,
                                width: iconSize,
                                height: iconSize,
                                fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: badgeCount > 9 ? 6 : 0,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
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
