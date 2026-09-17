import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tour_model.dart';
import '../services/itinerary_service.dart';
import '../theme/app_colors.dart';
import '../../features/itinerary/models/itinerary_item.dart';
import '../../features/tour_guide/screens/tour_hub_screen.dart';
import '../../features/tour_guide/screens/tour_guide_itinerary_screen.dart';
import '../../features/tourist/screens/tourist_itinerary_screen.dart';

/// Unified Tour Status Panel used across both Tour Guide and Tourist Dashboards.
///
/// Implements the 3-state schedule lifecycle:
/// 1. READY / UPCOMING (currentDate < startDate)
/// 2. ACTIVE (startDate <= currentDate <= endDate)
/// 3. COMPLETED (currentDate > endDate or status == 'completed')
class TourStatusCard extends StatelessWidget {
  final Tour tour;
  final bool isTourGuide;
  final VoidCallback? onGuideProfileTap;
  final VoidCallback? onTap;
  final VoidCallback? onEndTour;

  const TourStatusCard({
    super.key,
    required this.tour,
    this.isTourGuide = false,
    this.onGuideProfileTap,
    this.onTap,
    this.onEndTour,
  });

  @override
  Widget build(BuildContext context) {
    final status = tour.scheduleStatus;

    // Gradient styling based on lifecycle state
    final List<Color> gradientColors = switch (status) {
      TourScheduleStatus.ready => const [Color(0xFF0284C7), Color(0xFF0369A1)],
      TourScheduleStatus.active => const [Color(0xFF0284C7), Color(0xFF075985)],
      TourScheduleStatus.completed => const [Color(0xFF475569), Color(0xFF334155)],
    };

    final Color shadowColor = switch (status) {
      TourScheduleStatus.ready => const Color(0xFF0284C7).withValues(alpha: 0.25),
      TourScheduleStatus.active => const Color(0xFF0284C7).withValues(alpha: 0.3),
      TourScheduleStatus.completed => Colors.black.withValues(alpha: 0.15),
    };

    Widget cardBody = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBadgeRow(status),
          const SizedBox(height: 12),
          _buildTourTitle(),
          const SizedBox(height: 6),
          _buildScheduleDetailsRow(status),
          if (tour.guideName.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildGuideRow(context),
          ],
          if (isTourGuide && tour.accessCode.isNotEmpty && !tour.isCompleted) ...[
            const SizedBox(height: 14),
            _buildAccessCodeRow(context),
          ],
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 10),
          _buildItineraryStatusSection(context, status),
          if (isTourGuide) ...[
            const SizedBox(height: 14),
            _buildGuideActionButtons(context, status),
          ],
        ],
      ),
    );

    if (!isTourGuide && onTap != null) {
      cardBody = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: cardBody,
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: cardBody,
    );
  }

  // ── Guide Action Buttons (Guide Dashboard) ─────────────────

  Widget _buildGuideActionButtons(BuildContext context, TourScheduleStatus status) {
    return Row(
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
              padding: const EdgeInsets.symmetric(vertical: 11),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        if (status != TourScheduleStatus.completed && onEndTour != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onEndTour,
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
    );
  }

  // ── Header Badge Row ──────────────────────────────────────

  Widget _buildHeaderBadgeRow(TourScheduleStatus status) {
    switch (status) {
      case TourScheduleStatus.ready:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, color: Color(0xFFFDE68A), size: 12),
                  SizedBox(width: 5),
                  Text(
                    'READY TOUR',
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Starts ${_daysUntil(tour.startDate)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

      case TourScheduleStatus.active:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                  SizedBox(width: 6),
                  Text(
                    'ACTIVE TOUR',
                    style: TextStyle(
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
              'Day ${tour.currentScheduleDay} of ${tour.totalDays}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

      case TourScheduleStatus.completed:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF94A3B8), size: 12),
                  SizedBox(width: 5),
                  Text(
                    'COMPLETED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'Tour Completed ✓',
              style: TextStyle(
                color: Color(0xFF4ADE80),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
    }
  }

  // ── Tour Title ───────────────────────────────────────────

  Widget _buildTourTitle() {
    return Text(
      tour.name,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ── Schedule Details Row ─────────────────────────────────

  Widget _buildScheduleDetailsRow(TourScheduleStatus status) {
    if (status == TourScheduleStatus.ready) {
      return Row(
        children: [
          const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            'Starts ${Tour.formatDate(tour.startDate)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.white38,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Day 1 of ${tour.totalDays}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (status == TourScheduleStatus.completed) {
      return Text(
        tour.formattedDateRange,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      );
    }

    // Active
    return Row(
      children: [
        const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Text(
          tour.formattedDateRange,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  // ── Guide Row ────────────────────────────────────────────

  Widget _buildGuideRow(BuildContext context) {
    final guideWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.person_pin_rounded, color: Colors.white70, size: 15),
        const SizedBox(width: 6),
        Text(
          'Guide: ${tour.guideName}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (!isTourGuide && onGuideProfileTap != null) ...[
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 16),
        ],
      ],
    );

    if (!isTourGuide && onGuideProfileTap != null) {
      return GestureDetector(
        onTap: onGuideProfileTap,
        child: guideWidget,
      );
    }

    return guideWidget;
  }

  // ── Access Code Row (Guide Only) ─────────────────────────

  Widget _buildAccessCodeRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_rounded, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Code: ${tour.accessCode}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: tour.accessCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Access code "${tour.accessCode}" copied!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 13, color: Color(0xFF0369A1)),
                  SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: TextStyle(
                      color: Color(0xFF0369A1),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Itinerary Status Section ─────────────────────────────

  Widget _buildItineraryStatusSection(BuildContext context, TourScheduleStatus status) {
    if (status == TourScheduleStatus.completed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.history_rounded, color: Colors.white70, size: 14),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Tour has ended. Itinerary and records archived.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<ItineraryItem>>(
      stream: ItineraryService.watchItinerary(tour.id),
      builder: (context, snapshot) {
        final stops = snapshot.data ?? [];

        Widget content;
        if (stops.isEmpty) {
          content = const Row(
            children: [
              Icon(Icons.map_rounded, color: Colors.white54, size: 14),
              SizedBox(width: 6),
              Text(
                'No destinations added yet',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          );
        } else if (status == TourScheduleStatus.ready) {
          final firstStop = stops.first;
          final timeStr = firstStop.startTime.isNotEmpty ? ' – ${firstStop.startTime}' : '';
          content = Row(
            children: [
              const Icon(Icons.near_me_rounded, color: Color(0xFF38BDF8), size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Next: ${firstStop.destinationName}$timeStr',
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
          );
        } else {
          // ACTIVE state: check ongoing, completed today, or next
          final ongoing = stops.where((s) => s.isCurrentlyOngoing).firstOrNull;
          final upcoming =
              stops.where((s) => s.effectiveStatus == ItineraryStatus.upcoming).firstOrNull;
          final allDone = stops.every((s) => s.effectiveStatus == ItineraryStatus.completed);

          if (ongoing != null) {
            content = Row(
              children: [
                const Icon(Icons.near_me_rounded, color: Color(0xFF4ADE80), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Current: ${ongoing.destinationName}  ${ongoing.startTime} – ${ongoing.endTime}',
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
            );
          } else if (allDone) {
            content = const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 14),
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
            );
          } else if (upcoming != null) {
            content = Row(
              children: [
                const Icon(Icons.near_me_rounded, color: Color(0xFF38BDF8), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Next: ${upcoming.destinationName}  ${upcoming.startTime}',
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
            );
          } else {
            final first = stops.first;
            content = Row(
              children: [
                const Icon(Icons.near_me_rounded, color: Color(0xFF38BDF8), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Next: ${first.destinationName}  ${first.startTime}',
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
            );
          }
        }

        return InkWell(
          onTap: () {
            if (isTourGuide) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TourGuideItineraryScreen(tourId: tour.id),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TouristItineraryScreen(),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: content,
          ),
        );
      },
    );
  }

  String _daysUntil(DateTime start) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tourDay = DateTime(start.year, start.month, start.day);
    final diff = tourDay.difference(today).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'in $diff days';
  }
}
