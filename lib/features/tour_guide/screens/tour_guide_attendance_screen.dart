import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/attendance_service.dart';
import '../../../core/services/itinerary_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../attendance/models/tourist_attendance.dart';
import '../../itinerary/models/itinerary_item.dart' hide AttendanceStatus;
import '../../tracking/screens/tour_guide_map_screen.dart';

/// Screen to monitor tourist attendance (US-10 / US-26).
///
/// Tab 1 — "All Tourists": roster of every joined tourist with overall status.
/// Tab 2 — "By Stop": pick an itinerary stop and mark attendance per tourist.
class TourGuideAttendanceScreen extends StatefulWidget {
  final String sessionId;

  const TourGuideAttendanceScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<TourGuideAttendanceScreen> createState() =>
      _TourGuideAttendanceScreenState();
}

class _TourGuideAttendanceScreenState extends State<TourGuideAttendanceScreen> {
  // ── Live data ────────────────────────────────────────────
  List<TouristRecord> _roster = [];
  List<ItineraryItem> _stops = [];

  // For "By Stop" tab — selected stop + its attendance
  ItineraryItem? _selectedStop;
  Map<String, AttendanceRecord> _stopRecords = {};

  StreamSubscription? _rosterSub;
  StreamSubscription? _stopsSub;
  StreamSubscription? _recordsSub;

  @override
  void initState() {
    super.initState();

    _rosterSub = AttendanceService.watchRoster(widget.sessionId).listen((r) {
      if (mounted) setState(() => _roster = r);
    });

    _stopsSub =
        ItineraryService.watchItinerary(widget.sessionId).listen((stops) {
      if (!mounted) return;
      setState(() {
        _stops = stops;
        // Auto-select first stop if none chosen yet
        if (_selectedStop == null && stops.isNotEmpty) {
          _selectedStop = stops.first;
          _subscribeToRecords(_selectedStop!.id);
        }
      });
    });
  }

  void _subscribeToRecords(String stopId) {
    _recordsSub?.cancel();
    _recordsSub = AttendanceService.watchAttendance(widget.sessionId, stopId)
        .listen((recs) {
      if (mounted) setState(() => _stopRecords = recs);
    });
  }

