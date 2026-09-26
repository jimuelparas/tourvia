import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../../../core/models/tour_model.dart';
import '../../../core/services/attendance_service.dart';
import '../../../core/services/itinerary_service.dart';
import '../../../core/services/tour_service.dart';
import '../../../core/services/tour_session_service.dart';
import '../../../core/services/tour_status_resolver.dart';
import '../../../core/theme/app_colors.dart';
import '../../itinerary/models/itinerary_item.dart';
import 'add_edit_itinerary_screen.dart';
import 'tour_guide_home_screen.dart';
import 'tour_guide_stop_attendance_screen.dart';

/// Screen to view and manage the tour itinerary with OpenStreetMap integration.
class TourGuideItineraryScreen extends StatefulWidget {
  final String? sessionId;
  final String? tourId;

  const TourGuideItineraryScreen({
    super.key,
    this.sessionId,
    this.tourId,
  });

  String get effectiveId {
    if (tourId != null && tourId!.isNotEmpty) return tourId!;
    if (sessionId != null && sessionId!.isNotEmpty) return sessionId!;
    return '';
  }

  @override
  State<TourGuideItineraryScreen> createState() =>
      _TourGuideItineraryScreenState();
}

class _TourGuideItineraryScreenState extends State<TourGuideItineraryScreen> {
  final Set<String> _deletingIds = {};
  Tour? _tour;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _loadTour();
    ItineraryService.syncChronologicalOrder(widget.effectiveId);
    // Periodically re-evaluate time-based status (upcoming -> ongoing -> completed)
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTour() async {
    final t = await TourService.getTour(widget.effectiveId);
    if (mounted) setState(() => _tour = t);
  }

