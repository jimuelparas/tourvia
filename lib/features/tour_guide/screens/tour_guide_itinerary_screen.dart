
import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/itinerary_service.dart';
import '../../../core/services/tour_session_service.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../itinerary/models/itinerary_item.dart';
import '../../weather/screens/weather_screen.dart';
import 'add_edit_itinerary_screen.dart';
import 'tour_guide_stop_attendance_screen.dart';

/// Screen to view and manage the tour itinerary with per-stop attendance (US-07/08).
///
/// All data is now backed by Firestore via [ItineraryService].
/// [sessionId] is passed in from the home screen (currently using
/// a placeholder until session management is wired up).
class TourGuideItineraryScreen extends StatefulWidget {
  final String sessionId;

  const TourGuideItineraryScreen({
    super.key,
    this.sessionId = 'demo-session-001',
  });

  @override
  State<TourGuideItineraryScreen> createState() =>
      _TourGuideItineraryScreenState();
}

class _TourGuideItineraryScreenState extends State<TourGuideItineraryScreen> {
  // Track which stop is being deleted so we can show a spinner
  final Set<String> _deletingIds = {};

  // ── Firestore CRUD ───────────────────────────────────────

  Future<void> _navigateToAddEdit({ItineraryItem? item}) async {
    final result = await Navigator.of(context).push<ItineraryItem>(
      MaterialPageRoute(
        builder: (_) => AddEditItineraryScreen(
          itemToEdit: item,
          sessionId: widget.sessionId,
        ),
      ),
    );
    // result is null if user cancelled
    if (result == null) return;
    // Firestore write is done inside AddEditItineraryScreen — nothing needed here.
    // The StreamBuilder will auto-update.
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
      await ItineraryService.deleteStop(widget.sessionId, stop.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${stop.destinationName}"'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete stop. Please try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(stop.id));
    }
  }

  Future<void> _onReorder(List<ItineraryItem> stops, int oldIndex, int newIndex) async {
    // Optimistic UI: we just rely on Firestore stream to re-render
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
        const SnackBar(
          content: Text('Could not save new order.'),
          behavior: SnackBarBehavior.floating,
        ),
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

  Future<void> _showEditTourNameDialog(BuildContext context, String currentName, TourSession? session) async {
    final nameCtrl = TextEditingController(text: currentName == 'Unnamed Tour' ? '' : currentName);
    final currentDayCtrl = TextEditingController(text: session?.currentDay.toString() ?? '1');
    final totalDaysCtrl = TextEditingController(text: session?.totalDays.toString() ?? '3');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Tour Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tour Title / Name',
                hintText: 'e.g. Baguio City Heritage Tour',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: currentDayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Current Day',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: totalDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Days',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final curDay = int.tryParse(currentDayCtrl.text) ?? 1;
              final totDays = int.tryParse(totalDaysCtrl.text) ?? 3;
              if (newName.isNotEmpty) {
                await TourSessionService.updateSession(
                  widget.sessionId,
                  tourName: newName,
                  currentDay: curDay,
                  totalDays: totDays,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────

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
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Tour Itinerary'),
                  backgroundColor: AppColors.surface,
                  elevation: 0,
                  centerTitle: true,
                  leading: const BackButton(),
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Failed to load itinerary.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error, fontSize: 14),
                    ),
                  ),
                ),
              );
            }

            final stops = snapshot.data ?? [];
            final titleText = stops.isEmpty ? 'Tour Itinerary' : tourName;

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleText,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.textHint),
                      tooltip: 'Edit Tour Details',
                      onPressed: () => _showEditTourNameDialog(context, tourName, session),
                    ),
                  ],
                ),
                backgroundColor: AppColors.surface,
                elevation: 0,
                centerTitle: true,
                leading: const BackButton(),
              ),
              body: stops.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        _buildWeatherBanner(context, session),
                        Expanded(child: _buildTimeline(stops)),
                      ],
                    ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _navigateToAddEdit(),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  AppStrings.addStopButton,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            );
          },
        );
      },
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
      future: WeatherService.fetchWeather(
        latitude: lat,
        longitude: lon,
        locationName: name,
      ),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final tempStr = info != null ? '${info.tempC.toStringAsFixed(0)}°C' : '28°C';
        final descStr = info?.description ?? 'Partly Cloudy';
        final locationStr = info?.locationName ?? name;
        final rainStr = info != null ? 'Rain ${info.rainProbability}%' : 'Rain 65%';

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WeatherScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$tempStr  •  $descStr',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
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
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop_rounded,
                          color: Colors.lightBlueAccent, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        rainStr,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white70, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_rounded,
                  size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.emptyItineraryTG,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToAddEdit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Stop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(List<ItineraryItem> stops) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: stops.length,
      onReorder: (oldIndex, newIndex) =>
          _onReorder(stops, oldIndex, newIndex),
      itemBuilder: (_, index) => _buildStopCard(stops[index], index, stops),
    );
  }

  Widget _buildStopCard(
      ItineraryItem stop, int index, List<ItineraryItem> stops) {
    final isFirst = index == 0;
    final isLast = index == stops.length - 1;
    final isDeleting = _deletingIds.contains(stop.id);

    return IntrinsicHeight(
      key: ValueKey(stop.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline spine ─────────────────────────────────
          Column(
            children: [
              if (!isFirst)
                Container(
                    width: 2, height: 20, color: AppColors.primarySurface),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.primarySurface,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // ── Stop card ──────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: isLast ? 0 : 16, top: isFirst ? 0 : 20),
              child: Opacity(
                opacity: isDeleting ? 0.5 : 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stop.destinationName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded,
                                          size: 13, color: AppColors.textHint),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${stop.startTime} – ${stop.endTime}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color:
                                                    AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Edit button
                            IconButton(
                              icon: const Icon(Icons.edit_rounded,
                                  color: AppColors.textHint, size: 20),
                              tooltip: 'Edit Stop',
                              onPressed: isDeleting
                                  ? null
                                  : () => _navigateToAddEdit(item: stop),
                            ),
                            // Delete button
                            isDeleting
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.error),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.error,
                                        size: 20),
                                    tooltip: 'Delete Stop',
                                    onPressed: () => _deleteStop(stop),
                                  ),
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.drag_handle_rounded,
                                  color: AppColors.border),
                            ),
                          ],
                        ),
                      ),
                      if (stop.notes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    stop.notes,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: AppColors.textSecondary,
                                            height: 1.4),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.border),
                      // ── Attendance mini-row ─────────────────
                      InkWell(
                        onTap: () => _openAttendance(stop),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.checklist_rounded,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              const Text('Attendance',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              const Spacer(),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 18, color: AppColors.textHint),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