  @override
  void dispose() {
    _rosterSub?.cancel();
    _stopsSub?.cancel();
    _recordsSub?.cancel();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────

  AttendanceStatus _statusFor(TouristRecord tourist) =>
      _stopRecords[tourist.codeDocId]?.status ?? AttendanceStatus.pending;

  String? _checkInStr(TouristRecord tourist) {
    final dt = _stopRecords[tourist.codeDocId]?.checkInTime;
    if (dt == null) return null;
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  Future<void> _markAllPresent() async {
    final pending = _roster
        .where((t) => _statusFor(t) == AttendanceStatus.pending)
        .toList();
    for (final t in pending) {
      await AttendanceService.markAttendance(
        sessionId: widget.sessionId,
        stopId: _selectedStop!.id,
        touristId: t.codeDocId,
        touristName: t.touristName,
        touristCode: t.code,
        status: AttendanceStatus.present,
      );
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          iconTheme: const IconThemeData(color: AppColors.primary),
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TourGuideMapScreen(sessionId: widget.sessionId),
              )),
              icon:
                  const Icon(Icons.map_rounded, color: AppColors.primary),
              tooltip: AppStrings.mapTitle,
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 16),
            tabs: const [
              Tab(text: AppStrings.tabAllTourists),
              Tab(text: AppStrings.tabByDestination),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildRosterTab(), _buildByStopTab()],
        ),
      ),
    );
  }

  // ── Tab 1: Roster (all tourists) ────────────────────────

  Widget _buildRosterTab() {
    if (_roster.isEmpty) {
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
                child: const Icon(Icons.people_outline_rounded,
                    size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'No tourists have joined yet.\nShare access codes to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${_roster.length} tourist${_roster.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _roster.length,
            itemBuilder: (_, i) => _rosterCard(_roster[i]),
          ),
        ),
      ],
    );
  }

  Widget _rosterCard(TouristRecord tourist) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primarySurface,
              radius: 24,
              child: Text(
                tourist.touristName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tourist.touristName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tourist.code,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.person_rounded,
                color: AppColors.success, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Tab 2: By Stop ───────────────────────────────────────

  Widget _buildByStopTab() {
    if (_stops.isEmpty) {
      return const Center(
        child: Text(
          'No itinerary stops found.\nAdd stops in the Itinerary screen.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
      );
    }

    final stop = _selectedStop;
    final presentCount = _roster
        .where((t) => _statusFor(t) == AttendanceStatus.present)
        .length;
    final absentCount = _roster
        .where((t) => _statusFor(t) == AttendanceStatus.absent)
        .length;
    final pendingCount = _roster
        .where((t) => _statusFor(t) == AttendanceStatus.pending)
        .length;

    return Column(
      children: [
        // Stop selector
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: DropdownButtonFormField<String>(
            value: _selectedStop?.id,
            decoration: InputDecoration(
              labelText: AppStrings.selectDestinationHint,
              prefixIcon: const Icon(Icons.place_rounded,
                  color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            items: _stops
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.destinationName)))
                .toList(),
            onChanged: (id) {
              final chosen =
                  _stops.firstWhere((s) => s.id == id);
              setState(() {
                _selectedStop = chosen;
                _stopRecords = {};
              });
              _subscribeToRecords(chosen.id);
            },
          ),
        ),

        if (stop != null) ...[
          // Stats summary bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                _miniStat('Present', presentCount, AppColors.success),
                const SizedBox(width: 8),
                _miniStat('Absent', absentCount, AppColors.error),
                const SizedBox(width: 8),
                _miniStat('Pending', pendingCount, AppColors.textHint),
              ],
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_roster.length} tourist${_roster.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (pendingCount > 0)
                  TextButton.icon(
                    onPressed: _markAllPresent,
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text(AppStrings.markAllPresentButton),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
        ],

        // Tourist list for selected stop
        if (stop != null && _roster.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No tourists yet. Share access codes.',
                style: TextStyle(color: AppColors.textHint),
              ),
            ),
          )
        else if (stop != null)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _roster.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _stopAttendanceCard(_roster[i], stop),
            ),
          ),
      ],
    );
  }

  Widget _miniStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _stopAttendanceCard(TouristRecord tourist, ItineraryItem stop) {
    final status = _statusFor(tourist);
    final checkIn = _checkInStr(tourist);
    Color color;
    IconData icon;
    switch (status) {
      case AttendanceStatus.present:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case AttendanceStatus.absent:
        color = AppColors.error;
        icon = Icons.cancel_rounded;
        break;
      case AttendanceStatus.pending:
        color = AppColors.textHint;
        icon = Icons.help_outline_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Text(
                tourist.touristName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tourist.touristName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Row(
                    children: [
                      Icon(icon, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        checkIn != null
                            ? '${_statusLabel(status)} · $checkIn'
                            : _statusLabel(status),
                        style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Quick action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status != AttendanceStatus.present)
                  _quickBtn(Icons.check_rounded, AppColors.success, () async {
                    await AttendanceService.markAttendance(
                      sessionId: widget.sessionId,
                      stopId: stop.id,
                      touristId: tourist.codeDocId,
                      touristName: tourist.touristName,
                      touristCode: tourist.code,
                      status: AttendanceStatus.present,
                    );
                  }),
                if (status != AttendanceStatus.absent) ...[
                  const SizedBox(width: 6),
                  _quickBtn(Icons.close_rounded, AppColors.error, () async {
                    await AttendanceService.markAttendance(
                      sessionId: widget.sessionId,
                      stopId: stop.id,
                      touristId: tourist.codeDocId,
                      touristName: tourist.touristName,
                      touristCode: tourist.code,
                      status: AttendanceStatus.absent,
                    );
                  }),
                ],
              ],
            ),
          ],
        ),
      ),
    );
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

  Widget _quickBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
