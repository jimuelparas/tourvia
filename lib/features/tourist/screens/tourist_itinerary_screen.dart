import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/tourist_session.dart';
import '../../../core/services/attendance_service.dart';
import '../../../core/services/itinerary_service.dart';
import '../../../core/services/tour_session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../attendance/models/tourist_attendance.dart';
import '../../itinerary/models/itinerary_item.dart' hide AttendanceStatus;

/// Read-only itinerary view for the tourist (US-09).
///
/// Listens to a Firestore stream so any guide update is reflected live.
/// Also shows the tourist's own attendance status per stop, pulled
/// from the Firestore attendance records (Step 6).
class TouristItineraryScreen extends StatefulWidget {
  const TouristItineraryScreen({super.key});

  @override
  State<TouristItineraryScreen> createState() => _TouristItineraryScreenState();
}

class _TouristItineraryScreenState extends State<TouristItineraryScreen> {
  // Streams
  StreamSubscription? _stopsSub;
  final Map<String, StreamSubscription> _attendanceSubs = {};

  // State
  List<ItineraryItem> _stops = [];
  // stopId → AttendanceRecord for THIS tourist
  final Map<String, AttendanceRecord?> _myAttendance = {};

  late String _sessionId;
  late String _myTouristId; // codeDocId from the session

  @override
  void initState() {
    super.initState();
    final session = TouristSessionManager.current;
    _sessionId = session?.sessionId ?? 'demo-session-001';
    _myTouristId = session?.codeDocId ?? '';

    _stopsSub =
        ItineraryService.watchItinerary(_sessionId).listen((stops) {
      if (!mounted) return;
      setState(() => _stops = stops);

      // Subscribe to attendance for each stop
      for (final stop in stops) {
        if (!_attendanceSubs.containsKey(stop.id)) {
          final sub = AttendanceService.watchAttendance(_sessionId, stop.id)
              .listen((records) {
            if (!mounted) return;
            setState(() {
              _myAttendance[stop.id] = records[_myTouristId];
            });
          });
          _attendanceSubs[stop.id] = sub;
        }
      }
    });
  }

  @override
  void dispose() {
    _stopsSub?.cancel();
    for (final sub in _attendanceSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────

  Color _statusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return AppColors.success;
      case AttendanceStatus.absent:
        return AppColors.error;
      case AttendanceStatus.pending:
        return AppColors.textHint;
    }
  }

  IconData _statusIcon(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return Icons.check_circle_rounded;
      case AttendanceStatus.absent:
        return Icons.cancel_rounded;
      case AttendanceStatus.pending:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  String _statusLabel(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.pending:
        return 'Pending';
    }
  }

  String? _checkInStr(AttendanceRecord? rec) {
    final dt = rec?.checkInTime;
    if (dt == null) return null;
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TourSession>(
      stream: TourSessionService.watchSession(_sessionId),
      builder: (context, sessionSnapshot) {
        final session = sessionSnapshot.data;
        final tourName = session?.tourName ?? 'Tour Itinerary';
        final titleText = _stops.isEmpty ? 'Tour Itinerary' : tourName;

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
          body: _stops.isEmpty
              ? _buildEmptyState(context)
              : _buildTimeline(context),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_rounded,
                  size: 64, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.emptyItineraryTourist,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _stops.length,
      itemBuilder: (_, index) {
        final stop = _stops[index];
        final isLast = index == _stops.length - 1;
        final isFirst = index == 0;
        final myRecord = _myAttendance[stop.id];
        final myStatus = myRecord?.status ?? AttendanceStatus.pending;
        final nodeColor = myStatus == AttendanceStatus.present
            ? AppColors.success
            : myStatus == AttendanceStatus.absent
                ? AppColors.error
                : AppColors.accent;

        return _buildTimelineNode(
            context, stop, index, isLast, isFirst, myRecord, myStatus, nodeColor);
      },
    );
  }

  Widget _buildTimelineNode(
    BuildContext context,
    ItineraryItem stop,
    int index,
    bool isLast,
    bool isFirst,
    AttendanceRecord? myRecord,
    AttendanceStatus myStatus,
    Color nodeColor,
  ) {
    final checkIn = _checkInStr(myRecord);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline spine ──────────────────────────────
          Column(
            children: [
              if (!isFirst)
                Container(
                    width: 2,
                    height: 20,
                    color: AppColors.accent.withValues(alpha: 0.5)),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: nodeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: nodeColor.withValues(alpha: 0.35),
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
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.accent.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // ── Content card ───────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: isLast ? 0 : 20, top: isFirst ? 0 : 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: myStatus == AttendanceStatus.present
                        ? AppColors.success.withValues(alpha: 0.3)
                        : myStatus == AttendanceStatus.absent
                            ? AppColors.error.withValues(alpha: 0.3)
                            : AppColors.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Stop title ─────────────────────
                      Text(
                        stop.destinationName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      // ── Time ───────────────────────────
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Text(
                            '${stop.startTime} – ${stop.endTime}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                      // ── Notes ──────────────────────────
                      if (stop.notes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
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
                                        height: 1.4,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.border),
                      // ── My attendance status ───────────
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              _statusIcon(myStatus),
                              size: 16,
                              color: _statusColor(myStatus),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'My Status: ',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                            Text(
                              _statusLabel(myStatus),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(myStatus),
                              ),
                            ),
                            if (checkIn != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '· $checkIn',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint),
                              ),
                            ],
                          ],
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
