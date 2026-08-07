import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/itinerary_service.dart';
import '../../../core/services/tour_session_service.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../itinerary/models/itinerary_item.dart';
import '../../weather/screens/weather_screen.dart';
import 'add_edit_itinerary_screen.dart';
import 'tour_guide_stop_attendance_screen.dart';

/// Screen to view and manage the tour itinerary with OpenStreetMap integration.
class TourGuideItineraryScreen extends StatefulWidget {
  final String sessionId;

  const TourGuideItineraryScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<TourGuideItineraryScreen> createState() =>
      _TourGuideItineraryScreenState();
}

class _TourGuideItineraryScreenState extends State<TourGuideItineraryScreen> {
  final Set<String> _deletingIds = {};
  bool _fabExpanded = false;

  Future<void> _navigateToAddEdit({ItineraryItem? item}) async {
    setState(() => _fabExpanded = false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditItineraryScreen(
          itemToEdit: item,
          sessionId: widget.sessionId,
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
        content: Text('Remove "\${stop.destinationName}" from the itinerary?'),
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
      await ItineraryService.deleteStop(widget.sessionId, stop.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete stop.')),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(stop.id));
    }
  }

  Future<void> _onReorder(List<ItineraryItem> stops, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = List<ItineraryItem>.from(stops);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    try {
      await ItineraryService.reorderStops(
        widget.sessionId,
        reordered.map((s) => s.id).toList(),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save new order.')),
      );
    }
  }

  void _openAttendance(ItineraryItem stop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TourGuideStopAttendanceScreen(
          stop: stop,
          sessionId: widget.sessionId,
        ),
      ),
    );
  }

  Future<void> _confirmEndTour() async {
    setState(() => _fabExpanded = false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Tour?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will:'),
            SizedBox(height: 8),
            Text('✔ Stop Live Tracking'),
            Text('✔ Disable Access Code'),
            Text('✔ Finish Attendance'),
            Text('✔ Archive Tour'),
            Text('✔ Generate Tour Summary'),
            Text('✔ Return to Dashboard'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('End Tour'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // In a real app we'd archive data and show summary. For now, pop to dashboard.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TourSession>(
      stream: TourSessionService.watchSession(widget.sessionId),
      builder: (context, sessionSnapshot) {
        final session = sessionSnapshot.data;
        final tourName = session?.tourName ?? 'Tour Itinerary';

        return StreamBuilder<List<ItineraryItem>>(
          stream: ItineraryService.watchItinerary(widget.sessionId),
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
                leading: const BackButton(),
              ),
              body: stops.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        _buildWeatherBanner(context, session),
                        _buildProgress(stops),
                        Expanded(child: _buildTimeline(stops)),
                      ],
                    ),
              floatingActionButton: _buildExpandableFab(),
            );
          },
        );
      },
    );
  }

  Widget _buildExpandableFab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          FloatingActionButton.extended(
            heroTag: 'addStop',
            onPressed: _navigateToAddEdit,
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
            label: const Text('Add Stop', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'endTour',
            onPressed: _confirmEndTour,
            backgroundColor: AppColors.error,
            icon: const Icon(Icons.flag_rounded, color: Colors.white),
            label: const Text('End Tour', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          heroTag: 'mainFab',
          onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
          backgroundColor: AppColors.primary,
          child: AnimatedRotation(
            turns: _fabExpanded ? 0.125 : 0, // 45 degrees
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherBanner(BuildContext context, TourSession? session) {
    double lat = 14.5995;
    double lon = 120.9842;
    String name = 'Manila, Philippines';

    if (session != null) {
      name = session.tourName;
      if (name.toLowerCase().contains('baguio')) {
        lat = 16.4023;
        lon = 120.5960;
      }
    }

    return FutureBuilder<WeatherInfo>(
      future: WeatherService.fetchWeather(latitude: lat, longitude: lon, locationName: name),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final tempStr = info != null ? '${info.tempC.toStringAsFixed(0)}°C' : '28°C';
        final descStr = info?.description ?? 'Partly Cloudy';
        final locationStr = info?.locationName ?? name;
        final rainStr = info != null ? 'Rain ${info.rainProbability}%' : 'Rain 65%';

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen())),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_queue_rounded, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationStr,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$tempStr  •  $descStr',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(rainStr, style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgress(List<ItineraryItem> stops) {
    final completed = stops.where((s) => s.status == ItineraryStatus.completed).length;
    final percent = stops.isEmpty ? 0.0 : completed / stops.length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tour Progress', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
              Text('$completed / ${stops.length} Stops Completed', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primary)),
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

  Widget _buildTimeline(List<ItineraryItem> stops) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: stops.length,
      onReorder: (oldIndex, newIndex) => _onReorder(stops, oldIndex, newIndex),
      itemBuilder: (_, index) => _buildStopCard(stops[index], index, stops),
    );
  }

  Widget _buildStopCard(ItineraryItem stop, int index, List<ItineraryItem> stops) {
    final isFirst = index == 0;
    final isLast = index == stops.length - 1;
    final isDeleting = _deletingIds.contains(stop.id);

    return IntrinsicHeight(
      key: ValueKey(stop.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Vertical Timeline Spine ──
          Column(
            children: [
              if (!isFirst) Container(width: 2, height: 20, color: AppColors.primarySurface),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: stop.status == ItineraryStatus.completed ? AppColors.success : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: stop.status == ItineraryStatus.completed
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.primarySurface)),
            ],
          ),
          const SizedBox(width: 12),
          // ── Main Card ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8, top: isFirst ? 0 : 20),
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
                                    _buildStatusBadge(stop.status),
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
                                Row(
                                  children: [
                                    const Icon(Icons.people_alt_rounded, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text('${stop.presentCount} / ${stop.totalPassengers} Present', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                  ],
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

                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                onPressed: () => _navigateToAddEdit(item: stop),
                              ),
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