  Future<void> _navigateToAddEdit({ItineraryItem? item}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditItineraryScreen(
          itemToEdit: item,
          sessionId: widget.effectiveId,
          tourStartDate: _tour?.startDate,
          tourEndDate: _tour?.endDate,
          tourStartDateTime: _tour != null ? TourStatusResolver.getTourStartDateTime(_tour!) : null,
          tourEndDateTime: _tour != null ? TourStatusResolver.getTourEndDateTime(_tour!) : null,
        ),
      ),
    );
  }

  Future<void> _deleteStop(ItineraryItem stop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Stop?'),
        content: Text('Remove "${stop.destinationName}" from the itinerary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingIds.add(stop.id));
    try {
      await ItineraryService.deleteStop(widget.effectiveId, stop.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete stop.')),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(stop.id));
    }
  }

  void _openAttendance(ItineraryItem stop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TourGuideStopAttendanceScreen(
          stop: stop,
          sessionId: widget.effectiveId,
        ),
      ),
    );
  }

  Future<void> _markDone(ItineraryItem stop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mark as Done?'),
        content: Text('Mark "${stop.destinationName}" as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ItineraryService.markStopDone(widget.effectiveId, stop.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to mark stop as done.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TourSession>(
      stream: TourSessionService.watchSession(widget.effectiveId),
      builder: (context, sessionSnapshot) {
        final session = sessionSnapshot.data;
        final tourName = _tour?.name ?? session?.tourName ?? 'Tour Itinerary';

        return StreamBuilder<List<ItineraryItem>>(
          stream: ItineraryService.watchItinerary(widget.effectiveId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final stops = snapshot.data ?? [];
            final titleText = stops.isEmpty ? 'Tour Itinerary' : tourName;

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  titleText,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const TourGuideHomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
              body: stops.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        _buildProgress(stops),
                        Expanded(child: _buildTimeline(stops)),
                      ],
                    ),
              floatingActionButton: stops.isEmpty ? null : _buildFab(),
            );
          },
        );
      },
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      heroTag: 'addStop',
      onPressed: _navigateToAddEdit,
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
      label: const Text('Add Stop', style: TextStyle(color: Colors.white)),
    );
  }

  Widget _buildProgress(List<ItineraryItem> stops) {
    final completed =
        stops.where((s) => s.effectiveStatus == ItineraryStatus.completed).length;
    final percent = stops.isEmpty ? 0.0 : completed / stops.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tour Progress',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textSecondary)),
              Text('$completed / ${stops.length} Stops Completed',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percent,
            backgroundColor: AppColors.primarySurface,
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_rounded, size: 64, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              'No itinerary yet.\nTap + Add Stop to create your first destination.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToAddEdit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Stop'),
            ),
          ],
        ),
      ),
    );
  }

  int _getDayNumber(ItineraryItem stop, List<ItineraryItem> allStops) {
    if (_tour != null) {
      final dn = _tour!.dayNumberForDate(stop.date);
      if (dn > 0) return dn;
    }
    final uniqueDates = allStops
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet()
        .toList()
      ..sort();
    final stopDate = DateTime(stop.date.year, stop.date.month, stop.date.day);
    final idx = uniqueDates.indexOf(stopDate);
    return idx >= 0 ? idx + 1 : 1;
  }

  int _getStopNumberInDay(int index, List<ItineraryItem> allStops) {
    final current = allStops[index];
    int count = 0;
    for (int i = 0; i <= index; i++) {
      final s = allStops[i];
      if (s.date.year == current.date.year &&
          s.date.month == current.date.month &&
          s.date.day == current.date.day) {
        count++;
      }
    }
    return count;
  }

  bool _isFirstStopOfDay(int index, List<ItineraryItem> allStops) {
    if (index == 0) return true;
    final current = allStops[index];
    final prev = allStops[index - 1];
    return current.date.year != prev.date.year ||
        current.date.month != prev.date.month ||
        current.date.day != prev.date.day;
  }

  Widget _buildDayHeader(int dayNumber, DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'DAY $dayNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            Tour.formatDate(date),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(color: Colors.grey.shade300, height: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<ItineraryItem> stops) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: stops.length,
      itemBuilder: (_, index) => _buildStopCard(stops[index], index, stops),
    );
  }

  Widget _buildStopCard(ItineraryItem stop, int index, List<ItineraryItem> stops) {
    final isLast = index == stops.length - 1;
    final isDeleting = _deletingIds.contains(stop.id);
    final currentStatus = stop.effectiveStatus;
    final isNewDay = _isFirstStopOfDay(index, stops);
    final dayNumber = _getDayNumber(stop, stops);
    final stopNumberInDay = _getStopNumberInDay(index, stops);
    final isLastInDay = isLast || _isFirstStopOfDay(index + 1, stops);

    final cardContent = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Vertical Timeline Spine ──
          Column(
            children: [
              if (!isNewDay) Container(width: 2, height: 20, color: AppColors.primarySurface),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: currentStatus == ItineraryStatus.completed
                      ? AppColors.success
                      : (currentStatus == ItineraryStatus.ongoing
                          ? const Color(0xFFF5A623)
                          : AppColors.primary),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: currentStatus == ItineraryStatus.completed
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text(
                          '$stopNumberInDay',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              if (!isLastInDay) Expanded(child: Container(width: 2, color: AppColors.primarySurface)),
            ],
          ),
          const SizedBox(width: 12),
          // ── Main Card ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLastInDay ? 12 : 8, top: isNewDay ? 0 : 20),
              child: Opacity(
                opacity: isDeleting ? 0.5 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Info
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(stop.destinationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                    _buildStatusBadge(currentStatus),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textHint),
                                    const SizedBox(width: 4),
                                    Text('${stop.startTime} – ${stop.endTime}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                                if (stop.notes.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.notes_rounded, size: 14, color: AppColors.textHint),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(stop.notes, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                StreamBuilder<({int presentCount, int totalCount})>(
                                  stream: AttendanceService.watchStopAttendanceSummary(
                                    widget.effectiveId,
                                    stop.id,
                                  ),
                                  builder: (context, snap) {
                                    final data = snap.data;
                                    final present = data?.presentCount ?? 0;
                                    final total = data?.totalCount ?? 0;
                                    return Row(
                                      children: [
                                        const Icon(Icons.people_alt_rounded,
                                            size: 14, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$present / $total Present',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          // Embedded Map Preview (if lat/lng exists)
                          if (stop.latitude != 0.0) _buildMapPreview(stop),
                          // Actions
                          const Divider(height: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                onPressed: () => _openAttendance(stop),
                                icon: const Icon(Icons.checklist_rounded, size: 18),
                                label: const Text('Attendance', style: TextStyle(fontSize: 12)),
                              ),

                              // If completed: NO Edit, NO Delete, NO Done!
                              if (currentStatus != ItineraryStatus.completed) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  onPressed: () => _navigateToAddEdit(item: stop),
                                  tooltip: 'Edit Stop',
                                ),

                                // Delete allowed only for upcoming stops (destructive changes restricted for ongoing)
                                if (currentStatus == ItineraryStatus.upcoming)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                    onPressed: isDeleting ? null : () => _deleteStop(stop),
                                    tooltip: 'Delete Stop',
                                  ),

                                // "Done" button — only shown when stop is not yet completed
                                TextButton.icon(
                                  onPressed: isDeleting ? null : () => _markDone(stop),
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.success),
                                  label: const Text('Done', style: TextStyle(fontSize: 12, color: AppColors.success)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Route to next stop UI
                    if (!isLast && stop.distanceToNext != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.textHint),
                            const SizedBox(width: 8),
                            Text(stop.distanceToNext! >= 1000 ? '\${(stop.distanceToNext! / 1000).toStringAsFixed(1)} km' : '\${stop.distanceToNext!.toStringAsFixed(0)} m', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                            const SizedBox(width: 16),
                            Icon(stop.distanceToNext! < 1000 ? Icons.directions_walk_rounded : Icons.directions_car_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text('${(stop.durationToNext! / 60).ceil()} min', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      key: ValueKey(stop.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNewDay) _buildDayHeader(dayNumber, stop.date),
        cardContent,
      ],
    );
  }

  Widget _buildStatusBadge(ItineraryStatus status) {
    Color bg;
    Color fg;
    String text;
    switch (status) {
      case ItineraryStatus.upcoming:
        bg = AppColors.primarySurface; fg = AppColors.primary; text = 'Upcoming';
        break;
      case ItineraryStatus.ongoing:
        bg = AppColors.success.withValues(alpha: 0.1); fg = AppColors.success; text = 'Ongoing';
        break;
      case ItineraryStatus.completed:
        bg = AppColors.textHint.withValues(alpha: 0.1); fg = AppColors.textSecondary; text = 'Completed';
        break;
      case ItineraryStatus.skipped:
        bg = AppColors.error.withValues(alpha: 0.1); fg = AppColors.error; text = 'Skipped';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMapPreview(ItineraryItem stop) {
    List<LatLng> points = [];
    if (stop.encodedPolyline != null) {
      final decoded = PolylinePoints.decodePolyline(stop.encodedPolyline!);
      points = decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
    }

    return SizedBox(
      height: 120,
      width: double.infinity,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(stop.latitude, stop.longitude),
              initialZoom: 14.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none), // static preview
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tourvia.app',
              ),
              if (points.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: points, strokeWidth: 4.0, color: AppColors.primary),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(stop.latitude, stop.longitude),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: AppColors.error, size: 30),
                  ),
                ],
              ),
            ],
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // In the future, this could open a full-screen map modal.
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
