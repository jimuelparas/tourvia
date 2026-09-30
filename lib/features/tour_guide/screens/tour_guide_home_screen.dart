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
import '../../../core/services/tour_status_resolver.dart';
import '../../../core/widgets/weather_panel.dart';
import '../../itinerary/models/itinerary_item.dart';
import 'add_edit_itinerary_screen.dart';
import 'create_tour_screen.dart';
import 'tour_guide_itinerary_screen.dart';
import 'tour_hub_screen.dart';
import 'tour_join_requests_screen.dart';
import 'tour_management_screen.dart';
import 'tour_guide_attendance_screen.dart';
import '../widgets/tour_access_qr_dialog.dart';
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
  late final Stream<List<Tour>> _toursStream;

  // SOS live monitoring — delegated to SosNotificationService
  StreamSubscription<List<SosAlert>>? _sosUiSubscription;
  List<SosAlert> _activeAlerts = [];
  String? _currentSosTourId; // Track which tour ID we're watching SOS for

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _sessionId = AuthService.currentUser?.uid ?? '';
    _toursStream = TourService.watchToursByGuide(_sessionId);

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

    // SOS watching is started dynamically from the tour stream
    // (see _startSosForTour) so it watches the correct tour ID,
    // not the guide's UID.
    _activeAlerts = SosNotificationService.instance.currentAlerts;
    _sosUiSubscription = SosNotificationService.instance.activeAlertsStream
        .listen((alerts) {
          if (!mounted) return;
          setState(() => _activeAlerts = alerts);
        });
  }


  /// Starts (or updates) SOS watching for the given tour ID.
  /// Only restarts if the tour ID has changed.
  void _startSosForTour(String tourId) {
    if (tourId.isEmpty || tourId == _currentSosTourId) return;
    _currentSosTourId = tourId;
    SosNotificationService.instance.startWatching(
      sessionId: tourId,
      currentUserId: _sessionId, // guide's UID to filter out self-sent alerts
    );
    debugPrint('[TourGuideHome] SOS now watching tour: $tourId');
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
                // Unified Tour Dashboard Panel + Modules Stream
                StreamBuilder<List<Tour>>(
                  stream: _toursStream,
                  builder: (context, snapshot) {
                    final allTours = snapshot.data ?? [];

                    // Priority 1: ACTIVE tour
                    final activeTour = allTours
                        .where((t) => t.isActive && !t.isEnded)
                        .firstOrNull;

                    // Priority 2: Nearest UPCOMING tour
                    final upcomingTours = allTours.where((t) {
                      final raw = t.status.trim().toLowerCase();
                      return !t.isEnded &&
                          raw != 'completed' &&
                          raw != 'ended' &&
                          t.endedAt == null &&
                          t.completedAt == null &&
                          t.isUpcoming;
                    }).toList();
                    if (upcomingTours.length > 1) {
                      upcomingTours.sort((a, b) {
                        final sA = TourStatusResolver.getTourStartDateTime(a);
                        final sB = TourStatusResolver.getTourStartDateTime(b);
                        return sA.compareTo(sB);
                      });
                    }

                    // Dashboard Priority: Active -> Nearest Upcoming -> No Active Tour state
                    // (Completed tours are never displayed on the main dashboard)
                    final currentTour = activeTour ?? upcomingTours.firstOrNull;

                    // Start SOS watching for the active/upcoming tour
                    if (currentTour != null) {
                      _startSosForTour(currentTour.id);
                    }

                    final nonCompletedTours = [
                      if (activeTour != null) activeTour,
                      ...upcomingTours,
                    ];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (currentTour != null)
                          _buildActiveTourCard(currentTour)
                        else
                          _buildNoActiveTourCard(),
                        Text(
                          'Quick Modules',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildGrid(
                          allTours: allTours,
                          nonCompletedTours: nonCompletedTours,
                          activeTour: activeTour,
                          fallbackTour: currentTour,
                          guideId: _sessionId,
                        ),
                      ],
                    );
                  },
                ),
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
        final guideName =
            profile?['fullName'] as String? ??
            AuthService.currentUser?.displayName ??
            'Guide';
        final photoUrl = profile?['profilePhotoUrl'] as String?;
        final tourGuideType = profile?['tourGuideType'] as String?;
        final isVerifiedGuide = tourGuideType == 'verified';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome $guideName!',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: AppColors.textHint),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tourGuideType != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isVerifiedGuide
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isVerifiedGuide
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : Colors.teal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVerifiedGuide
                                ? Icons.verified_rounded
                                : Icons.shield_outlined,
                            size: 13,
                            color: isVerifiedGuide
                                ? AppColors.primary
                                : Colors.teal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerifiedGuide
                                ? 'Verified Tour Guide'
                                : 'Local Tour Guide',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isVerifiedGuide
                                  ? AppColors.primary
                                  : Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Tour Management',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
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
                      builder: (_) => const TourManagementScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('View Scheduled'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTourScreen()),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create Tour'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
    final isUpcoming = tour.isUpcoming;
    final isCompleted = tour.isCompleted;
    final isActive = tour.isActive;

    final dayNumber = tour.currentScheduleDay;
    final dayStr = 'Day $dayNumber of ${tour.totalDays}';

    // Status-dependent badge text and dot color
    final String badgeText;
    final Color badgeDotColor;
    if (isUpcoming) {
      badgeText = 'READY TOUR';
      badgeDotColor = const Color(0xFFFBBF24); // Amber
    } else if (isCompleted) {
      badgeText = 'COMPLETED TOUR';
      badgeDotColor = const Color(0xFF94A3B8); // Slate
    } else {
      badgeText = 'ACTIVE TOUR';
      badgeDotColor = const Color(0xFF4ADE80); // Green
    }

    final dateStr = tour.formattedDateRange;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
            dateStr,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Access code container with Copy button and QR popup tap
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => TourAccessQrDialog.show(context, tour),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Code: ${tour.accessCode}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: tour.accessCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: const [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                            ),
                            SizedBox(width: 10),
                            Text('Access code copied to clipboard!'),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: Color(0xFF0369A1),
                        ),
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
          Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
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
              final upcomingStop =
                  stops
                      .where(
                        (s) => s.effectiveStatus == ItineraryStatus.upcoming,
                      )
                      .firstOrNull ??
                  (tour.isReady ? stops.firstOrNull : null);
              final isAllDone =
                  stops.isNotEmpty &&
                  !tour.isReady &&
                  stops.every(
                    (s) => s.effectiveStatus == ItineraryStatus.completed,
                  );

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
                            tourStartDateTime:
                                TourStatusResolver.getTourStartDateTime(tour),
                            tourEndDateTime:
                                TourStatusResolver.getTourEndDateTime(tour),
                          ),
                  ),
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status & Destination presentation depending on tour lifecycle:
                      if (tour.isCompleted) ...[
                        // 3. COMPLETED TOUR
                        Row(
                          children: const [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF4ADE80),
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '✓ Tour completed',
                              style: TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ] else if (tour.isUpcoming) ...[
                        // 1. UPCOMING / READY TOUR
                        if (tour.startTime != null &&
                            tour.startTime!.trim().isNotEmpty) ...[
                          Text(
                            'Starts at ${tour.startTime}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (upcomingStop != null) const SizedBox(height: 4),
                        ],
                        if (upcomingStop != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.near_me_rounded,
                                color: Color(0xFF38BDF8),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Next: ',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${upcomingStop.destinationName} – ${upcomingStop.startTime}',
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
                        ] else if (!hasStops &&
                            (tour.startTime == null ||
                                tour.startTime!.trim().isEmpty)) ...[
                          Row(
                            children: const [
                              Icon(
                                Icons.add_location_alt_rounded,
                                color: Color(0xFF38BDF8),
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'No itinerary stops added yet',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else ...[
                        // 2. ACTIVE TOUR
                        if (ongoingStop != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.near_me_rounded,
                                color: Color(0xFF4ADE80),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Current',
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
                            children: const [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF4ADE80),
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'All stops completed today ✓',
                                style: TextStyle(
                                  color: Color(0xFF4ADE80),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ] else if (!hasStops) ...[
                          Row(
                            children: const [
                              Icon(
                                Icons.add_location_alt_rounded,
                                color: Color(0xFF38BDF8),
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'No itinerary stops added yet',
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
                          if (ongoingStop != null) const SizedBox(height: 6),
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
                                  '${upcomingStop.destinationName} • ${upcomingStop.startTime}',
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
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Color(0xFF38BDF8),
                            ),
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
                      builder: (_) =>
                          TourHubScreen(tourId: tour.id, initialTour: tour),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _confirmEndTour(tour),
                  icon: const Icon(
                    Icons.stop_circle_rounded,
                    color: Colors.white,
                  ),
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Tour?'),
        content: const Text(
          'Are you sure you want to end this tour? The tour will be moved to Completed.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('End Tour'),
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
      await TourService.endTour(tour.id);
      SosNotificationService.instance.stopWatching();
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tour Ended Successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
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
        ),
      );
    }
  }

  Widget _buildGrid({
    required List<Tour> allTours,
    required List<Tour> nonCompletedTours,
    required Tour? activeTour,
    required Tour? fallbackTour,
    required String guideId,
  }) {
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
            MaterialPageRoute(builder: (_) => const TourManagementScreen()),
          ),
        ),
        // Approvals Module — tour-specific with multi-tour support
        StreamBuilder<List<JoinRequest>>(
          stream: activeTour != null
              ? TourService.watchJoinRequests(
                  activeTour.id,
                  statusFilter: 'pending',
                )
              : (fallbackTour != null
                    ? TourService.watchJoinRequests(
                        fallbackTour.id,
                        statusFilter: 'pending',
                      )
                    : const Stream.empty()),
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
                _handleModuleTap(
                  allTours: allTours,
                  nonCompletedTours: nonCompletedTours,
                  activeTour: activeTour,
                  moduleTitle: 'Join Approvals',
                  onOpen: (tour) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TourJoinRequestsScreen(
                        tourId: tour.id,
                        tourName: tour.name,
                      ),
                    ),
                  ),
                );
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
            _handleModuleTap(
              allTours: allTours,
              nonCompletedTours: nonCompletedTours,
              activeTour: activeTour,
              moduleTitle: 'Attendance',
              onOpen: (tour) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TourGuideAttendanceScreen(
                    sessionId: tour.id,
                    tourId: tour.id,
                  ),
                ),
              ),
            );
          },
        ),
        _buildModuleCard(
          title: 'Tracking',
          subtitle: 'Live location',
          iconAsset: 'assets/icons/location.png',
          color: AppColors.accentTeal,
          onTap: () {
            _handleModuleTap(
              allTours: allTours,
              nonCompletedTours: nonCompletedTours,
              activeTour: activeTour,
              moduleTitle: 'Tracking',
              onOpen: (tour) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TourGuideMapScreen(sessionId: tour.id, tourId: tour.id),
                ),
              ),
            );
          },
        ),
        // Messages module with unread badge
        StreamBuilder<int>(
          stream: (activeTour ?? fallbackTour) != null
              ? ChatBadgeService.watchUnreadCount(
                  (activeTour ?? fallbackTour)!.id,
                  guideId,
                )
              : Stream.value(0),
          builder: (context, chatBadgeSnap) {
            final unread = chatBadgeSnap.data ?? 0;
            return _buildModuleCard(
              title: 'Group Chat',
              subtitle: 'Messages',
              iconAsset: 'assets/icons/groupchat.png',
              color: AppColors.accent,
              badgeCount: unread,
              onTap: () {
                _handleModuleTap(
                  allTours: allTours,
                  nonCompletedTours: nonCompletedTours,
                  activeTour: activeTour,
                  moduleTitle: 'Group Chat',
                  onOpen: (tour) async {
                    ChatBadgeService.updateLastRead(tour.id, guideId);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupChatScreen(
                          isCurrentUserGuide: true,
                          sessionId: tour.id,
                          isReadOnly: tour.isCompleted,
                        ),
                      ),
                    );
                    ChatBadgeService.updateLastRead(tour.id, guideId);
                  },
                );
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
            _handleModuleTap(
              allTours: allTours,
              nonCompletedTours: nonCompletedTours,
              activeTour: activeTour,
              moduleTitle: 'SOS Log',
              onOpen: (tour) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SosScreen(sessionId: tour.id),
                ),
              ),
            );
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
                            : Image.asset(
                                iconAsset!,
                                width: iconSize,
                                height: iconSize,
                                fit: BoxFit.contain,
                              ),
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

  void _handleModuleTap({
    required List<Tour> allTours,
    required List<Tour> nonCompletedTours,
    required Tour? activeTour,
    required String moduleTitle,
    required void Function(Tour tour) onOpen,
  }) {
    // 1. If an active tour is in progress, open it directly
    if (activeTour != null) {
      onOpen(activeTour);
      return;
    }

    // 2. If there is a single upcoming tour, open it directly
    if (nonCompletedTours.length == 1) {
      onOpen(nonCompletedTours.first);
      return;
    }

    // 3. If there are multiple upcoming tours, let the guide choose
    if (nonCompletedTours.length > 1) {
      _showTourPicker(
        tours: nonCompletedTours,
        title: 'Select Tour for $moduleTitle',
        subtitle: 'Choose which scheduled tour to open $moduleTitle for',
        onSelected: onOpen,
      );
      return;
    }

    // 4. No active or upcoming tours found (nonCompletedTours.isEmpty)
    // If the guide has existing tours (e.g. completed), allow selecting one to view records/history
    if (allTours.isNotEmpty) {
      _showTourPicker(
        tours: allTours,
        title: 'Select Tour for $moduleTitle',
        subtitle: 'No active tour running. Choose a tour to view $moduleTitle:',
        onSelected: onOpen,
      );
      return;
    }

    // 5. Zero tours created in account
    _showNoToursDialog(moduleTitle: moduleTitle);
  }

  void _showNoToursDialog({required String moduleTitle}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No Tours Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '$moduleTitle requires an active or scheduled tour session. You do not have any tours created yet.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTourScreen()),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Tour'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTourPicker({
    required List<Tour> tours,
    required String title,
    required String subtitle,
    required void Function(Tour tour) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tours.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tour = tours[index];
                    final isUpcoming = tour.isUpcoming;
                    final isActive = tour.isActive;
                    final statusColor = isActive
                        ? AppColors.primary
                        : (isUpcoming
                              ? const Color(0xFFF59E0B)
                              : AppColors.textSecondary);

                    return ListTile(
                      tileColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.tour, color: statusColor, size: 20),
                      ),
                      title: Text(
                        tour.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${tour.status.toUpperCase()} • ${tour.accessCode}',
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelected(tour);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateTourScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create Tour'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                    child: Image.asset(
                      widget.iconAsset,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
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
